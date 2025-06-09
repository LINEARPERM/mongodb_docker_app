@echo off
echo Stopping MongoDB Docker container...

REM Stop and remove containers
docker compose down

echo MongoDB stopped successfully
