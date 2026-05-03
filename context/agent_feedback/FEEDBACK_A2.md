# Feedback — Agent A2 (Dart screen pipeline + engine)

## Běh 2026-05-03

## Shrnutí (3–6 vět)

Sloučil jsem duplicitní typ `ScreenFrame` do jednoho zdroje v `lib/engine/screen/screen_frame.dart` (včetně `detachForIsolate` / `importFromIsolate` z původní features vrstvy) a `lib/features/screen_capture/screen_frame.dart` teď jen re-exportuje engine typ, aby pipeline a MethodChannel vracely identickou strukturu. `AmbilightAppController` v režimu `screen` spouští asynchronní `ScreenCaptureSource.captureFrame(screenMode.monitorIndex)` ve single-flight režimu, do engine posílá poslední platný snímek; při chybě se drží předchozí frame, při prvním běhu bez dat zůstává chování engine (mock gradient). Při opuštění screen módu se maže cache snímku a resetuje temporal smoothing. Dokument `SCREEN_COLOR_PIPELINE.md` doplněn o orchestraci; přidán test `test/ambilight_engine_screen_test.dart` pro nevalidní frame → černá bez výjimky.

## Co se povedlo (bullet)

- Jednotný `ScreenFrame` pro `ScreenColorPipeline` i `ScreenCaptureSource`.
- Napojení reálného capture na hlavní smyčku (~30 Hz) s `unawaited` + `_screenCaptureInFlight`.
- `monitorIndex` z `ScreenModeSettings` předán nativní vrstvě beze změny kontraktu.
- Úklid při `dispose` a při přepnutí módu ze `screen`.
- Test odolnosti proti špatné délce `rgba` v screen větvi engine.

## Co se nepovedlo / blokery (bullet)

- `flutter analyze` / `flutter test` na tomto stroji nešly spustit (CLI `flutter`/`dart` není v PATH) — ověření prosím u koordinátora nebo v CI.

## Konflikty s jinými agenty (soubory + doporučení merge)

- `lib/application/ambilight_app_controller.dart` — sdílený s A5 (Spotify/PC health); při merge řešit importy a `_tick` konzistentně (menší PR preferuje rebase).
- `lib/engine/screen/screen_frame.dart` — vlastně A2; A1/A8 by neměly měnit signaturu bez dohody s pipeline testy.

## Otevřené TODO pro další běh

- Zvážit throttling capture podle skutečné latence nativní vrstvy (A1) místo pevného ticku.
- Multi-monitor: UI pro výběr monitoru vs `listMonitors()` (může být A6).
- Parita `LedSegment.monitorIdx` vs virtuální desktop index `0` — ověřit proti Python MSS na reálných datech.

## Příkazy ověřené (např. flutter analyze, flutter test)

- IDE linter na upravených souborech: bez hlášení.
- Doporučené po merge: `cd ambilight_desktop && flutter test test/ambilight_engine_screen_test.dart test/screen_color_pipeline_test.dart test/screen_capture_contract_test.dart && flutter analyze`.
