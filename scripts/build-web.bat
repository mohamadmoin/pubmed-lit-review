@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."
set "FRONTEND=%ROOT%\frontend"
set "OUTPUT=%ROOT%\backend\frontend_dist"

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter SDK not found on PATH.
  echo Install Flutter: https://docs.flutter.dev/get-started/install
  echo Then restart your terminal and run this script again.
  exit /b 1
)

cd /d "%FRONTEND%"
call flutter pub get
if errorlevel 1 exit /b 1
call flutter build web --release --dart-define=API_BASE_URL=/api
if errorlevel 1 exit /b 1

if exist "%OUTPUT%" rmdir /s /q "%OUTPUT%"
mkdir "%OUTPUT%"
xcopy /E /I /Y build\web\* "%OUTPUT%\" >nul

echo Web app built to backend\frontend_dist\
echo Start the stack with scripts\start.bat or docker compose up -d --build

where docker >nul 2>&1
if not errorlevel 1 (
  docker info >nul 2>&1
  if not errorlevel 1 (
    for /f "delims=" %%i in ('docker ps --format "{{.Names}}" 2^>nul ^| findstr /x "litreview-django"') do (
      echo Refreshing Django container so it picks up the new web build...
      docker compose -f "%ROOT%\docker-compose.yml" up -d --force-recreate django
    )
  )
)
