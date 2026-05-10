$ErrorActionPreference = "Stop"

adb shell monkey -p com.example.text_helper -c android.intent.category.LAUNCHER 1

Write-Host ""
Write-Host "Text Helper launched." -ForegroundColor Green