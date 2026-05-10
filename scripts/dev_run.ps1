$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\Documents\text-helper-"

Write-Host ""
Write-Host "Running Text Helper dev build..." -ForegroundColor Cyan

flutter pub get

dart format `
  lib\main.dart `
  lib\screens\sms_rcs_dashboard_screen.dart `
  lib\screens\auto_reply_rules_screen.dart `
  lib\screens\bulk_sms_send_screen.dart `
  lib\screens\rcs_policy_simple_screen.dart

flutter clean
flutter pub get
flutter build apk --debug

$ApkPath = ".\build\app\outputs\flutter-apk\app-debug.apk"

if (-not (Test-Path $ApkPath)) {
    throw "APK was not created at $ApkPath"
}

Write-Host ""
Write-Host "Installing APK..." -ForegroundColor Cyan
adb install -r -d -t $ApkPath

Write-Host ""
Write-Host "Copying APK to phone Downloads..." -ForegroundColor Cyan
adb push $ApkPath /sdcard/Download/text-helper-debug.apk

Write-Host ""
Write-Host "Trying to grant dev permissions..." -ForegroundColor Cyan

cmd /c "adb shell pm grant com.example.text_helper android.permission.SEND_SMS 2>nul"
cmd /c "adb shell pm grant com.example.text_helper android.permission.RECEIVE_SMS 2>nul"
cmd /c "adb shell pm grant com.example.text_helper android.permission.POST_NOTIFICATIONS 2>nul"

Write-Host ""
Write-Host "Force-stopping app..." -ForegroundColor Cyan
adb shell am force-stop com.example.text_helper

Write-Host ""
Write-Host "Launching app..." -ForegroundColor Cyan
adb shell monkey -p com.example.text_helper -c android.intent.category.LAUNCHER 1

Write-Host ""
Write-Host "Done. App should open on SMS / RCS Dashboard." -ForegroundColor Green