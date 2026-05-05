import 'dart:io';

import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// F3 — golden vzorek JSON (parita s reálným `default.json`, zúženo na pole používaná v Dart).
void main() {
  test('GlobalSettings: prázdný firmware_manifest_url → výchozí GitHub Pages', () {
    final g = GlobalSettings.fromJson({'firmware_manifest_url': ''});
    expect(g.firmwareManifestUrl, kAmbilightFirmwareManifestUrl);
  });

  test('normalizeAmbilightPerformanceScreenLoopPeriodMs clamps', () {
    expect(normalizeAmbilightPerformanceScreenLoopPeriodMs(40), 40);
    expect(normalizeAmbilightPerformanceScreenLoopPeriodMs(10), 16);
    expect(normalizeAmbilightPerformanceScreenLoopPeriodMs(99), 40);
  });

  test('normalizeAmbilightUiTheme: legacy dark → dark_blue, snowrunner zůstane', () {
    expect(normalizeAmbilightUiTheme('dark'), 'dark_blue');
    expect(normalizeAmbilightUiTheme('DARK_BLUE'), 'dark_blue');
    expect(normalizeAmbilightUiTheme('snowrunner'), 'snowrunner');
    expect(normalizeAmbilightUiTheme('coffee'), 'coffee');
    expect(normalizeAmbilightUiTheme('light'), 'light');
  });

  test('GlobalSettings: chybějící onboarding_completed → legacy dokončeno', () {
    final g = GlobalSettings.fromJson({'devices': []});
    expect(g.onboardingCompleted, isTrue);
    final fresh = const GlobalSettings(devices: []);
    expect(fresh.onboardingCompleted, isFalse);
  });

  test('GlobalSettings: pc_health (Python) → pchealth', () {
    final g = GlobalSettings.fromJson({'start_mode': 'pc_health'});
    expect(g.startMode, 'pchealth');
    final g2 = GlobalSettings.fromJson({'start_mode': 'PC-Health'});
    expect(g2.startMode, 'pchealth');
  });

  test('AppConfig.parse golden_default.json — klíčová pole a roundtrip', () async {
    final f = File('test/fixtures/golden_default.json');
    expect(f.existsSync(), isTrue, reason: 'fixture musí být v repu');
    final text = await f.readAsString();
    final cfg = AppConfig.parse(text);

    expect(cfg.globalSettings.devices, hasLength(1));
    expect(cfg.globalSettings.devices.single.id, 'primary');
    expect(cfg.globalSettings.devices.single.type, 'serial');
    expect(cfg.globalSettings.startMode, 'light');
    expect(cfg.globalSettings.performanceScreenLoopPeriodMs, 40);
    expect(cfg.globalSettings.theme, 'dark_blue');
    expect(cfg.globalSettings.captureMethod, 'mss');
    expect(cfg.lightMode.effect, 'static');
    expect(cfg.lightMode.color, [255, 200, 100]);
    expect(cfg.lightMode.homekitEnabled, isFalse);
    expect(cfg.screenMode.monitorIndex, 1);
    expect(cfg.musicMode.effect, 'energy');
    expect(cfg.smartLights.enabled, isFalse);
    expect(cfg.smartLights.fixtures, isEmpty);
    expect(cfg.globalSettings.firmwareManifestUrl, kAmbilightFirmwareManifestUrl);
    expect(cfg.globalSettings.onboardingCompleted, isTrue);

    final round = AppConfig.parse(cfg.toJsonString());
    expect(round.toJsonString(), cfg.toJsonString());
  });
}
