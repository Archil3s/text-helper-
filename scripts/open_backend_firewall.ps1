$ErrorActionPreference = "Stop"

New-NetFirewallRule `
  -DisplayName "Text Helper WhatsApp Backend 8787" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 8787

Write-Host ""
Write-Host "Firewall rule added for TCP 8787." -ForegroundColor Green