import 'dart:typed_data';

import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/core/models/smart_lights_models.dart';
import 'package:ambilight_desktop/engine/screen/screen_frame.dart';
import 'package:ambilight_desktop/features/smart_lights/fixture_color_resolver.dart';
import 'package:ambilight_desktop/services/music/music_types.dart';
import 'package:flutter_test/flutter_test.dart';

MusicBandSnapshot _testMusicBand(double smoothed) => MusicBandSnapshot(
      isBeat: false,
      intensity: smoothed,
      smoothed: smoothed,
      energy: smoothed,
    );

void main() {
  test('FixtureColorResolver globalMean', () {
    final fx = SmartFixture(
      id: 'a',
      displayName: 'L',
      binding: const SmartLightBinding(kind: SmartBindingKind.globalMean),
    );
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: GlobalSettings(
        devices: [
          const DeviceSettings(id: 'd1', name: 'D1', type: 'serial', ledCount: 2),
        ],
      ),
    );
    final rgb = FixtureColorResolver.resolve(
      fixture: fx,
      config: cfg,
      perDevice: {
        'd1': [(10, 20, 30), (50, 60, 70)],
      },
      frame: null,
    );
    expect(rgb, (30, 40, 50));
  });

  test('FixtureColorResolver screenEdge left', () {
    final fx = SmartFixture(
      id: 'a',
      displayName: 'L',
      binding: const SmartLightBinding(
        kind: SmartBindingKind.screenEdge,
        monitorIndex: 1,
        edge: 'left',
        t0: 0,
        t1: 1,
        depthPercent: 100,
      ),
    );
    final w = 4;
    final h = 4;
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final o = (y * w + x) * 4;
        rgba[o] = x == 0 ? 255 : 0;
        rgba[o + 1] = 0;
        rgba[o + 2] = 0;
        rgba[o + 3] = 255;
      }
    }
    final frame = ScreenFrame(monitorIndex: 1, width: w, height: h, rgba: rgba);
    final cfg = AppConfig.defaults();
    final rgb = FixtureColorResolver.resolve(
      fixture: fx,
      config: cfg,
      perDevice: {},
      frame: frame,
    );
    // Levý sloupec 4×1 červený zbytek 0 → průměr R = 255×4/16 ≈ 64
    expect(rgb.$1, greaterThan(50));
  });

  test('FixtureColorResolver globalMean blends spectrum accent when not monitor', () {
    final fx = SmartFixture(
      id: 'a',
      displayName: 'L',
      binding: const SmartLightBinding(kind: SmartBindingKind.globalMean),
    );
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: GlobalSettings(
        devices: [
          const DeviceSettings(id: 'd1', name: 'D1', type: 'serial', ledCount: 2),
        ],
      ),
      musicMode: const MusicModeSettings(colorSource: 'fixed'),
    );
    final perDevice = {
      'd1': [(10, 20, 30), (50, 60, 70)],
    };
    final base = FixtureColorResolver.resolve(
      fixture: fx,
      config: cfg,
      perDevice: perDevice,
      frame: null,
    );
    final snap = MusicAnalysisSnapshot(
      subBass: _testMusicBand(0),
      bass: _testMusicBand(1),
      lowMid: _testMusicBand(0),
      mid: _testMusicBand(0),
      highMid: _testMusicBand(0),
      presence: _testMusicBand(0),
      brilliance: _testMusicBand(0),
      overallLoudness: 0.5,
      sampleRate: 48000,
    );
    final tinted = FixtureColorResolver.resolve(
      fixture: fx,
      config: cfg,
      perDevice: perDevice,
      frame: null,
      musicSnapshot: snap,
    );
    expect(base, (30, 40, 50));
    expect(tinted, isNot(equals(base)));
  });

  test('FixtureColorResolver globalMean skips spectrum blend for monitor color source', () {
    final fx = SmartFixture(
      id: 'a',
      displayName: 'L',
      binding: const SmartLightBinding(kind: SmartBindingKind.globalMean),
    );
    final cfg = AppConfig.defaults().copyWith(
      globalSettings: GlobalSettings(
        devices: [
          const DeviceSettings(id: 'd1', name: 'D1', type: 'serial', ledCount: 2),
        ],
      ),
      musicMode: const MusicModeSettings(colorSource: 'monitor'),
    );
    final perDevice = {
      'd1': [(10, 20, 30), (50, 60, 70)],
    };
    final snap = MusicAnalysisSnapshot(
      subBass: _testMusicBand(0),
      bass: _testMusicBand(1),
      lowMid: _testMusicBand(0),
      mid: _testMusicBand(0),
      highMid: _testMusicBand(0),
      presence: _testMusicBand(0),
      brilliance: _testMusicBand(0),
      overallLoudness: 0.5,
      sampleRate: 48000,
    );
    final rgb = FixtureColorResolver.resolve(
      fixture: fx,
      config: cfg,
      perDevice: perDevice,
      frame: null,
      musicSnapshot: snap,
    );
    expect(rgb, (30, 40, 50));
  });
}
