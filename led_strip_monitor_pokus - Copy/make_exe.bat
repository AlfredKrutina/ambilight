
@echo off
REM ==========================================
REM   ⚠️  DEPRECATED - Use build.py instead
REM ==========================================
REM This script is kept for backward compatibility.
REM For new builds, use: python build.py
REM ==========================================
echo ==========================================
echo      Building AmbiLight Application
echo      ⚠️  DEPRECATED - Use build.py instead
echo ==========================================

REM Clean previous build
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist

REM Run PyInstaller with explicit resource inclusion
REM --noconsole: Hide terminal window
REM --onedir: Create a folder (easier for debugging and config access)
REM --name: Executable name
REM --icon: Application icon
REM --paths src: Add src to python path so imports work
REM --add-data: Include resources folder
REM --clean: Clean cache
echo Running PyInstaller...
venv_new\Scripts\pyinstaller.exe --noconsole --onedir --name AmbiLight --icon=resources/icon_app.ico --paths src --add-data "resources;resources" --clean src/main.py

REM Force copy ALL resources and config to dist folder (overwrite PyInstaller's resources)
echo Copying assets...
echo Copying resources...
xcopy /E /I /Y /Q resources dist\AmbiLight\resources
echo Copying config...
xcopy /E /I /Y /Q config dist\AmbiLight\config
echo Copying installer...
copy /Y INSTALL_WINDOWS.bat dist\AmbiLight\
copy /Y README_INSTALLATION.txt dist\AmbiLight\ 2>nul

echo ==========================================
echo      Build Complete!
echo ==========================================
echo Application is in: dist\AmbiLight\AmbiLight.exe
echo.
echo Verifying resources...
dir /b dist\AmbiLight\resources
echo.
REM pause
