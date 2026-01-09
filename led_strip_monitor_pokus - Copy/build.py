#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Univerzální build skript pro AmbiLight
Vytváří jeden distribuční soubor pro Windows, Mac a Linux
"""

import platform
import sys
import subprocess
import shutil
import os
import zipfile
import tarfile
from pathlib import Path


def get_project_root():
    """Vrátí root adresář projektu"""
    return Path(__file__).parent.absolute()


def clean_dist():
    """Vyčistí obsah dist složek (Windows, Mac, Linux) a build složku"""
    project_root = get_project_root()
    build_dir = project_root / "build"
    
    # Vyčistit obsah platformových složek, ale zachovat strukturu
    for platform_dir in ["Windows", "Mac", "Linux"]:
        platform_path = project_root / "dist" / platform_dir
        if platform_path.exists():
            print(f"🧹 Cleaning dist/{platform_dir} folder...")
            for item in platform_path.iterdir():
                if item.is_file():
                    try:
                        item.unlink()
                    except PermissionError:
                        print(f"   ⚠️  Could not delete {item.name} (file may be in use)")
                elif item.is_dir():
                    try:
                        shutil.rmtree(item)
                    except PermissionError:
                        print(f"   ⚠️  Could not delete {item.name} (directory may be in use)")
    
    if build_dir.exists():
        print("🧹 Cleaning build folder...")
        try:
            shutil.rmtree(build_dir)
        except PermissionError:
            print("   ⚠️  Could not delete build folder (some files may be in use)")


def build_windows():
    """Build Windows onefile executable"""
    project_root = get_project_root()
    src_dir = project_root / "src"
    dist_dir = project_root / "dist" / "Windows"
    dist_dir.mkdir(parents=True, exist_ok=True)
    resources_dir = project_root / "resources"
    config_dir = project_root / "config"
    
    print("=" * 50)
    print("🔨 Building AmbiLight for Windows")
    print("=" * 50)
    
    # Zkontroluj PyInstaller
    try:
        import PyInstaller
    except ImportError:
        print("❌ PyInstaller not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
        import PyInstaller
    
    # PyInstaller argumenty pro Windows onefile
    icon_path = resources_dir / "icon_app.ico"
    if not icon_path.exists():
        icon_path = resources_dir / "icon_app.png"
    
    args = [
        str(src_dir / "main.py"),
        "--onefile",                          # Jeden .exe soubor
        "--windowed",                         # Bez console okna
        "--name", "AmbiLight",
        "--icon", str(icon_path),
        "--add-data", f"{resources_dir}{os.pathsep}resources",
        "--add-data", f"{config_dir}{os.pathsep}config",
        "--hidden-import=serial",
        "--hidden-import=serial.tools.list_ports",
        "--collect-all=PyQt6",
        "--clean",
        "--distpath", str(dist_dir),
        "--workpath", str(project_root / "build"),
    ]
    
    print("📦 Running PyInstaller...")
    import PyInstaller.__main__
    PyInstaller.__main__.run(args)
    
    exe_path = dist_dir / "AmbiLight.exe"
    
    if exe_path.exists():
        size_mb = exe_path.stat().st_size / 1024 / 1024
        print(f"\n✅ Windows build complete!")
        print(f"   Executable: {exe_path}")
        print(f"   Size: {size_mb:.1f} MB")
        
        # Přejmenovat na AmbiLight_Windows.exe
        windows_exe = dist_dir / "AmbiLight_Windows.exe"
        if windows_exe.exists():
            windows_exe.unlink()
        exe_path.rename(windows_exe)
        print(f"   Saved to: {windows_exe}")
        return True
    else:
        print("\n❌ Windows build failed!")
        return False


def build_mac():
    """Build Mac .app bundle a zabalit do ZIP"""
    project_root = get_project_root()
    src_dir = project_root / "src"
    dist_dir = project_root / "dist" / "Mac"
    dist_dir.mkdir(parents=True, exist_ok=True)
    resources_dir = project_root / "resources"
    config_dir = project_root / "config"
    
    print("=" * 50)
    print("🍎 Building AmbiLight for Mac")
    print("=" * 50)
    
    # Zkontroluj PyInstaller
    try:
        import PyInstaller
    except ImportError:
        print("❌ PyInstaller not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
        import PyInstaller
    
    # PyInstaller argumenty pro Mac .app bundle
    icon_path = resources_dir / "icon_app.ico"
    if not icon_path.exists():
        icon_path = resources_dir / "icon_app.png"
    
    args = [
        str(src_dir / "main.py"),
        "--windowed",                         # Vytvoří .app bundle
        "--name", "AmbiLight",
        "--icon", str(icon_path),
        "--add-data", f"{resources_dir}{os.pathsep}resources",
        "--add-data", f"{config_dir}{os.pathsep}config",
        "--hidden-import=serial",
        "--hidden-import=serial.tools.list_ports",
        "--collect-all=PyQt6",
        "--clean",
        "--distpath", str(dist_dir),
        "--workpath", str(project_root / "build"),
    ]
    
    print("📦 Running PyInstaller...")
    import PyInstaller.__main__
    PyInstaller.__main__.run(args)
    
    app_path = dist_dir / "AmbiLight.app"
    
    if app_path.exists():
        # Zkopíruj resources a config do app bundle
        # PyInstaller už je přidá přes --add-data, ale zkontrolujme a případně doplňme
        app_macos_dir = app_path / "Contents" / "MacOS"
        if app_macos_dir.exists():
            print("📁 Verifying resources and config in app bundle...")
            # Zkontroluj, jestli PyInstaller přidal resources a config
            if not (app_macos_dir / "resources").exists():
                print("   Adding resources...")
                shutil.copytree(resources_dir, app_macos_dir / "resources")
            if not (app_macos_dir / "config").exists():
                print("   Adding config...")
                shutil.copytree(config_dir, app_macos_dir / "config")
        
        # Ad-hoc signing (opraví "Damaged" error)
        print("🔐 Signing app bundle...")
        try:
            subprocess.run(
                ["codesign", "--force", "--deep", "--sign", "-", str(app_path)],
                check=True,
                capture_output=True
            )
        except subprocess.CalledProcessError as e:
            print(f"⚠️  Warning: Code signing failed: {e}")
        
        # Zabalit do ZIP
        zip_path = dist_dir / "AmbiLight_Mac.zip"
        print(f"📦 Creating ZIP archive: {zip_path}")
        if zip_path.exists():
            zip_path.unlink()
        
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(app_path):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(dist_dir)
                    zipf.write(file_path, arcname)
        
        zip_size_mb = zip_path.stat().st_size / 1024 / 1024
        print(f"\n✅ Mac build complete!")
        print(f"   App bundle: {app_path}")
        print(f"   ZIP archive: {zip_path}")
        print(f"   ZIP size: {zip_size_mb:.1f} MB")
        print(f"   Saved to: dist/Mac/")
        return True
    else:
        print("\n❌ Mac build failed!")
        return False


def build_linux():
    """Build Linux AppImage nebo tar.gz"""
    project_root = get_project_root()
    src_dir = project_root / "src"
    dist_dir = project_root / "dist" / "Linux"
    dist_dir.mkdir(parents=True, exist_ok=True)
    resources_dir = project_root / "resources"
    config_dir = project_root / "config"
    
    print("=" * 50)
    print("🐧 Building AmbiLight for Linux")
    print("=" * 50)
    
    # Zkontroluj PyInstaller
    try:
        import PyInstaller
    except ImportError:
        print("❌ PyInstaller not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
        import PyInstaller
    
    # PyInstaller argumenty pro Linux onefile
    icon_path = resources_dir / "icon_app.ico"
    if not icon_path.exists():
        icon_path = resources_dir / "icon_app.png"
    
    args = [
        str(src_dir / "main.py"),
        "--onefile",                          # Jeden executable
        "--windowed",                         # Bez console (pokud je GUI)
        "--name", "AmbiLight",
        "--icon", str(icon_path),
        "--add-data", f"{resources_dir}{os.pathsep}resources",
        "--add-data", f"{config_dir}{os.pathsep}config",
        "--hidden-import=serial",
        "--hidden-import=serial.tools.list_ports",
        "--collect-all=PyQt6",
        "--clean",
        "--distpath", str(dist_dir),
        "--workpath", str(project_root / "build"),
    ]
    
    print("📦 Running PyInstaller...")
    import PyInstaller.__main__
    PyInstaller.__main__.run(args)
    
    linux_exe = dist_dir / "AmbiLight"
    
    if linux_exe.exists():
        # Přejmenovat na AmbiLight_Linux
        linux_exe_renamed = dist_dir / "AmbiLight_Linux"
        if linux_exe_renamed.exists():
            linux_exe_renamed.unlink()
        linux_exe.rename(linux_exe_renamed)
        
        # Vytvořit tar.gz balíček
        tar_path = dist_dir / "AmbiLight_Linux.tar.gz"
        print(f"📦 Creating tar.gz archive: {tar_path}")
        if tar_path.exists():
            tar_path.unlink()
        
        with tarfile.open(tar_path, "w:gz") as tar:
            tar.add(linux_exe_renamed, arcname="AmbiLight")
            # Přidat resources a config jako samostatné soubory/složky
            tar.add(resources_dir, arcname="resources")
            tar.add(config_dir, arcname="config")
        
        tar_size_mb = tar_path.stat().st_size / 1024 / 1024
        exe_size_mb = linux_exe_renamed.stat().st_size / 1024 / 1024
        
        print(f"\n✅ Linux build complete!")
        print(f"   Executable: {linux_exe_renamed}")
        print(f"   Executable size: {exe_size_mb:.1f} MB")
        print(f"   tar.gz archive: {tar_path}")
        print(f"   tar.gz size: {tar_size_mb:.1f} MB")
        print(f"   Saved to: dist/Linux/")
        print(f"\n💡 Note: Extract tar.gz and run ./AmbiLight")
        return True
    else:
        print("\n❌ Linux build failed!")
        return False


def main():
    """Hlavní funkce - detekuje platformu a spustí příslušný build"""
    system = platform.system()
    
    print("=" * 50)
    print("🚀 AmbiLight Universal Build Script")
    print("=" * 50)
    print(f"Platform: {system}")
    print()
    
    # Vyčistit před buildem
    clean_dist()
    
    # Build podle platformy
    success = False
    if system == "Windows":
        success = build_windows()
    elif system == "Darwin":
        success = build_mac()
    elif system == "Linux":
        success = build_linux()
    else:
        print(f"❌ Unsupported platform: {system}")
        print("Supported platforms: Windows, macOS (Darwin), Linux")
        return 1
    
    if success:
        print("\n" + "=" * 50)
        print("✅ Build completed successfully!")
        print("=" * 50)
        print(f"Output directory: {get_project_root() / 'dist'}")
        return 0
    else:
        print("\n" + "=" * 50)
        print("❌ Build failed!")
        print("=" * 50)
        return 1


if __name__ == "__main__":
    sys.exit(main())
