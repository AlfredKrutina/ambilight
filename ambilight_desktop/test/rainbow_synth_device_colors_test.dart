import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/screen/screen_pipeline_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceSettings _testDevice(String id) => DeviceSettings(
      id: id,
      name: 'Test',
      type: 'wifi',
      port: '',
      ipAddress: '192.168.1.10',
      ledCount: 24,
    );

void main() {
  test('rainbowSynthDeviceColors fills each device strip with 0..255 RGB', () {
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: AppConfig.defaults().globalSettings.copyWith(
        devices: [_testDevice('dev-a')],
      ),
    );
    final m = rainbowSynthDeviceColors(cfg, 0.0);
    expect(m.length, cfg.globalSettings.devices.length);
    for (final d in cfg.globalSettings.devices) {
      final list = m[d.id];
      expect(list, isNotNull);
      final n = list!.length;
      expect(n, greaterThan(0));
      for (final c in list) {
        expect(c.$1, inInclusiveRange(0, 255));
        expect(c.$2, inInclusiveRange(0, 255));
        expect(c.$3, inInclusiveRange(0, 255));
      }
    }
  });

  test('rainbowSynthDeviceColors changes in time (not static)', () {
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: AppConfig.defaults().globalSettings.copyWith(
        devices: [_testDevice('dev-b')],
      ),
    );
    final a = rainbowSynthDeviceColors(cfg, 0.0);
    final b = rainbowSynthDeviceColors(cfg, 3.0);
    final id = cfg.globalSettings.devices.first.id;
    expect(a[id], isNot(equals(b[id])));
  });
}
