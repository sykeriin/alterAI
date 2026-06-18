param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-debug.apk",
    [string]$PackageName = "com.example.alter",
    [switch]$OpenPermissionSettings
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ResolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
    $ApkPath
} else {
    Join-Path $RepoRoot $ApkPath
}

if (-not (Test-Path $ResolvedApk)) {
    throw "APK not found: $ResolvedApk. Run flutter build apk --debug first."
}

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    throw "adb was not found on PATH. Install Android platform-tools or open Android Studio SDK tools."
}

$devices = adb devices -l | Select-String -Pattern "device\s" | ForEach-Object { $_.Line }
if (-not $devices) {
    throw "No Android device is connected. Enable USB debugging, connect the phone, accept the RSA prompt, then rerun this script."
}

Write-Host "Installing $ResolvedApk"
adb install -r $ResolvedApk

$permissions = @(
    "android.permission.RECORD_AUDIO",
    "android.permission.CAMERA",
    "android.permission.READ_CONTACTS",
    "android.permission.POST_NOTIFICATIONS"
)

foreach ($permission in $permissions) {
    adb shell pm grant $PackageName $permission 2>$null | Out-Null
}

Write-Host "Launching ALTER"
adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 5

$RunDir = Join-Path $RepoRoot ".codex-run\android"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$screenshot = Join-Path $RunDir "alter-launch.png"
$windowDump = Join-Path $RunDir "window.xml"

adb exec-out screencap -p > $screenshot
adb shell uiautomator dump /sdcard/alter-window.xml | Out-Null
adb pull /sdcard/alter-window.xml $windowDump | Out-Null

Write-Host "Launch screenshot: $screenshot"
Write-Host "Window dump: $windowDump"

if ($OpenPermissionSettings) {
    Write-Host "Opening Android Accessibility settings for manual ALTER enablement."
    adb shell am start -a android.settings.ACCESSIBILITY_SETTINGS | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "Opening Android Notification Listener settings for manual ALTER enablement."
    adb shell am start -a android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS | Out-Null
}

Write-Host "Phone smoke launch completed. Notification Listener, Accessibility, and Device Admin still require manual Android approval unless this is a managed AVD/device-owner test."
