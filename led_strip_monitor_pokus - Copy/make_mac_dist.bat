@echo off
REM ==========================================
REM   ⚠️  DEPRECATED - Use build.py instead
REM ==========================================
REM This script is kept for backward compatibility.
REM For new builds, use: python build.py
REM ==========================================
echo ==========================================
echo      Preparing Mac Distribution Folder
echo      ⚠️  DEPRECATED - Use build.py instead
echo ==========================================

set "TARGET_DIR=dist\Mac_AmbiLight"

REM Clean previous
if exist "%TARGET_DIR%" rmdir /s /q "%TARGET_DIR%"
mkdir "%TARGET_DIR%"

REM Copy Files
echo Copying Source Code...
xcopy /E /I /Y src "%TARGET_DIR%\src"
echo Copying Config...
xcopy /E /I /Y config "%TARGET_DIR%\config"
echo Copying Resources...
xcopy /E /I /Y resources "%TARGET_DIR%\resources"

REM Copy Root Files
echo Copying Installer & Requirements...
copy /Y requirements.txt "%TARGET_DIR%\"
copy /Y INSTALL_MAC.command "%TARGET_DIR%\"
copy /Y README_FOR_FRIENDS.txt "%TARGET_DIR%\"

REM Cleanup __pycache__ (Mac doesn't need Windows compiled python files)
echo Cleaning up junk...
if exist "%TARGET_DIR%\src\__pycache__" rmdir /s /q "%TARGET_DIR%\src\__pycache__"
if exist "%TARGET_DIR%\src\ui\__pycache__" rmdir /s /q "%TARGET_DIR%\src\ui\__pycache__"

echo.
echo ==========================================
echo      Mac Folder Ready!
echo ==========================================
echo Location: %TARGET_DIR%
echo Action: Copy the entire 'Mac_AmbiLight' folder to the flash drive.
echo.
pause
