#Requires -Version 5.1
# Ikshvaku installer for Windows (PowerShell 5.1+ and PowerShell 7).
# Run from the repository root:  .\install.ps1

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$InstallDir  = Join-Path $env:USERPROFILE '.ikshvaku'
$BinDir      = Join-Path $env:USERPROFILE '.local\bin'
$EnvDir      = Join-Path $env:USERPROFILE '.Python-Env'
$UvInstaller = 'https://astral.sh/uv/install.ps1'

# Where this script lives — and where its payload files are.
# When run remotely (irm ... | iex) $PSScriptRoot is empty: fetch the payload
# from GitHub instead. IKSHVAKU_REPO_RAW overrides the source (tests/forks).
$scriptDir = $PSScriptRoot
$fetchedRemotely = $false
if (-not $scriptDir -or -not (Test-Path (Join-Path $scriptDir 'ikshvaku.ps1'))) {
    $rawBase = if ($env:IKSHVAKU_REPO_RAW) { $env:IKSHVAKU_REPO_RAW } else { 'https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main' }
    $scriptDir = Join-Path ([IO.Path]::GetTempPath()) ("ikshvaku-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
    $fetchedRemotely = $true
    Write-Host ':: Remote install — downloading Ikshvaku files...'
    foreach ($f in @('ikshvaku.ps1', 'ikshvaku.cmd', 'uninstall.ps1')) {
        try {
            Invoke-WebRequest -Uri "$rawBase/$f" -OutFile (Join-Path $scriptDir $f) -UseBasicParsing
        } catch {
            Write-Host "❌ download failed ($f): $_" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ':: Installing Ikshvaku...'
Write-Host ":: PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition) Edition)"

# --- uv: powers all environments. Downloaded automatically if missing. ---
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host ":: uv found at $((Get-Command uv).Source)"
} else {
    Write-Host ':: uv not found — downloading uv...' -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri $UvInstaller | Invoke-Expression
    } catch {
        Write-Host "❌ uv download failed: $_" -ForegroundColor Red
        exit 1
    }
    $env:Path = "$BinDir;$env:Path"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host '❌ uv installation failed. Install it manually: https://docs.astral.sh/uv/' -ForegroundColor Red
        exit 1
    }
    Write-Host ':: uv installed' -ForegroundColor Green
}

# keep ~\.local\bin on the user PATH (survives new shells)
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
try {
    if (($userPath -split ';') -notcontains $BinDir) {
        [Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
        Write-Host ":: Added $BinDir to your user PATH (restart your shell to pick it up)"
    }
} catch {
    Write-Host "⚠ Could not update the user PATH: $_" -ForegroundColor Yellow
}

foreach ($dir in @($InstallDir, $BinDir, $EnvDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Copy-Item -Force (Join-Path $scriptDir 'ikshvaku.ps1')  $InstallDir
Copy-Item -Force (Join-Path $scriptDir 'ikshvaku.cmd')  $InstallDir
Copy-Item -Force (Join-Path $scriptDir 'uninstall.ps1') $InstallDir
Copy-Item -Force (Join-Path $scriptDir 'ikshvaku.cmd')  $BinDir
if ($fetchedRemotely) { Remove-Item -Recurse -Force $scriptDir -ErrorAction SilentlyContinue }

# --- wire up $PROFILE so the function loads in PowerShell ---
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir  = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
$existing = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
if (-not $existing -or $existing -notmatch 'ikshvaku\.ps1') {
    Add-Content -LiteralPath $profilePath -Value @"

# >>> Ikshvaku >>>
. "`$env:USERPROFILE\.ikshvaku\ikshvaku.ps1"
# <<< Ikshvaku <<<
"@
}

# --- execution policy: make sure dot-sourcing from $PROFILE is allowed ---
if ((Get-ExecutionPolicy -Scope CurrentUser) -in @('Restricted', 'Undefined')) {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host ':: Set execution policy to RemoteSigned (CurrentUser)'
    } catch {
        Write-Host '⚠ Could not set the execution policy — the function may not load from $PROFILE.' -ForegroundColor Yellow
    }
}

Write-Host ':: Installed successfully' -ForegroundColor Green
Write-Host ':: Restart your shell, or run:  . $PROFILE'
Write-Host ':: PowerShell: full function + tab completion.'
Write-Host ':: cmd: works too — activate/deactivate natively, the rest via PowerShell.'
Write-Host ':: To support us: https://github.com/ashish-jha-73/IkshvakuPEM'
Write-Host ':: To remove Ikshvaku later, run: ~\.ikshvaku\uninstall.ps1'
