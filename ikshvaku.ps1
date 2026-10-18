# ~/.ikshvaku/ikshvaku.ps1 — Ikshvaku for PowerShell and Windows cmd.
# Dot-sourced (from $PROFILE): defines the ikshvaku function.
# Run as a script (from the ikshvaku.cmd shim): dispatches ikshvaku directly.

$script:IkshvakuEnvDir = Join-Path $env:USERPROFILE '.Python-Env'
$script:IkshvakuUvInstaller = 'https://astral.sh/uv/install.ps1'

# Download and install uv if it is not already available.
function Install-IkshvakuUv {
    if (Get-Command uv -ErrorAction SilentlyContinue) { return $true }

    Write-Host ':: uv not found — downloading uv...' -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }
    try {
        Invoke-RestMethod -Uri $script:IkshvakuUvInstaller | Invoke-Expression
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

function ikshvaku {
    $cmd = $null
    $rest = @()
    if ($args.Count -gt 0) {
        $cmd = $args[0]
        if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }
    }

    switch ($cmd) {
        'list' {
            if (-not (Test-Path $script:IkshvakuEnvDir)) {
                Write-Host 'No environments yet. Create one: ikshvaku create <env>'
                return
            }
            $envs = @(Get-ChildItem -LiteralPath $script:IkshvakuEnvDir -Directory -ErrorAction SilentlyContinue)
            if ($envs.Count -eq 0) {
                Write-Host 'No environments yet. Create one: ikshvaku create <env>'
                return
            }
            $envs | ForEach-Object { Write-Host $_.Name }
        }

        'create' {
            if ($rest.Count -eq 0) { Write-Host 'Usage: ikshvaku create <env> [python-version]'; return }
            $name = $rest[0]
            $envPath = Join-Path $script:IkshvakuEnvDir $name
            if (Test-Path $envPath) { Write-Host "Environment '$name' already exists" -ForegroundColor Red; return }
            if (-not (Install-IkshvakuUv)) { return }
            New-Item -ItemType Directory -Force -Path $script:IkshvakuEnvDir | Out-Null
            $uvArgs = @('venv', '--seed')
            if ($rest.Count -ge 2) { $uvArgs += @('--python', $rest[1]) }
            $uvArgs += $envPath
            & uv @uvArgs
            if ($LASTEXITCODE -ne 0) { return }
            Set-IkshvakuPipShim $envPath
            Write-Host "Environment '$name' created" -ForegroundColor Green
            Write-Host 'Tip: activate it, then: pip install <package>'
        }

        'activate' {
            if ($rest.Count -eq 0) { Write-Host 'Usage: ikshvaku activate <env>'; return }
            $envPath = Join-Path $script:IkshvakuEnvDir $rest[0]
            $actScript = Join-Path (Join-Path $envPath 'Scripts') 'Activate.ps1'
            if (-not (Test-Path $actScript)) { Write-Host 'Env not found' -ForegroundColor Red; return }
            . $actScript
            $env:IKSHVAKU_ACTIVE = $rest[0]
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
            if (Test-Path (Join-Path $script:IkshvakuEnvDir $first) -PathType Container) {
                # explicit form: ikshvaku install <env> <package...>
                if ($rest.Count -lt 2) { Write-Host "Usage: ikshvaku install $first <package...>"; return }
                $envName = $first
                $packages = @($rest[1..($rest.Count - 1)])
            } elseif ($env:IKSHVAKU_ACTIVE -and (Test-Path (Join-Path $script:IkshvakuEnvDir $env:IKSHVAKU_ACTIVE) -PathType Container)) {
                # active form: every argument is a package for the active env
                $envName = $env:IKSHVAKU_ACTIVE
                $packages = $rest
            } else {
                Write-Host "Env not found: $first" -ForegroundColor Red
                return
            }
            if (-not (Install-IkshvakuUv)) { return }

            $envPath = Join-Path $script:IkshvakuEnvDir $envName
            $pyExe = Join-Path (Join-Path $envPath 'Scripts') 'python.exe'
            if (-not (Test-Path $pyExe)) { $pyExe = Join-Path (Join-Path $envPath 'bin') 'python' }
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

        'remove' {
            if ($rest.Count -eq 0) { Write-Host 'Usage: ikshvaku remove <env>'; return }
            $envPath = Join-Path $script:IkshvakuEnvDir $rest[0]
            if (-not (Test-Path $envPath)) { Write-Host 'Env not found' -ForegroundColor Red; return }
            Remove-Item -LiteralPath $envPath -Recurse -Force
            Write-Host "Environment '$($rest[0])' removed" -ForegroundColor Green
        }

        default {
            Write-Host 'Commands:'
            Write-Host '  ikshvaku list'
            Write-Host '  ikshvaku create <env> [python-version]'
            Write-Host '  ikshvaku activate <env>'
            Write-Host '  ikshvaku deactivate'
            Write-Host '  ikshvaku install <env> <package...>   (or: ikshvaku install <package...> while active)'
            Write-Host '  ikshvaku remove <env>'
            Write-Host ''
            Write-Host 'Powered by uv (downloaded automatically if missing).'
            Write-Host 'Environments ship with pip preinstalled (seeded by uv).'
        }
    }
}

# Tab completion for commands and environment names
Register-ArgumentCompleter -CommandName ikshvaku -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @('list', 'create', 'activate', 'deactivate', 'install', 'remove')
    $elems = @($commandAst.CommandElements)
    if ($elems.Count -le 2) {
        $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        return
    }
    $sub = $elems[1].ToString()
    if ($sub -in @('activate', 'remove', 'install')) {
        Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.Python-Env') -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Name)
            }
    }
}

# When dot-sourced (from $PROFILE), stop here — only the function is defined.
# When run as a script (e.g. from ikshvaku.cmd), dispatch immediately.
if ($MyInvocation.InvocationName -ne '.') {
    ikshvaku @args
}
