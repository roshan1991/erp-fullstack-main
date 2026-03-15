@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo   Elara POS Standalone Bundle Creator
echo ===================================================
echo.

set DIST_DIR=%~dp0DIST
set APP_DIR=%DIST_DIR%\ElaraPOS

if exist "%DIST_DIR%" rd /s /q "%DIST_DIR%"
mkdir "%APP_DIR%"

echo [1/4] Building Flutter Desktop (Release)...
cd /d "%~dp0pos_desktop"
call flutter clean
call flutter pub get
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo Flutter build failed!
    pause
    exit /b %ERRORLEVEL%
)

echo [2/4] Copying Flutter App files...
xcopy /E /I /Y "%~dp0pos_desktop\build\windows\x64\runner\Release\*" "%APP_DIR%\"

echo [3/4] Preparing Backend...
mkdir "%APP_DIR%\backend"
xcopy /E /I /Y "%~dp0config" "%APP_DIR%\backend\config"
xcopy /E /I /Y "%~dp0middleware" "%APP_DIR%\backend\middleware"
xcopy /E /I /Y "%~dp0models" "%APP_DIR%\backend\models"
xcopy /E /I /Y "%~dp0routes" "%APP_DIR%\backend\routes"
xcopy /E /I /Y "%~dp0sockets" "%APP_DIR%\backend\sockets"
xcopy /E /I /Y "%~dp0whatsapp" "%APP_DIR%\backend\whatsapp"
xcopy /E /I /Y "%~dp0public" "%APP_DIR%\backend\public"
if exist "%~dp0client\dist" (
    mkdir "%APP_DIR%\backend\client\dist"
    xcopy /E /I /Y "%~dp0client\dist" "%APP_DIR%\backend\client\dist"
)
copy /Y "%~dp0server.js" "%APP_DIR%\backend\"
copy /Y "%~dp0package.json" "%APP_DIR%\backend\"
copy /Y "%~dp0.env" "%APP_DIR%\backend\"
copy /Y "%~dp0users.json" "%APP_DIR%\backend\"
copy /Y "%~dp0accounts_db.js" "%APP_DIR%\backend\"
if exist "%~dp0accounts.db" copy /Y "%~dp0accounts.db" "%APP_DIR%\backend\"

echo [4/5] Installing Backend Dependencies...
cd /d "%APP_DIR%\backend"
call npm install --production
if %ERRORLEVEL% NEQ 0 (
    echo npm install failed!
    pause
    exit /b %ERRORLEVEL%
)
cd /d "%~dp0"

:: Note: AI and Accounts are integrated into the main backend above.

echo [5/5] Creating Launcher...

:: Create a VBScript to start services silently
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo ' Start ERP Backend (includes Elais AI)
echo WshShell.Run "cmd /c cd backend ^&^& node server.js", 0, False
echo ' Wait for servers
echo WScript.Sleep 5000
echo ' Start POS App
echo WshShell.Run "elara_pos.exe", 1, True
) > "%APP_DIR%\START_POS.vbs"

:: Create a simple BAT launcher too
(
echo @echo off
echo echo Starting Elara POS Services (with Elais AI)...
echo start /min cmd /c "cd backend ^&^& node server.js"
echo timeout /t 5 /nobreak
echo start "" "elara_pos.exe"
) > "%APP_DIR%\LAUNCHER.bat"

echo.
echo ===================================================
echo   BUNDLE CREATED SUCCESSFULLY!
echo   Location: %APP_DIR%
echo.
echo   To deploy:
echo   1. Copy the ElaraPOS folder to the target PC.
echo   2. Ensure Node.js is installed on the target PC.
echo   3. Run START_POS.vbs to launch.
echo ===================================================
echo.
pause
