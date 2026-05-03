# AmbiLight — analýza současné aplikace, FW rozhraní a plán Flutter desktopu

**Master backlog (všechny funkce + checklist):** [AmbiLight-MASTER-PLAN.md](./AmbiLight-MASTER-PLAN.md)  
**Responzivita, form faktory, mobil až nakonec:** v MASTER sekce G a H; prompty agentů P13/P14 v [AGENT_PROMPTS_AMBILIGHT_FLUTTER.md](./AGENT_PROMPTS_AMBILIGHT_FLUTTER.md).

Tento soubor konsoliduje analýzu a migrační plán (místo rozptýlených `.md` v kořeni).

---

## 1. Co je kde v repu

| Oblast | Cesta (referenční kopie) | Poznámka |
|--------|--------------------------|----------|
| Desktopová aplikace | `led_strip_monitor_pokus - Copy/src/` | Python 3, PyQt6 |
| Firmware ESP32-C3 | `led_strip_monitor_pokus - Copy/esp32c3_firmware/main/ambilight.c` | USB-serial JTAG + Wi‑Fi/UDP + MQTT/HomeKit logika |

Stará aplikace není „tenký klient“: obsahuje zachytávání obrazovky, audio pipeline, Spotify, systémové metriky, více zařízení, průvodce kalibrací atd.

---

## 2. Jak současná aplikace funguje (vrstvy)

### Orchestrace

- `main.py` / `startup.py` → `AmbiLightApplication` v `app.py`.
- `QTimer` ~30 Hz spojuje režimy (světlo / obrazovka / hudba) a posílá barvy do `DeviceManager`.
- Stav a konfigurace: `AppState`, `AppConfig` (JSON profily), `settings_manager.py`.

### Výstup na hardware (to musí zůstat kompatibilní s FW)

**Serial (USB CDC na ESP32-C3)** — `serial_handler.py`:

- Handshake: PC pošle `0xAA`, zařízení odpoví `0xBB`.
- Rámec: `0xFF` + opakování `(index, R, G, B)` pro **200** pozic (logický max v PC vrstvě), pak `0xFE`.
- Hodnoty R/G/B jsou v PC ořezané na **0–253** (aby nekolidovaly s `0xFF` / `0xFE` v datech — ve FW je v DATA stavu `0xFF` legální jako bajt v tuple).
- Brightness: na sériové lince se škáluje na straně PC (`brightness` z configu jako %).

**Firmware sériový parser** (`task_serial` v `ambilight.c`):

- `0xFF` → začátek rámce, buffer LED vynulován.
- `0xAA` → okamžitě echo `0xBB` (ping/pong).
- Pak stream 4B tuple `(idx, r, g, b)`; indexy mimo `LED_STRIP_NUM_LEDS` se ignorují.
- Konec rámce: **ne** podle `0xFE`, ale podle **ticha na UART** (read timeout ~10 ms) → `update_leds`.

Poznámka: Python posílá i `0xFE`; FW ho výslovně neřeší — rámec se stejně uzavře timeoutem. Při portaci do Dartu je rozumné **napodobit stejné bajty** jako Python (včetně `0xFE`), aby chování bylo 1:1.

**UDP (Wi‑Fi)** — `device_manager.py` / `NetworkHandler`:

- Hromadný snímek: `[0x02, brightness, R, G, B, ...]` (plochý RGB, 0–255).
- Jeden pixel (kalibrace / wizard): `[0x03, idx_hi, idx_lo, R, G, B]`.
- Textové příkazy na FW: mimo jiné `DISCOVER_ESP32`, `IDENTIFY`, `RESET_WIFI` (řetězce v UDP payload — viz `ambilight.c`).

**Objevování zařízení**: broadcast UDP + odpověď `ESP32_PONG|...` (viz FW).

### Vstupy a zpracování (desktop-specifické, náročné na multiplatform)

| Funkce | Knihovny / přístup | Flutter realita |
|--------|--------------------|-----------------|
| Snímek obrazovky | `mss`, případně `dxcam` (Windows GPU) | **Nativní** nebo FFI: žádný oficiálně „dokonalý“ cross-platform balíček; typicky **platform channel** + OS API ( DXGI/WGC, macOS ScreenCaptureKit, Linux PipeWire/X11). |
| Zpracování obrazu | OpenCV, NumPy | `dart:typed_data`, případně FFI na libyuv/OpenCV; nebo výpočty v nativním kódu. |
| Audio / spektrum | `sounddevice`, `pyaudiowpatch`, vlastní analyzátory | `record` + FFT v Dartu nebo nativně; výběr vstupního zařízení je per-OS. |
| Globální hotkeys | `keyboard` | Balíčky + často omezení na macOS (oprávnění Accessibility). |
| Tray, více monitorů | PyQt6 | `tray_manager`, `window_manager`, multi-display pluginy. |
| Spotify / OAuth | HTTP + tokeny v configu | Stejné REST API, `url_launcher`, secure storage. |
| CPU/GPU/RAM | `psutil`, vlastní moduly | Částečně Dart `system_info`; GPU často **nativní** snippet. |

---

## 3. Možnosti současné aplikace (co už umí)

- Režimy: **světlo** (statika, efekty), **obrazovka** (okrajové zóny, předvolby Movie/Gaming/Desktop), **hudba** (více vizualizací).
- Více **zařízení** (serial + Wi‑Fi), Home Assistant přepínač „nekontrolovat z PC“.
- Kalibrace barev / zón, metriky PC zdraví, Spotify barvy alba, discovery dialog.
- Témata, hotkeys, profily JSON.

---

## 4. Cíl: masivní update aplikace, **FW beze změny**

### Princip rozhraní

Zachovat **bajtové protokoly** a textové UDP příkazy popsané výše. Veškerá „inteligence“ může být přepsaná, ale **generované pakety** musí být binárně ekvivalentní (nebo FW-dokumentovaně kompatibilní).

### Proč Flutter desktop

- Jeden UI kód pro **Windows, macOS, Linux**.
- Dobrý layout, animace, stavová správa (`riverpod` / `bloc`).
- Slabina: **screen capture a nízkoúrovňová zařízení** = nutnost **tenké nativní vrstvy** nebo ověřených pluginů per platforma.

### Alternativy (stručně)

- **Tauri 2 + Rust**: výkon a systémové API výborné, UI ve WebView (jiný skillset než Flutter).
- **.NET MAUI**: silné na Windows, Linux/mac často horší provoz.
- **Electron + Rust modul**: podobně jako Tauri, těžší runtime.

Pro tvůj požadavek „něco jako Flutter“ je **Flutter rozumná volba**, pokud akceptuješ **fázi 1 = serial/UDP + nastavení + náhled**, a **fázi 2 = capture/audio** s nativními doplňky.

---

## 5. Doporučená architektura nové aplikace

```
lib/
  app.dart                 # MaterialApp, téma, routing
  core/
    protocol/
      serial_frame.dart    # sestavení 0xFF rámce + handshake bajtů
      udp_commands.dart    # 0x02, 0x03, text discover
    models/                # Device, Profile, Mode (freezed/json_serializable)
  data/
    device_repository.dart # abstrakce: Serial + UDP
  features/
    devices/               # seznam zařízení, test spojení
    capture/               # později: platform interface
    settings/
  platform/
    screen_capture/        # method channel kontrakty (prázdné implementace → postupně doplnit)
```

- **Transport vrstva v Dartu** čistě: handshake, fronta snímků (stejně jako `queue.Queue(maxsize=2)` pro nízkou latenci).
- **Screen capture**: definovat `ScreenCaptureProvider` interface; Windows první (největší uživatelská báze pro hry), pak Linux, pak macOS (oprávnění).

### Staging vs produkce (tvůj standard)

- `assert` + `kDebugMode` logování v transportu a v capture pipeline.
- V release build bez spamu do konzole; strukturované logy (např. `logger`).

---

## 6. Fáze implementace (realistický roadmap)

| Fáze | Obsah | Výstup |
|------|--------|--------|
| **0** | `flutter create` s `--platforms=windows,linux,macos`, struktura složek, CI lint | Běžící prázdná app |
| **1** | Serial (`flutter_libserialport` nebo vlastní FFI), UDP sender, handshake, test jedné barvy | Ověření na reálném ESP bez změny FW |
| **2** | JSON config (mapování z existujících polí), multi-device UI, discovery | Funkční náhrada „ovládání“ |
| **3** | Screen capture per OS + downsampling + mapování segmentů (přenos logiky z `geometry.py` / `capture.py`) | Parita screen módu |
| **4** | Audio capture + FFT + music módy | Parita hudby |
| **5** | Tray, hotkeys, autostart, Spotify OAuth | Parita „desktop integrace“ |

---

## 7. První kroky po naklonování nové složky

1. Nainstalovat [Flutter](https://docs.flutter.dev/get-started/install) a zapnout desktop: `flutter config --enable-windows-desktop` atd.
2. V nové složce projektu spustit doplnění platforem, pokud chybí:  
   `flutter create --platforms=windows,linux,macos .`
3. Ověřit build na každé cílové OS v CI nebo ručně.

---

## 8. Rizika (kritické myšlení)

- **Parita výkonu**: Python + NumPy + OpenCV je těžko překonat čistým Dartem bez nativních knihoven; očekávej buď více CPU, nebo Rust/C++ modul.
- **Linux fragmentace**: Wayland vs X11 ovlivní screen capture.
- **Podpis a notarizace** (macOS) pro distribuci mimo App Store.

---

*Poslední aktualizace: 2026-05-03*
