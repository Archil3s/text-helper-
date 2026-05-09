$ErrorActionPreference = "Stop"

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "BUILD FAILED: $Message" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root

if (-not (Test-Path "pubspec.yaml")) {
    Fail "pubspec.yaml not found. Run from the Flutter repo."
}

Write-Host "Running repo validation..." -ForegroundColor Cyan
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\validate_repo.ps1"
if ($LASTEXITCODE -ne 0) {
    Fail "Repo validation failed."
}

Write-Host "Running flutter pub get..." -ForegroundColor Cyan
flutter pub get

Write-Host "Running dart format lib..." -ForegroundColor Cyan
dart format lib

Write-Host "Running flutter analyze..." -ForegroundColor Cyan
flutter analyze

Write-Host "Building debug APK..." -ForegroundColor Cyan
flutter build apk --debug

$ApkPath = ".\build\app\outputs\flutter-apk\app-debug.apk"

if (-not (Test-Path $ApkPath)) {
    Fail "APK was not created at $ApkPath."
}

Write-Host "Installing APK on connected phone..." -ForegroundColor Cyan
adb install -r -d -t $ApkPath

Write-Host "Copying APK to phone Downloads..." -ForegroundColor Cyan
adb push $ApkPath /sdcard/Download/text-helper-debug.apk

Write-Host "Force-stopping app..." -ForegroundColor Cyan
adb shell am force-stop com.example.text_helper

Write-Host "Launching app..." -ForegroundColor Cyan
adb shell monkey -p com.example.text_helper -c android.intent.category.LAUNCHER 1

Write-Host ""
Write-Host "SAFE BUILD INSTALL PASSED." -ForegroundColor Green