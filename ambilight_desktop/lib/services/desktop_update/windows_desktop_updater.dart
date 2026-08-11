import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Výsledek pokusu o start Windows OTA updateru.
class WindowsDesktopUpdateLaunchResult {
  const WindowsDesktopUpdateLaunchResult.ok({
    required this.logPath,
    required this.method,
    required this.sessionId,
  })  : ok = true,
        error = null;

  const WindowsDesktopUpdateLaunchResult.fail({
    required this.logPath,
    required this.error,
    this.method,
    this.sessionId,
  }) : ok = false;

  final bool ok;
  final String logPath;
  final String? error;
  final String? method;
  final String? sessionId;
}

/// Nahrazení instalace po ukončení běžícího procesu (Windows).
///
/// Odolnost:
/// - staging + logy v `%LOCALAPPDATA%\AmbiLight\ota`
/// - konfigurace přes JSON (žádné lámání uvozovek v CLI)
/// - launch cascade: WMI/VBS → CIM → scheduled task → detached Process.start
/// - heartbeat se session tokenem (nikdy starý log)
/// - PS skript ASCII + UTF-8 BOM (PS 5.1 -File)
/// - parse preflight před launch
class WindowsDesktopUpdater {
  WindowsDesktopUpdater._();

  static String get otaRoot {
    final local = Platform.environment['LOCALAPPDATA']?.trim();
    if (local != null && local.isNotEmpty) {
      return p.join(local, 'AmbiLight', 'ota');
    }
    return p.join(Directory.systemTemp.path, 'AmbiLight_ota');
  }

  static String get updateLogPath => p.join(otaRoot, 'ambi_update.log');
  static String get statusPath => p.join(otaRoot, 'ambi_update_status.json');
  static String get heartbeatPath => p.join(otaRoot, 'heartbeat.txt');

  /// `null` = OK, jinak lidská chyba.
  static String? preflightWritableInstallDir() {
    if (!Platform.isWindows) return 'Aktualizace na místě je jen pro Windows.';
    final targetDir = p.dirname(Platform.resolvedExecutable);
    try {
      Directory(targetDir).createSync(recursive: true);
      final probe = File(p.join(targetDir, '.ambi_update_write_probe'));
      probe.writeAsStringSync('ok-${DateTime.now().millisecondsSinceEpoch}', flush: true);
      probe.deleteSync();
      return null;
    } catch (e) {
      return 'Do složky instalace nelze zapisovat ($targetDir): $e. '
          'Spusť AmbiLight z rozbaleného ZIP (portable), ne z Program Files, '
          'nebo aktualizuj ručně přes GitHub Releases.';
    }
  }

  /// Ověří, že updater této session stále žije (heartbeat s tokenem).
  static Future<bool> isSessionHeartbeatAlive(String sessionId) async {
    if (sessionId.trim().isEmpty) return false;
    try {
      final hb = File(heartbeatPath);
      if (!await hb.exists()) return false;
      final t = (await hb.readAsString()).trim();
      return t.contains('session=$sessionId') &&
          (t.contains('ps: boot') || t.contains('ps: early'));
    } catch (_) {
      return false;
    }
  }

  /// Připraví balíček + spustí updater mimo Job Object. Teprve po heartbeat vrať OK.
  static Future<WindowsDesktopUpdateLaunchResult> launchExpandCopyRestart({
    required File zipFile,
    required int waitPid,
  }) async {
    final logPath = updateLogPath;
    if (!Platform.isWindows) {
      return WindowsDesktopUpdateLaunchResult.fail(
        logPath: logPath,
        error: 'Aktualizace na místě je jen pro Windows.',
      );
    }

    final sessionId = _newSessionId();

    try {
      final liveExe = Platform.resolvedExecutable;
      final targetDir = p.dirname(liveExe);
      final exeName = p.basename(liveExe);
      final work = Directory(otaRoot);
      await work.create(recursive: true);

      // Fresh log for this session — never treat old "ps: boot" as success.
      try {
        await File(logPath).writeAsString(
          '[${DateTime.now().toIso8601String()}] host: session=$sessionId log reset\n',
          flush: true,
        );
      } catch (_) {}

      await _appendHostLog(logPath, 'host: prepare begin session=$sessionId pid=$waitPid target=$targetDir');

      final zipOk = await _validateZip(zipFile);
      if (zipOk != null) {
        await _appendHostLog(logPath, 'host: zip invalid: $zipOk');
        return WindowsDesktopUpdateLaunchResult.fail(
          logPath: logPath,
          error: zipOk,
          sessionId: sessionId,
        );
      }

      final zipCopy = File(p.join(work.path, 'update.zip'));
      final script = File(p.join(work.path, 'apply_update.ps1'));
      final config = File(p.join(work.path, 'apply_config.json'));
      final stageDir = p.join(work.path, 'stage');
      final heartbeat = File(heartbeatPath);
      final status = File(statusPath);

      for (final f in [heartbeat, status]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      final copied = await _copyFileWithRetry(zipFile, zipCopy, attempts: 5);
      if (!copied) {
        const err = 'Nepodarilo se zkopirovat ZIP do OTA slozky.';
        await _appendHostLog(logPath, 'host: $err');
        return WindowsDesktopUpdateLaunchResult.fail(
          logPath: logPath,
          error: err,
          sessionId: sessionId,
        );
      }
      // ZIP je v OTA — temp download uz nepotrebujeme.
      await _deleteDownloadTempForZip(zipFile);

      final cfg = <String, dynamic>{
        'sessionId': sessionId,
        'waitPid': waitPid,
        'zipPath': zipCopy.path,
        'stageDir': stageDir,
        'targetDir': targetDir,
        'exeName': exeName,
        'logPath': logPath,
        'heartbeatPath': heartbeat.path,
        'statusPath': status.path,
        'workDir': work.path,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await _writeUtf8BomFile(config, const JsonEncoder.withIndent('  ').convert(cfg));
      await _writeUtf8BomFile(script, _psScript());

      final psExe = await _resolvePowerShellExe();
      final parseErr = await _validatePowerShellScript(
        psExe: psExe,
        scriptPath: script.path,
        logPath: logPath,
      );
      if (parseErr != null) {
        await _writeStatusFile({
          'state': 'error',
          'message': parseErr,
          'logPath': logPath,
          'sessionId': sessionId,
          'at': DateTime.now().toUtc().toIso8601String(),
          'source': 'host-parse',
        });
        return WindowsDesktopUpdateLaunchResult.fail(
          logPath: logPath,
          error: parseErr,
          sessionId: sessionId,
        );
      }

      // Prefer -File with quoted paths; BOM makes PS 5.1 read UTF-8.
      final psArgs =
          '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "${script.path}" -ConfigPath "${config.path}"';

      await _appendHostLog(logPath, 'host: powershell=$psExe');

      final methods = <({String name, Future<bool> Function() run})>[
        (
          name: 'wmi_vbs',
          run: () => _launchViaWmiVbs(
                workDir: work.path,
                logPath: logPath,
                psExe: psExe,
                psArgs: psArgs,
              ),
        ),
        (
          name: 'cim',
          run: () => _launchViaCim(
                workDir: work.path,
                logPath: logPath,
                psExe: psExe,
                psArgs: psArgs,
              ),
        ),
        (
          name: 'schtasks',
          run: () => _launchViaSchtasks(
                workDir: work.path,
                logPath: logPath,
                psExe: psExe,
                psArgs: psArgs,
              ),
        ),
        (
          name: 'detached',
          run: () => _launchViaDetached(
                workDir: work.path,
                logPath: logPath,
                psExe: psExe,
                scriptPath: script.path,
                configPath: config.path,
              ),
        ),
      ];

      String? lastErr;
      for (final m in methods) {
        // Clear stale heartbeat between attempts (keep session requirement).
        try {
          if (await heartbeat.exists()) await heartbeat.delete();
        } catch (_) {}

        await _appendHostLog(logPath, 'host: try launch method=${m.name}');
        var launched = false;
        try {
          launched = await m.run();
        } catch (e) {
          lastErr = '$e';
          await _appendHostLog(logPath, 'host: method=${m.name} threw $e');
          continue;
        }
        if (!launched) {
          lastErr = 'method ${m.name} returned false';
          await _appendHostLog(logPath, 'host: method=${m.name} failed');
          continue;
        }

        final alive = await _waitForSessionHeartbeat(
          sessionId: sessionId,
          heartbeat: heartbeat,
          timeout: const Duration(seconds: 25),
        );
        if (alive) {
          // Double-check still present (avoid race with instant-crash PS).
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final still = await isSessionHeartbeatAlive(sessionId);
          if (!still) {
            lastErr = 'method ${m.name}: heartbeat zmizel (updater spadl hned po startu)';
            await _appendHostLog(logPath, 'host: $lastErr');
            continue;
          }
          await _appendHostLog(logPath, 'host: heartbeat OK via ${m.name} session=$sessionId');
          return WindowsDesktopUpdateLaunchResult.ok(
            logPath: logPath,
            method: m.name,
            sessionId: sessionId,
          );
        }
        lastErr = 'method ${m.name}: updater nespustil heartbeat session=$sessionId do 25s';
        await _appendHostLog(logPath, 'host: $lastErr');
      }

      final err = lastErr ?? 'Nepodarilo se spustit updater zadnou metodou.';
      await _writeStatusFile({
        'state': 'error',
        'message': err,
        'logPath': logPath,
        'sessionId': sessionId,
        'at': DateTime.now().toUtc().toIso8601String(),
        'source': 'host',
      });
      return WindowsDesktopUpdateLaunchResult.fail(
        logPath: logPath,
        error: '$err Log: $logPath',
        sessionId: sessionId,
      );
    } catch (e, st) {
      await _appendHostLog(logPath, 'host: FATAL $e\n$st');
      await _writeStatusFile({
        'state': 'error',
        'message': 'Priprava updateru selhala: $e',
        'logPath': logPath,
        'sessionId': sessionId,
        'at': DateTime.now().toUtc().toIso8601String(),
        'source': 'host',
      });
      return WindowsDesktopUpdateLaunchResult.fail(
        logPath: logPath,
        error: 'Priprava updateru selhala: $e\nLog: $logPath',
        sessionId: sessionId,
      );
    }
  }

  static String _newSessionId() {
    final r = Random.secure();
    final n = List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${DateTime.now().millisecondsSinceEpoch}-$n';
  }

  static Future<void> _writeUtf8BomFile(File file, String content) async {
    final payload = utf8.encode(content);
    await file.writeAsBytes(<int>[0xEF, 0xBB, 0xBF, ...payload], flush: true);
  }

  static Future<void> _writeStatusFile(Map<String, dynamic> map) async {
    try {
      await Directory(otaRoot).create(recursive: true);
      await File(statusPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(map),
        flush: true,
      );
    } catch (_) {}
  }

  /// Catch PowerShell parse errors before launch (e.g. `$i:` drive-scope trap).
  static Future<String?> _validatePowerShellScript({
    required String psExe,
    required String scriptPath,
    required String logPath,
  }) async {
    final cmd = '''
\$errs = \$null
\$tokens = \$null
[void][System.Management.Automation.Language.Parser]::ParseFile(@'
$scriptPath
'@.Trim(), [ref]\$tokens, [ref]\$errs)
if (\$errs -and \$errs.Count -gt 0) {
  \$errs | ForEach-Object { \$_.ToString() }
  exit 1
}
Write-Output 'PARSE_OK'
exit 0
''';
    try {
      final r = await Process.run(
        psExe,
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', cmd],
        runInShell: false,
      ).timeout(const Duration(seconds: 20));
      await _appendHostLog(logPath, 'host: ps-parse exit=${r.exitCode} out=${'${r.stdout}'.trim()}');
      if (r.exitCode != 0) {
        final detail = '${r.stdout}\n${r.stderr}'.trim();
        return 'Aktualizacni skript ma chybu syntaxe PowerShell:\n$detail';
      }
      return null;
    } catch (e) {
      await _appendHostLog(logPath, 'host: ps-parse exception $e');
      return 'Kontrola syntaxe updater skriptu selhala: $e';
    }
  }

  static Future<String?> _validateZip(File zip) async {
    try {
      if (!await zip.exists()) return 'ZIP neexistuje.';
      final len = await zip.length();
      if (len < 64) return 'ZIP je prazdny nebo poskozeny ($len B).';
      final raf = await zip.open();
      try {
        final magic = await raf.read(4);
        if (magic.length < 2 || magic[0] != 0x50 || magic[1] != 0x4b) {
          return 'Soubor neni platny ZIP (spatna magicka hlavicka).';
        }
      } finally {
        await raf.close();
      }
      return null;
    } catch (e) {
      return 'Kontrola ZIP selhala: $e';
    }
  }

  static Future<bool> _copyFileWithRetry(File src, File dst, {required int attempts}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        if (await dst.exists()) {
          try {
            await dst.delete();
          } catch (_) {}
        }
        await src.copy(dst.path);
        final a = await src.length();
        final b = await dst.length();
        if (a == b && a > 0) return true;
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: 200 * (i + 1)));
    }
    return false;
  }

  static Future<void> _deleteDownloadTempForZip(File zip) async {
    try {
      final parent = zip.parent;
      final name = p.basename(parent.path);
      if (!name.startsWith('ambi_desktop_up_')) return;
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (_) {}
  }

  static Future<String> _resolvePowerShellExe() async {
    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final candidates = <String>[
      p.join(windir, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
      p.join(windir, 'SysWOW64', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
      'powershell.exe',
    ];
    for (final c in candidates) {
      if (c == 'powershell.exe') return c;
      if (await File(c).exists()) return c;
    }
    return 'powershell.exe';
  }

  static Future<void> _appendHostLog(String logPath, String msg) async {
    try {
      final f = File(logPath);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        '[${DateTime.now().toIso8601String()}] $msg\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  /// Only trust heartbeat file with this session id — never historical log text.
  static Future<bool> _waitForSessionHeartbeat({
    required String sessionId,
    required File heartbeat,
    required Duration timeout,
  }) async {
    final needle = 'session=$sessionId';
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await heartbeat.exists()) {
          final t = (await heartbeat.readAsString()).trim();
          if (t.contains(needle) && (t.contains('ps: boot') || t.contains('ps: early'))) {
            // Prefer full boot; accept early only if it stays and then becomes boot.
            if (t.contains('ps: boot')) return true;
          }
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // Final check: early-only is NOT enough to exit the app.
    try {
      if (await heartbeat.exists()) {
        final t = (await heartbeat.readAsString()).trim();
        if (t.contains(needle) && t.contains('ps: boot')) return true;
      }
    } catch (_) {}
    return false;
  }

  static String _vbsEscape(String s) => s.replaceAll('"', '""');

  static Future<bool> _launchViaWmiVbs({
    required String workDir,
    required String logPath,
    required String psExe,
    required String psArgs,
  }) async {
    final vbs = File(p.join(workDir, 'launch_wmi.vbs'));
    final cmdLine = '"$psExe" $psArgs';
    final body = '''
On Error Resume Next
Dim svc, startup, proc, ret, pid, fso, logf
Set fso = CreateObject("Scripting.FileSystemObject")
Function L(msg)
  Set logf = fso.OpenTextFile("${_vbsEscape(logPath)}", 8, True)
  logf.WriteLine "[" & Now & "] vbs: " & msg
  logf.Close
End Function
L "WMI Create begin"
Set svc = GetObject("winmgmts:\\\\.\\root\\cimv2")
If Err.Number <> 0 Then
  L "GetObject failed " & Err.Number & " " & Err.Description
  WScript.Quit 11
End If
Set startup = svc.Get("Win32_ProcessStartup").SpawnInstance_()
startup.ShowWindow = 0
Set proc = svc.Get("Win32_Process")
ret = proc.Create("${_vbsEscape(cmdLine)}", "${_vbsEscape(workDir)}", startup, pid)
If ret <> 0 Then
  L "Create failed ret=" & ret & " err=" & Err.Number & " " & Err.Description
  WScript.Quit 12
End If
L "Create ok pid=" & pid
WScript.Quit 0
''';
    await vbs.writeAsString(body, flush: true);
    final r = await Process.run(
      'wscript.exe',
      ['//Nologo', vbs.path],
      workingDirectory: workDir,
      runInShell: false,
    ).timeout(const Duration(seconds: 30));
    await _appendHostLog(logPath, 'host: wmi_vbs exit=${r.exitCode}');
    return r.exitCode == 0;
  }

  static Future<bool> _launchViaCim({
    required String workDir,
    required String logPath,
    required String psExe,
    required String psArgs,
  }) async {
    final helper = File(p.join(workDir, 'launch_cim.ps1'));
    final cmdLine = '"$psExe" $psArgs';
    await _writeUtf8BomFile(helper, '''
\$ErrorActionPreference = 'Stop'
try {
  \$cmd = @'
$cmdLine
'@
  \$dir = @'
$workDir
'@
  \$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine = \$cmd.Trim()
    CurrentDirectory = \$dir.Trim()
  }
  if (\$null -eq \$r -or \$r.ReturnValue -ne 0) {
    throw "CIM ReturnValue=\$(\$r.ReturnValue)"
  }
  Write-Output ("OK pid=" + \$r.ProcessId)
  exit 0
} catch {
  Write-Output ("ERR " + \$_)
  exit 1
}
''');

    final r = await Process.run(
      psExe,
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        helper.path,
      ],
      workingDirectory: workDir,
      runInShell: false,
    ).timeout(const Duration(seconds: 45));
    await _appendHostLog(logPath, 'host: cim exit=${r.exitCode} out=${'${r.stdout}'.trim()}');
    return r.exitCode == 0;
  }

  static Future<bool> _launchViaSchtasks({
    required String workDir,
    required String logPath,
    required String psExe,
    required String psArgs,
  }) async {
    const taskName = 'AmbiLightDesktopOTA';
    final runner = File(p.join(workDir, 'schtasks_run.cmd'));
    await runner.writeAsString(
      '@echo off\r\n"$psExe" $psArgs\r\n',
      flush: true,
    );
    final tr = runner.path;

    await Process.run('schtasks', ['/Delete', '/TN', taskName, '/F'], runInShell: false)
        .timeout(const Duration(seconds: 15));
    final create = await Process.run(
      'schtasks',
      [
        '/Create',
        '/TN',
        taskName,
        '/SC',
        'ONCE',
        '/ST',
        '00:00',
        '/RL',
        'LIMITED',
        '/F',
        '/TR',
        tr,
      ],
      runInShell: false,
    ).timeout(const Duration(seconds: 20));
    await _appendHostLog(
      logPath,
      'host: schtasks create exit=${create.exitCode} out=${'${create.stdout} ${create.stderr}'.trim()}',
    );
    if (create.exitCode != 0) return false;
    final run = await Process.run(
      'schtasks',
      ['/Run', '/TN', taskName],
      runInShell: false,
    ).timeout(const Duration(seconds: 15));
    await _appendHostLog(logPath, 'host: schtasks run exit=${run.exitCode}');
    unawaited(Future<void>.delayed(const Duration(minutes: 5), () async {
      try {
        await Process.run('schtasks', ['/Delete', '/TN', taskName, '/F'], runInShell: false);
      } catch (_) {}
    }));
    return run.exitCode == 0;
  }

  static Future<bool> _launchViaDetached({
    required String workDir,
    required String logPath,
    required String psExe,
    required String scriptPath,
    required String configPath,
  }) async {
    try {
      await Process.start(
        psExe,
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          scriptPath,
          '-ConfigPath',
          configPath,
        ],
        workingDirectory: workDir,
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      await _appendHostLog(logPath, 'host: detached Process.start issued');
      return true;
    } catch (e) {
      await _appendHostLog(logPath, 'host: detached failed $e');
      return false;
    }
  }

  /// ASCII-only apply script — avoids PS 5.1 -File encoding traps with diacritics.
  static String _psScript() => r'''
param(
  [Parameter(Mandatory = $true)][string] $ConfigPath
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Earliest possible alive signal (before JSON parse).
$script:LogPath = $null
$script:HeartbeatPath = $null
$script:StatusPath = $null
try {
  $otaDir = Split-Path -Parent $ConfigPath
  $script:LogPath = Join-Path $otaDir 'ambi_update.log'
  $script:HeartbeatPath = Join-Path $otaDir 'heartbeat.txt'
  $sidPeek = 'unknown'
  try {
    $rawPeek = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop
    if ($rawPeek -match '"sessionId"\s*:\s*"([^"]+)"') { $sidPeek = $Matches[1] }
  } catch {}
  $early = ("[{0}] ps: early session={1}" -f (Get-Date -Format o), $sidPeek)
  Add-Content -LiteralPath $script:LogPath -Value $early -Encoding UTF8 -ErrorAction SilentlyContinue
  Set-Content -LiteralPath $script:HeartbeatPath -Value $early -Encoding UTF8 -ErrorAction SilentlyContinue
} catch {}

function Write-Status([hashtable] $h) {
  try {
    if ($script:StatusPath) {
      ($h | ConvertTo-Json -Compress) | Set-Content -LiteralPath $script:StatusPath -Encoding UTF8
    }
  } catch {}
}

function Write-Log([string] $msg) {
  $line = ("[{0}] {1}" -f (Get-Date -Format o), $msg)
  try {
    $dir = Split-Path -Parent $script:LogPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
  } catch {}
  try {
    if ($script:HeartbeatPath) {
      Set-Content -LiteralPath $script:HeartbeatPath -Value $line -Encoding UTF8
    }
  } catch {}
}

function Get-MatchingProcs([string] $liveExe, [string] $procName) {
  $out = @()
  try {
    $all = Get-Process -Name $procName -ErrorAction SilentlyContinue
    foreach ($proc in @($all)) {
      $match = $false
      try {
        if ($proc.Path -and ($proc.Path -ieq $liveExe)) { $match = $true }
      } catch {}
      if (-not $match) {
        try {
          $mp = $proc.MainModule.FileName
          if ($mp -and ($mp -ieq $liveExe)) { $match = $true }
        } catch {}
      }
      if ($match) { $out += $proc }
    }
  } catch {}
  return $out
}

function Stop-AppInstances([string] $liveExe, [string] $procName, [int] $seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  do {
    $alive = @(Get-MatchingProcs $liveExe $procName)
    foreach ($proc in $alive) {
      Write-Log ("stop pid={0}" -f $proc.Id)
      try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    try {
      & taskkill.exe /F /IM $procName /T 2>$null | Out-Null
    } catch {}
    Start-Sleep -Milliseconds 350
    $alive = @(Get-MatchingProcs $liveExe $procName)
  } while (($alive.Count -gt 0) -and ((Get-Date) -lt $deadline))
  return @($alive)
}

function Expand-UpdateZip([string] $ZipPath, [string] $StageDir) {
  if (Test-Path -LiteralPath $StageDir) {
    Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

  $expanded = $false
  try {
    Write-Log "expand: Expand-Archive"
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $StageDir -Force
    $expanded = $true
  } catch {
    Write-Log ("expand: Expand-Archive failed: " + $_)
  }

  if (-not $expanded) {
    try {
      Write-Log "expand: System.IO.Compression.ZipFile"
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $StageDir)
      $expanded = $true
    } catch {
      Write-Log ("expand: ZipFile failed: " + $_)
    }
  }

  if (-not $expanded) {
    try {
      Write-Log "expand: tar -xf"
      & tar.exe -xf $ZipPath -C $StageDir
      if ($LASTEXITCODE -eq 0) { $expanded = $true }
    } catch {
      Write-Log ("expand: tar failed: " + $_)
    }
  }

  if (-not $expanded) { throw "ZIP extract failed with all methods." }
}

function Find-ContentRoot([string] $StageDir, [string] $ExeName) {
  $direct = Join-Path $StageDir $ExeName
  if (Test-Path -LiteralPath $direct) { return $StageDir }

  $top = @(Get-ChildItem -LiteralPath $StageDir -Force -ErrorAction SilentlyContinue)
  if (($top.Count -eq 1) -and $top[0].PSIsContainer) {
    $nested = Join-Path $top[0].FullName $ExeName
    if (Test-Path -LiteralPath $nested) { return $top[0].FullName }
  }

  $found = Get-ChildItem -LiteralPath $StageDir -Recurse -Filter $ExeName -File -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -ne $found) {
    Write-Log ("contentRoot via recursive find: " + $found.DirectoryName)
    return $found.DirectoryName
  }
  throw ("Archive missing " + $ExeName)
}

function Copy-UpdateTree([string] $ContentRoot, [string] $TargetDir) {
  $ok = $false
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    Write-Log ("copy attempt={0} robocopy" -f $attempt)
    $rcArgs = @(
      $ContentRoot, $TargetDir, '/E', '/IS', '/IT', '/R:60', '/W:1',
      '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
    )
    & robocopy.exe @rcArgs | Out-Null
    $rc = $LASTEXITCODE
    Write-Log ("robocopy exit={0}" -f $rc)
    if ($rc -lt 8) { $ok = $true; break }

    Write-Log ("copy attempt={0} Copy-Item fallback" -f $attempt)
    try {
      Copy-Item -Path (Join-Path $ContentRoot '*') -Destination $TargetDir -Recurse -Force -ErrorAction Stop
      $ok = $true
      break
    } catch {
      Write-Log ("Copy-Item failed: " + $_)
      Start-Sleep -Seconds (2 * $attempt)
    }
  }
  if (-not $ok) { throw "Copy into install dir failed." }
}

function Test-InstallOk([string] $liveExe, [string] $TargetDir) {
  if (-not (Test-Path -LiteralPath $liveExe)) { return $false }
  $appSo = Join-Path $TargetDir 'data\app.so'
  $flutterDll = Join-Path $TargetDir 'flutter_windows.dll'
  if (-not (Test-Path -LiteralPath $flutterDll)) {
    Write-Log "warn: missing flutter_windows.dll"
  }
  if (-not (Test-Path -LiteralPath $appSo)) {
    Write-Log "warn: missing data\app.so (may be ok for some layouts)"
  }
  try {
    $len = (Get-Item -LiteralPath $liveExe).Length
    if ($len -lt 1024) { return $false }
  } catch { return $false }
  return $true
}

function Update-StartMenuShortcut([string] $liveExe, [string] $TargetDir) {
  try {
    $lnkDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AmbiLight'
    if (-not (Test-Path -LiteralPath $lnkDir)) {
      New-Item -ItemType Directory -Path $lnkDir -Force | Out-Null
    }
    $lnkPath = Join-Path $lnkDir 'AmbiLight.lnk'
    $w = New-Object -ComObject WScript.Shell
    $s = $w.CreateShortcut($lnkPath)
    $s.TargetPath = $liveExe
    $s.WorkingDirectory = $TargetDir
    $s.WindowStyle = 1
    $s.Description = 'AmbiLight Desktop'
    $s.IconLocation = ($liveExe + ',0')
    $s.Save()
    Write-Log ("ps: start menu shortcut refreshed: " + $lnkPath)
  } catch {
    Write-Log ("ps: start menu shortcut failed: " + $_)
  }
}

function Invoke-OtaCleanup([string] $WorkDir, [string] $liveExe, [bool] $success) {
  Write-Log ("ps: cleanup begin success={0}" -f $success)
  try {
    & schtasks.exe /Delete /TN 'AmbiLightDesktopOTA' /F 2>$null | Out-Null
  } catch {}

  $names = @(
    'stage',
    'launch_wmi.vbs',
    'launch_cim.ps1',
    'schtasks_run.cmd',
    'apply_update.ps1',
    'apply_config.json',
    'heartbeat.txt'
  )
  if ($success) {
    $names += 'update.zip'
  }
  foreach ($n in $names) {
    try {
      $p = Join-Path $WorkDir $n
      if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log ("ps: cleanup removed {0}" -f $n)
      }
    } catch {}
  }

  if ($success -and $liveExe) {
    try {
      $bak = $liveExe + '.bak'
      if (Test-Path -LiteralPath $bak) {
        Remove-Item -LiteralPath $bak -Force -ErrorAction SilentlyContinue
        Write-Log "ps: cleanup removed exe.bak"
      }
    } catch {}
  }

  # Keep status JSON + log for the restarted UI report.
  Write-Log "ps: cleanup done (kept status + log)"
}

$liveExe = $null
$TargetDir = $null
$WorkDir = $null
$sessionId = 'unknown'

try {
  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw ("Config missing: " + $ConfigPath)
  }
  $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $script:LogPath = [string]$cfg.logPath
  $script:HeartbeatPath = [string]$cfg.heartbeatPath
  $script:StatusPath = [string]$cfg.statusPath
  $sessionId = [string]$cfg.sessionId
  if (-not $sessionId) { $sessionId = 'unknown' }
  $WaitPid = [int]$cfg.waitPid
  $ZipPath = [string]$cfg.zipPath
  $StageDir = [string]$cfg.stageDir
  $TargetDir = [string]$cfg.targetDir
  $ExeName = [string]$cfg.exeName
  $WorkDir = [string]$cfg.workDir
  if (-not $WorkDir) { $WorkDir = Split-Path -Parent $ConfigPath }

  Write-Log ("ps: boot session={0}" -f $sessionId)
  Write-Status @{ state = 'running'; phase = 'boot'; sessionId = $sessionId; at = (Get-Date -Format o) }
  Write-Log ("ps: start WaitPid={0} TargetDir={1} ZipPath={2}" -f $WaitPid, $TargetDir, $ZipPath)

  if (-not (Test-Path -LiteralPath $ZipPath)) { throw ("ZIP missing: " + $ZipPath) }
  $zipLen = (Get-Item -LiteralPath $ZipPath).Length
  Write-Log ("ps: zip bytes={0}" -f $zipLen)

  Expand-UpdateZip -ZipPath $ZipPath -StageDir $StageDir
  Write-Status @{ state = 'running'; phase = 'expanded'; sessionId = $sessionId; at = (Get-Date -Format o) }

  $contentRoot = Find-ContentRoot -StageDir $StageDir -ExeName $ExeName
  $probeExe = Join-Path $contentRoot $ExeName
  Write-Log ("ps: contentRoot={0} probe={1}" -f $contentRoot, $probeExe)

  $liveExe = Join-Path $TargetDir $ExeName
  $procName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

  $p = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
  if ($null -ne $p) {
    Write-Log ("ps: waiting for WaitPid={0}" -f $WaitPid)
    Wait-Process -Id $WaitPid -Timeout 240 -ErrorAction SilentlyContinue
  } else {
    Write-Log "ps: WaitPid already gone"
  }

  Write-Log "ps: stopping app instances"
  Write-Status @{ state = 'running'; phase = 'stopping'; sessionId = $sessionId; at = (Get-Date -Format o) }
  $left = Stop-AppInstances -liveExe $liveExe -procName $procName -seconds 120
  if ($left.Count -gt 0) {
    Write-Log "ps: force taskkill by image name"
    & taskkill.exe /F /IM ($procName + '.exe') /T 2>$null | Out-Null
    Start-Sleep -Seconds 2
    $left = Stop-AppInstances -liveExe $liveExe -procName $procName -seconds 30
  }
  if ($left.Count -gt 0) {
    throw ("Processes still running: " + (($left | ForEach-Object { $_.Id }) -join ','))
  }

  Start-Sleep -Seconds 1
  try {
    if (Test-Path -LiteralPath $liveExe) {
      Copy-Item -LiteralPath $liveExe -Destination ($liveExe + '.bak') -Force -ErrorAction SilentlyContinue
    }
  } catch {}

  Write-Status @{ state = 'running'; phase = 'copying'; sessionId = $sessionId; at = (Get-Date -Format o) }
  Copy-UpdateTree -ContentRoot $contentRoot -TargetDir $TargetDir

  if (-not (Test-InstallOk -liveExe $liveExe -TargetDir $TargetDir)) {
    throw ("Install looks incomplete after copy: " + $liveExe)
  }

  Write-Log ("ps: starting {0}" -f $liveExe)
  Write-Status @{ state = 'running'; phase = 'starting'; sessionId = $sessionId; at = (Get-Date -Format o) }
  $started = $false
  for ($i = 1; $i -le 5; $i++) {
    try {
      # PS 5.1 Start-Process uses -FilePath (NOT -LiteralPath).
      Start-Process -FilePath $liveExe -WorkingDirectory $TargetDir
      Start-Sleep -Seconds 2
      $running = @(Get-MatchingProcs $liveExe $procName)
      if ($running.Count -gt 0) {
        Write-Log ("ps: app running pid=" + $running[0].Id)
        $started = $true
        break
      }
      Write-Log ("ps: start attempt={0} - process not seen yet" -f $i)
    } catch {
      Write-Log ("ps: Start-Process failed attempt={0} err={1}" -f $i, $_)
      Start-Sleep -Seconds $i
    }
  }
  if (-not $started) {
    throw "App did not start after update."
  }

  Write-Status @{
    state = 'ok'
    phase = 'done'
    message = 'Update applied'
    sessionId = $sessionId
    logPath = $script:LogPath
    at = (Get-Date -Format o)
  }
  Write-Log ("ps: done session={0}" -f $sessionId)
  try { Update-StartMenuShortcut -liveExe $liveExe -TargetDir $TargetDir } catch {}
  try { Invoke-OtaCleanup -WorkDir $WorkDir -liveExe $liveExe -success $true } catch {}
  exit 0
} catch {
  $errMsg = "$_"
  try { Write-Log ("ERROR: " + $errMsg) } catch {}
  try {
    Write-Status @{
      state = 'error'
      message = $errMsg
      sessionId = $sessionId
      logPath = $script:LogPath
      at = (Get-Date -Format o)
    }
  } catch {}

  try {
    if ($liveExe -and (Test-Path -LiteralPath ($liveExe + '.bak'))) {
      Write-Log "ps: restoring exe from .bak"
      Copy-Item -LiteralPath ($liveExe + '.bak') -Destination $liveExe -Force -ErrorAction SilentlyContinue
    }
  } catch {
    Write-Log ("ps: restore bak failed: " + $_)
  }

  try {
    if ($liveExe -and (Test-Path -LiteralPath $liveExe) -and $TargetDir) {
      Write-Log "ps: restarting app after failure so UI can show error"
      Start-Process -FilePath $liveExe -WorkingDirectory $TargetDir
    }
  } catch {
    Write-Log ("ps: restart after failure failed: " + $_)
  }
  try {
    if (-not $WorkDir) { $WorkDir = Split-Path -Parent $ConfigPath }
    Invoke-OtaCleanup -WorkDir $WorkDir -liveExe $liveExe -success $false
  } catch {}
  exit 1
}
''';
}
