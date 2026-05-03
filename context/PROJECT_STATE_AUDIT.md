# AmbiLight Flutter — audit kódu vs MASTER (opakovaná kontrola)

**Datum:** 2026-05-03 (prohlídka zdrojáků v repu; `flutter` nebyl v PATH v CI shellu — lokálně si ověř `flutter analyze` / `flutter test`).  
**Kód:** `ambilight_desktop/` · **Plán:** `AmbiLight-MASTER-PLAN.md`

## Shrnutí jednou větou

Desktop klient je **použitelný k vyzkoušení UI a light/screen/music toků**; parita s PyQt na úrovni „všechno včetně drobností“ ještě **není** (tray menu, EMA, B5/B7, čistý WASAPI loopback, E7 nativně, … — viz tabulka).

## Tabulka stavu

| Oblast | Stav | Poznámka (ověřeno v kódu) |
|--------|------|---------------------------|
| Platformy Win/Linux/macOS | **Ano** | Stejný `MethodChannel` capture na třech OS; **macOS** `AppDelegate` neukončí app po zavření okna (tray); tray ikona z `AppIcon.icns`; **Linux** screen = X11 (viz README_RUN). |
| JSON + modely + persist | **Ano** | `config_models.dart`, `ConfigRepository`; golden test `test/config_golden_test.dart` + fixture. |
| Serial + UDP + discovery | **Ano** | Transporty, `LedDiscoveryService`, multi-device v engine; sériový **baud** z `global_settings.baud_rate`; **auto-reconnect** cca 5 s při `!isConnected`. |
| Téma A5 | **Ano** | `AmbiLightRoot` → `themeMode` z `global_settings.theme`. |
| Hotkeys + autostart | **Ano** | `AmbilightHotkeyService`, `AutostartService`, hook po načtení configu. |
| Tray + okno | **Ano (Win/macOS/Linux)** | Menu + **dynamická ikona** podle režimu (`tray_mode_icon.dart`); macOS lifecycle + E8 entitlements. |
| Screen capture (nativní + Dart) | **Částečně** | `screen_capture`, `screen_color_pipeline`, engine větev; Linux/macOS a parita segmentů — dál testovat na HW. |
| Hudba C7 | **Silně rozšířeno** | `MUSIC_PORT_STATUS.md`: melody, melody_smart, AGC, `color_source == monitor`, per-segment; loopback pořád typicky přes Stereo Mix / virtuální zařízení, ne čistý WASAPI jako Python. |
| C11 zámek palety | **Ano** | `AmbilightAppController.toggleMusicPaletteLock` — zmrazení výstupu v music módu; tray + záložka Hudba. |
| PC Health C8 | **Částečně** | Collectory, smoother, záložka v nastavení; hloubka metrik vs PyQt. |
| Spotify C9 | **Částečně** | PKCE, token store, API, záložka; OAuth v praxi otestovat. |
| E7 process capture | **Kontrakt + příprava** | `process_capture_contract.dart`; nativní výběr okna dle plánu. |
| Nastavení D3–D8 | **Rozšířeno** | `lib/ui/settings/settings_page.dart` — **7 záložek** (Globální, Zařízení, Světlo, **Obrazovka**, **Hudba**, **PC zdraví**, **Spotify**); starý import `settings_page.dart` jen re-exportuje. |
| Scan / náhled snímání (D-detail) | **Částečně** | Stejné + v aplikaci **`IgnorePointer`** na vrstvě malby (kliky na UI pod overlay v rámci okna); OS-level pass-through jako PyQt ne. |
| Wizards D9–D14 | **Částečně** | Discovery, zóny, kalibrace, profily; **LED průvodce** má interaktivní náhled pixelu + segmenty jako PyQt (`setWizardLedPreview`, `led_strip_wizard_dialog.dart`). Detailní mezery: `context/FLUTTER_VS_PYQT_GAP_ANALYSIS.md`. |
| Adaptivní shell D15 / G | **Částečně** | `AmbiShell`: `NavigationRail` od breakpointu, jinak `NavigationBar`; `layout_breakpoints.dart` sdíleně se settings. |
| EMA runtime A4 | **Ne / minimálně** | Stále hlavní gap oproti Python `state.py` — ověř v controlleru/engine. |
| CI matice F3 | **Nejasné v repo** | V `ambilight_desktop/` nebyl nalezen `.github/workflows`; může být jen lokální nebo v kořeni jinak pojmenované. |
| Mobil H | **Záměrně později** | MASTER vlna 7. |

## Kde hledat (rychlá mapa)

| Téma | Cesta |
|------|--------|
| Engine + režimy | `lib/engine/ambilight_engine.dart` |
| Controller | `lib/application/ambilight_app_controller.dart` |
| Nastavení (7 tabů) | `lib/ui/settings/settings_page.dart`, `lib/ui/settings/tabs/*.dart` |
| Scan overlay | `lib/features/screen_overlay/*`, vrstva v `lib/main.dart` |
| Hudba | `lib/services/music/*` |
| Wizards | `lib/ui/wizards/*.dart` |
| Testy | `test/*.dart` |

## Další krok pro dokumentaci

Po lokálním běhu `flutter test` a ručním kliknutí v aplikaci aktualizuj checkboxy v `AmbiLight-MASTER-PLAN.md` tam, kde máš jistotu, a případně jednu větu sem do patičky auditu.

---

*Šablona pro další audit: zkopíruj tabulku, uprav datum a řádky „Poznámka“ podle diffu / feedbacku v `context/agent_feedback/`.*
