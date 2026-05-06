param(
  [ValidateSet("default", "gnosis")]
  [string]$Profile = "default",
  [switch]$NoStart,
  [string]$GitUser = "",
  [string]$Branch = "main",
  [string]$RemoteName = "origin",
  [ValidateSet("0", "1")]
  [string]$PreserveExistingRemote = "1",
  [ValidateSet("public", "private")]
  [string]$RepoVisibility = "public",
  [string]$ApiUrl = "https://api.github.com"
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[*] $msg" -ForegroundColor Green }
function Write-WarnMsg($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-ErrMsg($msg) { Write-Host "[x] $msg" -ForegroundColor Red }

function Convert-ToBashPath([string]$winPath) {
  $drive = $winPath.Substring(0,1).ToLower()
  $rest = $winPath.Substring(2).Replace('\\', '/')
  return "/$drive$rest"
}

function Ensure-File([string]$path) {
  if (-not (Test-Path $path)) {
    New-Item -ItemType File -Path $path -Force | Out-Null
  }
}

function Append-UniqueEntries([string]$sourceFile, [string]$targetFile, [string]$bashHome) {
  if (-not (Test-Path $sourceFile)) { return }
  Ensure-File $targetFile
  $existing = @{}
  foreach ($line in Get-Content $targetFile) {
    $trim = $line.Trim()
    if ($trim -ne "") { $existing[$trim] = $true }
  }

  foreach ($raw in Get-Content $sourceFile) {
    $line = $raw.Replace("__HOME_BASH__", $bashHome).Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    if (-not $existing.ContainsKey($line)) {
      Add-Content -Path $targetFile -Value $line
      $existing[$line] = $true
    }
  }
}

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$AutogitScriptSrc = Join-Path $RepoRoot "autogit.sh"
$AutogitWrapperSrc = Join-Path $RepoRoot "autogit_dirwatch.sh"
$AutosaveWrapperSrc = Join-Path $RepoRoot "autosave_dirwatch.sh"
$ProfileRoot = Join-Path (Join-Path $RepoRoot "windows") "profiles"

$HomeWin = $env:USERPROFILE
$HomeBash = Convert-ToBashPath $HomeWin
$AutoGitDirWin = Join-Path $HomeWin ".autogit"
$AuthDirWin = Join-Path $HomeWin ".AUTH"
$BinDirWin = Join-Path $HomeWin "bin"
$TokenFileWin = Join-Path $AuthDirWin ".GIT_token"

$MainFileWin = Join-Path $AutoGitDirWin "dirs_main.txt"
$CloneFileWin = Join-Path $AutoGitDirWin "dirs_clone.txt"
$AutoSaveFileWin = Join-Path $AutoGitDirWin "autosave_dirs_main.txt"
$AutoSaveCloneFileWin = Join-Path $AutoGitDirWin "autosave_dirs_clone.txt"
$IgnoreFileWin = Join-Path $AutoGitDirWin "ignore_globs.txt"

$RunnerAutogit = Join-Path $AutoGitDirWin "run_autogit_loop.sh"
$RunnerAutosave = Join-Path $AutoGitDirWin "run_autosave_loop.sh"

$BinDirBash = "$HomeBash/bin"
$AutoGitDirBash = "$HomeBash/.autogit"
$AuthDirBash = "$HomeBash/.AUTH"

if ($GitUser -eq "") {
  $GitUser = Read-Host "Enter your GitHub username"
}

if (-not (Test-Path $TokenFileWin) -or (Get-Item $TokenFileWin).Length -eq 0) {
  $SecureToken = Read-Host "Enter your GitHub Personal Access Token (repo scope)" -AsSecureString
  $TokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken))
}

New-Item -ItemType Directory -Force -Path $AutoGitDirWin, $AuthDirWin, $BinDirWin | Out-Null
if ($TokenPlain) {
  Set-Content -Path $TokenFileWin -Value $TokenPlain -NoNewline
  Write-Info "Saved token to $TokenFileWin"
}

Ensure-File $MainFileWin
Ensure-File $CloneFileWin
Ensure-File $AutoSaveFileWin
Ensure-File $AutoSaveCloneFileWin
Ensure-File $IgnoreFileWin

if (-not (Test-Path $AutogitScriptSrc) -or -not (Test-Path $AutogitWrapperSrc) -or -not (Test-Path $AutosaveWrapperSrc)) {
  Write-ErrMsg "Missing root scripts in repo."
  exit 1
}

Copy-Item $AutogitScriptSrc (Join-Path $BinDirWin "autogit.sh") -Force
Copy-Item $AutogitWrapperSrc (Join-Path $BinDirWin "autogit_dirwatch.sh") -Force
Copy-Item $AutosaveWrapperSrc (Join-Path $BinDirWin "autosave_dirwatch.sh") -Force
Write-Info "Installed scripts to $BinDirWin"

if ($Profile -eq "gnosis") {
  Append-UniqueEntries (Join-Path $ProfileRoot "gnosis\dirs_main.txt") $MainFileWin $HomeBash
  Append-UniqueEntries (Join-Path $ProfileRoot "gnosis\autosave_dirs_main.txt") $AutoSaveFileWin $HomeBash
  Append-UniqueEntries (Join-Path $ProfileRoot "gnosis\ignore_globs.txt") $IgnoreFileWin $HomeBash
  Write-Info "Applied GNOSIS profile entries"
}

$RunnerAutogitContent = @"
#!/usr/bin/env bash
set -Eeuo pipefail
export WATCH_FILE=\"$AutoGitDirBash/dirs_main.txt\"
export CLONE_FILE=\"$AutoGitDirBash/dirs_clone.txt\"
export LOG_FILE=\"$AutoGitDirBash/auto_git.log\"
export PID_FILE=\"$AutoGitDirBash/auto_git.pid\"
export IGNORE_FILE=\"$AutoGitDirBash/ignore_globs.txt\"
export INTERVAL=\"5\"
export BRANCH=\"$Branch\"
export REMOTE_NAME=\"$RemoteName\"
export PRESERVE_EXISTING_REMOTE=\"$PreserveExistingRemote\"
export REPO_VISIBILITY=\"$RepoVisibility\"
export GIT_USER=\"$GitUser\"
export TOKEN_FILE=\"$AuthDirBash/.GIT_token\"
export API_URL=\"$ApiUrl\"
exec \"$BinDirBash/autogit.sh\" run-loop
"@

$RunnerAutosaveContent = @"
#!/usr/bin/env bash
set -Eeuo pipefail
export WATCH_FILE=\"$AutoGitDirBash/autosave_dirs_main.txt\"
export CLONE_FILE=\"$AutoGitDirBash/autosave_dirs_clone.txt\"
export LOG_FILE=\"$AutoGitDirBash/dirwatch.log\"
export PID_FILE=\"$AutoGitDirBash/autosave.pid\"
export INTERVAL=\"0.2\"
exec \"$BinDirBash/autosave_dirwatch.sh\" run-loop
"@

Set-Content -Path $RunnerAutogit -Value $RunnerAutogitContent -NoNewline
Set-Content -Path $RunnerAutosave -Value $RunnerAutosaveContent -NoNewline

$BashExeCandidates = @(
  "C:\Program Files\Git\bin\bash.exe",
  "C:\Program Files (x86)\Git\bin\bash.exe"
)
$BashExe = $null
foreach ($candidate in $BashExeCandidates) {
  if (Test-Path $candidate) { $BashExe = $candidate; break }
}
if (-not $BashExe) {
  $bashCmd = Get-Command bash.exe -ErrorAction SilentlyContinue
  if ($bashCmd) { $BashExe = $bashCmd.Source }
}
if (-not $BashExe) {
  Write-ErrMsg "Could not find bash.exe (Git for Windows). Install Git Bash first."
  exit 1
}

$ActionAutoGit = New-ScheduledTaskAction -Execute $BashExe -Argument "-lc \"`$HOME/.autogit/run_autogit_loop.sh\""
$ActionAutoSave = New-ScheduledTaskAction -Execute $BashExe -Argument "-lc \"`$HOME/.autogit/run_autosave_loop.sh\""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 0)

$TaskPath = "\\AutoGIT\\"
try {
  Register-ScheduledTask -TaskName "AutoGitLoop" -TaskPath $TaskPath -Action $ActionAutoGit -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
  Register-ScheduledTask -TaskName "AutoSaveLoop" -TaskPath $TaskPath -Action $ActionAutoSave -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
} catch {
  Write-ErrMsg "Failed to register scheduled tasks: $($_.Exception.Message)"
  exit 1
}

if (-not $NoStart) {
  Start-ScheduledTask -TaskPath $TaskPath -TaskName "AutoGitLoop" -ErrorAction SilentlyContinue
  Start-ScheduledTask -TaskPath $TaskPath -TaskName "AutoSaveLoop" -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "AutoGIT Windows installation complete." -ForegroundColor Green
Write-Host "Profile: $Profile"
Write-Host "GitHub user: $GitUser"
Write-Host "Watch file: $MainFileWin"
Write-Host "Autosave file: $AutoSaveFileWin"
Write-Host "Tasks: ${TaskPath}AutoGitLoop, ${TaskPath}AutoSaveLoop"
