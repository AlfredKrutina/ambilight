
import sys
import os
import platform
from pathlib import Path

def get_base_path() -> Path:
    """
    Vrátí kořenový adresář aplikace.
    - Pokud běží jako .exe (frozen), vrátí složku, kde je .exe.
    - Pokud běží jako skript, vrátí kořen projektu (nad složkou src).
    """
    if getattr(sys, 'frozen', False):
        # Běžíme jako EXE
        # sys.executable je cesta k .exe
        return Path(sys.executable).parent
    else:
        # Běžíme jako skript src/utils.py -> parent=src -> parent=project_root
        return Path(__file__).parent.parent

def get_resource_path(relative_path: str) -> Path:
    """
    Vrátí cestu k resource souboru (např. 'resources/icon.png').
    Podporuje --onedir mode i dev mode.
    """
    base = get_base_path()
    return base / relative_path


# Platform Detection Helpers
def is_windows() -> bool:
    """Check if running on Windows"""
    return platform.system() == "Windows"


def is_mac() -> bool:
    """Check if running on macOS"""
    return platform.system() == "Darwin"


def is_linux() -> bool:
    """Check if running on Linux"""
    return platform.system() == "Linux"


def get_platform() -> str:
    """Get current platform name (windows, mac, linux)"""
    system = platform.system()
    if system == "Windows":
        return "windows"
    elif system == "Darwin":
        return "mac"
    elif system == "Linux":
        return "linux"
    else:
        return "unknown"
