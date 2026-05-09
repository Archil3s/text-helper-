param(
    [switch]$RunBuild,
    [ValidateSet("debug", "profile", "release")]
    [string]$BuildMode = "debug"
)

$ErrorActionPreference = "Continue"

$ScriptDir = $PSScriptRoot
$ProjectDir = Resolve-Path (Join-Path $ScriptDir "..")
$ReportPath = Join-Path $ProjectDir "chatgpt_git_context.txt"

Set-Location $ProjectDir

function Add-Line {
    param([string]$Text = "")
    Add-Content -Path $ReportPath -Value $Text
}

function Add-Section {
    param([string]$Title)

    Add-Line ""
    Add-Line "============================================================"
    Add-Line $Title
    Add-Line "============================================================"
}

function Add-Command {
    param(
        [string]$Title,
        [string]$Command
    )

    Add-Section $Title
    Add-Line "> $Command"

    try {
        $Output = Invoke-Expression $Command 2>&1
        if ($Output) {
            $Output | ForEach-Object { Add-Line $_.ToString() }
        } else {
            Add-Line "[no output]"
        }
    } catch {
        Add-Line "ERROR: $($_.Exception.Message)"
    }
}

function Add-FileHead {
    param(
        [string]$Path,
        [int]$Lines = 40
    )

    Add-Section "FILE HEAD: $Path"

    if (Test-Path $Path) {
        Get-Content $Path -TotalCount $Lines | ForEach-Object {
            Add-Line $_
        }
    } else {
        Add-Line "MISSING: $Path"
    }
}

function Add-FileFull {
    param([string]$Path)

    Add-Section "FULL FILE: $Path"

    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            Add-Line $_
        }
    } else {
        Add-Line "MISSING: $Path"
    }
}

function Add-RedactedCommand {
    param(
        [string]$Title,
        [string]$Command
    )

    Add-Section $Title
    Add-Line "> $Command"

    try {
        $Output = Invoke-Expression $Command 2>&1
        if ($Output) {
            $Output | ForEach-Object {
                $Line = $_.ToString()
                $Line = $Line -replace "https://[^/@\s]+@github.com/", "https://REDACTED@github.com/"
                Add-Line $Line
            }
        } else {
            Add-Line "[no output]"
        }
    } catch {
        Add-Line "ERROR: $($_.Exception.Message)"
    }
}

if (Test-Path $ReportPath) {
    Remove-Item $ReportPath -Force
}

Add-Line "CHATGPT GIT / FLUTTER / ADB CONTEXT REPORT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "Project: $ProjectDir"
Add-Line "RunBuild: $RunBuild"
Add-Line "BuildMode: $BuildMode"

Add-Section "IMPORTANT"
Add-Line "Paste this whole file into ChatGPT."
Add-Line "This script does not commit, push, pull, reset, or edit Git."
Add-Line "It only reads local state and optionally runs the local build script if -RunBuild is used."

Add-Command "CURRENT DIRECTORY" "Get-Location"
Add-Command "POWERSHELL VERSION" '$PSVersionTable.PSVersion'
Add-Command "GIT VERSION" "git --version"
Add-Command "FLUTTER VERSION" "flutter --version"
Add-Command "DART VERSION" "dart --version"
Add-Command "ADB VERSION" "adb version"
Add-Command "ADB DEVICES" "adb devices"

Add-RedactedCommand "GIT REMOTES" "git remote -v"
Add-Command "GIT STATUS SHORT" "git status --short"
Add-Command "GIT STATUS FULL" "git status"
Add-Command "GIT BRANCH VERBOSE" "git branch -vv"
Add-Command "GIT LAST 8 COMMITS" "git log --oneline --decorate -8"
Add-Command "GIT CURRENT HEAD" "git rev-parse HEAD"
Add-Command "GIT ORIGIN MAIN HEAD" "git rev-parse origin/main"
Add-Command "GIT DIFF STAT" "git diff --stat"
Add-Command "GIT DIFF IMPORTANT FILES" "git diff -- pubspec.yaml lib/main.dart lib/screens/home_screen.dart scripts/build-copy-apk.ps1 android/app/build.gradle.kts android/app/build.gradle"

Add-Command "PUBSPEC VERSION LINE" "Select-String -Path .\pubspec.yaml -Pattern '^version:'"
Add-Command "ANDROID APPLICATION ID" "Select-String -Path .\android\app\build.gradle.kts,.\android\app\build.gradle -Pattern 'applicationId|namespace' -ErrorAction SilentlyContinue"

Add-FileHead "pubspec.yaml" 80
Add-FileHead "lib/screens/home_screen.dart" 80
Add-FileHead "lib/main.dart" 80
Add-FileFull "scripts/build-copy-apk.ps1"

Add-Command "APK OUTPUT FILES" "Get-ChildItem .\build\app\outputs -Filter *.apk -Recurse -ErrorAction SilentlyContinue | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize"

if ($RunBuild) {
    Add-Section "RUNNING LOCAL BUILD SCRIPT"
    Add-Line "> .\scripts\build-copy-apk.ps1 -BuildMode $BuildMode"

    try {
        $BuildOutput = & ".\scripts\build-copy-apk.ps1" -BuildMode $BuildMode 2>&1
        $BuildOutput | ForEach-Object {
            Add-Line $_.ToString()
        }
    } catch {
        Add-Line "BUILD SCRIPT ERROR:"
        Add-Line $_.Exception.Message
    }

    Add-Command "APK OUTPUT FILES AFTER BUILD" "Get-ChildItem .\build\app\outputs -Filter *.apk -Recurse -ErrorAction SilentlyContinue | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize"
}

Add-Section "END"
Add-Line "Report path: $ReportPath"

Write-Host ""
Write-Host "Report written to:"
Write-Host $ReportPath
Write-Host ""
Write-Host "Opening report in Notepad..."
notepad $ReportPath
