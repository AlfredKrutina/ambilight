# PyQt (`led_strip_monitor_pokus - Copy`) vs Flutter (`ambilight_desktop`) — inventář mezer a parity

**Datum:** 2026-05-03  
**Účel:** Jedna přesná mapa „co stará aplikace uměla / kde je nová verze“ pro plánování a review.  
**Konvence:** **Parita** = stejné chování z pohledu uživatele a protokolu vůči ESP; **Částečně** = základ je, detaily chybí; **Ne** = v nové verzi chybí nebo je jen náhrada jiného typu.

**UI napojení (2026-05-03):** `light_settings_tab` (barva + zóny) → `previewStripColor` / `clearStripColorPreview`; **`music_settings_tab`** při `color_source=fixed` → stejné náhledové slidery; `screen_settings_tab` → rohy pásku + Vypnout; `config_backup_section` + Globální záložka → export/import JSON (`file_picker`). Při zavření nastavení se vypnou kalibrace a náhled barvy.

**Doplněno mimo UI (2026-05-03, vlna 2):** `previewStripColor` + expirace ticků, `setCalibrationLedMarkers` (indexy jako PyQt), chybový strip `(10,0,0)` po výjimce ve smyčce, přednostní pořadí ticku jako v `app.py` (vypnuto → náhled barvy → kalibrace → wizard pixel → engine), `AmbilightEngine.blackoutPerDevice`, import/export JSON přes controller, vypnutí výstupu vždy pošle černou i při HomeKit hold.

---

## 1. Shrnutí

| Oblast | Shrnutí |
|--------|---------|
| Jádro výstupu | Serial/UDP, multi-device, handshake, rámcový protokol — v Dartu pokryto transporty + engine. |
| Režimy | Screen / light / music / pc health — v engine + controller; HomeKit „nechat MQTT“ u light — zohledněno. |
| UI průvodců | Discovery, kalibrace, zóny, profily — existují; **interaktivní LED průvodce s náhledem pixelu** byl doplněn (2026-05-03) v `led_strip_wizard_dialog.dart` + `setWizardLedPreview` v controlleru. |
| Systém | Tray, hotkeys, autostart — ve Flutteru; menu tray vs PyQt se může lišit v počtu presetů / popisech. |
| Audio / hudba | PyQt WASAPI + analyzátory (melody, stem, hybrid…) vs Dart FFT + melody/melody_smart + monitor paleta — **parita algoritmů není 1:1**; loopback typicky přes Stereo Mix / virtuální audio, ne čistý WASAPI exclusive. |
| Snímání obrazovky | MSS + vlastní logika v Pythonu vs MethodChannel + Dart pipeline — funkčně obdobné, Linux omezení (X11) dokumentováno v README. |
| Stav / EMA | Python `state.py` / interpolace v čase — ve Flutteru částečně (screen smoothing v pipeline; globální „EMA runtime“ jako jedna vrstva stavu může chybět). |
| Pokročilé PyQt moduly | `adaptive_detector`, `hybrid_detector`, `stem_separator`, `capture_broken` experimenty — v Dartu bez přímého ekvivalentu nebo záměrně vynecháno. |

---

## 2. Modul po modulu (Python `src/` → Flutter)

### 2.1 `app.py` — hlavní smyčka

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Timer ~30 Hz | Ano | `Timer.periodic` ~33 ms v `AmbilightAppController` | |
| Startup blackout | Ano | `_startupActive` / `_startupFrame` | |
| Preview jedné LED (wizard) | `preview_pixel_override` | `_wizardLedPreview` + `_distribute` (Wi‑Fi: black + `sendPixel`; serial: full `targetLeds` buffer) | Wi‑Fi chování jako časný return v Pythonu u `send_pixel`. |
| Preview barvy (color picker) | `preview_override_color` + timer | **Ano** | Záložka Světlo — dialog základní barvy a barvy zóny. |
| Crash protection / červený error strip | Ano | **Ano** | Po výjimce v `_tick` ~90 snímků `(10,0,0)` na všechna zařízení. |
| Light + HomeKit — neposílat | Ano | `skipAllSends` + výjimka při wizard preview | |

### 2.2 `serial_handler.py` / `modules/serial_manager.py`

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Ping/pong, handshake | Ano | `SerialDeviceTransport` | |
| Hard reset DTR/RTS | Ano | `_hardResetEspSerial` | |
| Fronta rámců | Ano | `_queue` + drain timer | |
| Odeslání >200 LED na wire | Ořez / padding v protokolu | `SerialAmbilightProtocol.targetLeds` | Wizard serial náhled omezen na 0…199. |

### 2.3 `capture.py` / snímání

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| MSS monitory | Ano | Nativní kanál + `ScreenCaptureSource` | |
| Výběr monitoru | Ano | `screenMode.monitorIndex` | |
| Rychlost / latence | Závisí na OS | Stejně | |

### 2.4 `state.py` / interpolace globálního stavu

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| `AppState` + interpolace barev mezi ticky | Ano | Screen: `applyTemporalSmoothing`; hudba: `smoothingMs` | Legacy jeden flat list v Pythonu; ve Flutteru odděleně po režimech. |
| EMA / historie jako v MASTER A4 | Částečně v Pythonu | **Částečně** | Plná časová EMA jako `state.py` (float `current_colors`) u light módu zatím bez 1:1; viz audit. |

### 2.5 `audio_processor.py` / `audio_analyzer.py` / hudba

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| WASAPI loopback | Primární cesta | `record` / systémové zařízení | Často uživatel musí povolit Stereo Mix / virtuální kabel. |
| FFT / spektrum | Ano | `music_fft_analyzer` | |
| Melody | Ano | `music_melody_analyzer` | |
| Melody smart | Ano | `music_melody_smart_effect` | |
| Strobe / energy / VU | V Pythonu | `music_granular_engine` + efekty | Názvy a citlivost se mohou lišit. |
| Stem / demix | `stem_separator.py` | **Ne** | Velký rozsah (model / latency); záměrně mimo aktuální Flutter klient. |
| Hybrid / adaptive detekce | `hybrid_detector`, `adaptive_detector` | **Ne** | Stejně jako výše — odloženo. |
| Per-segment music mapping | V Pythonu přes segmenty | `music_segment_renderer` + modely | Ověřit paritu hranic a `music_effect` na segmentu. |

### 2.6 `modules/spotify_client.py` + UI

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| OAuth / tokeny | Ano | PKCE + `SpotifyTokenStore` (soubor) | Secure storage odstraněn kvůli buildu Windows (ATL). |
| Dominantní barva do engine | Ano | `spotify.dominantRgb` v ticku | |

### 2.7 `modules/process_monitor.py` / `system_monitor.py` — PC Health

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| CPU / RAM / GPU / disk / teploty | Částečně dle OS | `pc_health_collector` (+ IO) | Sada metrik a frekvence nemusí být identická. |
| Vizuální editor metrik | `metric_editor.py` | Základ v záložce nastavení | Parita „graf editoru“ nejasná bez porovnání obrazovek. |

### 2.8 `ui/settings_dialog.py` — monolit nastavení

| Oblast | PyQt | Flutter | Poznámka |
|--------|------|---------|----------|
| Globální | Ano | `global_settings_tab` | |
| Zařízení + discovery | Ano | `devices_page` + `devices_tab` + wizards | |
| Screen | Ano | `screen_settings_tab` + overlay | |
| Music | Ano | `music_settings_tab` | |
| Light | Ano | `light_settings_tab` | |
| PC Health | Ano | `pc_health_settings_tab` | |
| Spotify | Ano | `spotify_settings_tab` | |
| Hotkeys | Ano | Hotkey service + validace | |
| Import/export JSON | Závisí na buildu | `ConfigRepository` + **`exportConfigJsonString` / `importConfigFromJsonString`** na controlleru | UI: file picker + volání těchto metod (druhý agent). |

### 2.9 Průvodci (`ui/`)

| Soubor PyQt | Účel | Flutter | Stav |
|-------------|------|---------|------|
| `discovery_dialog.py` | UDP discover | `discovery_wizard_dialog.dart` | **Ano** — sken, identify, přidání do configu, **Reset Wi‑Fi** s potvrzením (`UdpDeviceCommands.sendResetWifi`). |
| `led_wizard.py` | Interaktivní mapa LED + segmenty | `led_strip_wizard_dialog.dart` | **Parita základního toku** (slider, `setWizardLedPreview`, segmenty, append). Výběr monitoru: **`ScreenCaptureSource.listMonitors()`** → dropdown MSS indexu; při nedostupnosti nativního seznamu ruční pole. |
| `zone_editor.py` | Editor zón | `zone_editor_wizard_dialog.dart` | **Parita polí** — LED rozsah, monitor, hrana, hloubka, reverse, zařízení, pixely, ref. rozměry (vč. tlačítka z posledního snímku), `music_effect`, role, reorder; ověření na HW. |
| `calibration.py` | Kalibrace obrazovky | `calibration_wizard_dialog.dart` | Částečně. |
| `color_calibration_wizard.py` | Barvy / profily | Částečně v `screen_mode` + profily | Plný multi-krok jako PyQt? |
| `_profile_helpers.py` | Presety | `config_profile_wizard_dialog.dart` + `ambilight_presets.dart` | Zkontrolovat názvy a počet presetů vs tray PyQt (Movie/Gaming/Desktop, Party/Chill/Bass Focus). |

### 2.10 `ui/scan_overlay.py`

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Překryv přes celou obrazovku | Ano | `screen_overlay` + window ops | |
| Kliknutí „propadnou“ na OS / hry | Částečně / OS-specific | `IgnorePointer` v rámci okna aplikace | PyQt mohl mít jiné chování průhledného okna. |

### 2.11 `ui/main_window.py` — tray

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Zap/Vyp | Ano | Ano | |
| Režimy včetně pchealth | Ano | Ověřit všechny položky menu v `desktop_chrome_io` / tray | |
| Quick presets screen + music | Sekce v menu | `applyQuickScreenPreset` / hudba | Seznam názvů se musí shodovat s produktem. |
| Lock colors | Ano | C11 music palette lock | |

### 2.12 `geometry.py` / `color_correction.py`

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Geometrie segmentů | Python + wizard | Dart pipeline + wizard | |
| Korekce barev / gamma | V Pythonu | `screen_color_pipeline` + `colorCalibration` v modelech | Porovnat číselně s legacy. |

### 2.13 `startup.py` / `settings_manager.py`

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Autostart | Ano | `AutostartService` | OS-specifické rozdíly možné. |
| První spuštění | Závisí na buildu | `main.dart` / controller `load` | |

### 2.14 `modules/device_manager.py`

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Agregace zařízení | Ano | `globalSettings.devices` + transport map | |

### 2.15 Procesní capture (okno aplikace místo monitoru)

| Prvek | PyQt | Flutter | Poznámka |
|-------|------|---------|----------|
| Výběr okna / procesu | Částečně v Pythonu | `process_capture_contract.dart` | MASTER E7 — nativní výběr okna může být nedokončený. |

---

## 3. Rizika a otevřené otázky

1. **LedSegment.monitorIdx** — PyQt wizard ukládal index z MSS combo (historicky 0-based v jedné větvi); Flutter používá konvenci `ScreenFrame.monitorIndex` / `screenMode.monitorIndex` (typicky 1…n). Průvodce ukládá `_monitorMss` do `monitorIdx` segmentu i `monitorIndex` v `screenMode` — při nesouladu s nativním snímkem segment „nepasuje“ k frame; ověřit na HW.  
2. **Sériový wizard** nad 199 — náhled nepřesáhne `targetLeds`; uživatel s delším páskem na USB musí spoléhat na Wi‑Fi single-pixel nebo dočasně zvýšit `led_count` ručně.  
3. **Globální color preview** (`preview_override_color`) — Světlo + **hudba při fixed** používají `previewStripColor` / `clearStripColorPreview`; jiné pickery ověřit při rozšíření.  
4. **Trvanlivost** — žádné automatické testy v tomto běhu (Dart nebyl v PATH); lokálně spusťte `flutter test` / `flutter analyze`.

---

## 4. Doporučené další kroky (priorita)

1. Otestovat LED průvodce na reálném ESP (serial i Wi‑Fi).  
2. Zarovnat názvy a sadu tray presetů s PyQt nebo zdokumentovat záměrné odchylky.  
3. Projít `zone_editor_wizard_dialog` vs `zone_editor.py` po polích JSON.  
4. Jednorázový diff `state.py` ↔ `AmbilightAppController` + `AmbilightEngine` pro EMA / lock / interpolace.  

---

*Tento soubor doplňuj při větších změnách parity; technický stav kódu viz také `PROJECT_STATE_AUDIT.md` a `AmbiLight-MASTER-PLAN.md`.*
