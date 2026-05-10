$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\Documents\text-helper-"

flutter pub get

dart format `
  lib\main.dart `
  lib\screens\whatsapp_business_sender_screen.dart

flutter build apk --debug

$ApkPath = ".\build\app\outputs\flutter-apk\app-debug.apk"

if (-not (Test-Path $ApkPath)) {
    throw "APK was not created at $ApkPath"
}

adb install -r -d -t $ApkPath
adb push $ApkPath /sdcard/Download/text-helper-debug.apk
adb shell am force-stop com.example.text_helper
adb shell monkey -p com.example.text_helper -c android.intent.category.LAUNCHER 1

Write-Host ""
Write-Host "Done. App should open on WhatsApp Business Sender." -ForegroundColor Green