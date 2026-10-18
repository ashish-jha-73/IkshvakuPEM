@echo off
rem ============================================================
rem  Ikshvaku cmd shim
rem  - activate/deactivate run natively in cmd (they must modify
rem    this very session, which only batch can do)
rem  - everything else delegates to the PowerShell implementation
rem ============================================================

if /i "%~1"=="activate" (
    if "%~2"=="" (
        echo Usage: ikshvaku activate ^<env^>
        exit /b 1
    )
    if not exist "%USERPROFILE%\.Python-Env\%~2\Scripts\activate.bat" (
        echo Env not found: %~2
        exit /b 1
    )
    call "%USERPROFILE%\.Python-Env\%~2\Scripts\activate.bat"
    set "IKSHVAKU_ACTIVE=%~2"
    exit /b 0
)

if /i "%~1"=="deactivate" (
    if defined VIRTUAL_ENV (
        call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
        set "IKSHVAKU_ACTIVE="
    ) else (
        echo No env active
    )
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.ikshvaku\ikshvaku.ps1" %*
exit /b %ERRORLEVEL%
