import 'dart:io';

import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// F3 — golden vzorek JSON (parita s reálným `default.json`, zúženo na pole používaná v Dart).
void main() {
  test('AppConfig.parse golden_default.json — klíčová pole a roundtrip', () async {
    final f = File('test/fixtures/golden_default.json');
    expect(f.existsSync(), isTrue, reason: 'fixture musí být v repu');
    final text = await f.readAsString();
    final cfg = AppConfig.parse(text);

    expect(cfg.globalSettings.devices, hasLength(1));
    expect(cfg.globalSettings.devices.single.id, 'primary');
    expect(cfg.globalSettings.devices.single.type, 'serial');
    expect(cfg.globalSettings.startMode, 'light');
    expect(cfg.globalSettings.theme, 'dark');
    expect(cfg.globalSettings.captureMethod, 'mss');
    expect(cfg.lightMode.effect, 'static');
    expect(cfg.lightMode.color, [255, 200, 100]);
    expect(cfg.lightMode.homekitEnabled, isFalse);
    expect(cfg.screenMode.monitorIndex, 1);
    expect(cfg.musicMode.effect, 'energy');
    expect(cfg.smartLights.enabled, isFalse);
    expect(cfg.smartLights.fixtures, isEmpty);

    final round = AppConfig.parse(cfg.toJsonString());
    expect(round.toJsonString(), cfg.toJsonString());
  });
}
