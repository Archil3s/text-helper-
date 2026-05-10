$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\Documents\text-helper-"

flutter pub get

dart format `
  lib\main.dart `
  lib\screens\sms_rcs_dashboard_screen.dart `
  lib\screens\auto_reply_rules_screen.dart `
  lib\screens\bulk_sms_send_screen.dart `
  lib\screens\rcs_policy_simple_screen.dart

flutter build apk --debug

$ApkPath = ".\build\app\outputs\flutter-apk\app-debug.apk"

if (-not (Test-Path $ApkPath)) {
    throw "APK was not created at $ApkPath"
}

adb install -r -d -t $ApkPath
adb push $ApkPath /sdcard/Download/text-helper-debug.apk

# Dev permission grants for testing.
adb shell pm grant com.example.text_helper android.permission.SEND_SMS 2>$null
adb shell pm grant com.example.text_helper android.permission.RECEIVE_SMS 2>$null
adb shell pm grant com.example.text_helper android.permission.POST_NOTIFICATIONS 2>$null

adb shell am force-stop com.example.text_helper
adb shell monkey -p com.example.text_helper -c android.intent.category.LAUNCHER 1

Write-Host ""
Write-Host "Done. App should open on SMS / RCS Dashboard." -ForegroundColor Green