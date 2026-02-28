# ============================================================
# MY AI SKILLS - One-Click Installer for New Machine (Windows)
# Copy file này sang máy mới, mở PowerShell Admin, chạy:
#   .\install-new-machine.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$RepoURL = "https://github.com/KieuTuanKien/my-ai-skills.git"
$InstallDir = Join-Path $env:USERPROFILE "my-ai-skills"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  MY AI SKILLS - Full Installer for New Machine" -ForegroundColor Cyan
Write-Host "  105 skills + working rules for Cursor IDE" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Install Git ---
Write-Host "[1/6] Checking Git..." -ForegroundColor Yellow
$gitOk = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitOk) {
    Write-Host "  -> Installing Git..." -ForegroundColor DarkGray
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  -> Git installed" -ForegroundColor Green
} else {
    Write-Host "  -> Git OK ($((git --version) -replace 'git version ',''))" -ForegroundColor Green
}

# --- Step 2: Install GitHub CLI ---
Write-Host "[2/6] Checking GitHub CLI..." -ForegroundColor Yellow
$ghOk = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghOk) {
    Write-Host "  -> Installing GitHub CLI..." -ForegroundColor DarkGray
    winget install GitHub.cli --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  -> GitHub CLI installed" -ForegroundColor Green
} else {
    Write-Host "  -> GitHub CLI OK ($((gh --version | Select-Object -First 1) -replace 'gh version ',''))" -ForegroundColor Green
}

# --- Step 3: Login GitHub ---
Write-Host "[3/6] Checking GitHub login..." -ForegroundColor Yellow
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  -> Please login to GitHub in the browser..." -ForegroundColor DarkGray
    gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] GitHub login failed. Please try again." -ForegroundColor Red
        exit 1
    }
    Write-Host "  -> Logged in successfully" -ForegroundColor Green
} else {
    Write-Host "  -> Already logged in" -ForegroundColor Green
}

# --- Step 4: Clone repo ---
Write-Host "[4/6] Cloning skills repo..." -ForegroundColor Yellow
if (Test-Path $InstallDir) {
    Write-Host "  -> Repo exists, pulling latest..." -ForegroundColor DarkGray
    Push-Location $InstallDir
    git pull
    Pop-Location
    Write-Host "  -> Updated to latest" -ForegroundColor Green
} else {
    git clone $RepoURL $InstallDir
    Write-Host "  -> Cloned to $InstallDir" -ForegroundColor Green
}

# --- Step 5: Install skills ---
Write-Host "[5/6] Installing skills..." -ForegroundColor Yellow

$SkillsSource = Join-Path $InstallDir "skills"
$CursorSkills = Join-Path $env:USERPROFILE ".cursor\skills"
$OrchestraSkills = Join-Path $env:USERPROFILE ".orchestra\skills"

New-Item -ItemType Directory -Path $CursorSkills -Force | Out-Null
New-Item -ItemType Directory -Path $OrchestraSkills -Force | Out-Null

$skills = Get-ChildItem $SkillsSource -Directory
$count = 0
foreach ($skill in $skills) {
    Copy-Item $skill.FullName (Join-Path $CursorSkills $skill.Name) -Recurse -Force

    $orchDest = Join-Path $OrchestraSkills $skill.Name
    New-Item -ItemType Directory -Path $orchDest -Force | Out-Null
    $skillFile = Join-Path $skill.FullName "SKILL.md"
    if (Test-Path $skillFile) { Copy-Item $skillFile (Join-Path $orchDest "SKILL.md") -Force }
    $refsDir = Join-Path $skill.FullName "references"
    if (Test-Path $refsDir) { Copy-Item $refsDir $orchDest -Recurse -Force }

    $count++
}
Write-Host "  -> $count skills installed to ~/.cursor/skills/" -ForegroundColor Green
Write-Host "  -> $count skills mirrored to ~/.orchestra/skills/" -ForegroundColor Green

# --- Step 6: Install rules ---
Write-Host "[6/6] Installing rules..." -ForegroundColor Yellow
$RulesSource = Join-Path $InstallDir "rules"
$ruleFiles = Get-ChildItem $RulesSource -File -Filter "*.mdc" -ErrorAction SilentlyContinue

if ($ruleFiles) {
    $currentDir = Get-Location
    $RulesDest = Join-Path $currentDir ".cursor\rules"
    New-Item -ItemType Directory -Path $RulesDest -Force | Out-Null
    foreach ($rule in $ruleFiles) {
        Copy-Item $rule.FullName $RulesDest -Force
        Write-Host "  -> $($rule.Name)" -ForegroundColor Green
    }
    Write-Host "  -> Rules installed to $RulesDest" -ForegroundColor Green
    Write-Host ""
    Write-Host "  TIP: To install rules to another project:" -ForegroundColor DarkGray
    Write-Host "    cd D:\YourProject" -ForegroundColor DarkGray
    Write-Host "    Copy-Item '$RulesSource\*' '.cursor\rules\' -Force" -ForegroundColor DarkGray
} else {
    Write-Host "  -> No rule files found" -ForegroundColor DarkGray
}

# --- Done ---
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  DONE! $count skills + rules installed" -ForegroundColor Green
Write-Host "" -ForegroundColor Cyan
Write-Host "  Skills location : $CursorSkills" -ForegroundColor White
Write-Host "  Repo location   : $InstallDir" -ForegroundColor White
Write-Host "" -ForegroundColor Cyan
Write-Host "  Next: Open Cursor IDE and start working!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
