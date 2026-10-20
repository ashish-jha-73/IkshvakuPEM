# Ikshvaku installer for Windows (PowerShell 5.1+ and PowerShell 7).
# Run from the repository root:  .\install.ps1
# NOTE: no BOM on this file - it is executed via `irm | iex` by the one-liner,
# where a BOM would break Invoke-Expression. Avoid file-only directives
# (#Requires); use runtime checks instead.
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host '[X] Ikshvaku requires PowerShell 5.1 or newer' -ForegroundColor Red
    exit 1
}

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

$InstallDir  = Join-Path $env:USERPROFILE '.ikshvaku'
$BinDir      = Join-Path $env:USERPROFILE '.local\bin'
$EnvDir      = Join-Path $env:USERPROFILE '.Python-Env'
$UvInstaller = 'https://astral.sh/uv/install.ps1'
$IkshvakuVersion = '1.4.0'

# Optional version pin: set IKSHVAKU_VERSION before invoking the installer
# (e.g. $env:IKSHVAKU_VERSION = 'v1.2.0') to install the payload from that tag.
$IkTag = $env:IKSHVAKU_VERSION
if ($IkTag) {
    if ($IkTag -notmatch '^[v]?[0-9]+\.[0-9]+\.[0-9]+$') {
        Write-Host "[X] invalid IKSHVAKU_VERSION '$IkTag' - expected e.g. 1.2.0 or v1.2.0" -ForegroundColor Red
        exit 1
    }
    $IkTag = 'v' + ($IkTag -replace '^v', '')
}

# Where this script lives - and where its payload files are.
# Payloads live in src/ in this repository. When run remotely
# (irm ... | iex) $PSScriptRoot is empty: fetch them from GitHub instead.
# IKSHVAKU_REPO_RAW overrides the source (useful for forks and tests).
$scriptDir = $PSScriptRoot
$fetchedRemotely = $false
$payloadDir = $null
if ($scriptDir -and (Test-Path (Join-Path (Join-Path $scriptDir 'src') 'ikshvaku.ps1'))) {
    $payloadDir = Join-Path $scriptDir 'src'          # repository checkout (this layout)
} elseif ($scriptDir -and (Test-Path (Join-Path $scriptDir 'ikshvaku.ps1'))) {
    $payloadDir = $scriptDir                          # legacy flat checkout
}
if (-not $payloadDir) {
    if ($env:IKSHVAKU_REPO_RAW) { $rawBase = $env:IKSHVAKU_REPO_RAW }
    elseif ($IkTag) { $rawBase = "https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/$IkTag" }
    else { $rawBase = 'https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main' }
    $payloadDir = Join-Path ([IO.Path]::GetTempPath()) ("ikshvaku-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $payloadDir | Out-Null
    $fetchedRemotely = $true
    Write-Host ':: Remote install - downloading Ikshvaku files...'
    foreach ($f in @('ikshvaku.ps1', 'ikshvaku.cmd', 'uninstall.ps1')) {
        try {
            # payloads live under src/ in current releases; older tags had
            # them flat at the repository root - try both
            Invoke-WebRequest -Uri "$rawBase/src/$f" -OutFile (Join-Path $payloadDir $f) -UseBasicParsing
        } catch {
            try {
                Invoke-WebRequest -Uri "$rawBase/$f" -OutFile (Join-Path $payloadDir $f) -UseBasicParsing
            } catch {
                Write-Host "[X] download failed ($f): $_" -ForegroundColor Red
                exit 1
            }
        }
    }
}

Write-Host ":: Installing Ikshvaku $IkshvakuVersion..."
if ($IkTag) { Write-Host ":: Version pinned - installing payload from $IkTag" }
Write-Host ":: PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition) Edition)"

# --- uv: powers all environments. Downloaded automatically if missing. ---
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host ":: uv found at $((Get-Command uv).Source)"
} else {
    Write-Host ':: uv not found - downloading uv...' -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri $UvInstaller | Invoke-Expression
    } catch {
        Write-Host "[X] uv download failed: $_" -ForegroundColor Red
        exit 1
    }
    $env:Path = "$BinDir;$env:Path"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host '[X] uv installation failed. Install it manually: https://docs.astral.sh/uv/' -ForegroundColor Red
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
    Write-Host "[WARN] Could not update the user PATH: $_" -ForegroundColor Yellow
}

foreach ($dir in @($InstallDir, $BinDir, $EnvDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Copy-Item -Force (Join-Path $payloadDir 'ikshvaku.ps1')  $InstallDir
Copy-Item -Force (Join-Path $payloadDir 'ikshvaku.cmd')  $InstallDir
Copy-Item -Force (Join-Path $payloadDir 'uninstall.ps1') $InstallDir
Copy-Item -Force (Join-Path $payloadDir 'ikshvaku.cmd')  $BinDir
if ($fetchedRemotely) { Remove-Item -Recurse -Force $payloadDir -ErrorAction SilentlyContinue }

# --- wire up $PROFILE so the function loads in PowerShell ---
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir  = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
$existing = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
if (-not $existing -or $existing -notmatch 'ikshvaku\.ps1') {
    Add-Content -LiteralPath $profilePath -Value @"

# >>> IkshvakuPEM >>>
. "`$env:USERPROFILE\.ikshvaku\ikshvaku.ps1"
# <<< IkshvakuPEM <<<
"@
}

# --- execution policy: make sure dot-sourcing from $PROFILE is allowed ---
if ((Get-ExecutionPolicy -Scope CurrentUser) -in @('Restricted', 'Undefined')) {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host ':: Set execution policy to RemoteSigned (CurrentUser)'
    } catch {
        Write-Host '[WARN] Could not set the execution policy - the function may not load from $PROFILE.' -ForegroundColor Yellow
    }
}

Write-Host ':: Installed successfully' -ForegroundColor Green
Write-Host ':: Restart your shell, or run:  . $PROFILE'
Write-Host ':: PowerShell: full function + tab completion.'
Write-Host ':: cmd: works too - activate/deactivate natively, the rest via PowerShell.'
Write-Host ':: To support us: https://github.com/ashish-jha-73/IkshvakuPEM'
Write-Host ':: To remove Ikshvaku later, run: ~\.ikshvaku\uninstall.ps1'
