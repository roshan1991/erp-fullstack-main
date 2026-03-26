@echo off
setlocal EnableDelayedExpansion

:: ================================================================
::  ELARA POS - Full Build & Distribution Script
::  1. Cleans and Rebuilds Flutter Windows
::  2. Consolidates everything into the DIST\ElaraPOS folder
::  3. Prepares the unified Backend (Node + MySQL + SQLite)
::  4. Installs Node dependencies
:: ================================================================

set "ROOT=%~dp0"
set "PROJECT=%ROOT%pos_desktop"
set "DIST=%ROOT%DIST\ElaraPOS"
set "BUILD_RELEASE=%PROJECT%\build\windows\x64\runner\Release"

echo.
echo  ================================================================
echo   ELARA POS - Build Distribution
echo  ================================================================
echo.

:: ── STEP 1: Flutter Clean & Rebuild ──────────────────────────────
echo [1/4] Cleaning and rebuilding Flutter...
cd /d "%PROJECT%"
call flutter clean
if %errorlevel% neq 0 ( echo [ERROR] flutter clean failed! & pause & exit /b 1 )

call flutter pub get
call flutter build windows --release
if %errorlevel% neq 0 ( echo [ERROR] flutter build windows failed! & pause & exit /b 1 )
echo       Done.
echo.

:: ── STEP 2: Prepare DIST Folder ──────────────────────────────────
echo [2/4] Preparing DIST\ElaraPOS folder...
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%"
mkdir "%DIST%\backend"

:: Copy Flutter build binaries
xcopy /E /I /Y /Q "%BUILD_RELEASE%\*" "%DIST%\" >nul
:: Copy POS config
copy /Y "%PROJECT%\config.json" "%DIST%\" >nul
echo       Done.
echo.

:: ── STEP 3: Consolidate Backend ──────────────────────────────────
echo [3/4] Consolidating unified Backend...
:: Core files
copy /Y "%ROOT%server.js" "%DIST%\backend\" >nul
copy /Y "%ROOT%accounts_db.js" "%DIST%\backend\" >nul
copy /Y "%ROOT%package.json" "%DIST%\backend\" >nul
copy /Y "%ROOT%.env" "%DIST%\backend\" >nul

:: Folders
xcopy /E /I /Y /Q "%ROOT%routes" "%DIST%\backend\routes\" >nul
xcopy /E /I /Y /Q "%ROOT%models" "%DIST%\backend\models\" >nul
xcopy /E /I /Y /Q "%ROOT%config" "%DIST%\backend\config\" >nul
xcopy /E /I /Y /Q "%ROOT%sockets" "%DIST%\backend\sockets\" >nul
xcopy /E /I /Y /Q "%ROOT%public" "%DIST%\backend\public\" >nul

:: React client (if exists)
if exist "%ROOT%client\dist" (
    xcopy /E /I /Y /Q "%ROOT%client\dist" "%DIST%\backend\client\" >nul
)

:: Launcher script
(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo ' Start Backend
echo WshShell.Run "cmd /c cd backend && node server.js", 0, False
echo ' Wait for server
echo WScript.Sleep 5000
echo ' Start POS App
echo WshShell.Run "elara_pos.exe", 1, True
) > "%DIST%\START_POS.vbs"

echo       Done.
echo.

:: ── STEP 4: Install Node Dependencies ────────────────────────────
echo [4/4] Installing Backend dependencies (Production)...
cd /d "%DIST%\backend"
call npm install --omit=dev
if %errorlevel% neq 0 ( 
    echo [WARN] npm install failed. Please run manually in DIST\ElaraPOS\backend.
)
echo       Done.
echo.

echo  ================================================================
echo   DISTRIBUTION READY!
echo.
echo   Location: %DIST%
echo   Launch: Double-click START_POS.vbs
echo  ================================================================
echo.
pause
exit /b 0
