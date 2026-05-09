$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$project = Split-Path -Parent $scriptDir
cd $project

$packageName = "com.example.text_helper"
$phoneDownloadPath = "/sdcard/Download/TextHelper-COPY-THIS.apk"
$constantCopyFileName = "TextHelper-COPY-THIS.apk"
$alwaysFreshBuild = $true
$createRevisionArchive = $true
$installAndLaunchOnPhone = $true

$apkPath = "$project\build\app\outputs\flutter-apk\app-debug.apk"
$shaPath = "$project\build\app\outputs\flutter-apk\app-debug.apk.sha1"
$sendDir = "$project\dist\localsend"
$revisionDir = "$sendDir\revisions"
$copyPath = "$sendDir\$constantCopyFileName"
$pubspecPath = "$project\pubspec.yaml"
$appVersionPath = "$project\lib\app_version.dart"

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

function Write-Utf8NoBomText {
    param(
        [string]$Path,
        [string]$Text
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
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

function Get-AdbPath {
    $adb = Get-Command "adb" -ErrorAction SilentlyContinue
    if ($adb) {
        return $adb.Source
    }
    $possible = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "C:\Android\platform-tools\adb.exe",
        "C:\platform-tools\adb.exe"
    )
    foreach ($path in $possible) {
        if (Test-Path $path) {
            return $path
        }
    }
    Write-Error "adb was not found. Install Android Platform Tools or add adb.exe to PATH."
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

function Write-AppVersionFile {
    param([hashtable]$VersionInfo)
    $content = "const String appVersion = '$($VersionInfo.FullVersion)';`nconst String appVersionName = '$($VersionInfo.VersionName)';`nconst String appBuildNumber = '$($VersionInfo.BuildNumber)';`n"
    Write-Utf8NoBomText $appVersionPath $content
}

function Assert-HomeScreenValid {
    $homePath = "$project\lib\screens\home_screen.dart"
    Assert-FileExists $homePath
    $homeText = Get-Content $homePath -Raw
    if ($homeText.Contains("C:\Users\")) {
        Write-Error "home_screen.dart is corrupted with a Windows path."
    }
    if (-not $homeText.Contains("class HomeScreen extends StatelessWidget")) {
        Write-Error "home_screen.dart does not contain HomeScreen class."
    }
}

function Assert-PhoneReady {
    param([string]$AdbPath)
    & $AdbPath start-server
    Stop-IfFailed "adb start-server failed."
    $devices = & $AdbPath devices
    $deviceLines = $devices | Where-Object { $_ -match "`tdevice$" }
    if (-not $deviceLines) {
        Write-Host $devices
        Write-Error "No authorized Android device found. Connect USB, enable USB debugging, and accept the phone prompt."
    }
    Write-Host "Connected Android device:"
    $deviceLines | ForEach-Object { Write-Host $_ }
}

Add-LocalGitExclude

$versionInfo = Get-AppVersionInfo
Write-AppVersionFile $versionInfo
$branch = git branch --show-current
$commit = git rev-parse --short HEAD
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safeBranch = $branch -replace "[^a-zA-Z0-9._-]", "-"
$revisionFileName = "TextHelper-$($versionInfo.FileVersion)-$safeBranch-$commit-$timestamp-debug.apk"
$revisionPath = "$revisionDir\$revisionFileName"
$adb = Get-AdbPath

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
Write-Host "PACKAGE:"
Write-Host $packageName
Write-Host "ADB:"
Write-Host $adb
Write-Host "PHONE DOWNLOAD TARGET:"
Write-Host $phoneDownloadPath

Assert-HomeScreenValid

if ($installAndLaunchOnPhone) {
    Assert-PhoneReady $adb
}

Write-Host "Preparing output folders..."
if (-not (Test-Path $sendDir)) {
    New-Item -ItemType Directory -Path $sendDir | Out-Null
}
if ($createRevisionArchive -and -not (Test-Path $revisionDir)) {
    New-Item -ItemType Directory -Path $revisionDir | Out-Null
}

if ($alwaysFreshBuild) {
    Write-Host "Deleting previous raw Flutter APK..."
    if (Test-Path $apkPath) {
        Remove-Item $apkPath -Force
    }
    if (Test-Path $shaPath) {
        Remove-Item $shaPath -Force
    }
    Write-Host "Deleting previous constant copy APK..."
    if (Test-Path $copyPath) {
        Remove-Item $copyPath -Force
    }
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
if ($createRevisionArchive) {
    Copy-Item $apkPath $revisionPath -Force
}

$hash = Get-FileHash $copyPath -Algorithm SHA256

if ($installAndLaunchOnPhone) {
    Write-Host "Pushing APK to Galaxy A16 Download folder..."
    & $adb push $copyPath $phoneDownloadPath
    Stop-IfFailed "adb push to phone Download failed."

    Write-Host "Force-stopping app before install..."
    & $adb shell am force-stop $packageName
    Stop-IfFailed "App force-stop before install failed."

    Write-Host "Installing/updating APK on phone..."
    & $adb install -r -d $copyPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "adb install failed. If you see INSTALL_FAILED_UPDATE_INCOMPATIBLE, the installed app has a different signature. Do not uninstall unless app data is backed up."
    }

    Write-Host "Force-stopping app after install so the new build reloads..."
    & $adb shell am force-stop $packageName
    Stop-IfFailed "App force-stop after install failed."

    Start-Sleep -Seconds 1

    Write-Host "Launching fresh app instance on phone..."
    & $adb shell am start -W -n "$packageName/.MainActivity" -a android.intent.action.MAIN -c android.intent.category.LAUNCHER
    Stop-IfFailed "Fresh app launch failed."

    Write-Host "Verifying installed package..."
    & $adb shell pm path $packageName
    Stop-IfFailed "Package verification failed."

    Write-Host "Verifying APK exists in phone Download..."
    & $adb shell ls -l $phoneDownloadPath
    Stop-IfFailed "Phone Download APK verification failed."
}

Write-Host "APK FILES:"
if ($createRevisionArchive) {
    Get-Item $apkPath, $copyPath, $revisionPath |
        Select-Object FullName, LastWriteTime, Length |
        Format-Table -AutoSize
} else {
    Get-Item $apkPath, $copyPath |
        Select-Object FullName, LastWriteTime, Length |
        Format-Table -AutoSize
}

Write-Host "DONE"
Write-Host "COPY THIS APK:"
Write-Host "$copyPath"
Write-Host "REVISION APK:"
Write-Host "$revisionPath"
Write-Host "PHONE DOWNLOAD APK:"
Write-Host "$phoneDownloadPath"
Write-Host "WINDOWS PHONE LOCATION:"
Write-Host "This PC\Galaxy A16\Internal storage\Download\TextHelper-COPY-THIS.apk"
Write-Host "SHA256:"
Write-Host $hash.Hash
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
