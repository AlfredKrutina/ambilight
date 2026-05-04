# Profilování: sekání Flutter UI vs výstup na ESP

## Cíl

Rozlišit **main isolate** (UI + `_tick`) od problémů **Wi‑Fi / FW** na ESP.

## Postup

1. Spusť aplikaci v profilu:  
   `flutter run --profile -d windows` (nebo linux / macos).
2. Otevři **DevTools → Performance**, nahraj 10–20 s při zapnutém ambilight režimu a případně s otevřeným **Nastavením**.
3. Hledej **dlouhé frame** (> 16 ms) na UI threadu — zoom na stack: často `AmbilightAppController._tick`, `notifyListeners`, rebuildy `MaterialApp` / settings stromu.
4. Volitelně **CPU profiler** — top funkce pod `_tick` → `_distribute` → `scheduleMicrotask`.

## Co už je ve kódu oddělené

- Snímání obrazovky: nativní vlákno + doručení na message loop (viz `ambilight_desktop/README.md`).
- Těžší výpočty: část režimů běží v **isolates** (screen pipeline, music flat, …).

## Když jank přetrvává

- Zkontroluj frekvenci rebuildů nastavení (velké `ListView` / animace).
- Ověř, že při minimalizaci do tray systém nezpomaluje timery (známé chování některých OS).

## ESP strana

Sekání **pásku** při plynulém UI často nesouvisí s Flutter profilem — viz [REPRO_MATRIX_FLUTTER_ESP.md](REPRO_MATRIX_FLUTTER_ESP.md) a [ESP_UDP_TRANSPORT_NOTES.md](ESP_UDP_TRANSPORT_NOTES.md).
