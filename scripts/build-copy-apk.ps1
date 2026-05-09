param(
    [ValidateSet("debug", "profile", "release")]
    [string]$BuildMode = "debug",

    [string]$PackageId = "com.example.text_helper",

    [switch]$Clean,
    [switch]$PullLatest,
    [switch]$CleanInstall,
    [switch]$AlsoCopyToPhoneDownloads
)

$ErrorActionPreference = "Stop"

function Need {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command: $Name"
    }
}

function RunCmd {
    param(
        [string]$Exe,
        [string[]]$CmdArgs
    )

    Write-Host ""
    Write-Host "> $Exe $($CmdArgs -join ' ')"
    & $Exe @CmdArgs

    if ($LASTEXITCODE -ne 0) {
        throw "$Exe failed with exit code $LASTEXITCODE"
    }
}

Need git
Need flutter
Need dart
Need adb

$ScriptDir = $PSScriptRoot
$ProjectDir = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $ProjectDir

Write-Host "PROJECT: $ProjectDir"

if (-not (Test-Path ".git")) {
    throw "Not a Git repository."
}

if (-not (Test-Path "pubspec.yaml")) {
    throw "Missing pubspec.yaml."
}

$HomePath = ".\lib\screens\home_screen.dart"
if (Test-Path $HomePath) {
    $HomeFirstLine = Get-Content $HomePath -TotalCount 1
    if ($HomeFirstLine -match "^C:\\Users\\") {
        throw "home_screen.dart is still corrupted. Fix it before building."
    }
}

if ($PullLatest) {
    RunCmd git @("pull", "--ff-only")
}

if ($Clean) {
    RunCmd flutter @("clean")
}

RunCmd flutter @("pub", "get")
RunCmd dart @("format", "lib")
RunCmd flutter @("analyze")

$BuildNumber = (git rev-list --count HEAD).Trim()
$Commit = (git rev-parse --short HEAD).Trim()

$Pubspec = Get-Content ".\pubspec.yaml" -Raw
$VersionMatch = [regex]::Match(
    $Pubspec,
    "(?m)^version:\s*([0-9A-Za-z\.\-_]+)(?:\+([0-9A-Za-z\.\-_]+))?\s*$"
)

if ($VersionMatch.Success) {
    $VersionName = $VersionMatch.Groups[1].Value
} else {
    $VersionName = "1.0.0"
}

Write-Host ""
Write-Host "BUILD MODE: $BuildMode"
Write-Host "VERSION: $VersionName+$BuildNumber"
Write-Host "COMMIT: $Commit"
Write-Host "PACKAGE: $PackageId"

$OutputDir = Join-Path $ProjectDir "build\app\outputs\flutter-apk"

if (Test-Path $OutputDir) {
    Get-ChildItem $OutputDir -Filter "*.apk" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

RunCmd flutter @(
    "build",
    "apk",
    "--$BuildMode",
    "--build-name",
    $VersionName,
    "--build-number",
    $BuildNumber
)

$Apks = Get-ChildItem $OutputDir -Filter "*.apk" -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if (-not $Apks -or $Apks.Count -eq 0) {
    Write-Host ""
    Write-Host "No APK found under:"
    Write-Host $OutputDir
    throw "Flutter did not produce an APK."
}

$Apk = $Apks[0]
$ApkPath = $Apk.FullName

Write-Host ""
Write-Host "APK FOUND:"
Write-Host $ApkPath

$Devices = adb devices | Select-String "`tdevice$"
if ($Devices.Count -eq 0) {
    throw "No Android device found. Connect Galaxy A16 and approve USB debugging."
}

if ($CleanInstall) {
    Write-Host ""
    Write-Host "CLEAN INSTALL: removing old app and app data..."
    adb shell am force-stop $PackageId | Out-Host
    adb uninstall $PackageId | Out-Host
}

Write-Host ""
Write-Host "INSTALLING APK..."
RunCmd adb @("install", "-r", "-d", "-t", $ApkPath)

Write-Host ""
Write-Host "STOPPING OLD APP..."
RunCmd adb @("shell", "am", "force-stop", $PackageId)

Start-Sleep -Seconds 1

Write-Host ""
Write-Host "RELOADING APP..."
RunCmd adb @(
    "shell",
    "monkey",
    "-p",
    $PackageId,
    "-c",
    "android.intent.category.LAUNCHER",
    "1"
)

if ($AlsoCopyToPhoneDownloads) {
    $RemoteApk = "/sdcard/Download/TextHelper-$BuildMode-$VersionName-$BuildNumber-$Commit.apk"

    Write-Host ""
    Write-Host "COPYING APK TO PHONE DOWNLOADS..."
    RunCmd adb @("push", $ApkPath, $RemoteApk)

    Write-Host "COPIED TO:"
    Write-Host $RemoteApk
}

Write-Host ""
Write-Host "DONE"
Write-Host "INSTALLED AND RELOADED: $PackageId"
Write-Host "APK: $ApkPath"
Write-Host "VERSION: $VersionName+$BuildNumber"
Write-Host "COMMIT: $Commit"
