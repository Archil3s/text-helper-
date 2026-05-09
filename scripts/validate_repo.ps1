$ErrorActionPreference = "Stop"

function Fail {
    param([string]$Message)
    Write-Host ""
    Write-Host "VALIDATION FAILED: $Message" -ForegroundColor Red
    Write-Host ""
    exit 1
}

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root

if (-not (Test-Path "pubspec.yaml")) {
    Fail "pubspec.yaml not found. Run from the Flutter repo."
}

function Is-SourceFile {
    param([string]$Path)

    return $Path -match "\.(dart|kt|xml|md|yaml|yml|ps1)$"
}

$Changed = New-Object System.Collections.Generic.HashSet[string]

git diff --name-only --cached | ForEach-Object {
    if ($_ -and (Is-SourceFile $_)) {
        [void]$Changed.Add($_)
    }
}

git diff --name-only | ForEach-Object {
    if ($_ -and (Is-SourceFile $_)) {
        [void]$Changed.Add($_)
    }
}

git rev-parse --verify origin/main *> $null
if ($LASTEXITCODE -eq 0) {
    git diff --name-only origin/main...HEAD | ForEach-Object {
        if ($_ -and (Is-SourceFile $_)) {
            [void]$Changed.Add($_)
        }
    }
}

git status --porcelain | ForEach-Object {
    if ($_.StartsWith("?? ")) {
        $Path = $_.Substring(3)

        if (Is-SourceFile $Path) {
            Fail "Untracked source file exists: $Path. Add it or remove it before commit/push."
        }
    }
}

foreach ($Path in $Changed) {
    if (-not (Test-Path $Path)) {
        continue
    }

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $Text = [System.IO.File]::ReadAllText($FullPath)
    $Bad = [regex]::Matches($Text, "[^\x09\x0A\x0D\x20-\x7E]")

    if ($Bad.Count -gt 0) {
        $Code = [int][char]$Bad[0].Value
        Fail "$Path contains non-ASCII text. First bad code: U+$('{0:X4}' -f $Code)"
    }
}

foreach ($Path in $Changed) {
    if ($Path -notmatch "\.dart$") {
        continue
    }

    if (-not (Test-Path $Path)) {
        continue
    }

    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $Text = [System.IO.File]::ReadAllText($FullPath)
    $Matches = [regex]::Matches($Text, "import\s+'([^']+)';")

    foreach ($Match in $Matches) {
        $ImportPath = $Match.Groups[1].Value

        if ($ImportPath.StartsWith("package:") -or $ImportPath.StartsWith("dart:")) {
            continue
        }

        $BaseDir = Split-Path -Parent $FullPath
        $Target = [System.IO.Path]::GetFullPath((Join-Path $BaseDir $ImportPath))

        if (-not (Test-Path $Target)) {
            Fail "$Path imports missing local file: $ImportPath"
        }
    }
}

if (Test-Path "lib/screens/home_screen.dart") {
    $HomeSource = [System.IO.File]::ReadAllText((Resolve-Path "lib/screens/home_screen.dart"))

    if ($HomeSource -match "C:\\Users") {
        Fail "home_screen.dart contains a pasted Windows path."
    }
}

Write-Host "Repo validation passed." -ForegroundColor Green