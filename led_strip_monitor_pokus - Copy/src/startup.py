import winreg
import os
import sys
from pathlib import Path


def get_app_path() -> str:
    """Zjisti příkaz pro spuštění aplikace"""
    if getattr(sys, 'frozen', False):
        # PyInstaller .exe
        return f'"{sys.executable}"'
    else:
        # Python script - chceme spouštět přes pythonw.exe (bez konzole)
        python_exe = sys.executable.replace("python.exe", "pythonw.exe")
        script_path = os.path.abspath(sys.argv[0])
        # Pokud pythonw neexistuje (venv), použijeme sys.executable
        if not os.path.exists(python_exe):
            python_exe = sys.executable
            
        return f'"{python_exe}" "{script_path}"'


def enable_autostart() -> bool:
    """Přidej aplikaci do Registry autostart"""
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


def disable_autostart() -> bool:
    """Odeber aplikaci z Registry autostart"""
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


def is_autostart_enabled() -> bool:
    """Zkontroluj, zda je autostart zapnutý"""
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
