# How to Share AmbiLight

## 1. For your WINDOWS Friend 🪟
1. Open the `dist` folder inside this project.
2. Copy the **entire** `AmbiLight` folder to your flash drive.
   (It contains `AmbiLight.exe`, `INSTALL_WINDOWS.bat`, and `resources`/`config` folders).
3. **Instructions for your friend:**
   - Copy the folder from the flash drive to their PC (e.g. local disk C: or Documents).
   - Open the folder.
   - Double-click `INSTALL_WINDOWS.bat`.
   - This will:
     - Create a Shortcut on their Desktop.
     - Add the app to Startup so it runs automatically.

## 2. For your MAC (M1/Intel) Friend 🍎
*Note: Mac cannot run Windows .exe files. They need the python source code.*

1. Copy this **ENTIRE PROJECT FOLDER** to the flash drive.
   - **Important**: You can DELETE the `venv`, `build`, and `dist` folders before copying to save space (Mac needs to create its own `venv`).
2. **Instructions for your friend:**
   - Copy the folder to their Mac (e.g. Documents).
   - Open Terminal.
   - Run `chmod +x INSTALL_MAC.command` (only needed once if permission is denied).
   - Double-click `INSTALL_MAC.command`.
   - This will:
     - Install Python dependencies completely automatically.
     - Set up the app to start automatically when they log in.
     - Create a `Run_AmbiLight.command` script for manual starting.

## 3. General Notes
- **Settings**: Settings are stored in `config/default.json`. If you want to give them your presets, make sure that file is included (it is by default).
