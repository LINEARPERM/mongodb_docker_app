@echo off
title MongoDB Docker App
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

REM Check if Docker is running
echo    - Checking if Docker is running...
docker info >nul 2>&1
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Docker is not running
    echo.
    echo 💡 Please start Docker Desktop and wait for it to finish starting
    echo    Then run this application again.
    echo.
    pause
    exit /b 1
)

echo       ✅ Docker is installed and running

REM ==================================================
REM 2. SETUP DOCKER CONFIGURATION
REM ==================================================

echo 🔧 Setting up Docker configuration...

REM Create docker directory if it doesn't exist
if not exist "docker" (
    echo    - Creating docker directory...
    mkdir docker
    if errorlevel 1 (
        echo ❌ ERROR: Cannot create docker directory
        pause
        exit /b 1
    )
    echo       ✅ Docker directory created
) else (
    echo    - Docker directory already exists
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
        echo     age: 30,
        echo     createdAt: new Date(^)
        echo   },
        echo   {
        echo     name: 'Jane Smith',
        echo     email: 'jane@example.com',
        echo     age: 25,
        echo     createdAt: new Date(^)
        echo   },
        echo   {
        echo     name: 'Bob Johnson',
        echo     email: 'bob@example.com',
        echo     age: 35,
        echo     createdAt: new Date(^)
        echo   },
        echo   {
        echo     name: 'Alice Wilson',
        echo     email: 'alice@example.com',
        echo     age: 28,
        echo     createdAt: new Date(^)
        echo   },
        echo   {
        echo     name: 'Charlie Brown',
        echo     email: 'charlie@example.com',
        echo     age: 32,
        echo     createdAt: new Date(^)
        echo   }
        echo ]^);
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

REM ==================================================
REM 3. LAUNCH APPLICATION
REM ==================================================

echo.
echo 🚀 Starting MongoDB Docker App...
echo.

REM Check if executable exists
if not exist "mongodb_docker_app.exe" (
    echo ❌ ERROR: mongodb_docker_app.exe not found
    echo    Expected location: %APP_ROOT%mongodb_docker_app.exe
    pause
    exit /b 1
)

REM Launch the application
start "MongoDB Docker App" mongodb_docker_app.exe

echo ✅ Application started successfully!
echo.
echo 💡 The application is now running in a separate window.
echo    You can close this console window.
echo.

REM Wait a moment then exit
timeout /t 3 /nobreak >nul

exit /b 0
