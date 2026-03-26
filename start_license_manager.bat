@echo off
setlocal
echo ==========================================
echo   Ahu ERP License Manager - Starting...   
echo ==========================================
echo.

cd license_manager

:: Check for pubspec.yaml
if not exist pubspec.yaml (
    echo Error: Could not find license_manager project directory.
    pause
    exit /b 1
)

:: Run the app on windows
echo Current Directory: %cd%
echo Launching Flutter Windows application...
echo.

flutter run -d windows

if %errorlevel% neq 0 (
    echo.
    echo Something went wrong while starting the app.
    echo Make sure Flutter is installed and you are on Windows.
    pause
)

endlocal
