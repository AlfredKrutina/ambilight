import 'dart:io';

import 'package:path/path.dart' as p;

/// Nahrazení instalace po ukončení běžícího procesu (Windows).
///
/// [zipFile] = obsah `runner/Release` (exe, dll, složka **data/** s assets). CI balí `Compress-Archive -Path *`.
class WindowsDesktopUpdater {
  WindowsDesktopUpdater._();

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

  /// Spustí PowerShell updater mimo Job Object Flutter procesu (`cmd start /b`),
  /// jinak `exit(0)` často zabije i „detached“ child a OTA nikdy nedoběhne.
  static Future<Process?> launchExpandCopyRestart({
    required File zipFile,
    required int waitPid,
  }) async {
    if (!Platform.isWindows) return null;
    final liveExe = Platform.resolvedExecutable;
    final targetDir = p.dirname(liveExe);
    final exeName = p.basename(liveExe);
    final work = zipFile.parent;
    final stageDir = p.join(work.path, 'stage');
    final logPath = p.join(work.path, 'ambi_update.log');
    final script = File(p.join(work.path, 'apply_update.ps1'));
    await script.writeAsString(_psScript(), flush: true);

    // Marker: pokud PowerShell vůbec nenačte skript, aspoň víme že launch proběhl.
    try {
      await File(p.join(work.path, 'ambi_update_launch.txt')).writeAsString(
        'pid=$waitPid\nzip=${zipFile.path}\ntarget=$targetDir\n',
        flush: true,
      );
    } catch (_) {}

    // `start "" /b` odpojí proces od Job Object rodiče (Flutter Windows runner).
    return Process.start(
      'cmd.exe',
      [
        '/c',
        'start',
        '',
        '/b',
        'powershell.exe',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
        '-WaitPid',
        '$waitPid',
        '-ZipPath',
        zipFile.path,
        '-StageDir',
        stageDir,
        '-TargetDir',
        targetDir,
        '-ExeName',
        exeName,
        '-LogPath',
        logPath,
      ],
      mode: ProcessStartMode.detached,
      workingDirectory: work.path,
    );
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

  # Nejdřív počkej na hlavní PID (aplikace volá exit po spuštění updateru).
  $p = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
  if ($null -ne $p) {
    Write-Log "waiting for WaitPid=$WaitPid"
    Wait-Process -Id $WaitPid -Timeout 120 -ErrorAction SilentlyContinue
  }

  # Tray / vícenásobné instance drží DLL — ukonči VŠECHNY procesy se stejnou cestou exe.
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
    Start-Sleep -Milliseconds 500
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

  Start-Sleep -Seconds 2
  if (Test-Path -LiteralPath $liveExe) {
    Copy-Item -LiteralPath $liveExe -Destination ($liveExe + '.bak') -Force -ErrorAction SilentlyContinue
  }

  Write-Log "copy from $contentRoot"
  # robocopy: spolehlivější než Copy-Item u zamčených/retry souborů
  $rcArgs = @(
    $contentRoot, $TargetDir, '/E', '/IS', '/IT', '/R:40', '/W:1',
    '/NFL', '/NDL', '/NJH', '/NJS', '/NP'
  )
  & robocopy @rcArgs | Out-Null
  $rc = $LASTEXITCODE
  Write-Log "robocopy exit=$rc"
  # robocopy: 0–7 = success-ish, >=8 = failure
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
