# ambilight_desktop

Flutter desktop klient pro AmbiLight (kompatibilní s existujícím JSON / firmware).

## Komunikace s ESP (USB sériové / Wi‑Fi UDP)

- **Protokol** — zdroj pravdy: `led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c` (**lampa**, až ~2000 LED): sériově `0xAA`/`0xBB`, délka pásku `0xA5 0x5A` + uint16 LE, rámec `0xFF` + legacy tuple (idx8, R, G, B) + `0xFE`, nebo `0xFC` + wide tuple (idx 16b, R, G, B) + `0xFE`; UDP `0x02` + jas + RGB trojice. Starší monitor build (200 LED, jen 8bit index) byl vyřazen z repa — viz kořenové `README.md`.
- **Baud rate** bere aplikace z `global_settings.baud_rate` v JSON (výchozí 115200) — musí sedět s firmwarem.
- **Firmware:** záložka **Nastavení → Firmware** — `manifest.json` z Pages, cache, flash **esptool** (PATH), nebo **OTA** přes UDP `OTA_HTTP <https://…/ambilight_esp32c6.bin>`; na zařízení lze totéž přes MQTT topic `…/ota` (viz firmware `ota_update.h`).
- **Po startu**: `load()` založí transporty a zkusí `connect()`. Pokud ESP ještě není připravený, spojení se **automaticky zkusí znovu cca každých 5 s**, dokud handshake / UDP bind nepůjde.
- **Zařízení**: v `config` musí být platný `port` (serial) nebo `ip_address` + `udp_port` (wifi). Prázdný port = žádný výstup na dané zařízení.

Obecný postup běhu a CI: **[README_RUN.md](README_RUN.md)** (včetně `flutter run` pro Windows / Linux / macOS).

## Windows screen capture

Screen režim používá **method channel** `ambilight/screen_capture` a nativní implementaci v `windows/runner/screen_capture_channel.cpp` (GDI **BitBlt** + `CreateDIBSection`, výstup **RGBA8**). Zachycení běží na **samostatném vlákně**; dokončení se doručí přes `PostMessage` na message loop host okna, takže neblokuje Flutter UI thread.

### Build

1. Nainstaluj [Flutter](https://docs.flutter.dev/get-started/install/windows) (stable) a ověř `flutter doctor`.
2. V kořeni projektu: `flutter pub get`.
3. První build Windows doplní `windows/flutter/ephemeral/` (CMake `generated_config.cmake`, knihovna Flutteru).
4. `flutter run -d windows` nebo `flutter build windows`.

Nativní zdroje runneru: `windows/runner/CMakeLists.txt` obsahuje `screen_capture_channel.cpp` a linkuje `gdi32.lib` / `user32.lib`.

### Tray (Windows)

Ikona v oznamovací oblasti se **mění podle režimu a zapnutí výstupu** (generovaný `.ico` v tempu, viz `lib/application/tray_mode_icon.dart`). Při chybě se použije `windows/runner/resources/app_icon.ico`.

### Konvence `monitorIndex` (MSS)

Shodně s Python MSS / `ScreenModeSettings.monitorIndex`:

- `0` — celý virtuální desktop (`SM_XVIRTUALSCREEN` …).
- `1` … `n` — fyzické monitory v **seřazeném** pořadí `(left, top)` z `EnumDisplayMonitors` (typicky odpovídá MSS, u složitých layoutů může mírně divergovat).

### Limity a známé problémy

- **HDR / široký gamut**: GDI vrstva často pracuje v SDR / kompozitovaném prostoru; barvy u HDR obsahu nemusí odpovídat „syrovému“ panelu.
- **Více GPU**: výběr DC je systémem řízený; hry na jiném GPU než desktop můžou mít výjimky.
- **Fullscreen exclusive / chráněný obsah**: obsah chráněný proti kopírování může být černý nebo zastaralý (stejná třída limitů jako u běžného desktop capture, není DXGI duplikace).
- **Výkon**: BitBlt je jednoduchý na údržbu; pro vyšší FPS / hry lze v P5 zvážit **Windows.Graphics.Capture** nebo **DXGI Desktop Duplication** a stejný Dart kontrakt.

### Dart API (P6)

`ScreenCaptureSource.platform()` vrací na **Windows, Linux a macOS** [`MethodChannelScreenCaptureSource`](lib/features/screen_capture/method_channel_screen_capture_source.dart) (kanál `ambilight/screen_capture`). Na **webu** nebo neznámé platformě je stub [`NonWindowsScreenCaptureSource`](lib/features/screen_capture/non_windows_screen_capture_source.dart). Snímek: [`ScreenFrame`](lib/features/screen_capture/screen_frame.dart) s `rgba`, `width`, `height`, `monitorIndex`.
