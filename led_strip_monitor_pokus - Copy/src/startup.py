import os
import sys
import platform
from pathlib import Path

# Windows-specific imports
if platform.system() == "Windows":
    import winreg
# Mac-specific imports
elif platform.system() == "Darwin":
    import plistlib
    import subprocess


def get_app_path() -> str:
    """Zjisti příkaz pro spuštění aplikace"""
    if getattr(sys, 'frozen', False):
        # PyInstaller .exe nebo .app bundle
        if platform.system() == "Darwin":
            # Na Mac je to .app bundle, použijeme open nebo přímou cestu
            return f'"{sys.executable}"'
        else:
            return f'"{sys.executable}"'
    else:
        # Python script
        if platform.system() == "Windows":
            # Windows - chceme spouštět přes pythonw.exe (bez konzole)
            python_exe = sys.executable.replace("python.exe", "pythonw.exe")
            script_path = os.path.abspath(sys.argv[0])
            # Pokud pythonw neexistuje (venv), použijeme sys.executable
            if not os.path.exists(python_exe):
                python_exe = sys.executable
            return f'"{python_exe}" "{script_path}"'
        else:
            # Mac/Linux - použijeme python3
            script_path = os.path.abspath(sys.argv[0])
            return f'"{sys.executable}" "{script_path}"'


def enable_autostart() -> bool:
    """Přidej aplikaci do autostart (Windows Registry nebo Mac LaunchAgents)"""
    system = platform.system()
    
    if system == "Windows":
        return _enable_autostart_windows()
    elif system == "Darwin":
        return _enable_autostart_mac()
    else:
        print(f"✗ Autostart not supported on {system}")
        return False


def _enable_autostart_windows() -> bool:
    """Přidej aplikaci do Windows Registry autostart"""
    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            0,
            winreg.KEY_SET_VALUE
        )
        
        app_path = get_app_path()
        winreg.SetValueEx(
            key,
            "AmbiLight",
            0,
            winreg.REG_SZ,
            f'{app_path} --silent'
        )
        winreg.CloseKey(key)
        print("✓ Autostart enabled")
        return True
    except Exception as e:
        print(f"✗ Failed to enable autostart: {e}")
        return False


def _enable_autostart_mac() -> bool:
    """Přidej aplikaci do Mac LaunchAgents"""
    try:
        home = Path.home()
        launch_agents_dir = home / "Library" / "LaunchAgents"
        launch_agents_dir.mkdir(parents=True, exist_ok=True)
        
        plist_path = launch_agents_dir / "com.ambilight.plist"
        
        app_path = get_app_path()
        # Pokud je frozen, použijeme sys.executable, jinak python3 script
        if getattr(sys, 'frozen', False):
            # .app bundle
            program_path = sys.executable
            program_args = ["--silent"]
        else:
            # Python script
            program_path = sys.executable
            script_path = os.path.abspath(sys.argv[0])
            program_args = [script_path, "--silent"]
        
        plist_content = {
            "Label": "com.ambilight",
            "ProgramArguments": [program_path] + program_args,
            "RunAtLoad": True,
            "KeepAlive": False,
        }
        
        with open(plist_path, 'wb') as f:
            plistlib.dump(plist_content, f)
        
        # Načíst LaunchAgent
        subprocess.run(["launchctl", "load", str(plist_path)], check=False)
        
        print("✓ Autostart enabled")
        return True
    except Exception as e:
        print(f"✗ Failed to enable autostart: {e}")
        return False


def disable_autostart() -> bool:
    """Odeber aplikaci z autostart"""
    system = platform.system()
    
    if system == "Windows":
        return _disable_autostart_windows()
    elif system == "Darwin":
        return _disable_autostart_mac()
    else:
        print(f"✗ Autostart not supported on {system}")
        return False


def _disable_autostart_windows() -> bool:
    """Odeber aplikaci z Windows Registry autostart"""
    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            0,
            winreg.KEY_SET_VALUE
        )
        
        winreg.DeleteValue(key, "AmbiLight")
        winreg.CloseKey(key)
        print("✓ Autostart disabled")
        return True
    except FileNotFoundError:
        # Klíč neexistuje, není problém
        print("✓ Autostart already disabled")
        return True
    except Exception as e:
        print(f"✗ Failed to disable autostart: {e}")
        return False


def _disable_autostart_mac() -> bool:
    """Odeber aplikaci z Mac LaunchAgents"""
    try:
        home = Path.home()
        plist_path = home / "Library" / "LaunchAgents" / "com.ambilight.plist"
        
        if plist_path.exists():
            # Odpojit LaunchAgent
            subprocess.run(["launchctl", "unload", str(plist_path)], check=False)
            # Smazat plist soubor
            plist_path.unlink()
            print("✓ Autostart disabled")
        else:
            print("✓ Autostart already disabled")
        return True
    except Exception as e:
        print(f"✗ Failed to disable autostart: {e}")
        return False


def is_autostart_enabled() -> bool:
    """Zkontroluj, zda je autostart zapnutý"""
    system = platform.system()
    
    if system == "Windows":
        return _is_autostart_enabled_windows()
    elif system == "Darwin":
        return _is_autostart_enabled_mac()
    else:
        return False


def _is_autostart_enabled_windows() -> bool:
    """Zkontroluj, zda je autostart zapnutý na Windows"""
    try:
        key = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Run",
            0,
            winreg.KEY_READ
        )
        
        try:
            winreg.QueryValueEx(key, "AmbiLight")
            winreg.CloseKey(key)
            return True
        except FileNotFoundError:
            winreg.CloseKey(key)
            return False
    except Exception as e:
        print(f"✗ Failed to check autostart: {e}")
        return False


def _is_autostart_enabled_mac() -> bool:
    """Zkontroluj, zda je autostart zapnutý na Mac"""
    try:
        home = Path.home()
        plist_path = home / "Library" / "LaunchAgents" / "com.ambilight.plist"
        return plist_path.exists()
    except Exception:
        return False
