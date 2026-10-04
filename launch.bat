@echo off
setlocal EnableExtensions
rem Double-click this file on Windows to always launch EXFac.
rem Requires Godot 4.3+ Standard (not .NET) on PATH, or in a common install folder,
rem or as godot.exe / Godot_v4*_win64.exe next to this script.

cd /d "%~dp0"

set "GODOT="

if exist "%~dp0godot.exe" set "GODOT=%~dp0godot.exe"
if not defined GODOT if exist "%~dp0Godot_v4.3-stable_win64.exe" set "GODOT=%~dp0Godot_v4.3-stable_win64.exe"
if not defined GODOT if exist "%~dp0Godot_v4.4-stable_win64.exe" set "GODOT=%~dp0Godot_v4.4-stable_win64.exe"

if not defined GODOT where godot >nul 2>&1 && for /f "delims=" %%i in ('where godot') do (
  set "GODOT=%%i"
  goto :found
)

if not defined GODOT if exist "%LOCALAPPDATA%\Godot\godot.exe" set "GODOT=%LOCALAPPDATA%\Godot\godot.exe"
if not defined GODOT if exist "%ProgramFiles%\Godot\Godot_v4.3-stable_win64.exe" set "GODOT=%ProgramFiles%\Godot\Godot_v4.3-stable_win64.exe"
if not defined GODOT if exist "%ProgramFiles%\Godot\godot.exe" set "GODOT=%ProgramFiles%\Godot\godot.exe"
if not defined GODOT if exist "%USERPROFILE%\Downloads\Godot_v4.3-stable_win64.exe" set "GODOT=%USERPROFILE%\Downloads\Godot_v4.3-stable_win64.exe"
if not defined GODOT if exist "%USERPROFILE%\Downloads\Godot_v4.4-stable_win64.exe" set "GODOT=%USERPROFILE%\Downloads\Godot_v4.4-stable_win64.exe"

rem Steam Godot installs vary; scan common Steam library path if present.
if not defined GODOT if exist "%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.exe" set "GODOT=%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.exe"

:found
if not defined GODOT (
  echo.
  echo Godot 4 not found.
  echo.
  echo Fix options:
  echo   1^) Download Godot 4.3 Standard and put Godot_v4.3-stable_win64.exe in this folder
  echo      %~dp0
  echo   2^) Or add godot.exe to your PATH
  echo   3^) Or open project.godot from the Godot Project Manager
  echo.
  echo Download: https://godotengine.org/download/archive/4.3-stable/
  echo.
  pause
  exit /b 1
)

echo Launching with:
echo   %GODOT%
echo   project: %CD%
echo.
"%GODOT%" --path "%CD%"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo Godot exited with code %ERR%.
  pause
)
exit /b %ERR%
