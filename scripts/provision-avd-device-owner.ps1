param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-debug.apk",
    [string]$PackageName = "com.example.alter",
    [string]$AdminReceiver = "com.example.alter/.AlterDeviceAdminReceiver",
    [switch]$EnableSensitiveServicesForAvd
)

$ErrorActionPreference = "Stop"

$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
if (-not $sdkRoot) {
    throw "ANDROID_HOME or ANDROID_SDK_ROOT must point to an Android SDK."
}

$adb = Join-Path $sdkRoot "platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    throw "adb.exe was not found at $adb."
}

$resolvedApk = Resolve-Path -LiteralPath $ApkPath

$devices = & $adb devices | Select-String -Pattern "`tdevice$"
if ($devices.Count -ne 1) {
    throw "Expected exactly one booted Android device/emulator. Found $($devices.Count)."
}

$serial = ($devices[0].ToString() -split "`t")[0]
$isEmulatorSerial = $serial -like "emulator-*"
$qemu = (& $adb -s $serial shell getprop ro.kernel.qemu).Trim()
if (-not $isEmulatorSerial -or $qemu -ne "1") {
    throw "Refusing to provision Device Owner on a physical device. This script is AVD-only."
}

Write-Host "Installing $resolvedApk on $serial..."
& $adb -s $serial install -r $resolvedApk

Write-Host "Granting runtime permissions available on this AVD..."
$permissions = @(
    "android.permission.RECORD_AUDIO",
    "android.permission.CAMERA",
    "android.permission.READ_CONTACTS",
    "android.permission.POST_NOTIFICATIONS"
)
foreach ($permission in $permissions) {
    & $adb -s $serial shell pm grant $PackageName $permission 2>$null | Out-Null
}

Write-Host "Setting ALTER as Device Owner when the AVD policy state allows it..."
$ownerResult = & $adb -s $serial shell dpm set-device-owner $AdminReceiver 2>&1
Write-Host $ownerResult

if ($EnableSensitiveServicesForAvd) {
    Write-Host "Enabling Accessibility and notification listener for emulator automation..."
    $accessibility = "$PackageName/com.example.alter.AlterAccessibilityService"
    $listener = "$PackageName/com.example.alter.AlterNotificationListenerService"
    & $adb -s $serial shell settings put secure enabled_accessibility_services $accessibility
    & $adb -s $serial shell settings put secure accessibility_enabled 1
    & $adb -s $serial shell cmd notification allow_listener $listener
}

Write-Host "Launching ALTER..."
& $adb -s $serial shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1

Write-Host "Provisioning complete for AVD $serial."
