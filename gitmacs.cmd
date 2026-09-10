@echo off
setlocal

set "GITMACS_HOME=%~dp0"
set "SOCKET_NAME=gitmacs"
set "TARGET_DIR=%~dp0"
set "GUI="

if "%~1"=="--gui" (
  set "GUI=1"
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

cd /d "%TARGET_DIR%" || (pause & exit /b 1)
set "TARGET_DIR=%CD%"

if defined GUI goto gui_mode

rem Windows can't attach an emacsclient text frame to the console that
rem launched it -- it always opens a new console window instead of
rem reusing this one. So for the terminal experience we just run Emacs
rem directly here (no daemon involved) to guarantee it stays in this
rem window, at the cost of a normal cold start each time. --gui below
rem doesn't have this problem (a new window is expected there anyway),
rem so it keeps the daemon speedup.
emacs -Q -nw --load "%GITMACS_HOME%init.el"
exit /b 0

:gui_mode
rem a persistent daemon means package/theme/magit loading only happens
rem once; every later --gui launch just opens a client frame against it.
rem `emacs --daemon' doesn't detach from the console on Windows the way
rem it does on Unix, so it would just hang this script forever; runemacs
rem is the console-free launcher Emacs ships specifically for this, so
rem we start it that way and poll until the daemon answers instead of
rem relying on the launch command blocking until it's ready. Windows
rem emacsclient also doesn't support -s/--socket-name -- it needs
rem --server-file instead.
emacsclient --server-file="%SOCKET_NAME%" --eval "nil" >nul 2>nul
if errorlevel 1 (
  call :start_daemon
  if errorlevel 1 exit /b 1
)

emacsclient -c --server-file="%SOCKET_NAME%" --eval "(gitmacs-open \"%TARGET_DIR:\=/%\")"
exit /b 0

:start_daemon
echo Starting Emacs daemon (first launch only, later ones are instant)...
start "" runemacs --daemon="%SOCKET_NAME%" -Q --load "%GITMACS_HOME%init.el"
for /l %%i in (1,1,180) do (
  emacsclient --server-file="%SOCKET_NAME%" --eval "nil" >nul 2>nul
  if not errorlevel 1 exit /b 0
  timeout /t 1 /nobreak >nul
)
echo Timed out waiting for the Emacs daemon to start.
pause
exit /b 1
