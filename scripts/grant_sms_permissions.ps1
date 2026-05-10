$ErrorActionPreference = "Stop"

adb shell pm grant com.example.text_helper android.permission.SEND_SMS 2>$null
adb shell pm grant com.example.text_helper android.permission.RECEIVE_SMS 2>$null
adb shell pm grant com.example.text_helper android.permission.POST_NOTIFICATIONS 2>$null

Write-Host ""
Write-Host "SMS permissions granted for dev testing." -ForegroundColor Green