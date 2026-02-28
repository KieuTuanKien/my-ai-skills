# ============================================================
# MY AI SKILLS - Setup Script (Windows PowerShell)
# One command to install all skills & rules on a new machine
# ============================================================

param(
    [switch]$SkipOrchestra,
    [switch]$SkipRules,
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$RepoRoot\my-ai-skills\skills")) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}
$SkillsSource = Join-Path $RepoRoot "skills"
$RulesSource = Join-Path $RepoRoot "rules"

$CursorSkills = Join-Path $env:USERPROFILE ".cursor\skills"
$OrchestraSkills = Join-Path $env:USERPROFILE ".orchestra\skills"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MY AI SKILLS - Setup Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Install Skills to ~/.cursor/skills/ ---
Write-Host "[1/3] Installing skills to $CursorSkills ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $CursorSkills -Force | Out-Null

$skills = Get-ChildItem $SkillsSource -Directory
$count = 0
foreach ($skill in $skills) {
    $dest = Join-Path $CursorSkills $skill.Name
    Copy-Item $skill.FullName $dest -Recurse -Force
    $count++
}
Write-Host "  -> $count skills installed" -ForegroundColor Green

# --- Install Skills to ~/.orchestra/skills/ ---
if (-not $SkipOrchestra) {
    Write-Host "[2/3] Installing skills to $OrchestraSkills ..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OrchestraSkills -Force | Out-Null

    foreach ($skill in $skills) {
        $dest = Join-Path $OrchestraSkills $skill.Name
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        $skillFile = Join-Path $skill.FullName "SKILL.md"
        if (Test-Path $skillFile) {
            Copy-Item $skillFile (Join-Path $dest "SKILL.md") -Force
        }
        $refsDir = Join-Path $skill.FullName "references"
        if (Test-Path $refsDir) {
            Copy-Item $refsDir $dest -Recurse -Force
        }
    }
    Write-Host "  -> $count skills mirrored to Orchestra" -ForegroundColor Green
} else {
    Write-Host "[2/3] Skipping Orchestra installation" -ForegroundColor DarkGray
}

# --- Install Rules ---
if (-not $SkipRules) {
    if ($ProjectPath) {
        $RulesDest = Join-Path $ProjectPath ".cursor\rules"
    } else {
        $RulesDest = Join-Path (Get-Location) ".cursor\rules"
    }
    Write-Host "[3/3] Installing rules to $RulesDest ..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $RulesDest -Force | Out-Null

    $ruleFiles = Get-ChildItem $RulesSource -File -Filter "*.mdc"
    foreach ($rule in $ruleFiles) {
        Copy-Item $rule.FullName $RulesDest -Force
        Write-Host "  -> $($rule.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "[3/3] Skipping rules installation" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "  $count skills + rules installed" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
