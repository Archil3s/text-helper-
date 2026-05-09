param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [switch]$SkipChecks,
    [switch]$DeleteFeatureBranchAfterMerge
)

$ErrorActionPreference = "Stop"

function Run-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs
    )

    Write-Host ""
    Write-Host "> git $($GitArgs -join ' ')"
    & git @GitArgs

    if ($LASTEXITCODE -ne 0) {
        throw "git failed: git $($GitArgs -join ' ')"
    }
}

function Run-Cmd {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Exe,

        [Parameter(Mandatory = $true)]
        [string[]]$CommandArgs
    )

    Write-Host ""
    Write-Host "> $Exe $($CommandArgs -join ' ')"
    & $Exe @CommandArgs

    if ($LASTEXITCODE -ne 0) {
        throw "$Exe failed: $Exe $($CommandArgs -join ' ')"
    }
}

function New-Slug {
    param([string]$Text)

    $slug = $Text.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ($slug.Length -gt 40) {
        $slug = $slug.Substring(0, 40).Trim("-")
    }

    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "feature-update"
    }

    return $slug
}

if (-not (Test-Path ".git")) {
    throw "Run this from the Git project root."
}

$currentBranch = (git branch --show-current).Trim()

if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    throw "Could not detect current Git branch."
}

Write-Host "CURRENT BRANCH: $currentBranch"

# If user is on main, automatically create a feature branch.
if ($currentBranch -eq "main" -or $currentBranch -eq "master") {
    $slug = New-Slug $Message
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $featureBranch = "feature/$slug-$timestamp"

    Run-Git @("switch", "-c", $featureBranch)
    $currentBranch = $featureBranch
} else {
    $featureBranch = $currentBranch
}

Write-Host "FEATURE BRANCH: $featureBranch"

if (-not $SkipChecks) {
    Run-Cmd "flutter" @("pub", "get")
    Run-Cmd "dart" @("format", "lib")
    Run-Cmd "flutter" @("analyze")
}

$status = (git status --short)

if ([string]::IsNullOrWhiteSpace($status)) {
    throw "No local changes to commit."
}

Run-Git @("add", "-A")
Run-Git @("commit", "-m", $Message)

Run-Git @("fetch", "origin")
Run-Git @("push", "-u", "origin", $featureBranch)

Run-Git @("switch", "main")
Run-Git @("pull", "--ff-only", "origin", "main")
Run-Git @("merge", "--no-ff", $featureBranch, "-m", "Merge $featureBranch")
Run-Git @("push", "origin", "main")

if ($DeleteFeatureBranchAfterMerge) {
    Run-Git @("branch", "-d", $featureBranch)
    Run-Git @("push", "origin", "--delete", $featureBranch)
}

Write-Host ""
Write-Host "DONE"
Write-Host "Committed branch: $featureBranch"
Write-Host "Merged into: main"
Write-Host "Pushed: origin main"
