#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Skript pro vytvoření release balíčku pro sdílení
Vytvoří ZIP soubory s distribučními soubory (bez src kódu)
"""

import platform
import sys
import shutil
import zipfile
from pathlib import Path


def get_project_root():
    """Vrátí root adresář projektu"""
    return Path(__file__).parent.absolute()


def create_windows_release():
    """Vytvoří release balíček pro Windows"""
    project_root = get_project_root()
    dist_windows = project_root / "dist" / "Windows"
    release_dir = project_root / "release"
    release_dir.mkdir(exist_ok=True)
    
    exe_file = dist_windows / "AmbiLight_Windows.exe"
    
    if not exe_file.exists():
        print("❌ Windows executable not found!")
        print(f"   Expected: {exe_file}")
        print("   Please run: python build.py")
        return False
    
    # Vytvořit ZIP s exe a README
    zip_path = release_dir / "AmbiLight_Windows_Release.zip"
    print(f"📦 Creating Windows release package: {zip_path.name}")
    
    if zip_path.exists():
        zip_path.unlink()
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Přidat exe
        zipf.write(exe_file, arcname="AmbiLight_Windows.exe")
        
        # Přidat README z dist/Windows
        readme_file = dist_windows / "README.txt"
        if readme_file.exists():
            zipf.write(readme_file, arcname="README.txt")
        
        # Přidat hlavní DISTRIBUTION_README.md
        main_readme = project_root / "DISTRIBUTION_README.md"
        if main_readme.exists():
            zipf.write(main_readme, arcname="DISTRIBUTION_README.md")
    
    zip_size_mb = zip_path.stat().st_size / 1024 / 1024
    print(f"✅ Windows release created: {zip_path.name} ({zip_size_mb:.1f} MB)")
    return True


def create_mac_release():
    """Vytvoří release balíček pro macOS"""
    project_root = get_project_root()
    dist_mac = project_root / "dist" / "Mac"
    release_dir = project_root / "release"
    release_dir.mkdir(exist_ok=True)
    
    zip_file = dist_mac / "AmbiLight_Mac.zip"
    
    if not zip_file.exists():
        print("❌ Mac ZIP archive not found!")
        print(f"   Expected: {zip_file}")
        print("   Please run: python build.py (on macOS)")
        return False
    
    # Zkopírovat ZIP do release
    release_zip = release_dir / "AmbiLight_Mac_Release.zip"
    print(f"📦 Creating Mac release package: {release_zip.name}")
    
    if release_zip.exists():
        release_zip.unlink()
    
    # Zkopírovat existující ZIP
    shutil.copy2(zip_file, release_zip)
    
    # Přidat README do ZIP
    readme_file = dist_mac / "README.txt"
    main_readme = project_root / "DISTRIBUTION_README.md"
    
    # Otevřít ZIP a přidat README soubory
    with zipfile.ZipFile(release_zip, 'a', zipfile.ZIP_DEFLATED) as zipf:
        if readme_file.exists():
            zipf.write(readme_file, arcname="README.txt")
        if main_readme.exists():
            zipf.write(main_readme, arcname="DISTRIBUTION_README.md")
    
    zip_size_mb = release_zip.stat().st_size / 1024 / 1024
    print(f"✅ Mac release created: {release_zip.name} ({zip_size_mb:.1f} MB)")
    return True


def create_linux_release():
    """Vytvoří release balíček pro Linux"""
    project_root = get_project_root()
    dist_linux = project_root / "dist" / "Linux"
    release_dir = project_root / "release"
    release_dir.mkdir(exist_ok=True)
    
    tar_file = dist_linux / "AmbiLight_Linux.tar.gz"
    
    if not tar_file.exists():
        print("❌ Linux tar.gz archive not found!")
        print(f"   Expected: {tar_file}")
        print("   Please run: python build.py (on Linux)")
        return False
    
    # Zkopírovat tar.gz do release
    release_tar = release_dir / "AmbiLight_Linux_Release.tar.gz"
    print(f"📦 Creating Linux release package: {release_tar.name}")
    
    if release_tar.exists():
        release_tar.unlink()
    
    shutil.copy2(tar_file, release_tar)
    
    # Přidat README soubory do tar.gz
    import tarfile
    readme_file = dist_linux / "README.txt"
    main_readme = project_root / "DISTRIBUTION_README.md"
    
    # Otevřít tar.gz a přidat README
    with tarfile.open(release_tar, 'r:gz') as tar:
        members = tar.getmembers()
        temp_tar = release_dir / "temp_AmbiLight_Linux.tar.gz"
        
    with tarfile.open(temp_tar, 'w:gz') as new_tar:
        # Zkopírovat všechny existující soubory
        with tarfile.open(release_tar, 'r:gz') as old_tar:
            for member in old_tar.getmembers():
                new_tar.addfile(member, old_tar.extractfile(member))
        
        # Přidat README soubory
        if readme_file.exists():
            new_tar.add(readme_file, arcname="README.txt")
        if main_readme.exists():
            new_tar.add(main_readme, arcname="DISTRIBUTION_README.md")
    
    # Přepsat původní tar.gz
    temp_tar.replace(release_tar)
    
    tar_size_mb = release_tar.stat().st_size / 1024 / 1024
    print(f"✅ Linux release created: {release_tar.name} ({tar_size_mb:.1f} MB)")
    return True


def create_all_releases():
    """Vytvoří release balíčky pro všechny dostupné platformy"""
    project_root = get_project_root()
    release_dir = project_root / "release"
    release_dir.mkdir(exist_ok=True)
    
    print("=" * 60)
    print("🚀 Creating Release Packages for Distribution")
    print("=" * 60)
    print()
    
    results = []
    
    # Windows
    print("📦 Windows Release:")
    results.append(("Windows", create_windows_release()))
    print()
    
    # Mac (pokud existuje)
    dist_mac = project_root / "dist" / "Mac" / "AmbiLight_Mac.zip"
    if dist_mac.exists():
        print("📦 macOS Release:")
        results.append(("macOS", create_mac_release()))
        print()
    else:
        print("⏭️  macOS Release: Skipped (not built)")
        print()
    
    # Linux (pokud existuje)
    dist_linux = project_root / "dist" / "Linux" / "AmbiLight_Linux.tar.gz"
    if dist_linux.exists():
        print("📦 Linux Release:")
        results.append(("Linux", create_linux_release()))
        print()
    else:
        print("⏭️  Linux Release: Skipped (not built)")
        print()
    
    # Shrnutí
    print("=" * 60)
    print("📊 Summary:")
    print("=" * 60)
    for platform_name, success in results:
        status = "✅ Created" if success else "❌ Failed"
        print(f"  {platform_name}: {status}")
    
    print()
    print(f"📁 Release packages location: {release_dir}")
    print()
    print("💡 These packages are ready to share - they contain")
    print("   only the executable files and documentation,")
    print("   NO source code is included.")
    print()


def main():
    """Hlavní funkce"""
    system = platform.system()
    
    # Pokud je zadán argument, vytvořit jen pro danou platformu
    if len(sys.argv) > 1:
        platform_arg = sys.argv[1].lower()
        if platform_arg == "windows" or platform_arg == "win":
            create_windows_release()
        elif platform_arg == "mac" or platform_arg == "macos" or platform_arg == "darwin":
            create_mac_release()
        elif platform_arg == "linux":
            create_linux_release()
        else:
            print(f"Unknown platform: {platform_arg}")
            print("Usage: python create_release.py [windows|mac|linux]")
            return 1
    else:
        # Vytvořit všechny dostupné
        create_all_releases()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
