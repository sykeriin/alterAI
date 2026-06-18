@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "TMP_ROOT=C:\tmp"
set "PROJECT_LINK=%TMP_ROOT%\alterAI"
set "FLUTTER_LINK=%TMP_ROOT%\flutter"
set "PUB_CACHE=%TMP_ROOT%\pub-cache"

if not exist "%TMP_ROOT%" mkdir "%TMP_ROOT%"

if not exist "%PROJECT_LINK%" (
  mklink /J "%PROJECT_LINK%" "%PROJECT_DIR:~0,-1%" >nul
)

if not exist "%FLUTTER_LINK%" (
  for %%F in (flutter.bat) do set "FLUTTER_BIN=%%~$PATH:F"
  if not defined FLUTTER_BIN (
    echo Flutter was not found on PATH.
    exit /b 1
  )
  for %%F in ("%FLUTTER_BIN%") do for %%R in ("%%~dpF..") do set "FLUTTER_ROOT=%%~fR"
  mklink /J "%FLUTTER_LINK%" "%FLUTTER_ROOT%" >nul
)

cd /d "%PROJECT_LINK%"
"%FLUTTER_LINK%\bin\flutter.bat" pub get
"%FLUTTER_LINK%\bin\flutter.bat" run -d web-server --web-port=8097 --web-hostname=127.0.0.1
