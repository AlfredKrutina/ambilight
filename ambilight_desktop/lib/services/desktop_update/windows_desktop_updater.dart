import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Výsledek pokusu o start Windows OTA updateru.
class WindowsDesktopUpdateLaunchResult {
  const WindowsDesktopUpdateLaunchResult.ok({
    required this.logPath,
    required this.method,
  })  : ok = true,
        error = null;

  const WindowsDesktopUpdateLaunchResult.fail({
    required this.logPath,
    required this.error,
    this.method,
  }) : ok = false;

  final bool ok;
  final String logPath;
  final String? error;
  final String? method;
}

/// Nahrazení instalace po ukončení běžícího procesu (Windows).
///
/// Odolnost:
/// - staging + logy v `%LOCALAPPDATA%\AmbiLight\ota`
/// - konfigurace přes JSON (žádné lámání uvozovek v CLI)
/// - launch cascade: WMI/VBS → CIM → scheduled task
/// - ověření heartbeatu v logu před `exit(0)`
/// - PowerShell: multi expand, taskkill, robocopy+copy fallback, verify, restart retry
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

  /// `null` = OK, jinak lidská chyba.
  static String? preflightWritableInstallDir() {
    if (!Platform.isWindows) return 'Aktualizace na místě je jen pro Windows.';
    final targetDir = p.dirname(Platform.resolvedExecutable);
    try {
      Directory(targetDir).createSync(recursive: true);
      final probe = File(p.join(targetDir, '.ambi_update_write_probe'));
      probe.writeAsStringSync('ok-${DateTime.now().millisecondsSinceEpoch}', flush: true);
      probe.deleteSync();
      // Disk space soft-check (need ~200 MiB free ideally; warn only via probe).
      return null;
    } catch (e) {
      return 'Do složky instalace nelze zapisovat ($targetDir): $e. '
          'Spusť AmbiLight z rozbaleného ZIP (portable), ne z Program Files, '
          'nebo aktualizuj ručně přes GitHub Releases.';
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

    try {
      final liveExe = Platform.resolvedExecutable;
      final targetDir = p.dirname(liveExe);
      final exeName = p.basename(liveExe);
      final work = Directory(otaRoot);
      await work.create(recursive: true);

      await _appendHostLog(logPath, 'host: prepare begin pid=$waitPid target=$targetDir');

      final zipOk = await _validateZip(zipFile);
      if (zipOk != null) {
        await _appendHostLog(logPath, 'host: zip invalid: $zipOk');
        return WindowsDesktopUpdateLaunchResult.fail(logPath: logPath, error: zipOk);
      }

      final zipCopy = File(p.join(work.path, 'update.zip'));
      final script = File(p.join(work.path, 'apply_update.ps1'));
      final config = File(p.join(work.path, 'apply_config.json'));
      final stageDir = p.join(work.path, 'stage');
      final heartbeat = File(p.join(work.path, 'heartbeat.txt'));
      final status = File(statusPath);

      // Reset markers
      for (final f in [heartbeat, status]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      final copied = await _copyFileWithRetry(zipFile, zipCopy, attempts: 5);
      if (!copied) {
        const err = 'Nepodařilo se zkopírovat ZIP do OTA složky.';
        await _appendHostLog(logPath, 'host: $err');
        return WindowsDesktopUpdateLaunchResult.fail(logPath: logPath, error: err);
      }

      final cfg = <String, dynamic>{
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
      await config.writeAsString(const JsonEncoder.withIndent('  ').convert(cfg), flush: true);
      await script.writeAsString(_psScript(), flush: true);

      final psExe = await _resolvePowerShellExe();
      final psArgs =
          '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "${script.path}" -ConfigPath "${config.path}"';

      await _appendHostLog(logPath, 'host: powershell=$psExe');

      // Cascade launch methods — first success that produces heartbeat wins.
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
      ];

      String? lastErr;
      for (final m in methods) {
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

        final alive = await _waitForUpdaterHeartbeat(
          logPath: logPath,
          heartbeat: heartbeat,
          timeout: const Duration(seconds: 20),
        );
        if (alive) {
          await _appendHostLog(logPath, 'host: heartbeat OK via ${m.name}');
          return WindowsDesktopUpdateLaunchResult.ok(logPath: logPath, method: m.name);
        }
        lastErr = 'method ${m.name}: updater nespustil heartbeat do 20s';
        await _appendHostLog(logPath, 'host: $lastErr');
      }

      final err = lastErr ?? 'Nepodařilo se spustit updater žádnou metodou.';
      await _writeStatusFile({
        'state': 'error',
        'message': err,
        'logPath': logPath,
        'at': DateTime.now().toUtc().toIso8601String(),
        'source': 'host',
      });
      return WindowsDesktopUpdateLaunchResult.fail(
        logPath: logPath,
        error: '$err Log: $logPath',
      );
    } catch (e, st) {
      await _appendHostLog(logPath, 'host: FATAL $e\n$st');
      await _writeStatusFile({
        'state': 'error',
        'message': 'Příprava updateru selhala: $e',
        'logPath': logPath,
        'at': DateTime.now().toUtc().toIso8601String(),
        'source': 'host',
      });
      return WindowsDesktopUpdateLaunchResult.fail(
        logPath: logPath,
        error: 'Příprava updateru selhala: $e\nLog: $logPath',
      );
    }
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

  static Future<String?> _validateZip(File zip) async {
    try {
      if (!await zip.exists()) return 'ZIP neexistuje.';
      final len = await zip.length();
      if (len < 64) return 'ZIP je prázdný nebo poškozený ($len B).';
      final raf = await zip.open();
      try {
        final magic = await raf.read(4);
        // PK\x03\x04 or PK\x05\x06 (empty) or PK\x07\x08
        if (magic.length < 2 || magic[0] != 0x50 || magic[1] != 0x4b) {
          return 'Soubor není platný ZIP (špatná magická hlavička).';
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

  static Future<bool> _waitForUpdaterHeartbeat({
    required String logPath,
    required File heartbeat,
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await heartbeat.exists()) {
          final t = (await heartbeat.readAsString()).trim();
          if (t.isNotEmpty) return true;
        }
      } catch (_) {}
      try {
        final log = File(logPath);
        if (await log.exists()) {
          final text = await log.readAsString();
          if (text.contains('ps: boot') || text.contains('ps: start WaitPid')) {
            return true;
          }
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
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
    await helper.writeAsString('''
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
''', flush: true);

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
    // cmd file avoids schtasks quoting hell; runs hidden via powershell -WindowStyle already in args.
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

  /// Masivní apply skript — config JSON, heartbeat, multi-kill, multi-copy, verify.
  static String _psScript() => r'''
param(
  [Parameter(Mandatory = $true)][string] $ConfigPath
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

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
    # Belt-and-suspenders
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

  if (-not $expanded) { throw "Rozbalení ZIP selhalo všemi metodami." }
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
  throw "V archivu chybí $ExeName"
}

function Copy-UpdateTree([string] $ContentRoot, [string] $TargetDir) {
  $ok = $false
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    Write-Log ("copy attempt=$attempt robocopy")
    $rcArgs = @(
      $ContentRoot, $TargetDir, '/E', '/IS', '/IT', '/R:60', '/W:1',
      '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
    )
    & robocopy.exe @rcArgs | Out-Null
    $rc = $LASTEXITCODE
    Write-Log "robocopy exit=$rc"
    if ($rc -lt 8) { $ok = $true; break }

    Write-Log "copy attempt=$attempt Copy-Item fallback"
    try {
      Copy-Item -Path (Join-Path $ContentRoot '*') -Destination $TargetDir -Recurse -Force -ErrorAction Stop
      $ok = $true
      break
    } catch {
      Write-Log ("Copy-Item failed: " + $_)
      Start-Sleep -Seconds (2 * $attempt)
    }
  }
  if (-not $ok) { throw "Kopírování do instalace selhalo." }
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

try {
  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config missing: $ConfigPath"
  }
  $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $script:LogPath = [string]$cfg.logPath
  $script:HeartbeatPath = [string]$cfg.heartbeatPath
  $script:StatusPath = [string]$cfg.statusPath
  $WaitPid = [int]$cfg.waitPid
  $ZipPath = [string]$cfg.zipPath
  $StageDir = [string]$cfg.stageDir
  $TargetDir = [string]$cfg.targetDir
  $ExeName = [string]$cfg.exeName

  Write-Log "ps: boot"
  Write-Status @{ state = 'running'; phase = 'boot'; at = (Get-Date -Format o) }
  Write-Log "ps: start WaitPid=$WaitPid TargetDir=$TargetDir ZipPath=$ZipPath"

  if (-not (Test-Path -LiteralPath $ZipPath)) { throw "ZIP neexistuje: $ZipPath" }
  $zipLen = (Get-Item -LiteralPath $ZipPath).Length
  Write-Log "ps: zip bytes=$zipLen"

  Expand-UpdateZip -ZipPath $ZipPath -StageDir $StageDir
  Write-Status @{ state = 'running'; phase = 'expanded'; at = (Get-Date -Format o) }

  $contentRoot = Find-ContentRoot -StageDir $StageDir -ExeName $ExeName
  $probeExe = Join-Path $contentRoot $ExeName
  Write-Log "ps: contentRoot=$contentRoot probe=$probeExe"

  $liveExe = Join-Path $TargetDir $ExeName
  $procName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

  $p = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
  if ($null -ne $p) {
    Write-Log "ps: waiting for WaitPid=$WaitPid"
    Wait-Process -Id $WaitPid -Timeout 240 -ErrorAction SilentlyContinue
  } else {
    Write-Log "ps: WaitPid already gone"
  }

  Write-Log "ps: stopping app instances"
  Write-Status @{ state = 'running'; phase = 'stopping'; at = (Get-Date -Format o) }
  $left = Stop-AppInstances -liveExe $liveExe -procName $procName -seconds 120
  if ($left.Count -gt 0) {
    # Last resort: kill by name only (same install folder risk accepted for OTA)
    Write-Log "ps: force taskkill by image name"
    & taskkill.exe /F /IM ($procName + '.exe') /T 2>$null | Out-Null
    Start-Sleep -Seconds 2
    $left = Stop-AppInstances -liveExe $liveExe -procName $procName -seconds 30
  }
  if ($left.Count -gt 0) {
    throw ("Procesy stále běží: " + (($left | ForEach-Object { $_.Id }) -join ','))
  }

  Start-Sleep -Seconds 1
  try {
    if (Test-Path -LiteralPath $liveExe) {
      Copy-Item -LiteralPath $liveExe -Destination ($liveExe + '.bak') -Force -ErrorAction SilentlyContinue
    }
  } catch {}

  Write-Status @{ state = 'running'; phase = 'copying'; at = (Get-Date -Format o) }
  Copy-UpdateTree -ContentRoot $contentRoot -TargetDir $TargetDir

  if (-not (Test-InstallOk -liveExe $liveExe -TargetDir $TargetDir)) {
    throw "Po kopírování instalace nevypadá kompletní ($liveExe)."
  }

  Write-Log "ps: starting $liveExe"
  Write-Status @{ state = 'running'; phase = 'starting'; at = (Get-Date -Format o) }
  $started = $false
  for ($i = 1; $i -le 5; $i++) {
    try {
      Start-Process -LiteralPath $liveExe -WorkingDirectory $TargetDir
      Start-Sleep -Seconds 2
      $running = @(Get-MatchingProcs $liveExe $procName)
      if ($running.Count -gt 0) {
        Write-Log ("ps: app running pid=" + $running[0].Id)
        $started = $true
        break
      }
      Write-Log "ps: start attempt=$i — process not seen yet"
    } catch {
      Write-Log ("ps: Start-Process failed attempt=$i: " + $_)
      Start-Sleep -Seconds $i
    }
  }
  if (-not $started) {
    throw "Aplikace se po aktualizaci nespustila."
  }

  Write-Status @{ state = 'ok'; phase = 'done'; message = 'Update applied'; logPath = $script:LogPath; at = (Get-Date -Format o) }
  Write-Log "ps: done"
  exit 0
} catch {
  $errMsg = "$_"
  try { Write-Log ("ERROR: " + $errMsg) } catch {}
  try {
    Write-Status @{
      state = 'error'
      message = $errMsg
      logPath = $script:LogPath
      at = (Get-Date -Format o)
    }
  } catch {}

  # Pokus o obnovu .bak, ať app vůbec naběhne a ukáže chybu uživateli.
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
      Start-Process -LiteralPath $liveExe -WorkingDirectory $TargetDir
    }
  } catch {
    Write-Log ("ps: restart after failure failed: " + $_)
  }
  exit 1
}
''';
}
