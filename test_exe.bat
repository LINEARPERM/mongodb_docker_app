@echo off
title Testing MongoDB Docker App Executable
echo Testing the executable...
echo.

cd /d "c:\Users\linea\Desktop\gitPerm\mongodb_docker_app\build\windows\x64\runner\Release"
echo Current directory: %CD%
echo.

echo Starting the app...
mongodb_docker_app.exe

echo.
echo App finished. Press any key to continue...
pause
