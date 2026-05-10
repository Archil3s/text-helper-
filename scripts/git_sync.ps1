$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\Documents\text-helper-"

Write-Host ""
Write-Host "Syncing local main with GitHub main..." -ForegroundColor Cyan

git fetch origin main
git switch main
git pull --rebase origin main
git status --short

Write-Host ""
Write-Host "Sync complete." -ForegroundColor Green