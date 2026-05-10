param(
    [Parameter(Mandatory=$true)]
    [string]$Message
)

$ErrorActionPreference = "Stop"

Set-Location "C:\Users\Danie\Documents\text-helper-"

git status --short

$Changes = git status --porcelain

if (-not $Changes) {
    Write-Host "No changes to save." -ForegroundColor Yellow
    exit 0
}

git add -A
git commit -m $Message
git pull --rebase origin main
git push origin main

Write-Host ""
Write-Host "Saved and pushed." -ForegroundColor Green