@echo off
title MongoDB Docker App - Uninstall
color 0C

echo.
echo ==========================================
echo    MongoDB Docker App - Uninstall
echo ==========================================
echo.

echo ⚠️  WARNING: This will remove all Docker containers and data
echo     created by MongoDB Docker App.
echo.

set /p CONFIRM="Are you sure you want to continue? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo.
    echo ❌ Uninstall cancelled by user
    echo.
    pause
    exit /b 0
)

echo.
echo 🧹 Starting cleanup process...

REM Get the directory where this batch file is located
set APP_ROOT=%~dp0

REM Change to the app root directory
cd /d "%APP_ROOT%"

echo.
echo 📁 Working directory: %APP_ROOT%

REM ==================================================
REM 1. STOP AND REMOVE DOCKER CONTAINERS
REM ==================================================

echo.
echo 🐳 Cleaning up Docker containers and volumes...

REM Check if Docker is available
docker --version >nul 2>&1
if not errorlevel 1 (
    echo    - Docker is available, proceeding with cleanup
    
    REM Stop and remove containers if docker folder exists
    if exist "docker" (
        echo    - Stopping MongoDB containers...
        cd docker
        docker compose down -v 2>nul
        if not errorlevel 1 (
            echo       ✅ Containers stopped and removed
        ) else (
            echo       ⚠️  No containers were running
        )
        
        REM Remove the specific image
        echo    - Removing MongoDB Docker image...
        docker rmi mongo:7.0-jammy 2>nul
        if not errorlevel 1 (
            echo       ✅ MongoDB image removed
        ) else (
            echo       ⚠️  Image not found or in use by other containers
        )
        
        REM Remove named volume
        echo    - Removing MongoDB data volume...
        docker volume rm mongodb_docker_app_mongodb_data 2>nul
        if not errorlevel 1 (
            echo       ✅ Data volume removed
        ) else (
            echo       ⚠️  Volume not found
        )
        
        cd /d "%APP_ROOT%"
    ) else (
        echo    - No docker configuration found
    )
) else (
    echo    - Docker not available, skipping container cleanup
)

REM ==================================================
REM 2. REMOVE APPLICATION FILES
REM ==================================================

echo.
echo 📂 Removing application files...

REM Remove docker configuration folder
if exist "docker" (
    echo    - Removing docker configuration...
    rmdir /s /q "docker" 2>nul
    if not exist "docker" (
        echo       ✅ Docker configuration removed
    ) else (
        echo       ❌ Failed to remove docker configuration
    )
) else (
    echo    - Docker configuration not found
)

REM List files that will remain (read-only files like README, etc.)
echo.
echo 📋 Remaining files in installation directory:
echo    - MongoDBDockerApp.bat (this launcher)
echo    - mongodb_docker_app.exe (main application)
echo    - README.txt, LICENSE.txt, etc. (documentation)
echo    - uninstall.bat (this script)
echo.
echo 💡 Note: These files should be removed by the system uninstaller
echo    if you used an installer to install this application.

REM ==================================================
REM 3. CLEANUP SUMMARY
REM ==================================================

echo.
echo ==========================================
echo    🧹 CLEANUP SUMMARY
echo ==========================================
echo.
echo ✅ Docker containers: Stopped and removed
echo ✅ Docker volumes: Removed (if existed)
echo ✅ Docker images: Removed (if existed)
echo ✅ Configuration files: Removed
echo.
echo ⚠️  NOTE: Main application files remain in:
echo    %APP_ROOT%
echo.
echo 💡 To completely remove the application:
echo    1. Close this window
echo    2. Use "Add or Remove Programs" in Windows Settings
echo    3. Or manually delete the installation folder
echo.

echo ==========================================

echo.
echo 👋 Thank you for using MongoDB Docker App!
echo.
pause