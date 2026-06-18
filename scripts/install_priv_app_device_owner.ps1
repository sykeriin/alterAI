# Install ALTER AI and provision Device Owner / device admin on Android.
# Prerequisites: USB debugging, adb in PATH, flutter in PATH.
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File scripts/install_priv_app_device_owner.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/install_priv_app_device_owner.ps1 -SkipBuild

param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$Package = "com.example.alter"
$AdminReceiver = "$Package/.AlterDeviceAdminReceiver"
$ApkPath = "build/app/outputs/flutter-apk/app-release.apk"
$PrivAppDir = "/system/priv-app/AlterAI"
$PrivAppPath = "$PrivAppDir/AlterAI.apk"

if (-not $SkipBuild) {
    Write-Host "==> Building release APK..."
    flutter pub get
    flutter build apk --release
}
if (-not (Test-Path $ApkPath)) {
    throw "APK not found at $ApkPath"
}

Write-Host "==> Checking connected device..."
adb devices
$devices = adb devices | Select-String "device$" | Where-Object { $_ -notmatch "List of devices" }
if (-not $devices) {
    throw "No adb device found. Connect your phone via USB and enable USB debugging."
}

Write-Host "==> Current device owners:"
adb shell dpm list-owners

$privAppInstalled = $false
Write-Host "==> Attempting priv-app install (root required)..."
adb root 2>$null | Out-Null
Start-Sleep -Seconds 2
$remount = adb remount 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -and $remount -notmatch "not running as root") {
    adb shell "mkdir -p $PrivAppDir"
    adb push $ApkPath $PrivAppPath
    adb shell "chmod 644 $PrivAppPath"
    adb shell "chown root:root $PrivAppPath"
    Write-Host "==> Priv-app pushed. Rebooting..."
    adb reboot
    adb wait-for-device
    Start-Sleep -Seconds 15
    adb wait-for-device
    $privAppInstalled = $true
} else {
    Write-Host "==> Priv-app install unavailable (no adb root). Falling back to adb install -r..."
    adb install -r $ApkPath
}

Write-Host "==> Enabling device admin (not device owner)..."
adb shell dpm set-active-admin $AdminReceiver

Write-Host ""
Write-Host "==> Device admin status:"
adb shell dpm list-owners
Write-Host "(ALTER only needs active admin - device owner is optional and often blocked by other apps.)"

Write-Host ""
if ($privAppInstalled) {
    Write-Host "Done (priv-app + admin). Open ALTER and complete Permission Hub."
} else {
    Write-Host "Done (user install + admin). Open ALTER and complete Permission Hub."
}
