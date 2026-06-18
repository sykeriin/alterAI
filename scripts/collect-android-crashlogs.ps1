param(
    [string]$PackageName = "com.example.alter",
    [int]$Lines = 800
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RunDir = Join-Path $RepoRoot ".codex-run\android"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    throw "adb was not found on PATH."
}

$devices = adb devices -l | Select-String -Pattern "device\s" | ForEach-Object { $_.Line }
if (-not $devices) {
    throw "No Android device is connected."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $RunDir "alter-crashlogs-$timestamp.txt"

adb logcat -d -t $Lines |
    Select-String -Pattern $PackageName, "AndroidRuntime", "FATAL EXCEPTION", "alter.ai", "com.example.alter" |
    ForEach-Object { $_.Line } |
    Set-Content -Path $logFile -Encoding UTF8

Write-Host "Crash log excerpt: $logFile"
