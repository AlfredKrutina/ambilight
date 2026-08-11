#Requires -Version 5.1
param(
  [switch] $UseLiveTarget,
  [int] $TimeoutSec = 180
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step([string] $msg) {
  Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg) -ForegroundColor Cyan
}
function Fail([string] $msg) {
  Write-Host ('FAIL: {0}' -f $msg) -ForegroundColor Red
  exit 1
}
function Ok([string] $msg) {
  Write-Host ('OK: {0}' -f $msg) -ForegroundColor Green
}

$repo = 'd:\projects\Programming\Git\ambilight'
$dartFile = Join-Path $repo 'ambilight_desktop\lib\services\desktop_update\windows_desktop_updater.dart'
$release = Join-Path $repo 'ambilight_desktop\build\windows\x64\runner\Release'
$ota = Join-Path $env:LOCALAPPDATA 'AmbiLight\ota'
$testRoot = Join-Path $env:TEMP ('AmbiLight_ota_e2e_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
if ($UseLiveTarget) {
  $target = Join-Path $env:LOCALAPPDATA 'Programs\AmbiLight'
} else {
  $target = Join-Path $testRoot 'install'
}
$session = 'e2e-{0}-{1}' -f (Get-Date -Format 'yyyyMMddHHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$zipPath = Join-Path $testRoot 'update.zip'
$stageDir = Join-Path $ota ('stage_' + $session)
$scriptPath = Join-Path $ota 'apply_update.ps1'
$configPath = Join-Path $ota 'apply_config.json'
$logPath = Join-Path $ota 'ambi_update_e2e.log'
$hbPath = Join-Path $ota 'heartbeat_e2e.txt'
$statusPath = Join-Path $ota 'status_e2e.json'
$runnerVbs = Join-Path $testRoot 'run_hidden.vbs'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

Write-Step ('session={0}' -f $session)
Write-Step ('target={0}' -f $target)
New-Item -ItemType Directory -Force -Path $testRoot, $ota | Out-Null

if (-not (Test-Path (Join-Path $release 'ambilight_desktop.exe'))) {
  Fail ('Release build missing: {0}' -f $release)
}
if (-not (Test-Path $dartFile)) { Fail ('Dart updater missing: {0}' -f $dartFile) }
if (-not (Test-Path $psExe)) { Fail 'powershell.exe missing' }

Write-Step 'Extract apply_update.ps1 from Dart source'
$dart = [IO.File]::ReadAllText($dartFile, [Text.Encoding]::UTF8)
$q3 = [string]::new([char]39, 3)  # '''
$marker = 'static String _psScript() => r' + $q3
$idx = $dart.IndexOf($marker)
if ($idx -lt 0) { Fail '_psScript marker not found' }
$cs = $idx + $marker.Length
if ($dart[$cs] -eq "`r") { $cs++ }
if ($dart[$cs] -eq "`n") { $cs++ }
$endMark = "`n" + $q3
$ce = $dart.IndexOf($endMark, $cs)
if ($ce -lt 0) { Fail '_psScript end not found' }
$psBody = $dart.Substring($cs, $ce - $cs)
$utf8bom = New-Object System.Text.UTF8Encoding $true
[IO.File]::WriteAllText($scriptPath, $psBody + "`n", $utf8bom)

Write-Step 'PowerShell parse check'
$errs = $null
$tok = $null
[void][Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tok, [ref]$errs)
if ($errs -and $errs.Count -gt 0) {
  $errs | ForEach-Object { Write-Host $_.ToString() -ForegroundColor Red }
  Fail 'apply_update.ps1 parse failed'
}
Ok 'PARSE_OK'

Write-Step 'Prepare target install + ZIP'
if (Test-Path $target) { Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $target | Out-Null
robocopy $release $target /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
Set-Content -LiteralPath (Join-Path $target '.e2e_seed') -Value 'seed' -Encoding ASCII
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($release, $zipPath)
Ok ('zip bytes={0}' -f (Get-Item $zipPath).Length)

$otaZip = Join-Path $ota 'update_e2e.zip'
Copy-Item -LiteralPath $zipPath -Destination $otaZip -Force

$cfg = [ordered]@{
  sessionId     = $session
  waitPid       = 999999
  zipPath       = $otaZip
  stageDir      = $stageDir
  targetDir     = $target
  exeName       = 'ambilight_desktop.exe'
  logPath       = $logPath
  heartbeatPath = $hbPath
  statusPath    = $statusPath
  workDir       = $ota
  startedAt     = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($configPath, ($cfg | ConvertTo-Json), $utf8bom)
Remove-Item $hbPath, $logPath, $statusPath -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $ota 'apply_lock_active.lock') -Force -ErrorAction SilentlyContinue

Write-Step 'Launch updater hidden via WScript.Shell.Run style 0'
# Keep a copy: successful apply deletes apply_update.ps1 during cleanup.
$scriptKeep = Join-Path $testRoot 'apply_update_kept.ps1'
Copy-Item -LiteralPath $scriptPath -Destination $scriptKeep -Force
$cmd = '"{0}" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "{1}" -ConfigPath "{2}"' -f $psExe, $scriptPath, $configPath
$cmdVbs = $cmd.Replace([string][char]34, ([string][char]34) + ([string][char]34))
$otaVbs = $ota.Replace([string][char]34, ([string][char]34) + ([string][char]34))
$dq = [string][char]34
$vbsLines = @(
  'On Error Resume Next',
  'Dim sh',
  ('Set sh = CreateObject({0}WScript.Shell{0})' -f $dq),
  ('sh.CurrentDirectory = {0}{1}{0}' -f $dq, $otaVbs),
  ('sh.Run {0}{1}{0}, 0, False' -f $dq, $cmdVbs)
)
[IO.File]::WriteAllLines($runnerVbs, $vbsLines)
# Do NOT -Wait: PS 5.1 can keep waiting on the process tree (started AmbiLight GUI).
$launch = Start-Process -FilePath 'wscript.exe' -ArgumentList @('//Nologo', '//B', $runnerVbs) -PassThru
if (-not $launch) { Fail 'wscript failed to start' }
Start-Sleep -Milliseconds 400

Write-Step 'Wait for session heartbeat (host simulation)'
$deadline = (Get-Date).AddSeconds(30)
$gotHb = $false
$sessionNeedle = 'session=' + $session
while ((Get-Date) -lt $deadline) {
  if (Test-Path $hbPath) {
    $t = Get-Content $hbPath -Raw -ErrorAction SilentlyContinue
    if ($t -and $t.Contains($sessionNeedle)) {
      $gotHb = $true
      $preview = $t.Trim()
      if ($preview.Length -gt 120) { $preview = $preview.Substring(0, 120) }
      Ok ('heartbeat: {0}' -f $preview)
      break
    }
  }
  if (Test-Path $logPath) {
    $logTxt = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    if ($logTxt -and $logTxt.Contains($sessionNeedle) -and $logTxt.Contains('ps: boot')) {
      $gotHb = $true
      Ok 'boot seen in log'
      break
    }
  }
  Start-Sleep -Milliseconds 150
}
if (-not $gotHb) {
  if (Test-Path $logPath) { Get-Content $logPath | Select-Object -Last 20 }
  Fail 'No session heartbeat within 30s'
}

Start-Sleep -Seconds 2
if (Test-Path $hbPath) {
  $t2 = Get-Content $hbPath -Raw
  if (-not $t2.Contains($sessionNeedle)) {
    Fail ('Heartbeat lost session token: {0}' -f $t2)
  }
  Ok 'heartbeat still has session token'
}

Write-Step 'Wait for apply completion'
$deadline2 = (Get-Date).AddSeconds($TimeoutSec)
$done = $false
while ((Get-Date) -lt $deadline2) {
  if (Test-Path $statusPath) {
    try {
      $st = Get-Content $statusPath -Raw | ConvertFrom-Json
      if ($st.state -eq 'ok') { $done = $true; Ok 'status=ok'; break }
      if ($st.state -eq 'error') {
        if (Test-Path $logPath) { Get-Content $logPath | Select-Object -Last 30 }
        Fail ('status=error message={0}' -f $st.message)
      }
    } catch {}
  }
  Start-Sleep -Milliseconds 400
}
if (-not $done) {
  if (Test-Path $logPath) { Get-Content $logPath | Select-Object -Last 40 }
  Fail 'Timed out waiting for status=ok'
}

Write-Step 'Verify install target'
$exe = Join-Path $target 'ambilight_desktop.exe'
$appSo = Join-Path $target 'data\app.so'
if (-not (Test-Path $exe)) { Fail 'exe missing after update' }
if (-not (Test-Path $appSo)) { Fail 'data\app.so missing after update' }
Ok ('exe={0} app.so={1}' -f (Get-Item $exe).Length, (Get-Item $appSo).Length)

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -match 'ambilight_desktop' -and
    $_.ExecutablePath -and
    $_.ExecutablePath.StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase)
  } |
  ForEach-Object {
    Write-Step ('Stopping test process pid={0}' -f $_.ProcessId)
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }
Start-Sleep -Milliseconds 500

Write-Step 'Duplicate apply should exit quickly (lock)'
Copy-Item -LiteralPath $scriptKeep -Destination $scriptPath -Force
Set-Content (Join-Path $ota 'apply_lock_active.lock') -Value $session -Encoding UTF8
$dupLog = Join-Path $ota 'ambi_update_e2e_dup.log'
$dupHb = Join-Path $ota 'heartbeat_e2e_dup.txt'
$dupStatus = Join-Path $ota 'status_e2e_dup.json'
$dupCfgPath = Join-Path $ota 'apply_config_dup.json'
$dupSession = $session + '-dup'
$dupCfg = [ordered]@{
  sessionId     = $dupSession
  waitPid       = 999999
  zipPath       = $otaZip
  stageDir      = Join-Path $ota ('stage_' + $dupSession)
  targetDir     = $target
  exeName       = 'ambilight_desktop.exe'
  logPath       = $dupLog
  heartbeatPath = $dupHb
  statusPath    = $dupStatus
  workDir       = $ota
  startedAt     = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.File]::WriteAllText($dupCfgPath, ($dupCfg | ConvertTo-Json), $utf8bom)
$dupProc = Start-Process -FilePath $psExe -ArgumentList @(
  '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
  '-File', $scriptPath, '-ConfigPath', $dupCfgPath
) -PassThru -WindowStyle Hidden
try {
  Wait-Process -Id $dupProc.Id -Timeout 25 -ErrorAction Stop
} catch {
  Stop-Process -Id $dupProc.Id -Force -ErrorAction SilentlyContinue
  Fail 'duplicate apply did not exit within 25s (lock broken?)'
}
$dupCode = $dupProc.ExitCode
if ($dupCode -ne 0) {
  Write-Host ('WARN: duplicate exit={0} (expected 0)' -f $dupCode) -ForegroundColor Yellow
} else {
  Ok 'duplicate exited 0 (lock respected)'
}
Remove-Item (Join-Path $ota 'apply_lock_active.lock') -Force -ErrorAction SilentlyContinue
# Cleanup may have started another GUI from lock path; stop temp installs only.
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -match 'ambilight_desktop' -and
    $_.ExecutablePath -and
    $_.ExecutablePath.StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase)
  } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Write-Host ''
Ok 'E2E OTA updater test PASSED'
Write-Host ('log: {0}' -f $logPath)
Write-Host ('status: {0}' -f $statusPath)
Write-Host ('target: {0}' -f $target)
if (-not $UseLiveTarget) {
  Write-Host ('temp root (safe to delete): {0}' -f $testRoot)
}
exit 0
