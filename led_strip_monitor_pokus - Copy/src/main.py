# src/main.py

import sys
import os
import argparse
from pathlib import Path

# Fix CWD for Autostart (ensure we run from project root or script dir)
# If running as script: src/main.py -> project root is parent
if not getattr(sys, 'frozen', False):
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(project_root)
else:
    # If frozen (exe), CWD should be executable dir
    os.chdir(os.path.dirname(sys.executable))

from PyQt6.QtWidgets import QApplication
from PyQt6.QtGui import QIcon

from app import AmbiLightApplication
from startup import enable_autostart, disable_autostart, is_autostart_enabled


def main():
    """
    @brief Application Entry Point.
    @details
    Parses command line arguments and initializes the Qt Application loop.
    
    Command Line Arguments:
    - --silent: Start minimized to system tray.
    - --config: Specify configuration profile (default: default.json).
    - --enable-autostart: Register application to run on system boot.
    - --disable-autostart: Unregister application from system boot.
    
    @return None (Runs sys.exit())
    """
    parser = argparse.ArgumentParser(description="AmbiLight Application")
    parser.add_argument("--silent", action="store_true", help="Start minimized to tray")
    parser.add_argument("--config", type=str, default="default.json", help="Config profile name")
    parser.add_argument("--enable-autostart", action="store_true", help="Enable autostart")
    parser.add_argument("--disable-autostart", action="store_true", help="Disable autostart")
    
    args = parser.parse_args()
    
    # Handle autostart flags
    if args.enable_autostart:
        enable_autostart()
        return
    
    if args.disable_autostart:
        disable_autostart()
        return
    
    # Create Qt application
    qt_app = QApplication(sys.argv)
    qt_app.setApplicationName("AmbiLight")
    qt_app.setApplicationVersion("1.0.0")
    qt_app.setApplicationDisplayName("AmbiLight - LED Monitor Backlight")
    
    # Set application icon (shows in Windows taskbar)
    qt_app.setWindowIcon(QIcon("resources/icon_app.png"))
    
    # Windows-specific: Set AppUserModelID for proper taskbar grouping
    # Mac/Linux: This is not needed, skip silently
    try:
        import platform
        if platform.system() == "Windows":
            import ctypes
            myappid = 'ambilight.ledcontroller.1.0'  # Arbitrary string
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
    except:
        pass  # Not on Windows or failed
    
    qt_app.setQuitOnLastWindowClosed(False)
    
    # Create main app
    ambilight = AmbiLightApplication(
        qt_app=qt_app,
        silent_start=args.silent,
        config_profile=args.config
    )
    
    
    # Run
    print("DEBUG: Entering Qt Main Loop...")
    sys.exit(qt_app.exec())


if __name__ == "__main__":
    main()