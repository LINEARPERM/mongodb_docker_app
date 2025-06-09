@echo off
title MongoDB Docker App - Installer Version
color 0A

echo.
echo ==========================================
echo    MongoDB Docker App v1.0
echo ==========================================
echo.

REM Get the directory where this batch file is located (installation directory)
set APP_ROOT=%~dp0

REM Change to the app root directory
cd /d "%APP_ROOT%"

echo 📁 Application Directory: %APP_ROOT%
echo.

REM ==================================================
REM 1. CHECK SYSTEM REQUIREMENTS
REM ==================================================

echo 🔍 Checking system requirements...

REM Check if Docker is installed and accessible
echo    - Checking Docker installation...
docker --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Docker is not installed or not accessible
    echo.
    echo 📋 REQUIRED: Docker Desktop must be installed and running
    echo 📥 Download from: https://www.docker.com/products/docker-desktop/
    echo.
    echo 💡 After installing Docker Desktop:
    echo    1. Start Docker Desktop
    echo    2. Wait for it to finish starting
    echo    3. Run this application again
    echo.
    pause
    exit /b 1
)

echo       ✅ Docker is available

REM Check if Docker service is running
echo    - Checking Docker service...
docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Docker service is not running
    echo.
    echo 📋 Please start Docker Desktop and try again
    echo.
    pause
    exit /b 1
)

echo       ✅ Docker service is running
echo.

REM ==================================================
REM 2. SETUP DOCKER CONFIGURATION
REM ==================================================

echo 🐳 Setting up Docker configuration...

REM Check if docker folder exists, if not create it
if not exist "docker" (
    echo    - Creating docker configuration folder...
    mkdir docker
    if errorlevel 1 (
        echo ❌ ERROR: Cannot create docker folder
        pause
        exit /b 1
    )
    echo       ✅ Docker folder created
) else (
    echo    - Docker folder already exists
)

REM Create docker-compose.yml if it doesn't exist
if not exist "docker\docker-compose.yml" (
    echo    - Creating docker-compose.yml configuration...
    (
        echo version: '3.8'
        echo services:
        echo   mongodb:
        echo     image: mongo:7.0-jammy
        echo     container_name: flutter_mongodb
        echo     restart: unless-stopped
        echo     environment:
        echo       MONGO_INITDB_ROOT_USERNAME: admin
        echo       MONGO_INITDB_ROOT_PASSWORD: admin123
        echo       MONGO_INITDB_DATABASE: myapp
        echo     ports:
        echo       - "27018:27017"
        echo     volumes:
        echo       - mongodb_data:/data/db
        echo       - ./init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js:ro
        echo     healthcheck:
        echo       test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping'^)"]
        echo       interval: 30s
        echo       timeout: 10s
        echo       retries: 3
        echo.
        echo volumes:
        echo   mongodb_data:
        echo     driver: local
    ) > docker\docker-compose.yml
    
    if errorlevel 1 (
        echo ❌ ERROR: Cannot create docker-compose.yml
        pause
        exit /b 1
    )
    echo       ✅ Docker Compose configuration created
) else (
    echo    - Docker Compose configuration already exists
)

REM Create init-mongo.js if it doesn't exist
if not exist "docker\init-mongo.js" (
    echo    - Creating database initialization script...
    (
        echo db = db.getSiblingDB('myapp'^);
        echo.
        echo db.createUser({
        echo   user: 'appuser',
        echo   pwd: 'apppass123',
        echo   roles: [
        echo     {
        echo       role: 'readWrite',
        echo       db: 'myapp'
        echo     }
        echo   ]
        echo }^);
        echo.
        echo db.users.insertMany([
        echo   {
        echo     name: 'John Doe',
        echo     email: 'john@example.com',
        echo     age: 25,
        echo     city: 'Bangkok',
        echo     createdAt: new Date(^)
        echo   },
        echo   {
        echo     name: 'Jane Smith', 
        echo     email: 'jane@example.com',
        echo     age: 30,
        echo     city: 'Chiang Mai',
        echo     createdAt: new Date(^)
        echo   }
        echo ]^);
        echo.
        echo print('✅ Database initialized with sample data'^);
    ) > docker\init-mongo.js
    
    if errorlevel 1 (
        echo ❌ ERROR: Cannot create init-mongo.js
        pause
        exit /b 1
    )
    echo       ✅ Database initialization script created
) else (
    echo    - Database initialization script already exists
)

echo.

REM ==================================================
REM 3. LAUNCH APPLICATION
REM ==================================================

echo 🚀 Launching application...

REM Try different possible locations for the executable
set EXE_FOUND=0

REM Check common installation paths
if exist "mongodb_docker_app.exe" (
    echo    - Found executable in root directory
    start "" "mongodb_docker_app.exe"
    set EXE_FOUND=1
) else if exist "bin\mongodb_docker_app.exe" (
    echo    - Found executable in bin directory
    start "" "bin\mongodb_docker_app.exe"
    set EXE_FOUND=1
) else if exist "app\mongodb_docker_app.exe" (
    echo    - Found executable in app directory
    start "" "app\mongodb_docker_app.exe"
    set EXE_FOUND=1
) else if exist "build\windows\x64\runner\Release\mongodb_docker_app.exe" (
    echo    - Found executable in development directory
    start "" "build\windows\x64\runner\Release\mongodb_docker_app.exe"
    set EXE_FOUND=1
)

if %EXE_FOUND%==0 (
    echo.
    echo ❌ ERROR: Application executable not found!
    echo.
    echo 📋 Searched locations:
    echo    - %APP_ROOT%mongodb_docker_app.exe
    echo    - %APP_ROOT%bin\mongodb_docker_app.exe
    echo    - %APP_ROOT%app\mongodb_docker_app.exe
    echo    - %APP_ROOT%build\windows\x64\runner\Release\mongodb_docker_app.exe
    echo.
    echo 💡 Please ensure the executable is in one of these locations
    echo.
    pause
    exit /b 1
)

echo       ✅ Application launched successfully!
echo.

REM ==================================================
REM 4. INFORMATION DISPLAY
REM ==================================================

echo ==========================================
echo    📋 INFORMATION
echo ==========================================
echo.
echo 📁 Application Directory:
echo    %APP_ROOT%
echo.
echo 🐳 Docker Configuration:
echo    %APP_ROOT%docker\
echo.
echo 🌐 MongoDB Connection:
echo    Host: localhost
echo    Port: 27018
echo    Database: myapp
echo    Username: appuser
echo.
echo 💡 USAGE NOTES:
echo    - MongoDB will start automatically when needed
echo    - Data is persistent between sessions
echo    - You can close this window now
echo.
echo ==========================================

REM Auto-close after 10 seconds, or wait for user input
echo This window will close automatically in 10 seconds...
echo Press any key to close immediately.
timeout /t 10 >nul

echo.
echo 👋 Thank you for using MongoDB Docker App!
exit /b 0