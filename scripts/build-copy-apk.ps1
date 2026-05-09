$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$project = Split-Path -Parent $scriptDir
cd $project

$apkPath = "$project\build\app\outputs\flutter-apk\app-debug.apk"
$sendDir = "$project\dist\localsend"
$pubspecPath = "$project\pubspec.yaml"

function Stop-IfFailed {
    param([string]$Message)
    if ($LASTEXITCODE -ne 0) {
        Write-Error $Message
    }
}

function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Error "Required file not found: $Path"
    }
}

function Add-LocalGitExclude {
    $excludePath = ".git\info\exclude"
    if (-not (Test-Path $excludePath)) {
        Write-Error "Missing git exclude file: $excludePath"
    }
    $exclude = Get-Content $excludePath -Raw
    if ($exclude -notmatch "(?m)^dist/$") {
        Add-Content $excludePath "`ndist/"
    }
}

function Get-AppVersionInfo {
    Assert-FileExists $pubspecPath
    $pubspec = Get-Content $pubspecPath -Raw
    $match = [regex]::Match(
        $pubspec,
        "(?m)^version:\s*([0-9A-Za-z\.\-_]+)(?:\+([0-9A-Za-z\.\-_]+))?\s*$"
    )
    if (-not $match.Success) {
        Write-Error "Could not find version line in pubspec.yaml"
    }
    $versionName = $match.Groups[1].Value
    $buildNumber = $match.Groups[2].Value
    if ([string]::IsNullOrWhiteSpace($buildNumber)) {
        $buildNumber = "0"
    }
    return @{
        VersionName = $versionName
        BuildNumber = $buildNumber
        FullVersion = "$versionName+$buildNumber"
        FileVersion = "v$versionName-$buildNumber"
    }
}

function Assert-HomeScreenValid {
    $homePath = "$project\lib\screens\home_screen.dart"
    Assert-FileExists $homePath
    $home = Get-Content $homePath -Raw
    if ($home.Contains("C:\Users\")) {
        Write-Error "home_screen.dart is corrupted with a Windows path."
    }
    if (-not $home.Contains("class HomeScreen extends StatelessWidget")) {
        Write-Error "home_screen.dart does not contain HomeScreen class."
    }
}

Add-LocalGitExclude

$versionInfo = Get-AppVersionInfo
$branch = git branch --show-current
$commit = git rev-parse --short HEAD
$copyFileName = "TextHelper-$($versionInfo.FileVersion)-COPY-THIS.apk"
$copyPath = "$sendDir\$copyFileName"

Write-Host "APP VERSION:"
Write-Host $versionInfo.VersionName
Write-Host "BUILD NUMBER:"
Write-Host $versionInfo.BuildNumber
Write-Host "FULL VERSION:"
Write-Host $versionInfo.FullVersion
Write-Host "BRANCH:"
Write-Host $branch
Write-Host "COMMIT:"
Write-Host $commit
Write-Host "COPY APK NAME:"
Write-Host $copyFileName

Assert-HomeScreenValid

Write-Host "Deleting old LocalSend APK files..."
if (-not (Test-Path $sendDir)) {
    New-Item -ItemType Directory -Path $sendDir | Out-Null
}
Get-ChildItem $sendDir -Filter "*.apk" -File -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "Deleting old Flutter build APK..."
if (Test-Path $apkPath) {
    Remove-Item $apkPath -Force
}

Write-Host "Running dart format..."
dart format lib
Stop-IfFailed "dart format lib failed."

Write-Host "Running flutter analyze..."
flutter analyze
Stop-IfFailed "flutter analyze failed."

$buildStartedAt = Get-Date

Write-Host "Building fresh debug APK..."
flutter build apk --debug
Stop-IfFailed "flutter build apk --debug failed."

if (-not (Test-Path $apkPath)) {
    Write-Error "APK was not created: $apkPath"
}

$apk = Get-Item $apkPath
if ($apk.LastWriteTime -lt $buildStartedAt.AddSeconds(-5)) {
    Write-Error "APK timestamp does not look fresh: $($apk.LastWriteTime)"
}

Copy-Item $apkPath $copyPath -Force

Write-Host "ONLY FILE TO COPY/SEND:"
Get-Item $copyPath | Select-Object FullName, LastWriteTime, Length | Format-Table -AutoSize

$explorer = Join-Path $env:WINDIR "explorer.exe"
if (Test-Path $explorer) {
    Start-Process $explorer $sendDir
}

Write-Host "DONE"
Write-Host "COPY THIS APK:"
Write-Host "$copyPath"
Write-Host "APP VERSION:"
Write-Host $versionInfo.VersionName
Write-Host "BUILD NUMBER:"
Write-Host $versionInfo.BuildNumber
Write-Host "FULL VERSION:"
Write-Host $versionInfo.FullVersion
Write-Host "BRANCH:"
Write-Host $branch
Write-Host "COMMIT:"
Write-Host $commit
Write-Host "APK:"
Write-Host "$project\build\app\outputs\flutter-apk\app-debug.apk"
