import 'dart:typed_data';

import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/ambilight_engine.dart';
import 'package:ambilight_desktop/engine/screen/screen_color_pipeline.dart';
import 'package:ambilight_desktop/engine/screen/screen_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbilightEngine screen mode', () {
    test('invalid rgba length yields black per device, no throw', () {
      final cfg = AppConfig.defaults().copyWith(
        globalSettings: AppConfig.defaults().globalSettings.copyWith(startMode: 'screen'),
        screenMode: const ScreenModeSettings(
          monitorIndex: 0,
          segments: [
            LedSegment(
              ledStart: 0,
              ledEnd: 0,
              monitorIdx: 0,
              edge: 'top',
              deviceId: 'primary',
            ),
          ],
        ),
      );
      final bad = ScreenFrame(
        monitorIndex: 0,
        width: 4,
        height: 4,
        rgba: Uint8List(16),
      );
      expect(bad.isValid, isFalse);
      final rt = ScreenPipelineRuntime();
      final out = AmbilightEngine.computeFrame(
        cfg,
        1,
        startupBlackout: false,
        enabled: true,
        screenFrame: bad,
        screenPipeline: rt,
      );
      expect(out['primary'], isNotNull);
      expect(out['primary']!.every((c) => c == (0, 0, 0)), isTrue);
    });

    test('prázdné segments → implicitní obvod, ne všechno černá', () {
      final cfg = AppConfig.defaults().copyWith(
        globalSettings: AppConfig.defaults().globalSettings.copyWith(startMode: 'screen'),
        screenMode: const ScreenModeSettings(monitorIndex: 1, segments: []),
      );
      final rt = ScreenPipelineRuntime();
      final out = AmbilightEngine.computeFrame(
        cfg,
        0,
        startupBlackout: false,
        enabled: true,
        screenFrame: MockScreenFrame.gradient(monitorIndex: 1),
        screenPipeline: rt,
      );
      expect(out['primary'], isNotNull);
      final nonBlack = out['primary']!.where((c) => c != (0, 0, 0)).length;
      expect(nonBlack, greaterThan(0));
    });
  });
}
