# PyQt (`led_strip_monitor_pokus - Copy`) vs Flutter (`ambilight_desktop`) — úplný inventář rozdílů

**Datum:** 2026-05-05  
**Účel:** Jedna souhrnná příloha k `FLUTTER_VS_PYQT_GAP_ANALYSIS.md` — co nejúplnější výpis rozdílů architektury, konfigurace, pipeline a funkcí (ne řádek-po-řádku celého firmware/openthread stromu).

**Konvence:** **Parita** = podobný záměr; **Částečně** = dílčí odchylky; **Ne** = chybí nebo záměrně vynecháno.

---

## 1. Shrnutí kritických odchylek (screen → ESP)

| Téma | PyQt | Flutter |
|------|------|---------|
| ROI → barva LED | `cv2.resize(..., INTER_AREA)` podél hrany | Binning po LED: medián R/G/B (`median`) nebo průměr (`average`) — viz `ScreenColorPipeline.sampleRoiColors` |
| UI median/average | Combo v nastavení + JSON; **`capture.py` `color_sampling` nečte** → efekt prakticky žádný | `ScreenModeSettings.colorSampling` skutečně mění algoritmus |
| Baseline barvy v capture | Natvrdo sat ×1.2 a gamma 2.2 v `capture.py`, pak config | `saturationBoost` / `gamma` z modelu + ultra sat + kalibrace (`applyTransforms`) |
| Časové vyhlazení screen | Větev `dict` → **`interpolate_colors` se nevolá** | `applyTemporalSmoothing` (EMA) podle `interpolation_ms` |
| `reverse` segmenty | Capture klíčuje s reverse; `_process_screen_mode` lookup často **bez** stejné logiky | Konzistentní mapování klíčů a merge bufferu |
| Monitor index | MSS `target_mss_idx = segment.monitor_idx + 1` | `segmentMatchesCaptureFrame`: přímý MSS index **nebo** legacy `seg.monitorIdx + 1` |
| Serial délka pásku | Rámec doplněný/oříznutý na **200** LED | Legacy `0xFF` ≤256 nebo wide `0xFC` až ~2000 LED |
| UDP | Jeden paket `0x02` + jas + celé RGB | Bulk `0x02` nebo chunky `0x06` + flush `0x08`, deduplikace |

---

## 2. Architektura a běh

- UI: PyQt6 vs Flutter.
- Smyčka: `app.py` timer vs `AmbilightAppController` + `AmbilightEngine` + volitelné **izoláty** (screen pipeline, music worker, light/PC).
- Konfigurace: Python `config/*.json` + `settings_manager.py` vs Flutter `ConfigRepository`; Dart model **nemusí načíst všechny legacy klíče** (viz §5).
- Diagnostika: Flutter `AMBI_PIPELINE_DIAGNOSTICS`, `debug_trace`, `app_crash_log`; PyQt převážně stdout.

---

## 3. Snímání obrazovky

- PyQt: MSS, vlákno `CaptureThread`, BGRA NumPy.
- Flutter: MethodChannel / nativní; Windows **`windows_capture_backend`** `gdi` | `dxgi`; globální `capture_method` (`mss`) je vedle toho legacy řetězec.
- Flutter `ScreenFrame` může nést **layout meta** (origin, výřez) — ROI přes `segmentRoiInFrameBuffer`.

---

## 4. Segmentace a geometrie

- Společně: hrany, `pixel_start`/`end`, `ref_width`/`height`, simple/advanced scan depth a padding.
- PyQt `LedSegment.depth` v dataclass — v `capture.py` se primárně berou **globální** `scan_depth_*` / `padding_*` z `app_state`.
- Overlay: PyQt `scan_overlay.py` vs Flutter `screen_overlay` — průchod kliků / fullscreen se může lišit.

---

## 5. Globální nastavení (`GlobalSettings`)

**PyQt (`app_config.py`), často v JSON:**

- `hotkeys_enabled`, `hotkey_toggle`, `hotkey_mode_light` / `_screen` / `_music`, `custom_hotkeys`.

**Flutter model tyto položky neobsahuje** — při načtení JSON se **nepoužijí** (klíče mohou v souboru zůstat).

**Jen Flutter:**

- `ui_animations_enabled`, `performance_mode`, `screen_refresh_rate_hz` (60 / 120 / 240).
- `firmware_manifest_url`, onboarding (`onboarding_completed`), `ui_language`, rozšířené `theme`.
- `DeviceSettings.firmware_version`.

---

## 6. Screen mode (`ScreenModeSettings`)

- Společné: monitor, scan depth, padding, ultra sat, min brightness, interpolation, gamma, kalibrace/profily, segmenty, brightness.
- Flutter navíc: `windows_capture_backend`, `color_sampling` (řádné pole v JSON).
- PyQt dataclass v souboru nemá `color_sampling`; UI ho někdy přidává jako dynamický atribut — závisí na serializaci.

---

## 7. Music mode

| Oblast | PyQt | Flutter |
|--------|------|---------|
| `color_source` | `fixed`, **`genre`**, `monitor` | UI: `fixed`, **`spectrum`**, `monitor` — import PyQt `genre` / `spectral` se normalizuje na `spectrum` (`normalizeMusicColorSource`); `toJson` ukládá už normalizovanou hodnotu |
| Efekty (enum / UI) | `constants.MusicEffect` + rozšířená logika v `app.py` | UI např. `smart_music`, `spectrum_rotate`, `spectrum_punchy`, `pulse`, `reactive_bass`, … + `music_segment_renderer` |
| Audio | WASAPI loopback primárně | `record` / výběr zařízení — jiná dostupnost na OS |
| Pokročilé moduly | `stem_separator`, `hybrid_detector`, `adaptive_detector`, `melody_detector.py` | **Ne** jako samostatné porty; část melody v Dart FFT/melody analyzátorech |

---

## 8. Light mode

- Modely blízko (`effect`, `speed`, `extra`, `custom_zones`, `homekit_enabled`).
- PyQt `state.py` EMA pro legacy flat list; Flutter: volitelné `smoothing_ms` v `LightModeSettings` + `LightRgbSmoothingRuntime` v `AmbilightAppController` (0 ms = okamžitý výstup jako dřív; kladné ms = stejný EMA vzorec jako screen interpolace).

---

## 9. PC Health

- PyQt: `process_monitor.py`, `system_monitor.py`, `metric_editor.py`.
- Flutter: `pc_health_collector_io` (+ stub), výchozí metriky — **jiná sada a přesnost podle OS**.

---

## 10. Spotify a média

- PyQt: OAuth tokeny, `client_id` / `client_secret` v configu.
- Flutter: PKCE, `SpotifyTokenStore` (soubor); secure storage kvůli Windows buildu vynechán.
- **Jen Flutter:** dominantní barva z **OS média** (`SystemMediaAlbumSettings`, GSMTC) — náhrada části „barvy z obalu“ mimo Spotify API.

---

## 11. Smart lights

- **Jen Flutter:** `SmartLightsSettings`, HA / HomeKit backendy, vazby `global_mean`, `virtual_led_range`, `screen_edge`, vlny.
- PyQt: jen příbuzné **`control_via_ha`** na zařízení v configu.

---

## 12. Kořenová konfigurace (`AppConfig`)

- Společné: `light_mode`, `screen_mode`, `music_mode`, `spotify`, `pc_health`, user presets.
- **Jen Flutter:** `system_media_album`, `smart_lights`.

---

## 13. Serial a UDP (detail)

- Serial: handshake, fronta ~2 snímky, PyQt škálování `brightness/100` — stejný princip ve Flutter `SerialAmbilightProtocol`.
- UDP PyQt: jeden velký datagram — u dlouhých pásek MTU problém; Flutter chunking + flush.

---

## 14. UI, průvodci, tray

- PyQt monolit `settings_dialog.py`; Flutter záložky `*_settings_tab.dart`.
- Průvodci: discovery, LED, zóny — obě strany; **kalibrace / color wizard** — částečná parita (`FLUTTER_VS_PYQT_GAP_ANALYSIS.md` §2.9).
- Tray / preset názvy: ověřit `desktop_chrome_io` vs `main_window.py` — mohou se lišit.
- Lokalizace: Flutter `en`/`cs`; PyQt bez stejného l10n.

---

## 15. Moduly jen Python (`src/`)

- Experimentální / bez Dart portu: `stem_separator.py`, `hybrid_detector.py`, `adaptive_detector.py`, `capture_broken.py`, `melody_detector.py`, `_ultra_saturation_helper.py`.
- Repo kořen: `integrate_ai_stems.py` (není v `src/`).
- Pomocné: `ui/styles.py`, `themes.py`, `utils.py`, `constants.py` (enumy `ScanMode`, `LedLayout`, `PCHealthMode`).

---

## 16. Moduly / funkce jen Flutter (`lib/`)

- Onboarding, firmware manifest / update služba.
- Screen/music/light izoláty, UDP dedupe a chunky protokol, wide serial.
- Smart lights orchestrace, HA token store, crash log, Spotify PKCE guide widgety.
- `process_capture_contract` — výběr okna procesu může být nedokončený (viz MASTER plán).

---

## 17. Presety obrazovky / hudby

- Zarovnáno: `ambilight_presets.dart` ↔ Python `SCREEN_PRESETS` / `MUSIC_PRESETS` (Movie, Gaming, Desktop; Party, Chill, Bass Focus, Vocals).

---

## 18. Rizika z předchozích auditů (kopie pro kontext)

1. `LedSegment.monitorIdx` vs nativní snímek — při nesouladu žádné vzorky (`segment_skip` v diagnostice). Flutter UI: banner v záložce Obrazovka a v editoru zón při nesouladu (`screenSegmentCaptureWarnings`).
2. Serial wizard nad ~199 — omezení legacy indexu; Wi‑Fi pixel / ruční `led_count`.
3. Globální color preview — rozšíření pickerů mimo Světlo / hudbu fixed ověřit při úpravách.

---

## 19. Odkazy na související dokumenty

- `context/FLUTTER_VS_PYQT_GAP_ANALYSIS.md` — modulová tabulka parity a doporučené kroky.
- `context/SCREEN_COLOR_PIPELINE.md` — Dart pipeline vs Python stručně.

---

*Soubor doplňovat při velkých změnách parity; úplný řádkový diff celého repozitáře včetně ESP/OpenThread není cílem tohoto dokumentu.*
