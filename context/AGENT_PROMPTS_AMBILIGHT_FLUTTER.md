# AmbiLight Flutter — podčásti zbytku a prompty pro agenty

Tento dokument **doplňuje** [AmbiLight-MASTER-PLAN.md](./AmbiLight-MASTER-PLAN.md). Obsahuje: rozbití zbytku na **podčásti**, **pořadí závislostí** a **samostatné prompty** (copy-paste do nového agenta). Agent má stejný přístup k repu jako vývojář — pracuj výhradně v `ambilight_desktop/` a v `context/` (dokumentace), referenční Python v `led_strip_monitor_pokus - Copy/src/`, **FW (lampa):** `led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c` (legacy monitor strom v repu není — jen lokální archiv, viz kořenové `README.md`).

**Paralelní běh (9 agentů):** aktuální sprint a vlastnictví souborů jsou v [AGENT_PARALLEL_9.md](./AGENT_PARALLEL_9.md); feedback agenty zapisují do [agent_feedback/](./agent_feedback/). Tento soubor (P0–P14) zůstává referencí závislostí a detailních úkolů.

**Výkon LED / latence / screen pipeline:** iterované prompty a ověřený stav jsou v [PERF_LED_AGENT_HANDOFF.md](./PERF_LED_AGENT_HANDOFF.md) (copy-paste Prompt #2–#3, backlog, baseline testů).

**Tvrdá pravidla pro všechny agenty**

- **Firmware neměň bez pokynu** — protokoly drž kompatibilní s lampou `esp32c3_lamp_firmware/main/ambilight.c`.
- **Nemaž soubory** bez explicitního pokynu uživatele; přidávej a upravuj.
- Po práci: `flutter analyze`, případně `flutter test`; oprav linter varování v dotčených souborech.
- Konfigurace JSON musí zůstat **zpětně kompatibilní** s `AppConfig` / `default.json` (viz `lib/core/models/config_models.dart`).
- Staging logy: `kDebugMode` / `Logger` — ve release bez spamu.
- **Responzivita (všichni, co sahají na UI):** žádné fixní šířky jako 900 px; používej `LayoutBuilder` / `MediaQuery` a sdílené breakpointy (viz MASTER G1–G4). Nastavení a průvodce musí být **scrollovatelné** a na úzkém okně **jednosloupcové**, na širokém **dvousloupec** kde to dává smysl. Touch-friendly rozestupy připrav tak, aby pozdější mobil (H) nevyžadoval přepis layoutu.
- **Mobil (iOS/Android):** neimplementuj v raných agentech. Až **Agent P14** na konci — do té doby desktop + tabletová šířka okna. **FW se nemění**; na telefonu počítej hlavně s **UDP** k ESP.

---

## 1. Mapa podčástí (co zbývá → kdo)

| ID | Podčást | Hlavní výstup | Závisí na |
|----|---------|---------------|-----------|
| **P0** | Bootstrap desktop projektu | `windows/`, `linux/`, `macos/`, build | — |
| **P1** | Tray + okno + minimalizace | tray menu, skrytí při zavření | P0 |
| **P2** | Hotkeys + autostart + auto-COM | globální zkratky, login startup, scan portů | P0 (P1 volitelně) |
| **P3** | Síťové příkazy zařízení + HomeKit přepínač | IDENTIFY, RESET_WIFI, `control_via_ha` v engine | P0 |
| **P4** | Nativní screen capture (rozhraní + Win) | Method channel / FFI, Windows frame | P0 |
| **P5** | Screen capture Linux + macOS | implementace pluginů / channels | P4 (stejné API) |
| **P6** | Screen pipeline (Dart) | gamma, segmenty, barvy → engine | P4 (mock nebo reálný frame) |
| **P7** | Audio + music režim | loopback/mic, FFT, efekty | P0 |
| **P8** | PC Health + Spotify | metriky, OAuth | P0 |
| **P9** | Nastavení UI vlna 1 | Global + Light + téma | P2 částečně |
| **P10** | Nastavení UI vlna 2 | Screen + Music + PC Health + Spotify záložky | P6, P7, P8 |
| **P11** | Průvodci a pokročilé UI | wizard, zóny, kalibrace, profily, live preview | P9, P10 |
| **P12** | Stav EMA + testy + CI dohled | interpolace, golden config, workflow | P6 nebo P7 |
| **P13** | Responzivní UI + adaptivní shell | breakpointy, `AmbiShell` / navigace, A9/A10/G1–G4, D15 | P0 |
| **P14** | **Poslední —** mobil iOS/Android | H1–H4: `ios`/`android`, UDP-first debug, volitelný USB serial stub; touch | P0 + dokončená desktopová vlna 6 (viz MASTER H) |

**Doporučené paralely:** Po P0 mohou běžet paralelně **P2**, **P3**, **P4**, **P13** (oddělené větve). **P5** až po stabilním API z P4. **P6** může začít s **mock** frame z P4, dokud není Win hotový. **P10** až po P6+P7+P8 rozhraních. **P14 nikdy paralelně s ranou fází** — až na závěr.

---

## 2. Propojení mezi agenty (kontrakty)

- **`ScreenCaptureSource`** (nebo ekvivalent): asynchronní stream / `Future<ScreenFrame?>` s `monitorIndex`, `width`, `height`, `rgba` / stride, timestamp. Implementace per OS v P4/P5; P6 jen konzumuje.
- **`AmbilightAppController`** (`lib/application/ambilight_app_controller.dart`): rozšiřuj metody (`setPreviewPixel`, `setMode`, …) bez rozbití stávající smyčky.
- **Transporty** (`DeviceTransport`, serial/UDP): rozšiřuj o `sendIdentify()`, `sendResetWifi()` jen u Wi‑Fi, nebo sdílený `UdpAdminCommands` util.
- **Konfigurace**: rozšíření modelů v `config_models.dart` + `fromJson`/`toJson` + migrace defaultů.

---

# PROMPTY PRO AGENTY (copy-paste)

Níže každý blok je **jeden celý prompt** pro nového agenta. Přidej k němu jen: „Repozitář je `d:\projects\Programming\Git\ambilight`“ nebo nech agenta pracovat v workspace root.

---

## PROMPT — Agent P0: Bootstrap Flutter Desktop

```
Jsi senior Flutter/Dart vývojář. Pracuješ v monorepu AmbiLight.

CÍL
- Zajisti, že projekt `ambilight_desktop/` je plnohodnotný Flutter **desktop** projekt pro Windows, Linux a macOS.
- Po `flutter pub get` a `flutter analyze` nesmí být chyby. `flutter test` musí projít.

KONTEXT
- Aplikace: `ambilight_desktop/`. Už existuje `lib/`, `pubspec.yaml`, závislosti včetně `flutter_libserialport`.
- Referenční plán: `context/AmbiLight-MASTER-PLAN.md`, agentní prompty: `context/AGENT_PROMPTS_AMBILIGHT_FLUTTER.md`.
- `flutter_libserialport` často rozbíjí Android build — buď vyluč Android z defaultních targetů, nebo `pubspec.yaml` + dokumentuj v `context/` jak spouštět jen desktop.

ÚKOLY
1) V adresáři `ambilight_desktop/` spusť (nebo vytvoř ručně ekvivalent) `flutter create --platforms=windows,linux,macos .` tak, aby se NEsmazal existující `lib/` (merge). Doplň chybějící `windows/`, `linux/`, `macos/`, `analysis_options.yaml` pokud chybí. **`ios` a `android` zatím nepřidávej** (řeší Agent P14) — pokud už v projektu jsou, nesmí rozbít `flutter pub get` kvůli desktop-only knihovnám; použij `dependency_overrides` / podmíněné závislosti nebo dokumentuj vyloučení mobilního buildu do doby P14.
2) Ověř `flutter pub get`, oprav konflikty verzí.
3) Přidej krátký `ambilight_desktop/README_RUN.md` (max ~40 řádků): příkazy run/test, požadavky na Flutter SDK, poznámka k serial na macOS (entitlements přidá jiný agent — zde jen TODO odkaz).
4) Pokud CI neexistuje, přidej `.github/workflows/ambilight_desktop.yml` s jobem `flutter analyze` + `flutter test` na `ubuntu-latest` (linux desktop compile může vyžadovat deps — pokud nejde, dokumentuj limity a nech aspoň analyze+test bez linux build).

OMEZENÍ
- Neměň firmware.
- Nemaž uživatelské soubory mimo repo.

VÝSTUP
- Shrnutí změn, seznam souborů, příkazy které jsi ověřil.
```

---

## PROMPT — Agent P1: System Tray, okno, minimalizace, macOS entitlements

```
Jsi senior Flutter desktop vývojář (Windows/Linux/macOS).

CÍL
- Implementuj chování blízké PyQt verzi: `led_strip_monitor_pokus - Copy/src/ui/main_window.py` (TrayIcon): tray ikona, kontextové menu, skrytí hlavního okna při zavření místo ukončení (konfigurovatelné později z GlobalSettings), double-click / otevření nastavení.
- Menu položky: zap/vyp, režimy (light/screen/music/pchealth), Quick presets (screen + music jako ve staré app — zatím může volat stejné preset mapování z `app_config.dart` SCREEN_PRESETS/MUSIC_PRESETS pokud přidáš do Dartu), Lock colors (stub s TODO napojení na C11), Settings, Quit.

KONTEXT
- `lib/main.dart` spouští `AmbilightAppController` + `AmbiShell`.
- Controller: `lib/application/ambilight_app_controller.dart` — rozšiř o metody které tray zavolá (toggle enabled, setStartMode, otevření settings route).
- Balíčky: `tray_manager`, `window_manager` (nebo ekvivalent udržovaný v roce 2026) — zvol stabilní kombinaci a zdůvodni v README.

ÚKOLY
1) Integuj tray: ikona podle režimu a zapnutí (můžeš začít jednou ikonou + tooltip).
2) `window_manager`: start hidden optional z config `start_minimized`; při close event → skrýt okno místo exit (Quit v menu ukončí app).
3) macOS: v `macos/Runner/*.entitlements` doplň co je potřeba pro síť a pozdější serial (viz MASTER E8) — alespoň základ pro tray + síťové sockety UDP.
4) Propoj menu s existujícím `Provider`/`ChangeNotifier` — žádné globální singletony kromě řízeného loggeru.

OMEZENÍ
- Nezasahuj do archivního monitor ESP stromu (není v repu; viz `.gitignore` / `README.md`).
- Zachovej spuštitelnost na Windows jako primární cíl.

VÝSTUP
- Krátký návod pro uživatele (tray, quit).
- `flutter analyze` čistý v dotčených souborech.
```

---

## PROMPT — Agent P2: Globální hotkeys, autostart, auto-detect sériového portu

```
Jsi senior Flutter vývojář se zkušenostmi s OS integrací.

CÍL
- Parita s Python: `app.py` `_init_hotkeys`, `startup.py` autostart, částečně `serial_handler._auto_detect_port`.
- Konfigurace už má `hotkeys_enabled`, `hotkey_toggle`, `hotkey_mode_*`, `custom_hotkeys`, `autostart` v `GlobalSettings` / JSON.

KONTEXT
- Modely: `lib/core/models/config_models.dart` — rozšiř pokud JSON z PyQt obsahuje pole která Dart nemodeluje (custom hotkeys struktura).
- Controller musí reagovat na hotkey bez blokování UI vlákna.

ÚKOLY
1) Hotkeys: použij `hotkey_manager` (nebo aktivně udržovanou alternativu). Mapuj výchozí akce: toggle, přepínání režimů, brightness +/- pokud bylo v PyQt — ověř v `app.py` a zreplikuj rozumnou množinu.
2) Custom hotkeys: načti z configu; akce jako v Pythonu (`_execute_custom_action`) — navrhni typově bezpečný enum + payload v Dartu.
3) Autostart: portuj logiku z `led_strip_monitor_pokus - Copy/src/startup.py` na Win (Registry/Task), Linux (.desktop), macOS (LaunchAgents) — použij existující balíček pokud je spolehlivý (`launch_at_startup` apod.), jinak tenký vlastní wrapper s dokumentací oprávnění.
4) Auto-detect COM: přidej službu která projde `SerialPort.availablePorts` a zkusí handshake `0xAA` / očekává `0xBB` (viz `SerialAmbilightProtocol`). API pro UI: `Future<String?> findAmbilightPort()`.

OMEZENÍ
- Na macOS upozorni na Accessibility oprávnění v README.
- Žádné mazání souborů.

VÝSTUP
- Dokumentace v `context/` nebo `README_RUN.md` — kde nastavit oprávnění.
```

---

## PROMPT — Agent P3: UDP admin příkazy, HomeKit přepínač, discovery UI

```
Jsi senior Dart/Flutter vývojář + základní síťové protokoly.

CÍL
- B5 z MASTER plánu: z PC posílej přes UDP řetězce `IDENTIFY`, `RESET_WIFI` (a případně další z `ambilight.c` task_udp) na známé IP zařízení.
- C4: pokud `light_mode.homekit_enabled` nebo `device.control_via_ha`, engine **neposílá** barvy na dané zařízení (stejně jako Python `DeviceManager.send_to_device`).
- D9: vylepši `DevicesPage` — dialog se seznamem z `LedDiscoveryService`, tlačítko Identify u řádku, potvrzení před RESET_WIFI.

KONTEXT
- FW: `led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c` — textové příkazy a binární hlavičky.
- UDP transport: `lib/data/udp_device_transport.dart`.
- Discovery: `lib/services/led_discovery_service.dart`.

ÚKOLY
1) Přidej na `UdpDeviceTransport` (nebo sdílený util) metody `sendIdentify()`, `sendResetWifi()` s logováním a bezpečným UX (reset jen po dialogu).
2) V `AmbilightEngine` / controller distribuci respektuj `control_via_ha` a globální homekit flag podle Python chování (projdi `app.py` kolem `send_to_device` a light módu).
3) UI: po discovery umožni uložit zařízení s validací IP; zobraz firmware verzi z PONG.

OMEZENÍ
- Neměň FW.

VÝSTUP
- Stručná tabulka příkazů → bajty/řetězce pro dokumentaci v `context/`.
```

---

## PROMPT — Agent P4: Screen capture — rozhraní + Windows implementace

```
Jsi senior Flutter + nativní Windows vývojář (C++/Dart FFI nebo oficiální platform channels).

CÍL
- Dodat **jednotné API** pro zachycení obrazovky/monitoru pro režim `screen`, které může konzumovat čistý Dart pipeline (Agent P6).
- Primární implementace: **Windows** (E3). Linux/macOS zde jen **stub** který vrací `null` + log warning — plná implementace pro P5.

KONTEXT
- Python referenční: `capture.py` (MSS, monitor geometry), `geometry.py`, `state.py`, `app.py` `_process_screen_mode`.
- Flutter: `lib/engine/ambilight_engine.dart` dnes používá `ScreenModeStub` — nahraditelný interface.
- Konfig: `ScreenModeSettings` v `config_models.dart` (`monitor_index`, scan depths, segments, gamma, …).

ÚKOLY
1) Navrhni abstrakci např. `abstract class ScreenCaptureSource` v `lib/features/screen_capture/` s factory pro Windows + stub.
2) Implementuj Windows: zvol strategii (Windows.Graphics.Capture / DXGI Desktop Duplication / nejnižší udržovaná knihovna). Výstup: raw RGBA + rozměry + `monitorIndex` konzistentní s výběrem v configu.
3) Method channel nebo `dart:ffi` — zvol jednu cestu a zdokumentuj build (CMake v `windows/`).
4) Jednotkové testy tam kde lze (mock native layer); alespoň test kontraktu rozhraní.

OMEZENÍ
- Nesmíš blokovat UI thread — capture běží na background isolate / vlastní thread s předáním frame přes `TransferableTypedData` nebo podobně.
- FW neměň.

VÝSTUP
- README sekce „Windows screen capture“ s limity (HDR, více GPU, fullscreen exclusive).
```

---

## PROMPT — Agent P5: Screen capture — Linux a macOS

```
Jsi senior Flutter + Linux (PipeWire/X11/Wayland) + macOS (ScreenCaptureKit) vývojář.

PŘEDPOKLAD
- Agent P4 dodal stabilní Dart rozhraní `ScreenCaptureSource` + Windows implementaci. Rozšiř **stejné API** — neinventuj paralelní rozhraní.

CÍL
- E4: Linux — funkční capture na typických desktopích (nejprve X11 nebo PipeWire podle feasibility dokumentuj).
- E5: macOS — ScreenCaptureKit nebo oficiálně doporučený postup; aktualizuj `macos/Runner` entitlements pro **screen recording**.
- Fallback: černý frame + user-visible chyba v UI místo crash.

KONTEXT
- `context/AmbiLight-analyza-a-Flutter-plan.md` — rizika Wayland vs X11.
- Entitlements už mohl začít Agent P1 — nerozbij serial entitlements.

ÚKOLY
1) Linux plugin / channel + detekce prostředí.
2) macOS plugin / channel + žádost o oprávnění (document „System Settings → Privacy“).
3) Integrace do factory `ScreenCaptureSource.create()`.

VÝSTUP
- Matice podpor: OS × session typ × poznámka.
```

---

## PROMPT — Agent P6: Screen pipeline (Dart) — barvy, segmenty, mapování na zařízení

```
Jsi senior Dart vývojář + image processing (bez UI kreslení overlay — to je P11).

PŘEDPOKLAD
- `ScreenCaptureSource` dodává `ScreenFrame` (RGBA). Pokud P4/P5 ještě nevrací reálná data, implementuj proti **mock frame** (gradient nebo statický obrázek) ale architektura musí být finální.

CÍL
- C5, C6 z MASTER: portovat chování z Pythonu do Dartu: výběr monitoru, segmenty (`LedSegment`), scan depth / padding per edge, saturation, ultra saturation, gamma, min brightness, interpolation v čase (ms z configu), color calibration + aktivní profil (`calibration_profiles`).
- Výstup pipeline: buď **flat** `List<(r,g,b)>` pro legacy rozdistribuování, nebo přímo `Map<deviceId, List<(r,g,b)>>` jako optimalizovaná cesta v Pythonu — zvol jedno a uprav `AmbilightAppController._distribute` konzistentně.

KONTEXT
- `led_strip_monitor_pokus - Copy/src/capture.py`, `geometry.py`, `color_correction.py`, `app.py` `_process_screen_mode`, `_remap_screen_zones`.
- Dart modely: `ScreenModeSettings`, `LedSegment` v `config_models.dart`.
- Engine: `lib/engine/ambilight_engine.dart`, controller.

ÚKOLY
1) Nový modul např. `lib/engine/screen/screen_color_pipeline.dart` s čistými funkcemi + unit testy na malých syntetických framech.
2) Nahraď `ScreenModeStub` reálným voláním pipeline.
3) Zajisti výkon: downsampling, minimalizace alokací (reuse bufferů kde jde).

OMEZENÍ
- Žádná změna FW.
- Žádné mazání uživatelských souborů.

VÝSTUP
- Stručný popis algoritmu vs Python (1 strana max v komentáři nebo `context/`).
```

---

## PROMPT — Agent P7: Audio vstup, FFT, music režim (parita s PyQt)

```
Jsi senior Dart + digitální zpracování signálu + Flutter desktop.

CÍL
- C7, E6: audio loopback nebo mikrofon dle `MusicModeSettings`, vizualizace efektů jako v `app.py` `_process_music_mode` / `_render_segment_effect` / granular music logika.
- Výstup: `List<(r,g,b)>` + brightness pro napojení na existující distribuci zařízení.

KONTEXT
- Python: `audio_processor.py`, `audio_analyzer.py`, `app.py` (hudba), `melody_detector.py` / další pokud používá režim.
- Flutter: `MusicModeStub` v `fallback_modes.dart` — nahradit.
- Konfigurace: `MusicModeSettings` v `config_models.dart` (7 pásem barev, sensitivity, effect enum stringy).

ÚKOLY
1) Zvol balíček pro capture (`record`, `flutter_sound`, …) s odůvodněním; enumerace vstupních zařízení.
2) FFT: buď čistý Dart, nebo C++ přes FFI — dokumentuj přesnost a CPU load.
3) Portuj efekty postupně: `energy`, `spectrum`, `strobe`, `vumeter`, `vumeter_spectrum` + beat detection parametry.
4) Integruj do `AmbilightEngine` když `start_mode == music`.

OMEZENÍ
- Neblokuj UI thread.
- FW beze změny.

VÝSTUP
- Tabulka efektů × stav implementace (checkbox) na konci `context/AmbiLight-MASTER-PLAN.md` nebo nový `context/MUSIC_PORT_STATUS.md` (krátký).
```

---

## PROMPT — Agent P8: PC Health režim + Spotify OAuth

```
Jsi senior Flutter vývojář + REST API + desktop security.

CÍL
- C8: PC Health — metriky jako v Pythonu (`modules/system_monitor.py`, `process_monitor.py`, `app.py` `_process_pchealth_mode`, `_get_gradient_color` s custom scales). Výstup barev na zóny dle `PcHealthSettings.metrics`.
- C9: Spotify — OAuth PKCE nebo device flow podle toho, co používá starý `spotify_client.py`; ukládání tokenů (`flutter_secure_storage`); volitelné barvy z alba pokud `use_album_colors`.

KONTEXT
- Modely: `PcHealthSettings`, `SpotifySettings` v `config_models.dart`.
- Režim `pchealth` dnes stub v `fallback_modes.dart`.

ÚKOLY
1) Odděl platformní sběr metrik (Win: WMI/Performance Counters — zvol realistický přístup; Linux `/proc` + sensors; macOS `sysctl`/powermetrics omezeně) do `lib/features/pc_health/` s jasným fallbackem.
2) Spotify: OAuth flow v desktop okně (`url_launcher` + lokální redirect server nebo deep link — zvol bezpečně).
3) Napoj na engine + základní UI indikátor „Spotify připojeno“.

OMEZENÍ
- Žádné skladování client_secret v plain text v gitu — jen v uživatelském configu mimo repo nebo secure storage.
- FW neměň.

VÝSTUP
- Bezpečnostní poznámky pro uživatele (tokeny, scopes).
```

---

## PROMPT — Agent P9: Nastavení UI — Global + Light + téma (A5, D3, D4)

```
Jsi senior Flutter UI vývojář (Material 3, formuláře, validace).

CÍL
- D3, D4, A5: záložky nebo sekce nastavení odpovídající PyQt `settings_dialog.py` části pro global + light (bez screen/music zatím).
- Uživatel musí měnit: zařízení (seznam, typ serial/wifi, port, IP, led_count, control_via_ha), autostart, start_minimized, capture_method string, hotkeys stringy (textfield + validace základní), theme dark/light, light: color picker, effect, speed, extra, custom_zones editor **minimálně** jako seznam zón (add/remove), homekit_enabled.

KONTEXT
- Controller: `AmbilightAppController.applyConfigAndPersist`, `replaceConfig`, `save`.
- Modely už existují — rozšiř jen pokud JSON z reálného `default.json` něco vynechává.

ÚKOLY
1) Navrhni navigaci v `SettingsPage` (TabBar nebo Master-Detail).
2) Formuláře vázané na lokální kopii `AppConfig` s Apply / Cancel.
3) Téma: aplikuj `global_settings.theme` na `MaterialApp` (`ThemeMode`).
4) **Responzivita:** formuláře v `SingleChildScrollView` / `ListView`; žádná pevná min šířka celého dialogu; na úzkém zobrazení jeden sloupec; respektuj breakpointy z MASTER G (můžeš je sdílet s Agentem P13).

OMEZENÍ
- Nerozbij existující `HomePage` navigaci.
- Neměň FW.

VÝSTUP
- Snímek struktury widgetů (textově) v PR popisu nebo v `context/`.
```

---

## PROMPT — Agent P10: Nastavení UI — Screen, Music, PC Health, Spotify (D5–D8)

```
Jsi senior Flutter UI vývojář — pracuješ na masivních formulářích.

PŘEDPOKLAD
- Agent P9 dodal kostru Settings navigace — rozšiř ji, nerozbij pattern.
- Agenti P6–P8 dodali funkční engine části — nastavení musí ovládat **skutečné** klíče v `ScreenModeSettings` / `MusicModeSettings` / `PcHealthSettings` / `SpotifySettings`.

CÍL
- D5: Všechna pole screen módu včetně segmentů (tabulka nebo seznam), předvolby Movie/Gaming/Desktop + user presets.
- D6: Music — audio device picker (napoj na P7 discovery vstupů), všechny slidery barev a citlivostí.
- D7: PC Health — metric editor jako koncept z PyQt (`metric_editor.py`).
- D8: Spotify — client id/secret, connect/disconnect, stav tokenu.

KONTEXT
- Python UI: `led_strip_monitor_pokus - Copy/src/ui/settings_dialog.py` + související widgety ve `ui/`.

ÚKOLY
1) Rozděl do pod-souborů `lib/ui/settings/` aby `settings_page.dart` nebyl monolit.
2) Validace čísel (gamma, procenta scan depth).
3) Live preview (D13) může být jen TODO hook do controlleru — pokud implementuješ, koordinuj s P11.
4) **Responzivita:** složité záložky (screen/music) musí zůstat použitelné na výšku notebooku i na šířku „tablet v okně“ — `LayoutBuilder`, případně horizontální scroll jen pro tabulky segmentů, ne pro celou stránku.

OMEZENÍ
- Zachovej načítání ze stejného JSON jako Python.

VÝSTUP
- Seznam obrazovek a mapování na MASTER ID (D5–D8).
```

---

## PROMPT — Agent P11: Průvodci, zone editor, kalibrace, profily JSON (D10–D14)

```
Jsi senior Flutter UI + canvas / overlay kde je potřeba.

CÍL
- Portovat z PyQt do Flutter desktop: LED wizard (`led_wizard.py`), zone editor (`zone_editor.py`), color calibration wizard (`color_calibration_wizard.py`), scan overlay (`scan_overlay.py`) v rozumné míře — multi-monitor zahrň v plánu i když první verze jen primární monitor.
- D14: výběr profilu JSON (`default.json` + user profiles), duplikace, import ze složky staré aplikace `config/`.
- D13: live preview barev/pixelů — napoj na controller rozšířený v P3/P9 (preview signály).

KONTEXT
- Python křivky a interakce jsou náročné — prioritizuj: (1) LED index test přes `sendPixel` na Wi‑Fi a serial buffer na USB, (2) jednoduchý zone editor číselně, (3) až pak plné drag overlay.

ÚKOLY
1) Navrhni modulární navigaci: Wizard jako `Navigator` push s vlastním stavem.
2) Ukládání výsledků do `AppConfig` + persist.
3) Dokumentuj limity vs PyQt v `context/`.
4) **Responzivita / touch:** kroky průvodce musí mít dostatečné mezery mezi tlačítky; overlaye respektují `SafeArea`; na malém okně kroky vertikálně.

OMEZENÍ
- Neměň FW.
- Nemaž uživatelské soubory.

VÝSTUP
- Checklist D10–D14 s [x]/[ ] v krátkém `context/WIZARDS_STATUS.md`.
```

---

## PROMPT — Agent P12: Runtime EMA interpolace, testy protokolu, golden config, CI

```
Jsi senior Dart vývojář + QA.

CÍL
- A4: Portuj z `state.py` logiku `interpolate_colors` / EMA pro režimy kde to Python dělá (ověř v `app.py` které režimy interpolují — nesmíš rozbít light chování).
- F1: rozšíř testy `SerialAmbilightProtocol` + `UdpAmbilightProtocol` (hraniční hodnoty, délky).
- F2: golden test: načti vzorkový `led_strip_monitor_pokus - Copy/AmbiLight_Distribution/AmbiLight/config/default.json` (nebo kopii v `ambilight_desktop/test/fixtures/`) a ověř že `AppConfig.fromJson` nespadne a klíčová pole sedí.
- F3: vylepši CI z P0 — matrix nebo alespoň windows build job pokud runner dovolí.

KONTEXT
- `lib/application/ambilight_app_controller.dart` — integrace interpolace před `_distribute` tam kde dává smysl (viz Python větev `interpolate_colors`).

ÚKOLY
1) Implementuj interpolaci srozitelně (konfigurovatelné `smooth_ms` pokud je v runtime stavu — přidej do modelu pokud chybí).
2) Testy musí běžet headless `flutter test`.

OMEZENÍ
- Nepřidávej těžké binární soubory do gitu bez nutnosti — golden config může být zkrácený fixture.

VÝSTUP
- `flutter test` výsledek + co ještě nechráněno testy.
```

---

## PROMPT — Agent P13: Responzivní UI, breakpointy, adaptivní shell (G / D15)

```
Jsi senior Flutter UI architekt (Material 3, adaptive layouts).

CÍL
- Splnit MASTER: A9, A10, G1–G4, D15 — aplikace musí vypadat a fungovat rozumně na širokém monitoru, zúženém okně, „tabletové“ šířce (iPad-like) i běžném notebooku bez horizontálního ořezávání kritických ovládacích prvků.
- Refaktoruj `lib/ui/ambi_shell.dart` (a související) na adaptivní navigaci: např. úzké okno = spodní NavigationBar nebo drawer; širší = NavigationRail + detail; jedna business logika, ne duplicitní stránky.

KONTEXT
- `context/AmbiLight-MASTER-PLAN.md` — sekce G, vlna 1b.
- Existující stránky: `home_page.dart`, `devices_page.dart`, `settings_page.dart`.

ÚKOLY
1) Přidej např. `lib/ui/layout/ambilight_breakpoints.dart` (nebo `lib/core/layout/`) s jednotnými práhy compact / medium / expanded.
2) Obal složité obrazovky do scrollovatelného těla kde je potřeba; ověř resize ručně (popiš v README krátké scénáře).
3) Minimální šířka/výška okna desktopu: rozumné hodnoty přes window_manager pokud je v projektu — nebo dokumentuj manuální resize test.
4) Nepřidávej iOS/Android targety — to je Agent P14.

OMEZENÍ
- FW neměň.
- Nemaž uživatelské soubory.

VÝSTUP
- Krátká tabulka breakpointů v `context/` nebo v `README_RUN.md`.
- `flutter analyze` bez chyb v dotčených souborech.
```

---

## PROMPT — Agent P14: Mobilní platformy až nakonec (H1–H4) — iOS / Android

```
Jsi senior Flutter vývojář multi-platform (desktop už funguje; dokončuješ mobilní cíle jako poslední vlna).

PŘEDPOKLAD
- Desktopová funkcionalita z MASTER plánu je hotová nebo má jasné TODO. Tento agent nesmí rozbít desktop build. Konzultuj pubspec.yaml: flutter_libserialport na Androidu často selže — vyřeš stubem, federovaným pluginem, nebo závislostí jen pro desktop (dokumentuj).

CÍL (MASTER sekce H)
- H1: Přidej ios/ a android/ přes flutter create (merge), CI volitelně.
- H2: Debug z telefonu/tabletu proti stejnému FW: primárně Wi-Fi/UDP (protokol beze změny). Obrazovka rychlé připojení: IP, port, test barvy / discovery.
- H3: USB serial na mobilu jen pokud udržitelné; jinak stub a zpráva v UI.
- H4: Touch: větší tap targets, stejná logika přes sdílené služby/controller — žádná duplikace engine.

KONTEXT
- UDP: lib/core/protocol/udp_frame.dart, lib/data/udp_device_transport.dart.
- Firmware v repu neměň.

ÚKOLY
1) Ověř flutter build apk / flutter build ios (aspoň compile) a oprav manifesty (síť, local network iOS 14+).
2) Dokumentuj: jak z telefonu ovládat ESP na LAN bez změny FW.
3) Respektuj compact layout z agenta P13.

OMEZENÍ
- Firmware ESP32 se nemění.
- Nemaž uživatelské soubory.

VÝSTUP
- Checklist H1–H4 v MASTER nebo context/MOBILE_STATUS.md.
```

---

## Shrnutí pro dispečera (ty)

1. Spusť **P0** první (nebo ručně `flutter create`), jinak ostatní agenti neověří build.  
2. **P13** může hned po **P0** paralelně s **P1** / **P2** / **P3** / **P4** — responzivní kostra UI (MASTER vlna 1b).  
3. **P1** a **P2** mohou běžet paralelně po P0.  
4. **P3** nezávisí na capture.  
5. **P4** → **P5** sériově na stejném API.  
6. **P6** může začít s mockem paralelně k P4, ale merge až API sedí.  
7. **P7**, **P8** paralelně po P0.  
8. **P9** před nebo paralelně s P10; **P10** až jsou data z P6–P8 stabilní.  
9. **P11** po základním settings (P9).  
10. **P12** průběžně nebo na konec — EMA může měnit chování, koordinuj s P6/P7.  
11. **P14 až úplně nakonec** — po desktopové vlně 6 a ideálně po dokončení P13; mobil nesmí regresovat desktop.

---

*Soubor: `context/AGENT_PROMPTS_AMBILIGHT_FLUTTER.md` — aktualizováno 2026-05-03 (responzivita, P13/P14, mobil až nakonec)*
