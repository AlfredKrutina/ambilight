# E7 — Process-attached capture (kontrakt)

## Cíl (MASTER E7)

Volitelný zdroj snímání pro screen režim: místo celého monitoru vrátit bitmapu aktivního okna nebo vybraného procesu (PID).

## Dart kontrakt

Soubor: `ambilight_desktop/lib/features/process_capture/process_capture_contract.dart`

- **`ProcessCaptureTarget`** — `processId` (OS PID), volitelně `executableName` pro UI.
- **`ProcessCaptureFrame`** — `width`, `height`, `rgba` (RGBA row-major), `isValid`.
- **`ProcessCaptureSource`** — `capture(target)` → `null` pokud není k dispozici / zamítnuto oprávněními.
- **`ProcessCaptureStub`** — vždy `null` (aktuální stav).

## Napojení (další kroky)

1. **A1:** Win (WGC `GraphicsCaptureItem` z HWND/PID), Linux (PipeWire portal / heuristika), macOS (ScreenCaptureKit window pick).
2. **A2:** V engine zvolit zdroj: `ScreenFrame` z monitoru **nebo** převod `ProcessCaptureFrame` → stejný typ jako `ScreenFrame` / sdílený buffer pro `ScreenColorPipeline`.
3. **UI (A6/A3):** výběr procesu z task listu + uložení PID do configu (nové pole — migrace JSON).

## Oprávnění

- Windows: žádný extra consent u WGC pro vlastní okno; cizí okna dle buildu.
- macOS: Screen Recording permission.
- Linux: závislost na compositoru / Portálu.

Firmware ESP se nemění.
