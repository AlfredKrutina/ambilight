import 'dart:io';

import 'package:path/path.dart' as p;

/// Nahrazení instalace po ukončení běžícího procesu (Windows).
///
/// [zipFile] = obsah `runner/Release` (exe, dll, složka **data/** s assets). CI balí `Compress-Archive -Path *`.
class WindowsDesktopUpdater {
  WindowsDesktopUpdater._();

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
  [Parameter(Mandatory = $true)][string] $ExeName
)
$ErrorActionPreference = 'Stop'
try {
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
  if (Test-Path -LiteralPath $liveExe) {
    Start-Process -LiteralPath $liveExe
  }
} catch {
  Write-Error $_
  exit 1
}
exit 0
''';
}
