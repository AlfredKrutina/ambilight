# AmbiLight (Flutter) — MASTER PLAN

*Primární cíl: desktop (Win/Mac/Linux). UI musí být responzivní pro různé velikosti okna a tabletové šířky; **iOS/Android až vlna 7** (sekce H).*

Dokument slouží jako **jednotný backlog**: kompletní inventura funkcí ze stávající PyQt aplikace, závislosti mezi moduly a pořadí implementace. Aktualizuj při dokončení položky (přepni `[ ]` → `[x]` v git diff).

Související: [AmbiLight-analyza-a-Flutter-plan.md](./AmbiLight-analyza-a-Flutter-plan.md) (protokol FW, rizika).  
**Prompty pro agenty (historické P0–P14):** [AGENT_PROMPTS_AMBILIGHT_FLUTTER.md](./AGENT_PROMPTS_AMBILIGHT_FLUTTER.md)  
**Paralelní sprint (9 agentů + koordinátor):** [AGENT_PARALLEL_9.md](./AGENT_PARALLEL_9.md) — každý agent na konci běhu zapíše [agent_feedback/](./agent_feedback/).  
**Audit kódu vs tento plán:** [PROJECT_STATE_AUDIT.md](./PROJECT_STATE_AUDIT.md)

**Kód nové aplikace:** `ambilight_desktop/` (jeden Flutter projekt; primárně desktop, UI ale **od začátku responzivní** pro různé velikosti okna a postupně i tablet/telefon — viz sekce G a H).

**Princip:** Aplikace musí **vizuálně a layoutově fungovat** na širokém monitoru, notebooku (Win/Mac/Linux), menším okně i na **tabletových rozměrech** (např. iPad) bez rozbití navigace a formulářů. **Mobilní buildy (iOS/Android)** a ladění z telefonu přicházejí **až v závěrečné fázi** — do té doby se soustřeď na desktop + responzivní UI v rámci okna. **Firmware ESP se nemění** — na mobilu se počítá hlavně s ovládáním přes **Wi‑Fi/UDP** (stejný protokol jako dnes); USB serial na telefonech je bonus s omezeními, ne blokátor.

---

## A. Infrastruktura a architektura

| # | Funkce | Popis (parita s Python) | Status |
|---|--------|-------------------------|--------|
| A1 | Projekt Flutter desktop | `windows`, `linux`, `macos`; `flutter create --platforms=...` | [x] |
| A2 | Konfigurace JSON | Načtení/uložení stejné struktury jako `AppConfig` + migrace legacy polí | [x] |
| A3 | Ukládání configu | Adresář aplikace (`path_provider`), kopírování / import ze starého `config/` | [x] částečně — `ConfigRepository`: `config/*.json` z CWD nebo app support; import wizard z PyQt zatím bez UI |
| A4 | Stav aplikace runtime | `enabled`, brightness%, smooth_ms, `TOTAL_LEDS`, current/target colors, EMA interpolace | [~] EMA časové vyhlazení screen módu v `ScreenPipelineRuntime`; globální `AppState` jako ve staré app zčásti nahrazeno controllerem |
| A5 | Téma UI | dark/light dle `global_settings.theme` | [x] |
| A6 | Logování | `logging`, debug vs release | [x] |
| A7 | Chybové hranice | Jeden špatný frame nesmí shodit engine (jako v `app.py`) | [x] |
| A9 | Responzivní layout | Breakpoints (`LayoutBuilder` / `MediaQuery`), compact vs expanded; žádné fixní šířky jako 900 px z PyQt; scrollovatelné nastavení; `NavigationBar` vs `NavigationRail` podle šířky | [x] částečně — `layout_breakpoints.dart`, shell + settings |
| A10 | Bezpečné oblasti | `SafeArea`, vstup pod klávesnicí, foldy kde relevantní | [x] částečně — např. spodní lišta nastavení |

---

## B. Hardware a síť (bez změny FW)

| # | Funkce | Popis | Status |
|---|--------|-------|--------|
| B1 | Serial transport | Handshake `0xAA`/`0xBB`, rámec `0xFF` + 200×(i,R,G,B) + `0xFE`, clamp 0–253, fronta max 2 snímky | [x] |
| B2 | UDP transport | `0x02` bulk, `0x03` pixel, brightness | [x] |
| B3 | Multi-device | `DeviceManager`: více serial + Wi‑Fi, `control_via_ha` neposílat z PC | [x] |
| B4 | Discovery | Broadcast `DISCOVER_ESP32`, parse `ESP32_PONG\|...`, cache | [x] |
| B5 | IDENTIFY / RESET_WIFI | UDP příkazy jako ve FW | [x] `UdpDeviceCommands` + UI na zařízeních / discovery |
| B6 | DTR/RTS + 8N1 | Po open: `SerialPortFlowControl.none`, RTS on / DTR off; při fail handshake hard reset sekvence jako Python; `cfg.dispose()`; UDP bind `anyIPv6` pro IPv6 cíle | [x] |
| B7 | Auto-detect port | Scan portů + ping | [x] `SerialAmbilightPortDiscovery.findAmbilightPort` + tlačítko na stránce Zařízení |

---

## C. Režimy a engine (30 Hz smyčka)

| # | Funkce | Popis | Status |
|---|--------|-------|--------|
| C1 | Hlavní tick | ~30 Hz, startup blackout, disabled → černá | [x] |
| C2 | Režim `light` | static, breathing, rainbow, chase | [x] |
| C3 | `custom_zones` | Zóny %, static/pulse/blink, GRB→RGB jako Python | [x] |
| C4 | `homekit_enabled` | Neposílat data (MQTT na FW) | [x] ve **light** módu (jako `app.py`); ostatní režimy při zapnutém HomeKit dál počítají — ověř, zda FW očekává víc |
| C5 | Režim `screen` | MSS/DXCam, segmenty, monitor, scan depth, padding, gamma, saturation, ultra_sat, interpolace ms, color calibration + profily, předvolby Movie/Gaming/Desktop | [~] pipeline + capture; kalibrace / presety částečně |
| C6 | Mapování segment → zařízení | Dict per device jako optimalizovaná cesta | [x] `ScreenColorPipeline.processFrameToDevices` + `_mapFlatToDevices` v ostatních módech |
| C7 | Režim `music` | energy, spectrum, strobe, vumeter, vumeter_spectrum, 7-band barvy, beat, auto gain, smoothing, granular segment effects, roles | [x] viz [MUSIC_PORT_STATUS.md](./MUSIC_PORT_STATUS.md) |
| C8 | Režim `pchealth` | Metriky CPU/GPU/RAM/temp, škály barev, mapování na zóny | [~] sběr + engine + nastavení; doladit metriky / Linux |
| C9 | Spotify integrace | OAuth, tokeny, barvy alba, propojení s hudbou | [~] PKCE + album barvy v music větvi engine |
| C10 | Kalibrace / preview | `preview_override_color`, `preview_pixel_override`, wizard serial vs UDP pixel | [ ] |
| C11 | `lock colors` (tray) | music_color_lock | [x] `toggleMusicPaletteLock` — zmrazení výstupu v music módu (tray + záložka Hudba) |
| C12 | Startup animace | ~60 framů černá | [x] |

---

## D. UI — obrazovky a dialogy

| # | Funkce | Popis | Status |
|---|--------|-------|--------|
| D1 | Hlavní okno | Toggle, režim, status připojení, jas | [x] základ |
| D2 | System tray | Ikony per režim, menu: toggle, módy, presety, lock, settings, quit | [x] Win/macOS/Linux — generovaná `.ico`/`.png` podle režimu a zapnutí (`tray_mode_icon.dart`); fallback na `app_icon` / `AppIcon.icns` |
| D3 | Settings — Global | Zařízení, autostart, minimalizace, capture method, hotkeys, custom hotkeys | [x] základ v `GlobalSettingsTab` |
| D4 | Settings — Light | Barva, efekt, rychlost, extra, zóny, HomeKit | [x] základ v `LightSettingsTab` |
| D5 | Settings — Screen | Všechna pole `ScreenModeSettings`, segment editor, scan overlay, calibration overlay | [~] pole + scan sekce; plný segment editor / kalibrace viz wizardy |
| D6 | Settings — Music | Audio zařízení, efekt, sensitivity, barvy, presety | [x] základ `MusicSettingsTab` |
| D7 | Settings — PC Health | Metric editor, update rate | [x] základ `PcHealthSettingsTab` |
| D8 | Settings — Spotify | Client id/secret, token flow | [x] základ `SpotifySettingsTab` |
| D9 | Discovery dialog | Seznam, přidat zařízení, identify | [x] `DiscoveryWizardDialog` + stránka Zařízení |
| D10 | LED Wizard | Průvodce mapováním LED | [x] částečně — `LedStripWizardDialog` (napojení z UI ověřit) |
| D11 | Zone editor | Drag segmenty | [x] částečně — `ZoneEditorWizardDialog` |
| D12 | Color calibration wizard | Profily den/noc | [x] částečně — `CalibrationWizardDialog` |
| D13 | Live preview v nastavení | `settings_preview` signál | [~] náhled snímku / overlay; thumbnail z `latestScreenFrame` doladit |
| D14 | Profily JSON | Výběr / duplikace profilu `default.json` | [x] částečně — `ConfigProfileWizardDialog` |
| D15 | Adaptivní shell | Jedna navigace pro úzké vs široké okno (drawer / rail / bottom bar) bez duplikace logiky | [x] částečně — `AmbiShell` rail vs bottom bar |

### D-detail — Screen, scan overlay a náhled „odkud se snímá“ (parita `scan_overlay.py` a související UI)

Tyto body **nejsou duplicitou** tabulky D5/D13 — rozpadají implementaci na ověřitelné chování. Reference PyQt: `led_strip_monitor_pokus - Copy/src/ui/scan_overlay.py`, kalibrace / preview v nastavení screen režimu.

- [x] **Fullscreen overlay na správném monitoru:** `scan_overlay_window_ops_io` + `ScreenRetriever` / `window_manager` (ověř na více monitorech).
- [~] **Vrstvení a focus:** frameless + on-top; OS-level „nepřebírá focus“ není plně replikováno jako PyQt Tool.
- [x] **Průhlednost:** `ScanOverlayPainter` — ztmavený střed, zvýrazněné okraje.
- [x] **Pass-through myši (v rámci Flutter okna):** `IgnorePointer` na vrstvě `CustomPaint` v `main.dart` — kliky jdou na UI pod náhledem; **ne** propad mimo aplikaci jako u PyQt.
- [x] **Per-edge depth a padding:** `ScanRegionGeometry` / `ScreenColorPipeline.segmentRoi` shodná logika s Pythonem.
- [x] **Live update parametrů:** `ScanOverlayController.syncFromDraft` při změně sliderů.
- [x] **Vizuální režim zap/vyp:** přepínač v screen nastavení + zavření v banneru.
- [ ] **Auto-hide:** volitelné; PyQt `scan_overlay` bez časovače v našem portu.
- [~] **Náhled v samotném nastavení (D13):** overlay + `latestScreenFrame` v controlleru; miniaturní diagram ve formě widgetu lze doplnit.
- [x] **Multi-monitor:** stejný `monitor_index` pro capture i `scanOverlayDisplayRectForMonitor` (ověř mapování MSS index vs Flutter display order).
- [~] **Kalibrace obrazovky:** wizard existuje; plná parita profilů v čase.
- [~] **Segment editor + živý náhled:** wizard zón + pipeline; drag jako v PyQt částečně.

---

## E. Integrace OS (Win / Linux / Mac)

| # | Funkce | Popis | Status |
|---|--------|-------|--------|
| E1 | Globální hotkeys | Stejné výchozí + custom akce | [x] `AmbilightHotkeyService` + validace v nastavení |
| E2 | Autostart | Jako `startup.py` per OS | [x] `AutostartService` + `launch_at_startup` |
| E3 | Screen capture — Windows | WGC / DXGI / fallback | [~] nativní runner / kanál — ověř na cílových Win |
| E4 | Screen capture — Linux | PipeWire / X11 | [~] `screen_capture_linux.cc` — ověř na distro |
| E5 | Screen capture — macOS | ScreenCaptureKit + oprávnění | [~] viz macos runner / dokumentace v `context/` |
| E6 | Audio loopback / mikrofon | Výběr zařízení, multi-backend | [~] `record` + enumerace; plný WASAPI loopback viz status |
| E7 | Procesní zaměření (process monitor) | Volitelné okno pro screen režim | [ ] kontrakt v kódu; nativní výběr okna |
| E8 | macOS entitlements | Serial, síť, přístupnost | [x] částečně — `com.apple.security.device.serial`, audio-input, síť, sandbox; `NSInputMonitoringUsageDescription` (globální zkratky); App Store / notářský podpis dle cíle distribuce |

---

## G. Responzivita a tvar displeje (cross-cutting)

| # | Funkce | Popis | Status |
|---|--------|-------|--------|
| G1 | Breakpointy | Definice např. compact pod ~600 dp, medium ~600–1200, expanded nad ~1200 (doladitelné) — jeden zdroj pravdy v kódu | [x] `AppBreakpoints` |
| G2 | Nastavení a formuláře | Dlouhé obrazovky: `SingleChildScrollView` / `CustomScrollView`; na šířku: `Wrap`, `Flexible`, dvousloupec jen od medium výš | [x] částečně |
| G3 | Tabulky a editory | Segmenty / metriky: na úzkém zobrazení pod sebou, na širokém vedle sebe | [~] dle záložky |
| G4 | Okno a multitasking | Rozumné `constraints` pro min velikost okna desktopu; nepadat při resize během ticku engine | [x] částečně — `WindowOptions.minimumSize` |

---

## H. Mobilní platformy — **až nakonec** (iOS / Android)

| # | Funkce | Popis | Status |
|---|--------|-------|--------|
| H1 | Cíle buildů | `flutter create` doplní `ios/` a `android/`; CI volitelně později; **nesmí rozbít desktop** (podmíněná závislost na `flutter_libserialport` — dokumentovat) | [ ] |
| H2 | Debug z mobilu | Primárně **UDP** k ESP na síti (stejný FW protokol); UI pro IP/port; žádná změna FW | [ ] |
| H3 | USB serial na mobilu | Volitelné, platformně křehké — až po H1–H2; oddělený modul / stub | [ ] |
| H4 | Mobilní UI | Touch cíle, větší tap targets, stejná business logika jako desktop přes sdílené služby | [ ] |

**Pořadí:** Sekce **H až po dokončení desktopové parity** (vlny 1–6 a G). Mobil není blokující pro vývoj engine ani UDP.

---

## F. Testování a distribuce

| # | Funkce | Status |
|---|--------|--------|
| F1 | Unit testy protokolu (serial/UDP bytes) | [x] mimo jiné `serial_frame_test`, capture contract |
| F2 | Golden test config load (vzorek `default.json`) | [x] `test/config_golden_test.dart` |
| F3 | CI build matrix win/linux/macos | [x] `.github/workflows/ambilight_desktop.yml` |

---

## Implementační pořadí (doporučené vlny)

1. **Vlna 1 (hotové / rozšířené v tomto PR):** A2, A4, A6, A7, B1–B4, C1–C3, C12, D1 — funkční „ambilight desktop“ s light módem a reálným výstupem.
2. **Vlna 1b (průběžně s UI prací):** A9, A10, G1–G4, D15 — responzivní layout a adaptivní shell (nečeká na mobil).
3. **Vlna 2:** B5, B7, C4, D2, E2, E8 — tray, autostart, dokončení device vrstvy.
4. **Vlna 3:** C5 + E3–E5 — screen pipeline + nativní capture pluginy.
5. **Vlna 4:** C7 + E6 — audio + music efekty.
6. **Vlna 5:** C8, C9, E1, E7 — PC health, Spotify, hotkeys, process monitor.
7. **Vlna 6:** D3–D14 — plná parita nastavení a průvodců (všechny nové obrazovky musí splňovat G1–G3).
8. **Vlna 7 (poslední — mobil):** H1–H4 — iOS/Android buildy, síťový debug k FW, volitelně USB serial; **FW beze změny**.

---

*Verze plánu: 2026-05-03 — doplněno responzivita (G), mobil až nakonec (H), vlna 1b a 7.*

---

## Tabulka efektů hudby (implementace)

| Efekt | Hotovo |
|-------|--------|
| energy | [x] |
| spectrum (+ rotate / punchy v názvu) | [x] |
| strobe | [x] |
| vumeter | [x] |
| vumeter_spectrum | [x] |
| pulse | [x] |
| reactive_bass | [x] |
| melody / melody_smart | [x] |

Detail (capture, FFT, loopback, limity): [MUSIC_PORT_STATUS.md](./MUSIC_PORT_STATUS.md).

---

## Stav kódu `ambilight_desktop/` (2026-05-03, druhá aktualizace)

- **Hotové / rozšířené:** sedm záložek nastavení (včetně Screen/Music/PC/Spotify), scan overlay + geometrie, wizards v repu, CI workflow, B5/B7, C6/C11 (zámek palety hudby), tray menu s lockem, music podle `MUSIC_PORT_STATUS.md`, Spotify/PCHealth základ, adaptivní shell.
- **Zbývá k „PyQt pixel-perfect“:** E7 nativní výběr okna, čistý WASAPI loopback, doladění capture na všech OS, D13 mini náhled ve formě diagramu, ikony tray per režim, případné rozšíření HomeKit skip na další režimy dle FW chování.
- **Pravda o stavu:** [PROJECT_STATE_AUDIT.md](./PROJECT_STATE_AUDIT.md); agenti [agent_feedback/](./agent_feedback/).
- **Mobil (H):** záměrně mimo tento cíl — vlna 7.

Spusť v kořeni projektu: `flutter create --platforms=windows,linux,macos .` pokud chybí platformní složky, pak `flutter pub get` a `flutter test`. Pro **vlna 7** později doplníš `ios` a `android` (`flutter create .` s příslušnými platformami) — nedělej to předčasně, pokud by to rozbilo závislosti desktopu.
