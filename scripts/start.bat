@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."
cd /d "%ROOT%"

set "APP_URL=http://127.0.0.1:8002/"
set "HEALTH_URL=http://127.0.0.1:8002/api/docs/"

echo === LitReview ===
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo Docker is required but was not found.
  echo Install Docker Desktop: https://docs.docker.com/get-docker/
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo Docker is installed but not running. Start Docker Desktop, then run this script again.
  exit /b 1
)

if not exist .env (
  copy .env.example .env >nul
  echo Created .env from .env.example
  echo.
  echo IMPORTANT - edit .env before generating documents:
  echo   1. PUBMED_EMAIL=your.email@example.com   (required by NCBI)
  echo   2. NEO4J_PASSWORD=choose-a-strong-password
  echo   3. LLM settings - OpenAI key OR local LM Studio (see docs\GETTING_STARTED.md)
  echo.
  pause
)

if not exist backend\frontend_dist\index.html (
  echo Building web app...
  call "%ROOT%\scripts\build-web.bat"
  if errorlevel 1 exit /b 1
)

echo Starting services...
docker compose up -d --build
if errorlevel 1 exit /b 1

echo.
echo Waiting for LitReview to become ready...
set /a TRIES=0
:wait_loop
curl -sf "%HEALTH_URL%" >nul 2>&1
if not errorlevel 1 goto ready
set /a TRIES+=1
if %TRIES% GEQ 60 (
  echo Timed out waiting for the app. Check logs with: docker compose logs django
  exit /b 1
)
timeout /t 2 /nobreak >nul
goto wait_loop

:ready
echo.
echo LitReview is running.
echo   Web app:  %APP_URL%
echo   API docs: %APP_URL%api/docs/
echo.
start "" "%APP_URL%"
echo.
echo To stop: docker compose down
echo After UI changes, rebuild with: scripts\build-web.bat
