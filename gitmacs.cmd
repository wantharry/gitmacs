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
rem once; every later launch just opens a client frame against it.
rem `emacs --daemon' doesn't detach from the console on Windows the way
rem it does on Unix, so it would just hang this script forever; runemacs
rem is the console-free launcher Emacs ships specifically for this, so
rem we start it that way and poll until the daemon answers instead of
rem relying on the launch command blocking until it's ready.
emacsclient -s "%SOCKET_NAME%" --eval "nil" >nul 2>nul
if errorlevel 1 (
  call :start_daemon
  if errorlevel 1 exit /b 1
)

emacsclient %CLIENT_ARGS% -s "%SOCKET_NAME%" --eval "(gitmacs-open \"%TARGET_DIR:\=/%\")"
exit /b 0

:start_daemon
echo Starting Emacs daemon (first launch only, later ones are instant)...
start "" runemacs --daemon="%SOCKET_NAME%" -Q --load "%GITMACS_HOME%init.el"
for /l %%i in (1,1,60) do (
  emacsclient -s "%SOCKET_NAME%" --eval "nil" >nul 2>nul
  if not errorlevel 1 exit /b 0
  timeout /t 1 /nobreak >nul
)
echo Timed out waiting for the Emacs daemon to start.
pause
exit /b 1
