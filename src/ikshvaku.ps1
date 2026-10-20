# ~/.ikshvaku/ikshvaku.ps1 — Ikshvaku for PowerShell and Windows cmd.
# Dot-sourced (from $PROFILE): defines the ikshvaku function.
# Run as a script (from the ikshvaku.cmd shim): dispatches ikshvaku directly.

$global:IkshvakuVersion = '1.4.0'
$global:IkshvakuEnvDir = Join-Path $env:USERPROFILE '.Python-Env'
$global:IkshvakuHome = Join-Path $env:USERPROFILE '.ikshvaku'
$global:IkshvakuUvInstaller = 'https://astral.sh/uv/install.ps1'

# Download and install uv if it is not already available.
function Install-IkshvakuUv {
    if (Get-Command uv -ErrorAction SilentlyContinue) { return $true }

    Write-Host ':: uv not found — downloading uv...' -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }
    try {
        Invoke-RestMethod -Uri $global:IkshvakuUvInstaller | Invoke-Expression
    } catch {
        Write-Host ":: uv download failed: $_" -ForegroundColor Red
        return $false
    }

    # the installer drops uv in ~\.local\bin
    $localBin = Join-Path $env:USERPROFILE '.local\bin'
    if (($env:Path -split ';') -notcontains $localBin) {
        $env:Path = "$localBin;$env:Path"
    }

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host ':: uv installation failed — see https://docs.astral.sh/uv/' -ForegroundColor Red
        return $false
    }
    Write-Host ':: uv ready' -ForegroundColor Green
    return $true
}

# Fallback: if an environment somehow has no pip (uv --seed normally provides
# it), drop in a tiny cmd shim that forwards to `uv pip`.
function Set-IkshvakuPipShim {
    param([string]$EnvPath)
    $scriptsDir = Join-Path $EnvPath 'Scripts'
    if (-not (Test-Path $scriptsDir)) { $scriptsDir = Join-Path $EnvPath 'bin' }
    if (-not (Test-Path $scriptsDir)) { return }
    if (Test-Path (Join-Path $scriptsDir 'pip.exe')) { return }   # real pip from --seed
    if (Test-Path (Join-Path $scriptsDir 'pip')) { return }
    $pyExe = Join-Path $scriptsDir 'python.exe'
    if (-not (Test-Path $pyExe)) { $pyExe = Join-Path $scriptsDir 'python' }
    $shim = "@echo off`r`nif `"%~1`"==`"--version`" (`r`n    uv --version`r`n    exit /b 0`r`n)`r`nuv pip %* --python `"$pyExe`"`r`n"
    Set-Content -Path (Join-Path $scriptsDir 'pip.cmd') -Value $shim -Encoding ASCII
}

# Print the path to an environment's python interpreter.
function Get-IkshvakuEnvPython {
    param([string]$EnvPath)
    $pyExe = Join-Path (Join-Path $EnvPath 'Scripts') 'python.exe'
    if (Test-Path $pyExe) { return $pyExe }
    $pyExe = Join-Path (Join-Path $EnvPath 'bin') 'python'
    if (Test-Path $pyExe) { return $pyExe }
    return $null
}

# Create a seeded environment (shared by `create` and `init`).
function New-IkshvakuEnv {
    param([string]$Name, [string]$PythonVersion)
    if (-not $Name) { Write-Host 'Usage: ikshvaku create <env> [python-version]'; return $false }
    $envPath = Join-Path $global:IkshvakuEnvDir $Name
    if (Test-Path $envPath) { Write-Host "Environment '$Name' already exists" -ForegroundColor Red; return $false }
    if (-not (Install-IkshvakuUv)) { return $false }
    New-Item -ItemType Directory -Force -Path $global:IkshvakuEnvDir | Out-Null
    $uvArgs = @('venv', '--seed')
    if (-not $PythonVersion) { $PythonVersion = Get-IkshvakuConfig 'python_default' }
    if ($PythonVersion) { $uvArgs += @('--python', $PythonVersion) }
    $uvArgs += $envPath
    & uv @uvArgs
    if ($LASTEXITCODE -ne 0) { return $false }
    # --seed installs real pip; the shim below is only a fallback
    Set-IkshvakuPipShim $envPath
    Touch-IkshvakuUsage $Name
    Write-Host "Environment '$Name' created" -ForegroundColor Green
    return $true
}

# --- state: usage tracking & config ---

function Touch-IkshvakuUsage {
    param([string]$EnvName)
    try {
        $dir = Join-Path (Join-Path $global:IkshvakuHome 'state') 'usage'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $now = [DateTimeOffset]::Now
        Set-Content -LiteralPath (Join-Path $dir $EnvName) -Value ("{0} {1}" -f $now.ToUnixTimeSeconds(), $now.ToString('yyyy-MM-dd HH:mm')) -ErrorAction SilentlyContinue
    } catch { }
}

function Get-IkshvakuUsageLastUsed {
    param([string]$EnvName)
    $f = Join-Path (Join-Path $global:IkshvakuHome 'state') (Join-Path 'usage' $EnvName)
    if (Test-Path $f) {
        $line = (Get-Content -LiteralPath $f -ErrorAction SilentlyContinue | Select-Object -First 1)
        $i = $line.IndexOf(' ')
        if ($i -gt 0) { return $line.Substring($i + 1) }
    }
    return 'never'
}

function Get-IkshvakuConfig {
    param([string]$Key)
    $cfg = Join-Path $global:IkshvakuHome 'config'
    if (-not (Test-Path $cfg)) { return $null }
    foreach ($line in @(Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -eq $Key) { return $line.Substring($i + 1) }
    }
    return $null
}

function Set-IkshvakuConfig {
    param([string]$Key, [string]$Value)
    New-Item -ItemType Directory -Force -Path $global:IkshvakuHome | Out-Null
    $cfg = Join-Path $global:IkshvakuHome 'config'
    $kept = @()
    foreach ($line in @(Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -ne $Key) { $kept += $line }
    }
    $kept += "$Key=$Value"
    Set-Content -LiteralPath $cfg -Value $kept
}

function Remove-IkshvakuConfig {
    param([string]$Key)
    $cfg = Join-Path $global:IkshvakuHome 'config'
    if (-not (Test-Path $cfg)) { return }
    $kept = @()
    foreach ($line in @(Get-Content -LiteralPath $cfg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -ne $Key) { $kept += $line }
    }
    Set-Content -LiteralPath $cfg -Value $kept
}

function Test-IkshvakuRegistryEnvLinked {
    param([string]$EnvName)
    $reg = Join-Path $global:IkshvakuHome 'registry'
    if (-not (Test-Path $reg)) { return $false }
    foreach ($line in @(Get-Content -LiteralPath $reg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('|')
        if ($i -lt 1) { continue }
        if ($line.Substring($i + 1) -eq $EnvName) { return $true }
    }
    return $false
}

# --- registry: project directory <-> environment links ---

function Get-IkshvakuRegistryLink {
    param([string]$Dir)
    $reg = Join-Path $global:IkshvakuHome 'registry'
    if (-not (Test-Path $reg)) { return $null }
    foreach ($line in @(Get-Content -LiteralPath $reg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('|')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -eq $Dir) { return $line.Substring($i + 1) }
    }
    return $null
}

function Set-IkshvakuRegistryLink {
    param([string]$Dir, [string]$EnvName)
    New-Item -ItemType Directory -Force -Path $global:IkshvakuHome | Out-Null
    $reg = Join-Path $global:IkshvakuHome 'registry'
    $kept = @()
    foreach ($line in @(Get-Content -LiteralPath $reg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('|')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -ne $Dir) { $kept += $line }
    }
    $kept += "$Dir|$EnvName"
    Set-Content -LiteralPath $reg -Value $kept
}

function Remove-IkshvakuRegistryLink {
    param([string]$Dir)
    $reg = Join-Path $global:IkshvakuHome 'registry'
    if (-not (Test-Path $reg)) { return }
    $kept = @()
    foreach ($line in @(Get-Content -LiteralPath $reg -ErrorAction SilentlyContinue)) {
        $i = $line.IndexOf('|')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -ne $Dir) { $kept += $line }
    }
    Set-Content -LiteralPath $reg -Value $kept
}

# Nearest registered project directory for a path, walking up.
function IkshvakuRegistryDir {
    param([string]$Dir)
    $d = $Dir
    while ($true) {
        if (Get-IkshvakuRegistryLink $d) { return $d }
        $parent = Split-Path -Parent $d
        if (-not $parent -or $parent -eq $d) { return $null }
        $d = $parent
    }
}

# Nearest linked env for a directory, walking up (git-style).
function IkshvakuAutoLookup {
    param([string]$Dir)
    $d = $Dir
    while ($true) {
        $e = Get-IkshvakuRegistryLink $d
        if ($e) { return $e }
        $parent = Split-Path -Parent $d
        if (-not $parent -or $parent -eq $d) { return $null }
        $d = $parent
    }
}

# --- auto-activation on directory change (opt-in: ikshvaku auto on) ---

function global:IkshvakuAutoCheck {
    if (-not (Test-Path (Join-Path $global:IkshvakuHome 'auto-on'))) { return }
    $target = IkshvakuAutoLookup ((Get-Location).Path)
    if (-not $target) { return }
    if ($target -eq $env:IKSHVAKU_ACTIVE) { return }
    $envPath = Join-Path $global:IkshvakuEnvDir $target
    $actScript = Join-Path (Join-Path $envPath 'Scripts') 'Activate.ps1'
    if (-not (Test-Path $actScript)) { return }
    if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate | Out-Null }
    ikshvaku activate $target
    if ($env:IKSHVAKU_ACTIVE -eq $target) {
        Write-Host "⚡ ikshvaku: $target activated" -ForegroundColor Cyan
    }
}

function Install-IkshvakuAutoHook {
    if ($global:IkshvakuHookInstalled) { return }
    # wrap Set-Location (cd is an alias to it) with the auto-activation check
    $global:IkshvakuSetLocationCmd = Get-Command Set-Location -CommandType Cmdlet
    function global:Set-Location {
        & $global:IkshvakuSetLocationCmd @args
        IkshvakuAutoCheck
    }
    $global:IkshvakuHookInstalled = $true
}

function ikshvaku {
    $cmd = $null
    $rest = @()
    if ($args.Count -gt 0) {
        $cmd = $args[0]
        if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }
    }

    switch ($cmd) {
        'list' {
            if (-not (Test-Path $global:IkshvakuEnvDir)) {
                Write-Host 'No environments yet. Create one: ikshvaku create <env>'
                return
            }
            $envs = @(Get-ChildItem -LiteralPath $global:IkshvakuEnvDir -Directory -ErrorAction SilentlyContinue)
            if ($envs.Count -eq 0) {
                Write-Host 'No environments yet. Create one: ikshvaku create <env>'
                return
            }
            if ($rest[0] -eq '--json') {
                $rows = @()
                foreach ($e in $envs) {
                    $sum = (Get-ChildItem -LiteralPath $e.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                    $mb = 0
                    if ($sum) { $mb = [math]::Round($sum / 1MB, 1) }
                    $rows += [pscustomobject]@{ name = $e.Name; size = "$mb MB"; last_used = (Get-IkshvakuUsageLastUsed $e.Name) }
                }
                ConvertTo-Json -InputObject $rows
                return
            }
            if ($rest[0] -eq '--size') {
                Write-Output ("{0,-18} {1,8}  {2}" -f 'ENV', 'SIZE', 'LAST USED')
                foreach ($e in $envs) {
                    $sum = (Get-ChildItem -LiteralPath $e.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                    $mb = 0
                    if ($sum) { $mb = [math]::Round($sum / 1MB, 1) }
                    Write-Output ("{0,-18} {1,6} MB  {2}" -f $e.Name, $mb, (Get-IkshvakuUsageLastUsed $e.Name))
                }
                Write-Output ''
                $total = (Get-ChildItem -LiteralPath $global:IkshvakuEnvDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                $tmb = 0
                if ($total) { $tmb = [math]::Round($total / 1MB, 1) }
                Write-Output ("Envs total: {0} MB" -f $tmb)
                $uvCache = Join-Path $HOME '.cache\uv'
                if ($env:OS -eq 'Windows_NT') { $uvCache = Join-Path $env:LOCALAPPDATA 'uv\cache' }
                if (Test-Path $uvCache) {
                    $cs = (Get-ChildItem -LiteralPath $uvCache -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                    $cmb = 0
                    if ($cs) { $cmb = [math]::Round($cs / 1MB, 1) }
                    Write-Output ("uv cache:   {0} MB  (prune with: ikshvaku cleanup --apply --cache)" -f $cmb)
                }
            } else {
                $envs | ForEach-Object { Write-Host $_.Name }
            }
        }

        'create' {
            if (-not $rest[0]) { Write-Host 'Usage: ikshvaku create <env> [python-version]'; return }
            if (-not (New-IkshvakuEnv -Name $rest[0] -PythonVersion $rest[1])) { return }
            Write-Host 'Tip: activate it, then: pip install <package>'
        }

        'init' {
            $dir = (Get-Location).Path
            if ($dir -eq $env:USERPROFILE) {
                Write-Host 'Refusing to link your home directory (it would match every subdirectory)' -ForegroundColor Red
                return
            }
            if ($rest[0]) {
                $name = $rest[0]
            } else {
                # derive the name from the directory
                $leaf = Split-Path $dir -Leaf
                if (-not $leaf) { $leaf = 'env' }
                $name = $leaf.ToLower() -replace '[^a-z0-9._-]', '-'
                $name = $name.Trim('-')
                if (-not $name) { $name = 'env' }
            }
            if (-not (Test-Path (Join-Path $global:IkshvakuEnvDir $name))) {
                if (-not (New-IkshvakuEnv -Name $name -PythonVersion $rest[1])) { return }
            }
            Set-IkshvakuRegistryLink $dir $name
            Write-Host "Linked $dir -> '$name'" -ForegroundColor Green
            # bootstrap: install dependencies from requirements.txt or pyproject.toml
            $reqs = Join-Path $dir 'requirements.txt'
            $pyproj = Join-Path $dir 'pyproject.toml'
            $depFile = $null
            if (Test-Path $reqs) { $depFile = $reqs }
            elseif (Test-Path $pyproj) { $depFile = $pyproj }
            if ($depFile -and (Test-Path (Join-Path $global:IkshvakuEnvDir $name))) {
                if (Get-Command uv -ErrorAction SilentlyContinue) {
                    Write-Host "Found $(Split-Path $depFile -Leaf) - installing dependencies..."
                    $pyExe = Get-IkshvakuEnvPython (Join-Path $global:IkshvakuEnvDir $name)
                    & uv pip install --python $pyExe -r $depFile
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host '⚠️  dependency installation failed - the env is still usable' -ForegroundColor Yellow
                    }
                }
            }
            if ($env:IKSHVAKU_ACTIVE -and $env:IKSHVAKU_ACTIVE -ne $name) {
                if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate | Out-Null }
            }
            ikshvaku activate $name
        }

        'link' {
            if (-not $rest[0]) { Write-Host 'Usage: ikshvaku link <env>'; return }
            if (-not (Test-Path (Join-Path $global:IkshvakuEnvDir $rest[0]) -PathType Container)) {
                Write-Host "Env not found: $($rest[0])" -ForegroundColor Red
                return
            }
            Set-IkshvakuRegistryLink (Get-Location).Path $rest[0]
            Write-Host "Linked $((Get-Location).Path) -> '$($rest[0])'" -ForegroundColor Green
        }

        'unlink' {
            $here = (Get-Location).Path
            if (-not (Get-IkshvakuRegistryLink $here)) {
                # not linked here — remove the nearest parent's link (git-style)
                $here = IkshvakuRegistryDir $here
                if (-not $here) {
                    Write-Host 'No linked environment found for this directory'
                    return
                }
            }
            $linked = Get-IkshvakuRegistryLink $here
            Remove-IkshvakuRegistryLink $here
            Write-Host "Unlinked $here (was -> '$linked')" -ForegroundColor Green
        }

        'links' {
            $reg = Join-Path $global:IkshvakuHome 'registry'
            if (-not (Test-Path $reg)) {
                Write-Host 'No projects linked yet. Run: ikshvaku init'
                return
            }
            $any = $false
            foreach ($line in @(Get-Content -LiteralPath $reg -ErrorAction SilentlyContinue)) {
                $i = $line.IndexOf('|')
                if ($i -lt 1) { continue }
                $any = $true
                $d = $line.Substring(0, $i)
                $e = $line.Substring($i + 1)
                if (Test-Path (Join-Path $global:IkshvakuEnvDir $e) -PathType Container) {
                    Write-Host "$d  ->  $e"
                } else {
                    Write-Host "$d  ->  $e  (missing env)"
                }
            }
            if (-not $any) { Write-Host 'No projects linked yet. Run: ikshvaku init' }
        }

        'activate' {
            $target = $rest[0]
            if (-not $target) {
                # bare activate: use this project's linked env (nearest parent)
                $target = IkshvakuAutoLookup ((Get-Location).Path)
                if (-not $target) {
                    Write-Host 'No environment linked to this directory. Run: ikshvaku init'
                    return
                }
            }
            if ($env:IKSHVAKU_ACTIVE -eq $target) { Write-Host "Already in '$target'"; return }
            $envPath = Join-Path $global:IkshvakuEnvDir $target
            if (-not (Test-Path $envPath)) { Write-Host "Env not found: $target" -ForegroundColor Red; return }
            $actScript = Join-Path (Join-Path $envPath 'Scripts') 'Activate.ps1'
            if (-not (Test-Path $actScript)) {
                Write-Host "Env '$target' has no PowerShell activation script (Scripts/Activate.ps1) — it may have been created on Unix" -ForegroundColor Red
                return
            }
            . $actScript
            $env:IKSHVAKU_ACTIVE = $target
            Touch-IkshvakuUsage $target
        }

        'deactivate' {
            if (Get-Command deactivate -ErrorAction SilentlyContinue) {
                deactivate
            } else {
                Write-Host 'No env active'
            }
            Remove-Item Env:\IKSHVAKU_ACTIVE -ErrorAction SilentlyContinue
        }

        'install' {
            if ($rest.Count -eq 0) {
                Write-Host 'Usage: ikshvaku install <env> <package...>'
                Write-Host '       or, while an env is active: ikshvaku install <package...>'
                return
            }
            $envName = $null
            $packages = @()
            $first = $rest[0]
            if (Test-Path (Join-Path $global:IkshvakuEnvDir $first) -PathType Container) {
                # explicit form: ikshvaku install <env> <package...>
                if ($rest.Count -lt 2) { Write-Host "Usage: ikshvaku install $first <package...>"; return }
                $envName = $first
                $packages = @($rest[1..($rest.Count - 1)])
            } elseif ($env:IKSHVAKU_ACTIVE -and (Test-Path (Join-Path $global:IkshvakuEnvDir $env:IKSHVAKU_ACTIVE) -PathType Container)) {
                # active form: every argument is a package for the active env
                $envName = $env:IKSHVAKU_ACTIVE
                $packages = $rest
            } else {
                Write-Host "Env not found: $first" -ForegroundColor Red
                return
            }
            if (-not (Install-IkshvakuUv)) { return }

            $envPath = Join-Path $global:IkshvakuEnvDir $envName
            $pyExe = Get-IkshvakuEnvPython $envPath
            if (-not $pyExe) { Write-Host "Env '$envName' is missing its python" -ForegroundColor Red; return }
            $actScript = Join-Path (Join-Path $envPath 'Scripts') 'Activate.ps1'
            if (-not (Test-Path $actScript)) {
                Write-Host "Env '$envName' is missing its activate script" -ForegroundColor Red
                return
            }
            Touch-IkshvakuUsage $envName

            # Run the install inside an isolated activate -> install -> deactivate
            # cycle. $env: variables are process-wide in PowerShell, so the
            # previous state is saved and restored — whatever you had active
            # stays active after the install.
            $oldVenv = $env:VIRTUAL_ENV
            $oldActive = $env:IKSHVAKU_ACTIVE
            . $actScript
            $env:IKSHVAKU_ACTIVE = $envName
            try {
                & uv pip install --python $pyExe @packages
            } finally {
                if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
                if ($oldVenv) { $env:VIRTUAL_ENV = $oldVenv } else { Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue }
                if ($oldActive) { $env:IKSHVAKU_ACTIVE = $oldActive } else { Remove-Item Env:\IKSHVAKU_ACTIVE -ErrorAction SilentlyContinue }
                if (-not $oldVenv) {
                    Remove-Item function:\deactivate -ErrorAction SilentlyContinue
                }
            }
        }

        'run' {
            if ($rest.Count -lt 2) { Write-Host 'Usage: ikshvaku run <env> <command...>'; return }
            $envPath = Join-Path $global:IkshvakuEnvDir $rest[0]
            if (-not (Test-Path $envPath)) { Write-Host "Env not found: $($rest[0])" -ForegroundColor Red; return }
            $actScript = Join-Path (Join-Path $envPath 'Scripts') 'Activate.ps1'
            if (-not (Test-Path $actScript)) {
                Write-Host "Env '$($rest[0])' has no PowerShell activation script (Scripts/Activate.ps1) — it may have been created on Unix" -ForegroundColor Red
                return
            }
            $cmdArgs = @($rest[1..($rest.Count - 1)])
            Touch-IkshvakuUsage $rest[0]
            $oldVenv = $env:VIRTUAL_ENV
            $oldActive = $env:IKSHVAKU_ACTIVE
            . $actScript
            $env:IKSHVAKU_ACTIVE = $rest[0]
            try {
                if ($cmdArgs.Count -gt 1) {
                    & $cmdArgs[0] @($cmdArgs[1..($cmdArgs.Count - 1)])
                } else {
                    & $cmdArgs[0]
                }
            } finally {
                if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
                if ($oldVenv) { $env:VIRTUAL_ENV = $oldVenv } else { Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue }
                if ($oldActive) { $env:IKSHVAKU_ACTIVE = $oldActive } else { Remove-Item Env:\IKSHVAKU_ACTIVE -ErrorAction SilentlyContinue }
                if (-not $oldVenv) {
                    Remove-Item function:\deactivate -ErrorAction SilentlyContinue
                }
            }
        }

        'export' {
            if (-not $rest[0]) { Write-Host 'Usage: ikshvaku export <env>  (> requirements.txt)'; return }
            $envPath = Join-Path $global:IkshvakuEnvDir $rest[0]
            if (-not (Test-Path $envPath)) { Write-Host "Env not found: $($rest[0])" -ForegroundColor Red; return }
            if (-not (Install-IkshvakuUv)) { return }
            Touch-IkshvakuUsage $rest[0]
            & uv pip freeze --python $envPath
        }

        'clone' {
            if ($rest.Count -lt 2) { Write-Host 'Usage: ikshvaku clone <src> <dst>'; return }
            $srcPath = Join-Path $global:IkshvakuEnvDir $rest[0]
            $dstPath = Join-Path $global:IkshvakuEnvDir $rest[1]
            if (-not (Test-Path $srcPath)) { Write-Host "Env not found: $($rest[0])" -ForegroundColor Red; return }
            if (Test-Path $dstPath) { Write-Host "Environment '$($rest[1])' already exists" -ForegroundColor Red; return }
            if (-not (Install-IkshvakuUv)) { return }
            $srcPy = Get-IkshvakuEnvPython $srcPath
            if (-not $srcPy) { Write-Host "Env '$($rest[0])' is missing its python" -ForegroundColor Red; return }
            & uv venv --seed --python $srcPy $dstPath
            if ($LASTEXITCODE -ne 0) { return }
            Set-IkshvakuPipShim $dstPath
            Touch-IkshvakuUsage $rest[1]
            $tmpReqs = Join-Path ([IO.Path]::GetTempPath()) ("ikshvaku-clone-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".txt")
            & uv pip freeze --python $srcPath > $tmpReqs 2>$null
            if ((Get-Item $tmpReqs -ErrorAction SilentlyContinue).Length -gt 0) {
                & uv pip install --python (Get-IkshvakuEnvPython $dstPath) -r $tmpReqs
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "⚠️  package install failed — '$($rest[1])' created but incomplete" -ForegroundColor Yellow
                }
            }
            Remove-Item -LiteralPath $tmpReqs -Force -ErrorAction SilentlyContinue
            Write-Host "Cloned '$($rest[0])' -> '$($rest[1])'" -ForegroundColor Green
        }

        'cleanup' {
            $apply = $false
            $doCache = $false
            $days = Get-IkshvakuConfig 'cleanup_days'
            if (-not $days) { $days = 90 }
            foreach ($a in $rest) {
                if ($a -eq '--apply') { $apply = $true }
                elseif ($a -eq '--cache') { $doCache = $true }
                elseif ($a -like '--days=*') { $days = $a.Substring(7) }
                elseif ($a -eq '--days') { $pendingDays = $true }
                elseif ($pendingDays) { $days = $a; $pendingDays = $false }
                else { Write-Host "Usage: ikshvaku cleanup [--days N] [--apply] [--cache]"; return }
            }
            Write-Host "ikshvaku cleanup — stale = unused for $days days (linked projects and the active env are always kept)"
            Write-Host ''
            $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $cutoff = $now - ([int]$days * 86400)
            $total = 0
            $stale = 0
            $dups = 0
            $seen = @()
            foreach ($e in @(Get-ChildItem -LiteralPath $global:IkshvakuEnvDir -Directory -ErrorAction SilentlyContinue)) {
                $total++
                if (Test-IkshvakuRegistryEnvLinked $e.Name) {
                    Write-Output ("  keep      {0,-18} linked to a project" -f $e.Name)
                    continue
                }
                if ($e.Name -eq $env:IKSHVAKU_ACTIVE) {
                    Write-Output ("  keep      {0,-18} currently active" -f $e.Name)
                    continue
                }
                $uf = Join-Path (Join-Path $global:IkshvakuHome 'state') (Join-Path 'usage' $e.Name)
                $lastEpoch = $null
                $stamp = 'never'
                if (Test-Path $uf) {
                    $line = Get-Content -LiteralPath $uf -ErrorAction SilentlyContinue | Select-Object -First 1
                    $i = $line.IndexOf(' ')
                    if ($i -gt 0) {
                        $lastEpoch = $line.Substring(0, $i)
                        $stamp = $line.Substring($i + 1)
                    }
                }
                if (-not $lastEpoch) {
                    Write-Output ("  skip      {0,-18} no usage data (created before v1.2)" -f $e.Name)
                } elseif ([long]$lastEpoch -le $cutoff) {
                    $stale++
                    if ($apply) {
                        Remove-Item -LiteralPath $e.FullName -Recurse -Force
                        Remove-Item -LiteralPath $uf -Force -ErrorAction SilentlyContinue
                        Write-Output ("  DELETE    {0,-18} last used {1}" -f $e.Name, $stamp)
                    } else {
                        Write-Output ("  stale     {0,-18} last used {1}" -f $e.Name, $stamp)
                    }
                } elseif (Get-Command uv -ErrorAction SilentlyContinue) {
                    # duplicate detection: identical package sets are redundant
                    $fz = (& uv pip freeze --python (Get-IkshvakuEnvPython $e.FullName) 2>$null | Out-String)
                    if ($seen -contains $fz) {
                        $dups++
                        Write-Output ("  duplicate {0,-18} identical package set - remove with: ikshvaku remove {0}" -f $e.Name)
                    } else {
                        $seen += $fz
                        Write-Output ("  keep      {0,-18} last used {1}" -f $e.Name, $stamp)
                    }
                } else {
                    Write-Output ("  keep      {0,-18} last used {1}" -f $e.Name, $stamp)
                }
            }
            Write-Output ''
            if ($stale -eq 0 -and $dups -eq 0) {
                Write-Output "Nothing to clean ($total environment(s) checked)."
            } elseif ($apply) {
                Write-Output "Deleted $stale environment(s)."
            } else {
                Write-Output "Dry run: $stale environment(s) would be deleted. Re-run with --apply."
            }
            if ($dups -gt 0) {
                Write-Output "$dups duplicate environment(s) found (identical package sets)."
            }
            if ($doCache) {
                if (Get-Command uv -ErrorAction SilentlyContinue) {
                    & uv cache prune
                } else {
                    Write-Host '⚠️  uv not found — cannot prune the cache' -ForegroundColor Yellow
                }
            }
        }

        'config' {
            if (-not $rest[0]) {
                $cfg = Join-Path $global:IkshvakuHome 'config'
                if (Test-Path $cfg) {
                    Write-Output '# ~/.ikshvaku/config'
                    Write-Output (Get-Content -LiteralPath $cfg | Out-String).TrimEnd()
                } else {
                    Write-Output 'No configuration set.'
                }
                Write-Output 'Available keys: python_default, cleanup_days'
                return
            }
            if ($rest[0] -notin @('python_default', 'cleanup_days')) {
                Write-Host "Unknown key '$($rest[0])'. Available keys: python_default, cleanup_days" -ForegroundColor Red
                return
            }
            if ($rest[1] -eq '--unset') {
                Remove-IkshvakuConfig $rest[0]
                Write-Output "Unset: $($rest[0])"
                return
            }
            if ($rest.Count -lt 2) {
                $v = Get-IkshvakuConfig $rest[0]
                if ($v) { Write-Output "$($rest[0])=$v" } else { Write-Output "$($rest[0]) is not set" }
                return
            }
            Set-IkshvakuConfig $rest[0] $rest[1]
            Write-Output "Saved: $($rest[0])=$($rest[1])"
        }

        'jupyter' {
            if (-not $rest[0]) { Write-Host 'Usage: ikshvaku jupyter <env>'; return }
            $envPath = Join-Path $global:IkshvakuEnvDir $rest[0]
            if (-not (Test-Path $envPath)) { Write-Host "Env not found: $($rest[0])" -ForegroundColor Red; return }
            if (-not (Install-IkshvakuUv)) { return }
            $pyExe = Get-IkshvakuEnvPython $envPath
            if (-not $pyExe) { Write-Host "Env '$($rest[0])' is missing its python" -ForegroundColor Red; return }
            & $pyExe -c "import ipykernel" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Installing ipykernel into '$($rest[0])'..."
                & uv pip install --python $pyExe ipykernel
                if ($LASTEXITCODE -ne 0) { Write-Host '⚠️  could not install ipykernel' -ForegroundColor Red; return }
            }
            & $pyExe -m ipykernel install --user --name "ikshvaku-$($rest[0])" --display-name "Python (ikshvaku: $($rest[0]))"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Kernel registered - select 'Python (ikshvaku: $($rest[0]))' in Jupyter." -ForegroundColor Green
            }
        }

        'help' {
            switch ($rest[0]) {
                'create' {
                    Write-Output 'ikshvaku create <env> [python-version]'
                    Write-Output '  Create a seeded environment (real pip included).'
                    Write-Output '  A python version is downloaded on demand: ikshvaku create web 3.12'
                }
                'init' {
                    Write-Output 'ikshvaku init [env] [python-version]'
                    Write-Output '  Link the current directory to an environment, creating it if needed.'
                    Write-Output '  Installs requirements.txt / pyproject.toml dependencies when present.'
                }
                'activate' {
                    Write-Output 'ikshvaku activate [env]'
                    Write-Output "  Activate an environment. With no argument, uses this project's"
                    Write-Output '  linked env (nearest parent directory).'
                }
                'install' {
                    Write-Output 'ikshvaku install <env> <pkg...>   |   ikshvaku install <pkg...>'
                    Write-Output '  Install packages into an environment (isolated cycle), or into the'
                    Write-Output '  active environment when no env is named.'
                }
                'run' {
                    Write-Output 'ikshvaku run <env> <cmd...>'
                    Write-Output '  Run a command inside an environment without activating.'
                    Write-Output '  Exit codes propagate: ikshvaku run web pytest -q'
                }
                'export' {
                    Write-Output 'ikshvaku export <env>'
                    Write-Output '  Print installed packages. Redirect: ikshvaku export web > requirements.txt'
                }
                'clone' {
                    Write-Output 'ikshvaku clone <src> <dst>'
                    Write-Output '  Duplicate an environment (same interpreter, packages included).'
                }
                'cleanup' {
                    Write-Output 'ikshvaku cleanup [--days N] [--apply] [--cache]'
                    Write-Output '  Find environments unused for N days (default 90). Dry-run by default;'
                    Write-Output '  --apply deletes; --cache also prunes uv cache. Linked projects and'
                    Write-Output '  the active env are always kept.'
                }
                'config' {
                    Write-Output 'ikshvaku config [key [value]] | ikshvaku config <key> --unset'
                    Write-Output '  Keys: python_default (used by create/init), cleanup_days (default 90).'
                }
                'jupyter' {
                    Write-Output 'ikshvaku jupyter <env>'
                    Write-Output '  Register the environment as a Jupyter kernel.'
                }
                'doctor' {
                    Write-Output 'ikshvaku doctor'
                    Write-Output '  Health check: installation, uv, shell integration, registry links,'
                    Write-Output '  auto-activation state and uv cache size.'
                }
                'list' {
                    Write-Output 'ikshvaku list [--size | --json]'
                    Write-Output '  List environments; --size adds disk usage and last-used; --json emits JSON.'
                }
                'status' {
                    Write-Output 'ikshvaku status [--json]'
                    Write-Output '  Show the active env, project link, python version, package count, size.'
                }
                'auto' {
                    Write-Output 'ikshvaku auto on|off'
                    Write-Output '  Opt-in: switch environments automatically as you cd.'
                }
                'upgrade' {
                    Write-Output 'ikshvaku upgrade'
                    Write-Output '  Update Ikshvaku to the latest release. Homebrew users: brew upgrade ikshvakupem'
                }
                'remove' {
                    Write-Output 'ikshvaku remove <env>'
                    Write-Output '  Delete an environment.'
                }
                default {
                    Write-Output 'Usage: ikshvaku help <command>'
                    Write-Output 'Commands: list create activate deactivate install remove init link unlink'
                    Write-Output '          links status doctor auto run export clone cleanup config jupyter upgrade help'
                }
            }
        }

        'status' {
            $here = (Get-Location).Path
            if ($rest[0] -eq '--json') {
                $linked = Get-IkshvakuRegistryLink $here
                $via = 'this directory'
                if (-not $linked) {
                    $linked = IkshvakuAutoLookup $here
                    if ($linked) { $via = 'parent directory' }
                }
                $show = $env:IKSHVAKU_ACTIVE
                if (-not $show) { $show = $linked }
                $py = ''
                $pkgs = 0
                $size = ''
                if ($show -and (Test-Path (Join-Path $global:IkshvakuEnvDir $show) -PathType Container)) {
                    $envPath = Join-Path $global:IkshvakuEnvDir $show
                    $pyExe = Get-IkshvakuEnvPython $envPath
                    if ($pyExe) { $py = (& $pyExe --version 2>&1 | Out-String).Trim() }
                    if (Get-Command uv -ErrorAction SilentlyContinue) {
                        $pkgs = (& uv pip list --python $envPath 2>$null | Select-Object -Skip 2 | Measure-Object).Count
                    }
                    $sum = (Get-ChildItem -LiteralPath $envPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                    if ($sum) { $size = "$([math]::Round($sum / 1MB, 1)) MB" }
                }
                ConvertTo-Json -InputObject ([pscustomobject]@{
                    version = $global:IkshvakuVersion
                    active = $env:IKSHVAKU_ACTIVE
                    linked_env = $linked
                    linked_via = $via
                    python = $py
                    packages = $pkgs
                    size = $size
                })
                return
            }
            Write-Output "ikshvaku $global:IkshvakuVersion"
            if ($env:IKSHVAKU_ACTIVE) {
                Write-Output ("Active env:   {0}  ({1})" -f $env:IKSHVAKU_ACTIVE, (Join-Path $global:IkshvakuEnvDir $env:IKSHVAKU_ACTIVE))
            } else {
                Write-Output 'Active env:   none'
            }
            $here = (Get-Location).Path
            if ($rest[0] -eq '--json') {
                $linked = Get-IkshvakuRegistryLink $here
                $via = 'this directory'
                if (-not $linked) {
                    $linked = IkshvakuAutoLookup $here
                    if ($linked) { $via = 'parent directory' }
                }
                $show = $env:IKSHVAKU_ACTIVE
                if (-not $show) { $show = $linked }
                $py = ''
                $pkgs = 0
                $size = ''
                if ($show -and (Test-Path (Join-Path $global:IkshvakuEnvDir $show) -PathType Container)) {
                    $envPath = Join-Path $global:IkshvakuEnvDir $show
                    $pyExe = Get-IkshvakuEnvPython $envPath
                    if ($pyExe) { $py = (& $pyExe --version 2>&1 | Out-String).Trim() }
                    if (Get-Command uv -ErrorAction SilentlyContinue) {
                        $pkgs = (& uv pip list --python $envPath 2>$null | Select-Object -Skip 2 | Measure-Object).Count
                    }
                    $sum = (Get-ChildItem -LiteralPath $envPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                    if ($sum) { $size = "$([math]::Round($sum / 1MB, 1)) MB" }
                }
                ConvertTo-Json -InputObject ([pscustomobject]@{
                    version = $global:IkshvakuVersion
                    active = $env:IKSHVAKU_ACTIVE
                    linked_env = $linked
                    linked_via = $via
                    python = $py
                    packages = $pkgs
                    size = $size
                })
                return
            }
            $here = (Get-Location).Path
            $linked = Get-IkshvakuRegistryLink $here
            if ($linked) {
                Write-Output "Linked:       this directory -> $linked"
            } else {
                $linked = IkshvakuAutoLookup $here
                if ($linked) {
                    Write-Output "Linked:       parent directory -> $linked"
                } else {
                    Write-Output 'Linked:       none (run: ikshvaku init)'
                }
            }
            $show = $env:IKSHVAKU_ACTIVE
            if (-not $show) { $show = $linked }
            if ($show -and (Test-Path (Join-Path $global:IkshvakuEnvDir $show) -PathType Container)) {
                $envPath = Join-Path $global:IkshvakuEnvDir $show
                $pyExe = Get-IkshvakuEnvPython $envPath
                if ($pyExe) { Write-Output ("Python:       " + (& $pyExe --version 2>&1)) }
                if (Get-Command uv -ErrorAction SilentlyContinue) {
                    $count = (& uv pip list --python $envPath 2>$null | Select-Object -Skip 2 | Measure-Object).Count
                    Write-Output "Packages:     $count"
                } else {
                    Write-Output 'Packages:     ? (uv not found)'
                }
                $sum = (Get-ChildItem -LiteralPath $envPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                $mb = 0
                if ($sum) { $mb = [math]::Round($sum / 1MB, 1) }
                Write-Output ("Size:         {0} MB" -f $mb)
            }
        }

        'doctor' {
            $ok = $true
            Write-Output "ikshvaku $global:IkshvakuVersion — health check"
            Write-Output ''
            if (Test-Path (Join-Path $env:USERPROFILE '.ikshvaku\ikshvaku.ps1')) {
                Write-Output '✅ installation: ~\.ikshvaku present'
            } else {
                Write-Output '❌ installation: ~\.ikshvaku not found — run the installer'
                $ok = $false
            }
            if (Get-Command uv -ErrorAction SilentlyContinue) {
                Write-Output "✅ uv: $(((& uv --version) | Out-String).Trim()) at $((Get-Command uv).Source)"
            } else {
                Write-Output '❌ uv: not found — it will be downloaded on the next create/install'
                $ok = $false
            }
            if (Test-Path $global:IkshvakuEnvDir) {
                $envCount = @(Get-ChildItem -LiteralPath $global:IkshvakuEnvDir -Directory -ErrorAction SilentlyContinue).Count
                Write-Output "✅ environments: $envCount in $global:IkshvakuEnvDir"
            } else {
                Write-Output 'ℹ️  environments: none yet'
            }
            $prof = $PROFILE.CurrentUserAllHosts
            $blocks = @(Select-String -LiteralPath $prof -Pattern '>>> Ikshvaku(PEM)? >>>' -ErrorAction SilentlyContinue).Count
            if ($blocks -eq 1) {
                Write-Output "✅ shell integration: $prof"
            } elseif ($blocks -eq 0) {
                Write-Output "⚠️  shell integration: not found in $prof — re-run the installer"
            } else {
                Write-Output "❌ shell integration: $blocks blocks in $prof — run the uninstaller, then reinstall"
                $ok = $false
            }
            $reg = Join-Path $global:IkshvakuHome 'registry'
            if (Test-Path $reg) {
                $total = 0
                $broken = 0
                foreach ($line in @(Get-Content -LiteralPath $reg -ErrorAction SilentlyContinue)) {
                    $i = $line.IndexOf('|')
                    if ($i -lt 1) { continue }
                    $total++
                    $d = $line.Substring(0, $i)
                    $e = $line.Substring($i + 1)
                    if (-not (Test-Path (Join-Path $global:IkshvakuEnvDir $e) -PathType Container)) {
                        $broken++
                        Write-Output "⚠️  broken link: $d -> '$e' (remove it: cd $d; ikshvaku unlink)"
                    }
                }
                if ($broken -eq 0) {
                    Write-Output "✅ registry: $total link(s), all valid"
                } else {
                    Write-Output "❌ registry: $broken of $total link(s) broken"
                    $ok = $false
                }
            } else {
                Write-Output 'ℹ️  registry: empty (no projects linked — try: ikshvaku init)'
            }
            if (Test-Path (Join-Path $global:IkshvakuHome 'auto-on')) {
                Write-Output '✅ auto-activation: ON (envs switch on cd)'
            } else {
                Write-Output 'ℹ️  auto-activation: off (enable with: ikshvaku auto on)'
            }
            $uvCache = Join-Path $HOME '.cache\uv'
            if ($env:OS -eq 'Windows_NT') { $uvCache = Join-Path $env:LOCALAPPDATA 'uv\cache' }
            if (Test-Path $uvCache) {
                $cs = (Get-ChildItem -LiteralPath $uvCache -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                $cmb = 0
                if ($cs) { $cmb = [math]::Round($cs / 1MB, 1) }
                Write-Output "ℹ️  uv cache: $cmb MB (prune with: uv cache prune)"
            }
            Write-Output ''
            if ($ok) { Write-Output 'All checks passed.' }
            else { Write-Output 'Some checks failed.' }
        }

        'auto' {
            switch ($rest[0]) {
                'on' {
                    New-Item -ItemType Directory -Force -Path $global:IkshvakuHome | Out-Null
                    Set-Content -LiteralPath (Join-Path $global:IkshvakuHome 'auto-on') -Value ''
                    Install-IkshvakuAutoHook
                    Write-Host 'Auto-activation ON — cd into a linked project activates its env.' -ForegroundColor Green
                    Write-Host '(This session is hooked; other shells pick it up on restart.)'
                }
                'off' {
                    Remove-Item -LiteralPath (Join-Path $global:IkshvakuHome 'auto-on') -Force -ErrorAction SilentlyContinue
                    Write-Host 'Auto-activation OFF.'
                }
                default {
                    Write-Host 'Usage: ikshvaku auto on|off'
                }
            }
        }

        'remove' {
            if (-not $rest[0]) { Write-Host 'Usage: ikshvaku remove <env>'; return }
            $envPath = Join-Path $global:IkshvakuEnvDir $rest[0]
            if (-not (Test-Path $envPath)) { Write-Host 'Env not found' -ForegroundColor Red; return }
            Remove-Item -LiteralPath $envPath -Recurse -Force
            Write-Host "Environment '$($rest[0])' removed" -ForegroundColor Green
        }

        'upgrade' {
            Write-Host "ikshvaku $global:IkshvakuVersion — upgrading to the latest release..."
            try {
                $ikUrl = "https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.ps1?cb=" + [DateTimeOffset]::Now.ToUnixTimeSeconds()
                Invoke-RestMethod -Uri $ikUrl | Invoke-Expression
            } catch {
                Write-Host "⚠️  upgrade failed — run the install command manually" -ForegroundColor Red
                return
            }
            Write-Host 'Restart your shell to load the new version.'
        }

        '--version' {
            Write-Output "ikshvaku $global:IkshvakuVersion"
        }

        'version' {
            Write-Output "ikshvaku $global:IkshvakuVersion"
        }

        '-V' {
            Write-Output "ikshvaku $global:IkshvakuVersion"
        }

        '_resolve-link' {
            # internal: prints the linked env for the current directory (used by ikshvaku.cmd)
            $t = IkshvakuAutoLookup ((Get-Location).Path)
            if ($t) { Write-Output $t }
        }

        default {
            Write-Host "ikshvaku $global:IkshvakuVersion — Python environments powered by uv"
            Write-Host ''
            Write-Host 'Commands:'
            Write-Host '  ikshvaku list [--size]'
            Write-Host '  ikshvaku status'
            Write-Host '  ikshvaku doctor'
            Write-Host '  ikshvaku create <env> [python-version]'
            Write-Host '  ikshvaku init [env] [python-version]   link this directory to an env (+ requirements.txt)'
            Write-Host '  ikshvaku link <env> / unlink'
            Write-Host '  ikshvaku links'
            Write-Host '  ikshvaku activate [env]                no arg = this project env'
            Write-Host '  ikshvaku deactivate'
            Write-Host '  ikshvaku install <env> <pkg...>        or: ikshvaku install <pkg...> (active env)'
            Write-Host '  ikshvaku run <env> <cmd...>            run a command inside an env'
            Write-Host '  ikshvaku export <env>                  print installed packages (> requirements.txt)'
            Write-Host '  ikshvaku clone <src> <dst>             duplicate an environment'
            Write-Host '  ikshvaku cleanup [--days N] [--apply] [--cache]'
            Write-Host '  ikshvaku config [key [value]]          python_default, cleanup_days'
            Write-Host '  ikshvaku jupyter <env>                 register env as a Jupyter kernel'
            Write-Host '  ikshvaku help <command>                detailed help for a command'
            Write-Host '  ikshvaku auto on|off                   switch envs automatically on cd'
            Write-Host '  ikshvaku upgrade                       update to the latest release'
            Write-Host '  ikshvaku remove <env>'
            Write-Host '  ikshvaku --version'
            Write-Host ''
            Write-Host 'Powered by uv (downloaded automatically if missing).'
            Write-Host 'Environments ship with pip preinstalled (seeded by uv).'
        }
    }
}

# Tab completion for commands and environment names
Register-ArgumentCompleter -CommandName ikshvaku -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @('list', 'create', 'activate', 'deactivate', 'install', 'remove', 'init', 'link', 'unlink', 'links', 'status', 'doctor', 'auto', 'run', 'export', 'clone', 'cleanup', 'config', 'jupyter', 'help', 'upgrade')
    $elems = @($commandAst.CommandElements)
    if ($elems.Count -le 2) {
        $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }
    $sub = $elems[1].ToString()
    if ($sub -in @('activate', 'remove', 'install', 'link')) {
        Get-ChildItem -LiteralPath $global:IkshvakuEnvDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
            }
    } elseif ($sub -eq 'auto') {
        'on', 'off' | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# When dot-sourced (from $PROFILE), stop here — only the function is defined,
# plus the auto-activation hook if it is enabled.
# When run as a script (e.g. from ikshvaku.cmd), dispatch immediately.
if ($MyInvocation.InvocationName -ne '.') {
    ikshvaku @args
} elseif (Test-Path (Join-Path $global:IkshvakuHome 'auto-on')) {
    Install-IkshvakuAutoHook
}
