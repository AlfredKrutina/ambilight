import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/ambilight_engine.dart';
import 'package:ambilight_desktop/engine/screen/screen_color_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pipeline = ScreenPipelineRuntime();

  test('light + homekit bez control_via_ha stále počítá barvy', () {
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: GlobalSettings(
        startMode: 'light',
        ledCount: 10,
        devices: [
          DeviceSettings(id: 'd1', name: 'T', type: 'wifi', ipAddress: '192.168.1.10', controlViaHa: false),
        ],
      ),
      lightMode: const LightModeSettings(homekitEnabled: true, brightness: 255),
    );
    final out = AmbilightEngine.computeFrame(
      cfg,
      0,
      startupBlackout: false,
      enabled: true,
      screenPipeline: pipeline,
    );
    expect(out['d1'], isNotNull);
    expect(out['d1']!.every((t) => t == (0, 0, 0)), isFalse);
  });

  test('light + homekit + control_via_ha = černo', () {
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: GlobalSettings(
        startMode: 'light',
        devices: [
          DeviceSettings(id: 'd1', name: 'T', type: 'wifi', ipAddress: '192.168.1.10', controlViaHa: true),
        ],
      ),
      lightMode: const LightModeSettings(homekitEnabled: true),
    );
    final out = AmbilightEngine.computeFrame(
      cfg,
      0,
      startupBlackout: false,
      enabled: true,
      screenPipeline: pipeline,
    );
    expect(out['d1'], isNotNull);
    expect(out['d1']!.every((t) => t == (0, 0, 0)), isTrue);
  });
}
