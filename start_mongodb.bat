@echo off
echo Starting MongoDB Docker container...

REM Pull MongoDB image
docker compose pull

REM Start container
docker compose up -d

REM Check if container is running
timeout /t 5 >nul
docker compose ps

echo MongoDB startup completed successfully
