# AmbiLight - Distribution Guide

## 📦 Distribuční soubory

Každá platforma má svůj vlastní distribuční soubor:

- **Windows**: `AmbiLight_Windows.exe` - Standalone executable (onefile)
- **macOS**: `AmbiLight_Mac.zip` - App bundle zabalený v ZIP
- **Linux**: `AmbiLight_Linux.tar.gz` - Executable s resources a config

## 🪟 Windows

### Požadavky
- Windows 10 nebo novější
- Microsoft Visual C++ 2015-2022 Redistributable (x64) - [Stáhnout zde](https://aka.ms/vs/17/release/vc_redist.x64.exe)

### Instalace a spuštění

1. **Stáhněte** `AmbiLight_Windows.exe`
2. **Spusťte** soubor dvojklikem
   - První spuštění může trvat déle (extrakce do temp složky)
   - Aplikace se spustí v system tray (ikona vpravo dole)
3. **Nastavení**: Klikněte pravým tlačítkem na tray ikonu → Settings

### Autostart (volitelné)

Pro automatické spuštění při startu Windows:
1. Klikněte pravým tlačítkem na `AmbiLight_Windows.exe`
2. Vytvořte zástupce (Create shortcut)
3. Zkopírujte zástupce do složky Startup:
   - Stiskněte `Win + R`
   - Zadejte: `shell:startup`
   - Vložte zástupce do této složky

### Troubleshooting

**Aplikace se nespustí:**
- Nainstalujte Visual C++ Redistributable (viz Požadavky)
- Zkontrolujte antivirus (může blokovat .exe soubory)
- Spusťte jako správce (pravý klik → Run as administrator)

**LEDky nesvítí:**
- Zkontrolujte COM port v Settings
- Ověřte připojení ESP32-C3
- Zkontrolujte baud rate (115200)

## 🍎 macOS

### Požadavky
- macOS 10.14 (Mojave) nebo novější
- Intel nebo Apple Silicon (M1/M2/M3)

### Instalace a spuštění

1. **Stáhněte** `AmbiLight_Mac.zip`
2. **Rozbalte** ZIP soubor
3. **Otevřete** `AmbiLight.app`
   - Pokud se zobrazí varování "App is damaged", spusťte v terminálu:
     ```bash
     xattr -cr /path/to/AmbiLight.app
     ```
4. **První spuštění**: Možná budete muset povolit v System Preferences → Security & Privacy

### Autostart (volitelné)

1. Otevřete System Preferences → Users & Groups
2. Přejděte na tab Login Items
3. Přidejte `AmbiLight.app` pomocí tlačítka `+`

### Troubleshooting

**"App is damaged" chyba:**
```bash
xattr -cr /path/to/AmbiLight.app
```

**App se nespustí:**
- Zkontrolujte System Preferences → Security & Privacy
- Povolte spuštění z "Unidentified Developer" (pokud je potřeba)

## 🐧 Linux

### Požadavky
- Linux distribuce s podporou X11 nebo Wayland
- GTK+ nebo Qt5/Qt6 runtime (obvykle už nainstalováno)

### Instalace a spuštění

1. **Stáhněte** `AmbiLight_Linux.tar.gz`
2. **Rozbalte** archiv:
   ```bash
   tar -xzf AmbiLight_Linux.tar.gz
   ```
3. **Udělte oprávnění k spuštění**:
   ```bash
   chmod +x AmbiLight
   ```
4. **Spusťte** aplikaci:
   ```bash
   ./AmbiLight
   ```

### Autostart (volitelné)

Pro GNOME:
1. Otevřete Settings → Applications → Startup
2. Přidejte novou aplikaci
3. Zadejte název a cestu k `AmbiLight`

Pro KDE:
1. Otevřete System Settings → Startup and Shutdown → Autostart
2. Přidejte novou aplikaci s cestou k `AmbiLight`

### Troubleshooting

**"Permission denied" chyba:**
```bash
chmod +x AmbiLight
```

**Chybí závislosti:**
- Nainstalujte Qt6 runtime (distribuce-specifické):
  - Ubuntu/Debian: `sudo apt install qt6-base-dev`
  - Fedora: `sudo dnf install qt6-qtbase`
  - Arch: `sudo pacman -S qt6-base`

## ⚙️ Konfigurace

### Serial Port

Aplikace automaticky detekuje dostupné COM porty (Windows) nebo /dev/tty* zařízení (Mac/Linux).

**Nastavení:**
1. Otevřete Settings (pravý klik na tray ikonu)
2. Vyberte správný Serial Port
3. Uložte nastavení

### Profily

Aplikace obsahuje přednastavené profily:
- **Gaming**: Vysoká citlivost, rychlé přechody
- **Movie**: Plynulé přechody, nižší citlivost
- **Work**: Střední nastavení

### Pokročilé nastavení

Všechna nastavení jsou uložena v `config/` složce jako JSON soubory:
- `default.json` - Výchozí profil
- `gaming.json` - Gaming profil
- `movie.json` - Movie profil

## 📝 Poznámky

- **První spuštění** může trvat déle kvůli inicializaci
- **System tray ikona** se zobrazí vpravo dole (Windows) nebo v menu baru (Mac)
- **Konfigurace** se ukládá automaticky při změně nastavení
- **Resources a config** jsou součástí distribučního balíčku

## 🆘 Podpora

Pro problémy nebo dotazy:
1. Zkontrolujte tento README
2. Ověřte připojení ESP32-C3
3. Zkontrolujte COM port v Settings
4. Zkontrolujte logy aplikace (pokud jsou dostupné)

## 📄 Licence

MIT License - viz LICENSE soubor v projektu
