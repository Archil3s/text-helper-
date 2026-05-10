$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Text Helper LAN IP helper" -ForegroundColor Cyan
Write-Host ""

$addresses = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixOrigin -ne "WellKnown"
    } |
    Select-Object IPAddress, InterfaceAlias, AddressState

if (-not $addresses) {
    Write-Host "No LAN IPv4 address found." -ForegroundColor Red
    Write-Host "Try running: ipconfig" -ForegroundColor Yellow
    exit 1
}

Write-Host "Possible PC LAN IP addresses:" -ForegroundColor Green
$addresses | Format-Table -AutoSize

$preferred = $addresses |
    Where-Object {
        $_.InterfaceAlias -match "Wi-Fi|Ethernet" -and
        $_.AddressState -eq "Preferred"
    } |
    Select-Object -First 1

if (-not $preferred) {
    $preferred = $addresses | Select-Object -First 1
}

Write-Host ""
Write-Host "Use this Backend URL in the phone app:" -ForegroundColor Green
Write-Host "http://$($preferred.IPAddress):8787" -ForegroundColor Yellow
Write-Host ""
Write-Host "Test from the Galaxy A16 browser:" -ForegroundColor Cyan
Write-Host "http://$($preferred.IPAddress):8787/health" -ForegroundColor Yellow
