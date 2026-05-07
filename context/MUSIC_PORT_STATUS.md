# Music mód — stav portu (Flutter `ambilight_desktop`)

Aktualizace: 2026-05-07 — §5 macOS + §6 capture diagnostika (input level meter, capture info, bezpečný PCM acc). FW beze změny.

## 1) Capture balíček

| Volba | Pro / proti |
|--------|-------------|
| **`record` (vybráno)** | Oficiální Flutter plugin, `listInputDevices()`, `startStream` + PCM pro vlastní DSP, Windows/macOS/Linux. Údržba a desktop podpora lepší než u starších wrapperů. |
| `flutter_sound` | Silné pro přehrávání/nahrávání souborů; capture API složitější na desktop parity. |
| Vlastní FFI (WASAPI / CoreAudio / Pulse) | Jediná cesta k **čistému** systémovému loopback bez „Stereo Mix“; víc práce a CI matice. |

**Loopback:** Python používá `pyaudiowpatch` (WASAPI loopback). `record` typicky vidí **mikrofon a virtuální vstupy** (Stereo Mix, VB-Audio Cable, …), ne vždy stejné jméno jako PyAudio index. Skutečný WASAPI loopback ve Flutteru = budoucí nativní modul nebo FFI.

**Enumerace:** `MusicAudioService.listDevices()` → `MusicCaptureDeviceInfo` (`index`, `id`, `label`, heuristika `isLoopback` z názvu).

## 2) FFT

| Přístup | Přesnost / zátěž |
|---------|------------------|
| **Čistý Dart — `fftea`** | Stejný řád jako NumPy FFT pro danou délku okna; 4096 vzorků, Hanning, 7 pásem jako v `audio_analyzer.py`. Na desktopu typicky **sub‑ms až jednotky ms** na snímek při 30 Hz UI ticku (audio přichází častěji; výpočet v callbacku s `_busy` dropuje přetížení). |
| C++ přes FFI | Nižší latence při velmi vysokých sazbách / více kanálech; náklad na build a platformní vrstvu. |

**Poznámka:** `beat_threshold` z configu škáluje multiplikátory beat detectorů (mapováno okolo výchozí hodnoty 1.5 z Pythonu).

## 3) Efekty × implementace

| Efekt / oblast | Stav |
|----------------|------|
| `energy` | [x] |
| `spectrum` (+ `spectrum_rotate`, `spectrum_punchy` — řetězec obsahuje `spectrum`) | [x] |
| `strobe` | [x] |
| `vumeter` | [x] |
| `vumeter_spectrum` | [x] (stejná priorita jako Python: obsahuje `spectrum` → větev spectrum dřív než vumeter) |
| `pulse` | [x] |
| `reactive_bass` | [x] |
| `melody` / `melody_detector` | [x] — barva z chromatické třídy (`MusicMelodyAnalyzer` + FFT magnitudes); při slabém signálu šedý pulz z pásem. |
| `melody_smart` | [x] — port 4 zón / onset flash z `app.py` (`music_melody_smart_effect.dart`). |
| `color_source == monitor` | [x] — `dominantRgbFromFrame` + throttled capture v `AmbilightAppController` když `music` + `color_source == monitor'` (sdílený kanál se screen módem). |
| AGC (`auto_gain` / `auto_mid` / `auto_high`) | [x] — `auto_gain`: škálování pásem podle `_agcPeak` (legacy Python); `auto_mid` / `auto_high`: dynamická násobitel citlivosti v `music_segment_renderer.dart`. |
| Per-segment `music_effect` | [x] — `LedSegment.musicEffect` ≠ `default` přepíše globální `music_mode.effect` v `MusicGranularEngine`. |

## 4) Integrace

- `AmbilightEngine.computeFrame` → `music` větev: `MusicGranularEngine` + `_mapFlatToDevices` (stejný model jako light/screen).
- `AmbilightAppController`: `MusicAudioService` životní cyklus dle `start_mode` a configu.

## 5) macOS — proč může být „hudba“ téměř zhasnutá

- **Žádný nativní loopback** (na rozdíl od Windows WASAPI v `MusicAudioService._tryStartWindowsWasapiLoopback`). Na macu se vždy jede přes `record` + seznam **vstupních** zařízení.
- **Výchozí vstup** (`audioDeviceIndex == null`): v `_startRecordCapture` se vybere heuristika (mikrofon vs. zařízení s názvem loopback) a nakonec `inputs.first` — pokud **nepoužíváš BlackHole / agregát**, často to chytí **fyzický mikrofon**; hudba z repráků do FFT skoro neleze → slabé pásma → `MusicSegmentRenderer` škáluje barvy nízkou intenzitou → LED skoro nesvítí.
- **I když je vstup mikrofon záměrně:** akustika v místnosti je řádově slabší než digitální loopback → FFT hodnoty zůstanou nízké, výsledné RGB jsou tmavé (ne bug, fyzika SPL).
- **Jas navíc**: `musicMode.brightness` (0–255) se posílá do `_distribute` (`brightnessForMode`); barvy z hudby jsou už „intenzitou“ z FFT — slabý signál = tmavé RGB i při slušném jasu.
- **Permissions ověřeno**: `Info.plist` má `NSMicrophoneUsageDescription`, `Release.entitlements` + `DebugProfile.entitlements` mají `com.apple.security.device.audio-input`. `desktop_audio_capture` plugin je linkovaný i pro macOS (`AudioCapturePlugin` v `GeneratedPluginRegistrant.swift`), ale `SystemAudioCapture` pro macOS zatím v `_tryStart…` cestě **není** (kandidát na následnou rozšíření přes ScreenCaptureKit + screen-recording permission).
- **Praktická kontrola** (UI): Nastavení → Hudba → **karta „Vstup“** (`_MusicCaptureDiagnosticsCard`) zobrazí aktivní zařízení / backend a real-time peak meter. Pokud peak < 0.5 % po >1.5 s → červené varování s návodem. Tlačítko „Průvodce macOS zvukem“ vede k BlackHole / Aggregate.

## 6) Capture diagnostika a bezpečnost (2026-05-07)

- `MusicAudioService.inputLevelNotifier` — peak 0..1 z PCM bytes, throttled na 30 Hz, **vždy aktivní** (i bez AGC).
- `MusicAudioService.captureInfoNotifier` — `MusicCaptureInfo` (backend, label, sr, channels, isLoopback) pro UI diagnostiku.
- **PCM accumulator** přepsaný z `List<int>` (boxed integers, O(n) `removeRange`) na `BytesBuilder` + `Uint8List.sublistView` pro framování. Strop **`_pcmAccMaxBytes = 6 × 8192 B`** zahodí nejstarší data při zaostávání FFT (jinak buffer drží sekundy zvuku a UI vidí mrtvou analýzu po ztichnutí skladby).
- **Logy** capture startu nyní jdou na `Logger.info` i mimo `kDebugMode` (jednorázově), aby uživatelské reporty obsahovaly cestu / zařízení / formát bez extra debug buildu.
- UI: `_MusicCaptureDiagnosticsCard` v `MusicSettingsTab` — popis vstupu + level meter + macOS specifické varování.
