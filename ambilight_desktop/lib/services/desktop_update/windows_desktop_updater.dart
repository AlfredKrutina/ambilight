import 'dart:io';

import 'package:path/path.dart' as p;

/// Nahrazení instalace po ukončení běžícího procesu (Windows).
///
/// [zipFile] = obsah `runner/Release` (exe, dll, složka **data/** s assets). CI balí `Compress-Archive -Path *`.
class WindowsDesktopUpdater {
  WindowsDesktopUpdater._();

  static String get _otaRoot {
    final local = Platform.environment['LOCALAPPDATA']?.trim();
    if (local != null && local.isNotEmpty) {
      return p.join(local, 'AmbiLight', 'ota');
    }
    return p.join(Directory.systemTemp.path, 'AmbiLight_ota');
  }

  static String get updateLogPath => p.join(_otaRoot, 'ambi_update.log');

  /// `null` = OK, jinak lidská chyba (např. Program Files bez práv zápisu).
  static String? preflightWritableInstallDir() {
    if (!Platform.isWindows) return 'Aktualizace na místě je jen pro Windows.';
    final targetDir = p.dirname(Platform.resolvedExecutable);
    try {
      final probe = File(p.join(targetDir, '.ambi_update_write_probe'));
      probe.writeAsStringSync('ok', flush: true);
      probe.deleteSync();
      return null;
    } catch (_) {
      return 'Do složky instalace nelze zapisovat ($targetDir). '
          'Spusť AmbiLight z rozbaleného ZIP (portable), ne z Program Files, '
          'nebo aktualizuj ručně přes installer z GitHub Releases.';
    }
  }

  /// Spustí PowerShell updater **mimo** Job Object Flutter procesu.
  ///
  /// `cmd start` / běžný `Process.detached` zůstávají v jobu → `exit(0)` je zabije
  /// (typicky: blikne černý terminál a nic se nestane). WMI `Win32_Process.Create`
  /// child do jobu nepřidá (MSDN).
  ///
  /// Vrací `true`, pokud WMI updater úspěšně odstartoval.
  static Future<bool> launchExpandCopyRestart({
    required File zipFile,
    required int waitPid,
  }) async {
    if (!Platform.isWindows) return false;
    final liveExe = Platform.resolvedExecutable;
    final targetDir = p.dirname(liveExe);
    final exeName = p.basename(liveExe);

    final ota = Directory(_otaRoot);
    await ota.create(recursive: true);
    final work = ota;
    final stageDir = p.join(work.path, 'stage');
    final logPath = updateLogPath;
    final zipCopy = File(p.join(work.path, 'update.zip'));
    final script = File(p.join(work.path, 'apply_update.ps1'));
    final vbs = File(p.join(work.path, 'launch_update.vbs'));
    final marker = File(p.join(work.path, 'ambi_update_launch.txt'));

    try {
      if (await zipCopy.exists()) await zipCopy.delete();
      await zipFile.copy(zipCopy.path);
    } catch (e) {
      await marker.writeAsString('copy_zip_failed=$e\n', flush: true);
      return false;
    }

    await script.writeAsString(_psScript(), flush: true);
    await vbs.writeAsString(
      _vbsLauncher(
        ps1Path: script.path,
        waitPid: waitPid,
        zipPath: zipCopy.path,
        stageDir: stageDir,
        targetDir: targetDir,
        exeName: exeName,
        logPath: logPath,
        workDir: work.path,
      ),
      flush: true,
    );

    await marker.writeAsString(
      'pid=$waitPid\nzip=${zipCopy.path}\ntarget=$targetDir\nlog=$logPath\nvbs=${vbs.path}\n',
      flush: true,
    );

    // Sync: počkej, až VBS/WMI vytvoří updater mimo job, teprve pak volej exit(0).
    final result = await Process.run(
      'wscript.exe',
      ['//Nologo', vbs.path],
      workingDirectory: work.path,
      runInShell: false,
    );

    await File(p.join(work.path, 'ambi_update_wscript.txt')).writeAsString(
      'exit=${result.exitCode}\nstdout=${result.stdout}\nstderr=${result.stderr}\n',
      flush: true,
    );

    return result.exitCode == 0;
  }

  static String _vbsEscape(String s) => s.replaceAll('"', '""');

  static String _vbsLauncher({
    required String ps1Path,
    required int waitPid,
    required String zipPath,
    required String stageDir,
    required String targetDir,
    required String exeName,
    required String logPath,
    required String workDir,
  }) {
    // PowerShell command line — quoted paths for spaces.
    final psArgs =
        '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "${_vbsEscape(ps1Path)}" '
        '-WaitPid $waitPid '
        '-ZipPath "${_vbsEscape(zipPath)}" '
        '-StageDir "${_vbsEscape(stageDir)}" '
        '-TargetDir "${_vbsEscape(targetDir)}" '
        '-ExeName "${_vbsEscape(exeName)}" '
        '-LogPath "${_vbsEscape(logPath)}"';
    final cmdLine = 'powershell.exe $psArgs';
    return '''
On Error Resume Next
Dim svc, startup, proc, ret, pid, fso, logf
Set fso = CreateObject("Scripting.FileSystemObject")
Set logf = fso.OpenTextFile("${_vbsEscape(logPath)}", 8, True)
logf.WriteLine "[" & Now & "] vbs: launching via Win32_Process.Create"
logf.Close

Set svc = GetObject("winmgmts:\\\\.\\root\\cimv2")
Set startup = svc.Get("Win32_ProcessStartup").SpawnInstance_()
startup.ShowWindow = 0
Set proc = svc.Get("Win32_Process")
ret = proc.Create("$cmdLine", "${_vbsEscape(workDir)}", startup, pid)
If ret <> 0 Then
  Set logf = fso.OpenTextFile("${_vbsEscape(logPath)}", 8, True)
  logf.WriteLine "[" & Now & "] vbs: Win32_Process.Create failed ret=" & ret
  logf.Close
  WScript.Quit 1
End If
Set logf = fso.OpenTextFile("${_vbsEscape(logPath)}", 8, True)
logf.WriteLine "[" & Now & "] vbs: created updater pid=" & pid
logf.Close
WScript.Quit 0
''';
  }

  static String _psScript() => r'''
param(
  [Parameter(Mandatory = $true)][int] $WaitPid,
  [Parameter(Mandatory = $true)][string] $ZipPath,
  [Parameter(Mandatory = $true)][string] $StageDir,
  [Parameter(Mandatory = $true)][string] $TargetDir,
  [Parameter(Mandatory = $true)][string] $ExeName,
  [Parameter(Mandatory = $true)][string] $LogPath
)
$ErrorActionPreference = 'Stop'
function Write-Log([string] $msg) {
  $line = ("[{0}] {1}" -f (Get-Date -Format o), $msg)
  try {
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
  } catch {}
}
try {
  Write-Log "start WaitPid=$WaitPid TargetDir=$TargetDir ZipPath=$ZipPath"
  if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "ZIP neexistuje: $ZipPath"
  }
  if (Test-Path -LiteralPath $StageDir) {
    Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Path $StageDir -Force | Out-Null
  Write-Log "expand archive"
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $StageDir -Force
  $top = @(Get-ChildItem -LiteralPath $StageDir -Force)
  $contentRoot = $StageDir
  if (($top.Count -eq 1) -and ($top[0].PSIsContainer)) {
    $contentRoot = $top[0].FullName
  }
  $probeExe = Join-Path $contentRoot $ExeName
  if (-not (Test-Path -LiteralPath $probeExe)) {
    throw "V archivu chybí $ExeName (kořen ZIPu nebo jedna podsložka). Root=$contentRoot"
  }
  $liveExe = Join-Path $TargetDir $ExeName
  $procName = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)

  $p = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
  if ($null -ne $p) {
    Write-Log "waiting for WaitPid=$WaitPid"
    Wait-Process -Id $WaitPid -Timeout 180 -ErrorAction SilentlyContinue
  } else {
    Write-Log "WaitPid=$WaitPid already gone"
  }

  Write-Log "stopping all processes for $liveExe"
  $deadline = (Get-Date).AddSeconds(90)
  do {
    $alive = @(
      Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object {
          try {
            $_.Path -and ($_.Path -ieq $liveExe)
          } catch {
            $false
          }
        }
    )
    foreach ($proc in $alive) {
      Write-Log ("stop pid={0}" -f $proc.Id)
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 400
    $alive = @(
      Get-Process -Name $procName -ErrorAction SilentlyContinue |
        Where-Object {
          try {
            $_.Path -and ($_.Path -ieq $liveExe)
          } catch {
            $false
          }
        }
    )
  } while (($alive.Count -gt 0) -and ((Get-Date) -lt $deadline))

  if ($alive.Count -gt 0) {
    throw ("Procesy stále běží po stop: " + (($alive | ForEach-Object { $_.Id }) -join ','))
  }

  Start-Sleep -Seconds 1
  if (Test-Path -LiteralPath $liveExe) {
    Copy-Item -LiteralPath $liveExe -Destination ($liveExe + '.bak') -Force -ErrorAction SilentlyContinue
  }

  Write-Log "copy from $contentRoot"
  $rcArgs = @(
    $contentRoot, $TargetDir, '/E', '/IS', '/IT', '/R:40', '/W:1',
    '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
  )
  & robocopy @rcArgs | Out-Null
  $rc = $LASTEXITCODE
  Write-Log "robocopy exit=$rc"
  if ($rc -ge 8) {
    throw "robocopy selhal s kódem $rc"
  }
  if (-not (Test-Path -LiteralPath $liveExe)) {
    throw "Po kopírování chybí $liveExe"
  }
  Write-Log "starting $liveExe"
  Start-Process -LiteralPath $liveExe -WorkingDirectory $TargetDir
} catch {
  Write-Log ("ERROR: " + $_)
  exit 1
}
Write-Log "done"
exit 0
''';
}
