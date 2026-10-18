@echo off
rem ============================================================
rem  Ikshvaku cmd shim
rem  - activate/deactivate run natively in cmd (they must modify
rem    this very session, which only batch can do)
rem  - bare `ikshvaku activate` resolves the linked env through
rem    PowerShell, then activates it natively here
rem  - everything else delegates to the PowerShell implementation
rem ============================================================

if /i not "%~1"=="activate" goto :deactivate_check

if not "%~2"=="" goto :activate_named

set "IKENV="
for /f "usebackq delims=" %%e in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.ikshvaku\ikshvaku.ps1" _resolve-link`) do set "IKENV=%%e"
if not defined IKENV (
    echo No environment linked to this directory. Run: ikshvaku init
    exit /b 1
)
goto :activate_env

:activate_named
if not exist "%USERPROFILE%\.Python-Env\%~2\Scripts\activate.bat" (
    echo Env not found: %~2
    exit /b 1
)
set "IKENV=%~2"

:activate_env
call "%USERPROFILE%\.Python-Env\%IKENV%\Scripts\activate.bat"
set "IKSHVAKU_ACTIVE=%IKENV%"
exit /b 0

:deactivate_check
if /i not "%~1"=="deactivate" goto :delegate

if defined VIRTUAL_ENV (
    call "%VIRTUAL_ENV%\Scripts\deactivate.bat"
    set "IKSHVAKU_ACTIVE="
) else (
    echo No env active
)
exit /b 0

:delegate
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.ikshvaku\ikshvaku.ps1" %*
exit /b %ERRORLEVEL%
