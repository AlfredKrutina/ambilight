# UDP odesílání — strategie (Fáze 2 plánu)

## Stav po Fázi 1

- Hlavní izolát: **eager** `_distribute` po výstupu screen worker izolátu (`AMBI_SCREEN_EAGER_DISTRIBUTE`, default `true`).
- **Noop tick**: při nezměněném `seq` oproti `_lastDistributedScreenSeq` jen `SmartLightCoordinator.onFrame` (žádný opakovaný `sendColors` na pásek).
- UDP transport: jedna **async fronta** na zařízení (`_rgbLatestJob`, latest wins), dedupe stejného rámce v `_emitFramePacedRgb`; screen izolát může na Wi‑Fi volat `sendPackedRgbBytes` (bez převodu tuple→bytes na main thread před frontou).
- Čekání `_waitRgbTransportIdle` / smyčka v `sendColorsNow` má **horní limit** (~10 s) + log, aby kalibrace nevisela při zaseknutém workeru.

## Rozhodnutí: send-only isolate vs nativní vlákno (B / C)

**Nejdřív měřit** po Fázi 1 (`AMBI_PIPELINE_DIAGNOSTICS`): `distributeCalls`, `noopTickSmartOnly`, `eagerFlush`, `capToIsolateAvgMs` (průměr v ms), UDP `emitAvgMs` / `superseded`.

- Pokud je úzké hrdlo stále **Dart async** u `_emitFramePacedRgb` (2000 LED, mnoho datagramů), zvážit **B**: dedikovaný izolát jen pro `RawDatagramSocket` + fronta `Uint8List` (socket vytvořen v tom izolátu).
- **C** (C++ vlákno v pluginu) dává smysl při jedné binárce s nativním capture (ROI v C++) — kombinovat s [PIPELINE_NATIVE_ROI.md](PIPELINE_NATIVE_ROI.md).

PyQt se neembeduje; cílem je stejná disciplína front a jedna odesílací cesta.
