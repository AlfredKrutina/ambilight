# Screen color pipeline (Dart) vs Python

## Zdroj dat

- **Python:** `CaptureThread` (MSS) → BGRA NumPy, ROI z `_recalc_geometry_cache`, `cv2.resize(..., INTER_AREA)` podél hrany na počet LED.
- **Dart:** `ScreenFrame` RGBA (`Uint8List`), stejné ROI jako v `capture.py` (`segmentRoi`). Místo OpenCV: průměr přes hloubku ROI (sloupce u top/bottom, řádky u left/right), pak box-resample na `ledCount` (area-like).
- **Orchestrace:** `AmbilightAppController` v režimu `screen` spouští asynchronně `ScreenCaptureSource.captureFrame(screenMode.monitorIndex)` (single-flight); do `AmbilightEngine.computeFrame` jde poslední platný snímek, při absenci/chybě zůstane předchozí nebo fallback mock v engine.

## Barvy

- **Python:** vždy jemný HSV boost (1.2) + pevná gamma 2.2, volitelná ultra saturace, pak `apply_color_correction`.
- **Dart:** `saturationBoost` a `gamma` z `ScreenModeSettings`, stejná volitelná ultra větev jako v `capture.py`, kalibrace jako `color_correction.apply_color_correction` (profil z `calibration_profiles[active_calibration_profile]` nebo legacy `color_calibration`). `min_brightness` jako dorovnání luminance (Python nemá v capture vláknu; v Dartu po kalibraci).

## Mapování na zařízení

- **Python:** `captured_leds[(device_id, led_idx)]` → `_process_screen_mode` plní `device_buffers`. Lookup klíč používá **raw** `device_id` z segmentu (např. `primary`).
- **Dart:** stejné klíče `(deviceId, ledIdx)`; `ledIdx` včetně `reverse` jako v capture. Sloučení do bufferu zapisuje na stejný fyzický `ledIdx` (shoda s capture, ne s případnou chybou v Python `app.py` smyčce u `reverse`).

## Časové vyhlazení

- **Python:** u screen dict větev často nevolá `interpolate_colors` před odesláním; stav `smooth_ms` je ale nastaven.
- **Dart:** EMA nad **per-device** buffery, `alpha = min(1, dt_ms / interpolation_ms)` jako `AppState.interpolate_colors`; při `interpolation_ms <= 0` se posílá přímo cíl.

## Výkon

- Jednorázový pracovní buffer `rgbStripWork` v `ScreenPipelineRuntime` (žádné alokace na segment při stabilním max. délce segmentu).
- Volitelný mock snímek: `MockScreenFrame.gradient` v `AmbilightEngine`, dokud reálný `ScreenCaptureSource` nepředává `screenFrame` do `computeFrame`.
