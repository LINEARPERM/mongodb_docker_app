@echo off
title MongoDB Docker App Launcher
color 0A

echo ==========================================
echo    MongoDB Docker App v1.0
echo ==========================================
echo.

REM Get the directory where this launcher is located (should be project root)
set APP_ROOT=%~dp0

REM Change to the app root directory  
cd /d "%APP_ROOT%"

echo 📁 Application Directory: %APP_ROOT%
echo.

REM Check if Docker files exist
if exist "docker\docker-compose.yml" (
    echo ✓ Docker configuration found
) else (
    echo ⚠ Docker configuration will be created automatically
)

echo.
echo 🚀 Starting MongoDB Docker App...
echo.

REM Run the executable from the project root
"%APP_ROOT%build\windows\x64\runner\Release\mongodb_docker_app.exe"

echo.
echo 📝 App finished. Press any key to exit...
pause
