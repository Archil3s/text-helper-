$ErrorActionPreference = "Stop"

adb shell am force-stop com.example.text_helper

Write-Host ""
Write-Host "Text Helper force-stopped." -ForegroundColor Green