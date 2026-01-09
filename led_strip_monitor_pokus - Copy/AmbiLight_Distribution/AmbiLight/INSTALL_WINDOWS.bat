@echo off
set "SCRIPT_DIR=%~dp0"
set "APP_PATH=%SCRIPT_DIR%AmbiLight.exe"
set "ICON_PATH=%SCRIPT_DIR%resources\icon_app.ico"
set "APP_NAME=AmbiLight"

echo ==========================================
echo      Installing AmbiLight for Windows
echo ==========================================
echo.
echo Target: %APP_PATH%

if not exist "%APP_PATH%" (
    echo [ERROR] AmbiLight.exe not found!
    echo Please make sure you unzipped the entire folder.
    pause
    exit /b
)

echo.
echo 1. Creating Desktop Shortcut...
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%USERPROFILE%\Desktop\%APP_NAME%.lnk'); $SC.TargetPath = '%APP_PATH%'; $SC.WorkingDirectory = '%SCRIPT_DIR%'; $SC.IconLocation = '%ICON_PATH%'; $SC.Save()"
echo    - Done.

echo.
echo 2. Adding to Startup (Auto-start)...
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $StartupDir = $WS.SpecialFolders.Item('Startup'); $SC = $WS.CreateShortcut(\"$StartupDir\%APP_NAME%.lnk\"); $SC.TargetPath = '%APP_PATH%'; $SC.WorkingDirectory = '%SCRIPT_DIR%'; $SC.IconLocation = '%ICON_PATH%'; $SC.Save()"
echo    - Done.

echo.
echo ==========================================
echo      Installation Complete!
echo ==========================================
echo You can now delete this installer script if you want.
echo.
pause
