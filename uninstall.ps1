# Ikshvaku uninstaller for Windows (PowerShell 5.1+ and PowerShell 7).

$ErrorActionPreference = 'Continue'

$InstallDir  = Join-Path $env:USERPROFILE '.ikshvaku'
$BinDir      = Join-Path $env:USERPROFILE '.local\bin'
$profilePath = $PROFILE.CurrentUserAllHosts

Write-Host ':: Uninstalling Ikshvaku...'

if (Test-Path $profilePath) {
    $content = Get-Content -LiteralPath $profilePath -Raw
    $cleaned = $content -replace '(?s)\r?\n?# >>> Ikshvaku >>>.*?# <<< Ikshvaku <<<\r?\n?', ''
    Set-Content -LiteralPath $profilePath -Value $cleaned -NoNewline
}

Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $env:USERPROFILE '.Python-Env') -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $BinDir 'ikshvaku.cmd') -Force -ErrorAction SilentlyContinue

Write-Host ':: Files removed' -ForegroundColor Green

Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue

Write-Host ':: Uninstalled successfully' -ForegroundColor Green
Write-Host ':: Restart your shell to apply changes'
Write-Host ':: uv was left installed (other tools may use it). Remove with: uv self uninstall'
Write-Host ':: To report any problem: https://github.com/ashish-jha-73/IkshvakuPEM'
