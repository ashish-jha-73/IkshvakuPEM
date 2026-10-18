# ~/.ikshvaku/ikshvaku.ps1 — Ikshvaku for PowerShell and Windows cmd.
# Dot-sourced (from $PROFILE): defines the ikshvaku function.
# Run as a script (from the ikshvaku.cmd shim): dispatches ikshvaku directly.

$global:IkshvakuVersion = '1.1.0'
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
    if ($PythonVersion) { $uvArgs += @('--python', $PythonVersion) }
    $uvArgs += $envPath
    & uv @uvArgs
    if ($LASTEXITCODE -ne 0) { return $false }
    # --seed installs real pip; the shim below is only a fallback
    Set-IkshvakuPipShim $envPath
    Write-Host "Environment '$Name' created" -ForegroundColor Green
    return $true
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
            $envs | ForEach-Object { Write-Host $_.Name }
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

        'status' {
            Write-Output "ikshvaku $global:IkshvakuVersion"
            if ($env:IKSHVAKU_ACTIVE) {
                Write-Output ("Active env:   {0}  ({1})" -f $env:IKSHVAKU_ACTIVE, (Join-Path $global:IkshvakuEnvDir $env:IKSHVAKU_ACTIVE))
            } else {
                Write-Output 'Active env:   none'
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
            $blocks = @(Select-String -LiteralPath $prof -Pattern '>>> Ikshvaku >>>' -ErrorAction SilentlyContinue).Count
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
            Write-Host '  ikshvaku list'
            Write-Host '  ikshvaku status'
            Write-Host '  ikshvaku doctor'
            Write-Host '  ikshvaku create <env> [python-version]'
            Write-Host '  ikshvaku init [env] [python-version]   link this directory to an env'
            Write-Host '  ikshvaku link <env> / unlink'
            Write-Host '  ikshvaku links'
            Write-Host '  ikshvaku activate [env]                no arg = this project env'
            Write-Host '  ikshvaku deactivate'
            Write-Host '  ikshvaku install <env> <pkg...>        or: ikshvaku install <pkg...> (active env)'
            Write-Host '  ikshvaku auto on|off                   switch envs automatically on cd'
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
    $commands = @('list', 'create', 'activate', 'deactivate', 'install', 'remove', 'init', 'link', 'unlink', 'links', 'status', 'doctor', 'auto')
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
