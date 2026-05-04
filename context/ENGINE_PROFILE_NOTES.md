# Profilování výkonu engine (A8 — poznámky pro vývoj)

Cíl: měřit **hlavní tick** (`AmbilightAppController` → `AmbilightEngine.computeFrame` → transport), ne UI překreslení.

## Flutter / Dart DevTools

1. Spusť aplikaci v profile módu:  
   `flutter run --profile` (desktop target dle OS).
2. Otevři **DevTools → Performance** a nahrávej 5–10 s při běžícím ticku (~30 Hz).
3. Hledej dlouhé frame na UI threadu; engine by měl držet CPU v rozumných mezích — při problémech zkontroluj alokace v `LightModeLogic` / `ScreenColorPipeline` (dočasné listy vs reuse bufferu). Těžké části kontroluj na worker isolate: screen, hudba‑monitor, light a pc_health (`ScreenPipelineIsolateBridge`, `MusicFlatStripIsolateBridge`, `LightPcEngineIsolateBridge`).

## Mikrobenchmark v kódu (bez závislosti na CI)

Do dočasného `test/engine_bench_test.dart` (necommitovat jako trvalý pokud je hlučný) lze dát:

```dart
import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/ambilight_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeFrame smoke + čas', () {
    final cfg = AppConfig.defaults();
    final sw = Stopwatch()..start();
    for (var i = 0; i < 500; i++) {
      AmbilightEngine.computeFrame(cfg, i, startupBlackout: false, enabled: true);
    }
    sw.stop();
    // Očekávání: řád stovek ms na desktopu — uprav podle HW.
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
```

Spusť: `flutter test test/engine_bench_test.dart`.

## Co zatím neřešit v CI

Plnohodnotný **benchmark harness** (regrese ms/frame) je náchylný na šum ve sdílených runnerech — GitHub Actions zůstává u `flutter test` + lehkých unit testů; těžké profilování nechte lokálně nebo v samostatném jobu s `runs-on: self-hosted` pokud bude potřeba.

---

*Dokument pro paralelní sprint (Agent A8), 2026-05-03.*
