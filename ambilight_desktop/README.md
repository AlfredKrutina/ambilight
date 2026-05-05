# ambilight_desktop

Flutter desktop klient pro AmbiLight (kompatibilní s existujícím JSON / firmware).

## Komunikace s ESP (USB sériové / Wi‑Fi UDP)

- **Protokol** — zdroj pravdy: `led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c` (**lampa**, až ~2000 LED): sériově `0xAA`/`0xBB`, délka pásku `0xA5 0x5A` + uint16 LE, rámec `0xFF` + legacy tuple (idx8, R, G, B) + `0xFE`, nebo `0xFC` + wide tuple (idx 16b, R, G, B) + `0xFE`; UDP `0x02` + jas + RGB trojice. Jednobajt **`0xF0`** (USB i UDP): PC ukončuje řízení — FW uvolní sériovou prioritu / watchdog a přejde na **MQTT / Home Assistant** (desktop při vypnutí výstupu nebo `dispose`). **`0xF1` + uint8** (0=vypnuté, 1=plynulé EMA, 2=snap): časové vyhlazování na lampě (NVS), odpověď stejnými 2 bajty (ACK); `ESP32_PONG` na discovery: `…|ledCount|FW_VER|2.1|<mode>` (starší FW jen `…|2.1|<mode>`). Starší monitor build (200 LED, jen 8bit index) byl vyřazen z repa — viz kořenové `README.md`.
- **Baud rate** bere aplikace z `global_settings.baud_rate` v JSON (výchozí 115200) — musí sedět s firmwarem.
- **Firmware:** záložka **Nastavení → Firmware** — `manifest.json` z Pages, cache, flash **esptool** (PATH), nebo **OTA** přes UDP `OTA_HTTP <https://…/ambilight_esp32c6.bin>` (aplikace čeká na odpověď `AMBILIGHT OTA_OK <verze>` z lampy před restartem; MQTT `…/ota` totéž bez UDP potvrzení); viz firmware `ota_update.h` a `context/UDP_TASK_UDP_COMMANDS.md`.
- **Po startu**: `load()` založí transporty a zkusí `connect()`. Pokud ESP ještě není připravený, spojení se **automaticky zkusí znovu cca každých 5 s**, dokud handshake / UDP bind nepůjde.
- **Zařízení**: v `config` musí být platný `port` (serial) nebo `ip_address` + `udp_port` (wifi). Prázdný port = žádný výstup na dané zařízení.
- **UDP a FW lampy:** firmware v `ambilight.c` zpracuje zobrazení u bulk (`0x02`) / flush (`0x08`) nejrychleji cca **každých 15 ms** — rychlejší rámce na RX **může zahodit** (sdílený throttle). Klient ve [`UdpDeviceTransport`](lib/data/udp_device_transport.dart) **nehistoruje frontu** dlouhých snímků: `sendColors` přepíše jeden „nejnovější“ job a worker odesílá na pozadí jedním trvalým UDP socketem (při plném TX bufferu retry s krátkou prodlevou). Chunky **`0x06`** jdou **bez prodlev mezi datagramy** — `Future.delayed(1 ms)` na Windows kvůli výchozí timer resolution (~15,6 ms) uměle nafukoval emit na desítky ms. **Deduplikace** stejného RGB hashe mezi ticky je omezená: po **cca 80 ms** bez úspěšného odeslání se rámec pošle znovu i při stejném hash (plynulý pohyb LED). Diagnostika end-to-end: `--dart-define=AMBI_PIPELINE_DIAGNOSTICS=true` (bez define se v konzoli neobjeví `PIPELINE_DIAG`; při zapnutí max. ~5 řádků/s z throttlovaného loggeru). Rozšířené logy: `--dart-define=AMBI_VERBOSE_LOGS=true`.
- **Wi‑Fi &gt;499 LED:** jeden `0x02` stačí jen do **499** LED od indexu 0; delší pásek = chunky **`0x06`** + jeden flush **`0x08`** (vyžaduje aktuální lamp FW). Kalibrace jedním bodem dál používá **`0x03`**.
- **USB + Wi‑Fi na stejný ESP:** po sériové komunikaci FW **ignoruje UDP** po dobu řádu sekund (source lock). Pro stabilní stream použij **jednu cestu** nebo dva oddělené kontrolery. Podrobně: [context/ESP_UDP_TRANSPORT_NOTES.md](../../context/ESP_UDP_TRANSPORT_NOTES.md), matice testů [context/REPRO_MATRIX_FLUTTER_ESP.md](../../context/REPRO_MATRIX_FLUTTER_ESP.md), HA [context/HA_AMBILIGHT_COEXIST.md](../../context/HA_AMBILIGHT_COEXIST.md).

Obecný postup běhu a CI: **[README_RUN.md](README_RUN.md)** (včetně `flutter run` pro Windows / Linux / macOS).

## Vydání desktopu (autoaktualizace)

1. Zvedni `version` v [`pubspec.yaml`](pubspec.yaml).
2. Vytvoř a pushni tag ve tvaru **`desktop-vMAJOR.MINOR.PATCH`** (např. `desktop-v1.0.4`), který odpovídá verzi v manifestu.
3. Spustí se workflow [`.github/workflows/desktop_release.yml`](../.github/workflows/desktop_release.yml): Windows **Release** build, ZIP z celého `build/windows/x64/runner/Release/` (včetně podsložky **`data/`** s Flutter assets — bez ní by po aktualizaci aplikace nenaběhla), **`desktop-manifest.json`** s URL na GitHub Releases a SHA-256 ZIPu, GitHub Release s oběma soubory.
4. Aplikace na stránce **O aplikaci** kontroluje manifest z výchozí URL (`AMBI_DESKTOP_UPDATE_MANIFEST_URL` / GitHub `releases/latest/download/desktop-manifest.json`). Kanál v manifestu musí sedět s buildem (`AMBI_CHANNEL`, výchozí `stable`). Na Windows po ověření hashe proběhne stažení, ukončení procesu a PowerShell skript přepíše soubory v instalaci a znovu spustí `.exe`.

**GitHub „latest“:** URL `…/releases/latest/download/desktop-manifest.json` vždy bere **nejnovější** release podle data publikace. Nesmíš tedy vytvořit novější release bez tohoto assetu (např. jen dokumentace), jinak kontrola aktualizací vrátí 404. Stačí znovu spustit `desktop_release` tagem nebo přiložit `desktop-manifest.json` k tomu nejnovějšímu release ručně.

## Windows screen capture

Screen režim používá **method channel** `ambilight/screen_capture` a nativní implementaci v `windows/runner/screen_capture_channel.cpp` (**DXGI** Desktop Duplication jako výchozí, při selhání **GDI BitBlt** + `CreateDIBSection`, výstup **RGBA8**). DXGI používá **neblokující** `AcquireNextFrame(0)`; krátké `noUpdate` jsou normální. Po **řadě timeoutů** nebo **>400 ms** bez úspěšného snímku worker udělá jeden **GDI „insurance“** snímek (`gdi_insurance` v DebugView), aby se pipeline nezasekla na starém framebufferu, když DWM dlouho neemituje nový composed frame. Zachycení běží na **jednom perzistentním worker vlákně** s frontou požadavků (ne nové vlákno na každý snímek); priorita vlákna mírně zvýšena, dokončení přes `PostMessage`. Uložený `windows_capture_backend` v JSON přebíjí výchozí backend (nastavení obrazovky: DXGI / GDI).

**Cadence snímání (Dart):** `global_settings.performance_mode` zapne výkonový režim (mimo skryté okno): driver snímání ~40 ms; pokud ještě běží předchozí `captureFrame`, další tick jen nastaví replay (žádný umělý „stride“ — překryv delšího nativního capture už není brán jako důvod vynechávat snímky). Při vypnutém výkonovém režimu řídí periodu `screen_refresh_rate_hz` (např. 60); interval mezi úspěšnými snímky v logu může odpovídat **délce native capture** (řád desítky ms). Pro vyšší frekvenci hlavní smyčky vypni výkonový režim a drž 60 Hz.

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
- **Výkon**: BitBlt je jednoduchý na údržbu; pro vyšší FPS / hry lze v P5 zvážit **Windows.Graphics.Capture** nebo **DXGI Desktop Duplication** a stejný Dart kontrakt. Profilování Flutter UI vs ESP: [context/FLUTTER_PERFORMANCE_PROFILE.md](../../context/FLUTTER_PERFORMANCE_PROFILE.md).

### Dart API (P6)

`ScreenCaptureSource.platform()` vrací na **Windows, Linux a macOS** [`MethodChannelScreenCaptureSource`](lib/features/screen_capture/method_channel_screen_capture_source.dart) (kanál `ambilight/screen_capture`). Na **webu** nebo neznámé platformě je stub [`NonWindowsScreenCaptureSource`](lib/features/screen_capture/non_windows_screen_capture_source.dart). Snímek: [`ScreenFrame`](lib/features/screen_capture/screen_frame.dart) s `rgba`, `width`, `height`, `monitorIndex`.
