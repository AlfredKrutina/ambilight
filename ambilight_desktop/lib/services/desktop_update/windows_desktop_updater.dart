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
    final body = _psScript();
    await script.writeAsString(body, flush: true);
    return Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
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
  Add-Content -LiteralPath $LogPath -Value $line -ErrorAction SilentlyContinue
}
try {
  Write-Log "start WaitPid=$WaitPid TargetDir=$TargetDir"
  if (Test-Path -LiteralPath $StageDir) {
    Remove-Item -LiteralPath $StageDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Path $StageDir -Force | Out-Null
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $StageDir -Force
  $top = @(Get-ChildItem -LiteralPath $StageDir -Force)
  $contentRoot = $StageDir
  if (($top.Count -eq 1) -and ($top[0].PSIsContainer)) {
    $contentRoot = $top[0].FullName
  }
  $probeExe = Join-Path $contentRoot $ExeName
  if (-not (Test-Path -LiteralPath $probeExe)) {
    throw "V archivu chybí $ExeName (kořen ZIPu nebo jedna podsložka)."
  }
  $p = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
  if ($null -ne $p) {
    Wait-Process -Id $WaitPid -Timeout 120 -ErrorAction SilentlyContinue
  }
  $still = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
  if ($null -ne $still) {
    throw "Proces $WaitPid stále běží po 120 s — aktualizace zrušena (soubory by byly zamčené)."
  }
  Start-Sleep -Seconds 2
  $liveExe = Join-Path $TargetDir $ExeName
  if (Test-Path -LiteralPath $liveExe) {
    Copy-Item -LiteralPath $liveExe -Destination ($liveExe + '.bak') -Force -ErrorAction SilentlyContinue
  }
  Get-ChildItem -LiteralPath $contentRoot -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($contentRoot.Length)
    if ($rel.StartsWith('\') -or $rel.StartsWith('/')) { $rel = $rel.Substring(1) }
    $dest = Join-Path $TargetDir $rel
    $destDir = Split-Path -Parent $dest
    if (($null -ne $destDir) -and ($destDir.Length -gt 0) -and (-not (Test-Path -LiteralPath $destDir))) {
      New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $retries = 0
    while ($retries -lt 50) {
      try {
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        break
      } catch {
        Start-Sleep -Milliseconds 400
        $retries++
      }
    }
    if ($retries -ge 50) {
      throw "Kopirovani selhalo: $rel"
    }
  }
  Write-Log "copy ok; starting $liveExe"
  if (Test-Path -LiteralPath $liveExe) {
    Start-Process -LiteralPath $liveExe
  } else {
    throw "Po kopírování chybí $liveExe"
  }
} catch {
  Write-Log ("ERROR: " + $_)
  Write-Error $_
  exit 1
}
Write-Log "done"
exit 0
''';
}
