@echo off
title MongoDB Docker App - Testing Executable
color 0A

echo ==========================================
echo    Testing MongoDB Docker App Executable
echo ==========================================
echo.

REM Test from Release directory (where the exe is located)
echo Testing from Release directory...
cd /d "c:\Users\linea\Desktop\gitPerm\mongodb_docker_app\build\windows\x64\runner\Release"
echo Current directory: %CD%
echo.

REM Check if docker folder exists here (should not)
if exist "docker" (
    echo ✓ Docker folder found in Release directory
) else (
    echo ✗ Docker folder NOT found in Release directory (expected)
)

REM Check if we can find the project root
cd ..\..\..\..\..\
echo Project root directory: %CD%
if exist "docker" (
    echo ✓ Docker folder found in project root
) else (
    echo ✗ Docker folder NOT found in project root
)

echo.
echo Press any key to start the application...
pause

REM Go back to Release directory and run the app
cd build\windows\x64\runner\Release
start mongodb_docker_app.exe
