# Windows screen capture (E3) — poznámky pro agenty

## Strategie (aktuální)

- **Method channel** `ambilight/screen_capture` (ne FFI) — jednoduchá registrace v `windows/runner/flutter_window.cpp`, CMake jen přidá `.cpp` + `gdi32`.
- **GDI BitBlt** z obrazovkového DC do 32bpp DIB, konverze BGRA → RGBA v C++. Důvod: minimální závislosti, čitelná údržba; vhodné pro ambilight sampling, ne pro HDR reference.

## Vlákna

- `capture` na nativní straně spustí `std::thread`, po dokončení odešle `WM_APP+64` s haldou struktury obsahující `MethodResult` + buffer.
- `TryHandleAmbilightWindowMessage` v `MessageHandler` **před** Flutter plugin hookem.

## Alternativy (P5+)

| Přístup | Poznámka |
|---------|----------|
| Windows.Graphics.Capture | WinRT, lepší pro HDR/moderní okna, víc boilerplate (cppwinrt). |
| DXGI Desktop Duplication | Nízká latence, složitější D3D11, hry / exclusive. |

Dart rozhraní (`ScreenFrame`, `ScreenCaptureSource`) má zůstat stejné; mění se jen C++ implementace za kanálem.

## Konfigurace

- `ScreenModeSettings.monitorIndex` a `LedSegment.monitorIdx` mapují na MSS styl: segmenty v Pythonu používají `target_mss_idx = mon_idx + 1` vůči `sct.monitors`.
