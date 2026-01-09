AmbiLight Windows Application
Ambilight systém pro Windows 11 – automatické RGB osvětlení za monitorem s Adafruit LED páskou a ESP32-C3.

Features
✅ Real-time screen capture + color analysis
✅ Smooth LED transitions (adjustable smoothing 0-500ms)
✅ Multiple profiles: Gaming, Movie, Work, Off
✅ Adjustable sensitivity, brightness, color modes
✅ System tray integration + autostart
✅ Serial communication with ESP32-C3 @ 115200 baud
✅ Fail-safe LED shutdown
✅ Config persistence (JSON)

Instalace
1. Prerequisites
Python 3.9+ (https://www.python.org/)

Windows 11 (vlastně funguje i na Windows 10)

USB kabel k ESP32-C3

2. Setup
bash
# Clone/create project
git clone <repo> ambilight_windows
cd ambilight_windows

# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate

# Install dependencies
pip install -r requirements.txt
3. Spuštění
bash
# Dev mode (s GUI oknem)
python src/main.py

# Silent mode (jen tray icon – jak se chová na startup)
python src/main.py --silent

# Specific profile
python src/main.py --config gaming
Build & Deployment
1. Build distribuční soubor (univerzální skript)
bash
# Univerzální build skript pro všechny platformy
python build.py

# Výstup podle platformy:
# - Windows: dist/Windows/AmbiLight_Windows.exe (onefile)
# - macOS: dist/Mac/AmbiLight_Mac.zip (.app bundle)
# - Linux: dist/Linux/AmbiLight_Linux.tar.gz (executable + resources)

2. Vytvoření release balíčků pro sdílení (bez src kódu)
bash
# Vytvoří ZIP/TAR balíčky připravené k sdílení
python create_release.py

# Výstup: release/ složka s balíčky:
# - AmbiLight_Windows_Release.zip (jen exe + README)
# - AmbiLight_Mac_Release.zip (app bundle + README)
# - AmbiLight_Linux_Release.tar.gz (executable + README)

# Tyto balíčky obsahují POUZE distribuční soubory,
# žádný Python source kód!
2. Enable Autostart
bash
# Program flag
python src/main.py --enable-autostart

# Or v UI: Settings → "Start with Windows"
3. Disable Autostart
bash
python src/main.py --disable-autostart
Nastavení
Configuration Files
Všechny config jsou v config/ adresáři jako JSON:

text
config/
├── default.json     # Default profil
├── gaming.json      # Gaming preset
└── movie.json       # Movie preset
Příklad config/default.json:

json
{
  "enabled": true,
  "brightness": 80,
  "sensitivity": 80,
  "color_mode": "normal",
  "profile": "gaming",
  "smooth_ms": 100,
  "autostart": false,
  "serial_port": "COM3"
}
Settings UI
Otevři Settings → všechny parametry:

Brightness (0-100%) – intenzita LED

Sensitivity (0-100%) – sytost barev

Smoothing (0-500 ms) – čas interpolace

Color Mode – Normal, Inverted, Saturated

Profile – Gaming, Movie, Work, Off

Serial Port – COM1, COM2, COM3, ...

Start with Windows – autostart checkbox

Serial Configuration
Zjistit COM port
bash
# List all COM ports
python -m serial.tools.list_ports
Výstup:

text
COM3 - Silicon Labs CP210x USB to UART Bridge
COM4 - USB Serial Device (CH340)
Nastavit v aplikaci
Settings → Serial Port → Vyber COM3

Nebo manuálně v config/default.json:

json
"serial_port": "COM3"
Troubleshooting
Problém	Řešení
"No module named PyQt6"	pip install PyQt6
App se nezobrazuje na startup	Zkontroluj Registry: HKCU\Software\Microsoft\Windows\CurrentVersion\Run\AmbiLight
Serial port nenalezený	Device Manager → COM & LPT Ports → zkontroluj ESP32
LEDky nesvítí	Kontrola baud rate (115200), GPIO pin (GPIO6), WS2812B zapojení
Vysoká CPU zátěž	Sníž capture FPS (soubor capture.py: capture_fps: int = 15)
Memory leak	Update PyQt6: pip install --upgrade PyQt6
Development
Project Structure
text
src/
├── main.py                # Entry point
├── app.py                 # Main application orchestration
├── state.py               # Global app state
├── config.py              # Settings management
├── startup.py             # Registry autostart
├── capture.py             # Screen capture + analysis
├── serial_handler.py      # UART communication
└── ui/
    ├── main_window.py     # Main UI window + tray
    └── settings_dialog.py # Settings dialog

resources/
├── icon_app.png           # 32x32 app icon
├── icon_tray.png          # 16x16 tray icon
└── icon_disabled.png      # 16x16 disabled icon
Adding Features
New setting? → Přidej do AppSettings (config.py)

New color mode? → Přidej do capture.py (_analyze_segment)

New profile? → Přidej do Config.PROFILES (config.py)

Serial changes? → Uprav SerialHandler (serial_handler.py)

Performance
Typické latence:

text
Screen capture:    ~33 ms (30 FPS)
Color analysis:    ~5 ms
Serial TX:         ~1 ms @ 115200 baud
LED smoothing:     ~100 ms (configurable)
─────────────────────────
Total latency:     ~70-130 ms  ✓ Acceptable
Optimace:

Capture FPS: capture.py line 35

Smooth time: Settings UI

Serial baud: serial_handler.py line 20

Verze & Changelog
v1.0.0 (2025-01-XX)

Initial release

20 LED segments (top, bottom, left, right)

Gaming, Movie, Work profiles

System tray + autostart

License
MIT

Support
Problémy? Issues?

Zkontroluj troubleshooting tabulku

Spusť s debug logem: python src/main.py (non-silent)

Zkontroluj Device Manager → COM porty

Made with ❤️ for RGB enthusiasts