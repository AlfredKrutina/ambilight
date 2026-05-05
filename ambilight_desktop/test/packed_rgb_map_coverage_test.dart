import 'dart:typed_data';

import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/screen/screen_pipeline_isolate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('packedRgbMapCoversWifiAndSerialOutputs rejects missing device id', () {
    final base = AppConfig.defaults();
    final cfg = base.copyWith(
      globalSettings: base.globalSettings.copyWith(
        devices: [
          const DeviceSettings(
            id: 'devA',
            name: 'A',
            type: 'wifi',
            ipAddress: '192.168.1.2',
            udpPort: 4210,
            ledCount: 10,
            controlViaHa: false,
          ),
        ],
      ),
    );
    expect(packedRgbMapCoversWifiAndSerialOutputs(cfg, {}), isFalse);
    expect(
      packedRgbMapCoversWifiAndSerialOutputs(cfg, {
        'wrong': Uint8List(30),
      }),
      isFalse,
    );
    expect(
      packedRgbMapCoversWifiAndSerialOutputs(cfg, {
        'devA': Uint8List(30),
      }),
      isTrue,
    );
  });

  test('HA-only device does not require packed entry', () {
    final base = AppConfig.defaults();
    final cfg = base.copyWith(
      globalSettings: base.globalSettings.copyWith(
        devices: [
          const DeviceSettings(
            id: 'ha1',
            name: 'H',
            type: 'wifi',
            ipAddress: '192.168.1.2',
            udpPort: 4210,
            ledCount: 10,
            controlViaHa: true,
          ),
        ],
      ),
    );
    expect(packedRgbMapCoversWifiAndSerialOutputs(cfg, {}), isTrue);
  });
}
