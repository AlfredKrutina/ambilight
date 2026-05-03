import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/ambilight_engine.dart';
import 'package:ambilight_desktop/engine/screen/screen_color_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('musicAlbumDominantRgb vyplní celý virtuální pás', () {
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: AppConfig.defaults().globalSettings.copyWith(startMode: 'music'),
    );
    final out = AmbilightEngine.computeFrame(
      cfg,
      0,
      startupBlackout: false,
      enabled: true,
      screenPipeline: ScreenPipelineRuntime(),
      musicAlbumDominantRgb: (12, 34, 56),
    );
    expect(out['primary'], isNotNull);
    expect(out['primary']!.every((c) => c == (12, 34, 56)), isTrue);
  });
}
