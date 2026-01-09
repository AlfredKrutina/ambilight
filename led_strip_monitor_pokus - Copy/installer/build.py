# installer/build.py

import PyInstaller.__main__
import os
import shutil
from pathlib import Path


def build_exe():
    """Build standalone .exe s PyInstaller"""
    
    project_root = Path(__file__).parent.parent
    src_dir = project_root / "src"
    dist_dir = project_root / "dist"
    
    print("🔨 Building AmbiLight.exe...")
    print(f"Project root: {project_root}")
    
    # Vyčisti dist
    if dist_dir.exists():
        shutil.rmtree(dist_dir)
    
    # PyInstaller argumenty
    args = [
        str(src_dir / "main.py"),
        "--onefile",                          # Jeden .exe
        "--windowed",                         # Bez console okna
        "--name", "AmbiLight",
        "--icon", str(project_root / "resources" / "icon_app.png"),
        "--add-data", f"{src_dir}{os.pathsep}src",
        "--add-data", f"{project_root / 'resources'}{os.pathsep}resources",
        "--add-data", f"{project_root / 'config'}{os.pathsep}config",
        "--hidden-import=serial",
        "--hidden-import=serial.tools.list_ports",
        "--collect-all=PyQt6",
        "--clean",
        "--distpath", str(dist_dir),
        "--specpath", str(project_root / "build"),
        "--buildpath", str(project_root / "build"),
    ]
    
    # Run PyInstaller
    PyInstaller.__main__.run(args)
    
    exe_path = dist_dir / "AmbiLight.exe"
    
    if exe_path.exists():
        print(f"\n✓ Build complete!")
        print(f"  Executable: {exe_path}")
        print(f"  Size: {exe_path.stat().st_size / 1024 / 1024:.1f} MB")
    else:
        print("\n✗ Build failed!")
        return False
    
    return True


if __name__ == "__main__":
    import sys
    success = build_exe()
    sys.exit(0 if success else 1)