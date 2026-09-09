@echo off
setlocal

set "GITMACS_HOME=%~dp0"
set "EMACS_ARGS=-Q -nw"
set "TARGET_DIR=%~dp0"

if "%~1"=="--gui" (
  set "EMACS_ARGS=-Q"
  shift
)

if not "%~1"=="" set "TARGET_DIR=%~1"

where emacs >nul 2>nul
if errorlevel 1 (
  echo emacs was not found on PATH.
  echo Install GNU Emacs for Windows first: https://www.gnu.org/software/emacs/download.html
  pause
  exit /b 1
)

pushd "%TARGET_DIR%" || (pause & exit /b 1)
emacs %EMACS_ARGS% --load "%GITMACS_HOME%init.el"
popd
