# Music mód — stav portu (Flutter `ambilight_desktop`)

Aktualizace: 2026-05-03 (A4: melody, AGC, monitor barvy, per-segment). FW beze změny.

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
