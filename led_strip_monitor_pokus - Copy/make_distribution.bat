@echo off
REM ============================================
REM   ⚠️  DEPRECATED - Use build.py instead
REM ============================================
REM This script is kept for backward compatibility.
REM For new builds, use: python build.py
REM build.py creates a single distribution file automatically.
REM ============================================
REM   AmbiLight - Create Distribution Package
REM ============================================
REM This script creates a clean distribution folder
REM ready to share with friends (no source code)

setlocal enabledelayedexpansion

echo.
echo ==========================================
echo   Creating Distribution Package
echo ==========================================
echo.

REM Define paths
set "DIST_SOURCE=dist\AmbiLight"
set "DIST_TARGET=AmbiLight_Distribution"
set "README_SOURCE=dist\AmbiLight\README_INSTALLATION.txt"

REM Check if dist folder exists
if not exist "%DIST_SOURCE%" (
    echo [ERROR] dist\AmbiLight folder not found!
    echo Please run make_exe.bat first to build the application.
    pause
    exit /b 1
)

REM Clean up old distribution folder
if exist "%DIST_TARGET%" (
    echo Removing old distribution folder...
    rmdir /s /q "%DIST_TARGET%"
)

REM Create distribution folder
echo Creating distribution folder...
mkdir "%DIST_TARGET%"

REM Copy AmbiLight folder
echo Copying AmbiLight application...
xcopy "%DIST_SOURCE%" "%DIST_TARGET%\AmbiLight\" /E /I /H /Y >nul

REM Check if README exists, if not warn user
if not exist "%README_SOURCE%" (
    echo [WARNING] README_INSTALLATION.txt not found in dist folder!
    echo The distribution will be created without installation instructions.
)

REM Create a top-level README for the distribution
echo Creating distribution README...
(
echo ═══════════════════════════════════════════════════════════════
echo                    AmbiLight - Distribution Package
echo ═══════════════════════════════════════════════════════════════
echo.
echo 📦 WHAT'S INSIDE:
echo.
echo   AmbiLight\              - The application folder
echo   └── AmbiLight.exe       - Main application
echo   └── INSTALL_WINDOWS.bat - Installation helper
echo   └── README_INSTALLATION.txt - Full installation guide
echo   └── _internal\          - Required libraries
echo   └── config\             - Configuration files
echo   └── resources\          - Icons and assets
echo.
echo ═══════════════════════════════════════════════════════════════
echo 🚀 QUICK START:
echo ═══════════════════════════════════════════════════════════════
echo.
echo 1. Copy the "AmbiLight" folder to your PC
echo    ^(e.g., C:\Program Files\ or Documents\^)
echo.
echo 2. Open the folder and double-click "INSTALL_WINDOWS.bat"
echo    ^(This creates Desktop shortcut and adds to Startup^)
echo.
echo 3. Run "AmbiLight.exe" or use the Desktop shortcut
echo.
echo 4. Right-click the tray icon to open Settings
echo.
echo ═══════════════════════════════════════════════════════════════
echo 📖 FULL INSTRUCTIONS:
echo ═══════════════════════════════════════════════════════════════
echo.
echo Open: AmbiLight\README_INSTALLATION.txt
echo.
echo ═══════════════════════════════════════════════════════════════
echo                        Enjoy your AmbiLight! 🌈
echo ═══════════════════════════════════════════════════════════════
) > "%DIST_TARGET%\START_HERE.txt"

REM Optional: Download VC++ Redistributable info
echo Creating VC++ Redistributable info...
(
echo ═══════════════════════════════════════════════════════════════
echo           Visual C++ Redistributable Information
echo ═══════════════════════════════════════════════════════════════
echo.
echo If AmbiLight crashes on startup, you may need to install:
echo Microsoft Visual C++ 2015-2022 Redistributable ^(x64^)
echo.
echo Download from:
echo https://aka.ms/vs/17/release/vc_redist.x64.exe
echo.
echo Installation:
echo 1. Download the file
echo 2. Run vc_redist.x64.exe
echo 3. Follow the installation wizard
echo 4. Restart your PC
echo 5. Try running AmbiLight again
echo.
echo ═══════════════════════════════════════════════════════════════
) > "%DIST_TARGET%\VC_REDIST_INFO.txt"

echo.
echo ==========================================
echo   Distribution Package Created!
echo ==========================================
echo.
echo Location: %DIST_TARGET%\
echo.
echo 📦 WHAT TO DO NEXT:
echo.
echo 1. ZIP the "%DIST_TARGET%" folder
echo    ^(Right-click → Send to → Compressed folder^)
echo.
echo 2. Upload to:
echo    - Google Drive / OneDrive / Dropbox
echo    - USB Flash Drive
echo    - Email ^(if small enough^)
echo.
echo 3. Share the link/file with your friends!
echo.
echo ⚠️  IMPORTANT: Share the ENTIRE folder, not just AmbiLight.exe
echo.
REM pause
