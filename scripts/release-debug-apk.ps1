$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $RepoRoot

Write-Host "Running Flutter tests"
flutter test

Write-Host "Running API gateway compile check"
$env:PYTHONPATH = "$RepoRoot\services\api_gateway\src"
python -m compileall services\api_gateway\src\alter_api_gateway

Write-Host "Building debug APK"
flutter build apk --debug

$Apk = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-debug.apk"
if (-not (Test-Path $Apk)) {
    throw "Expected APK was not created: $Apk"
}

Write-Host "Latest debug APK: $Apk"
