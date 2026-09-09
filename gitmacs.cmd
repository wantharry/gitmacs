@echo off
setlocal

set "GITMACS_HOME=%~dp0"
set "SOCKET_NAME=gitmacs"
set "CLIENT_ARGS=-nw"
set "TARGET_DIR=%~dp0"

if "%~1"=="--gui" (
  set "CLIENT_ARGS=-c"
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
set "TARGET_DIR=%CD%"
popd

rem a persistent daemon means package/theme/magit loading only happens
rem once; every later launch just opens a client frame against it
emacsclient -s "%SOCKET_NAME%" --eval "nil" >nul 2>nul
if errorlevel 1 (
  emacs --daemon="%SOCKET_NAME%" -Q --load "%GITMACS_HOME%init.el"
)

emacsclient %CLIENT_ARGS% -s "%SOCKET_NAME%" --eval "(gitmacs-open \"%TARGET_DIR:\=/%\")"
