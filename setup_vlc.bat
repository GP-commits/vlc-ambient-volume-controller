@echo off
title VLC Ambient Volume Controller Setup
echo ==========================================================
echo  VLC Ambient Volume Controller Setup Script
echo ==========================================================
echo.

:: Step 1: Install Python dependencies
echo [1/3] Checking Python installation...
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Python was not found in your system PATH.
    echo Please install Python and ensure "Add Python to PATH" is checked during installation.
    pause
    exit /b 1
)
echo Python found.
echo.
echo [2/3] Installing Python dependencies (sounddevice, numpy)...
python -m pip install sounddevice numpy
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Failed to install dependencies via pip.
    echo Please run "pip install sounddevice numpy" manually in your terminal.
) else (
    echo Dependencies successfully installed.
)
echo.

:: Step 2: Deploy Lua plugin to VLC directory
echo [3/3] Locating VLC local extension directory...
set "VLC_EXT_DIR=%APPDATA%\vlc\lua\extensions"

if not exist "%VLC_EXT_DIR%" (
    echo Directory "%VLC_EXT_DIR%" does not exist. Creating it...
    mkdir "%VLC_EXT_DIR%"
)

echo Copying ambient_volume.lua to "%VLC_EXT_DIR%"...
copy /Y "%~dp0ambient_volume.lua" "%VLC_EXT_DIR%\"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy the Lua script to VLC extensions directory.
    echo Please run this script with Administrative permissions, or manually copy
    echo ambient_volume.lua to %VLC_EXT_DIR%
    pause
    exit /b 1
)

echo.
echo ==========================================================
echo  Setup Completed Successfully!
echo ==========================================================
echo.
echo HOW TO USE:
echo 1. Start the python background listener by double-clicking:
echo    vlc_noise_listener.py
echo 2. Open VLC Media Player.
echo 3. Navigate to: View -> Ambient Volume Controller
echo 4. Play any media! The volume will adjust based on room noise.
echo.
echo NOTE: You can customize parameters (baseVolume, maxVolume,
echo sensitivity, noiseThreshold) in:
echo %~dp0config.json
echo ==========================================================
echo.
pause
