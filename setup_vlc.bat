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

:: Step 2: Deploy Lua interface script to VLC directory
echo [3/3] Deploying Lua interface script to VLC...
set "VLC_INTF_DIR=%APPDATA%\vlc\lua\intf"

if not exist "%VLC_INTF_DIR%" (
    echo Directory "%VLC_INTF_DIR%" does not exist. Creating it...
    mkdir "%VLC_INTF_DIR%"
)

echo Copying ambient_volume.lua to "%VLC_INTF_DIR%"...
copy /Y "%~dp0ambient_volume.lua" "%VLC_INTF_DIR%\"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy the Lua script to VLC interface directory.
    echo Please manually copy ambient_volume.lua to %VLC_INTF_DIR%
    pause
    exit /b 1
)

echo.
echo ==========================================================
echo  Setup Completed Successfully!
echo ==========================================================
echo.
echo HOW TO USE:
echo.
echo 1. Start the Python background listener:
echo    Double-click vlc_noise_listener.py (keep the window open)
echo.
echo 2. Launch VLC with the ambient volume interface enabled:
echo    "C:\Program Files\VideoLAN\VLC\vlc.exe" --extraintf=luaintf --lua-intf=ambient_volume
echo.
echo    Or create a shortcut with that command to launch easily!
echo.
echo 3. Play any media. The volume will adjust based on room noise.
echo.
echo NOTE: You can customize parameters (baseVolume, maxVolume,
echo sensitivity, noiseThreshold) in:
echo %~dp0config.json
echo ==========================================================
echo.
pause
