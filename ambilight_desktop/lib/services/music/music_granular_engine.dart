import '../../core/models/config_models.dart';
import '../../core/protocol/serial_frame.dart';
import '../../engine/screen/screen_color_pipeline.dart';
import '../../engine/screen/screen_frame.dart';
import 'music_segment_renderer.dart';
import 'music_types.dart';

/// Port `app.py` `_process_granular_music_logic` + sloučení do jednoho flat bufferu pro `_distribute`.
class MusicGranularEngine {
  MusicGranularEngine._();

  /// Vrátí RGB pro každé LED v pořadí [device0 led0..n-1, device1 ...] jako v `AmbilightAppController._distribute`.
  static List<(int, int, int)> computeFlatStrip(
    AppConfig config,
    MusicAnalysisSnapshot analysis,
    double timeSec, {
    ScreenFrame? monitorSample,
  }) {
    final devices = config.globalSettings.devices;
    if (devices.isEmpty) {
      final n = config.globalSettings.ledCount.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice);
      return MusicSegmentRenderer.render(
        effect: config.musicMode.effect,
        numLeds: n,
        settings: config.musicMode,
        analysis: analysis,
        seg: null,
        timeSec: timeSec,
        monitorSample: monitorSample,
      );
    }

    final buffers = <String, List<(int, int, int)>>{};
    for (final d in devices) {
      final dn = ScreenColorPipeline.effectiveDeviceLedCount(config, d);
      buffers[d.id] = List<(int, int, int)>.filled(dn, (0, 0, 0), growable: false);
    }

    final segments = config.screenMode.segments;
    final settings = config.musicMode;

    String effectForSegment(LedSegment seg) =>
        seg.musicEffect == 'default' || seg.musicEffect.isEmpty ? settings.effect : seg.musicEffect;

    if (segments.isEmpty) {
      for (final d in devices) {
        var devId = d.id;
        if (buffers[devId] == null) continue;
        final pixels = MusicSegmentRenderer.render(
          effect: settings.effect,
          numLeds: ScreenColorPipeline.effectiveDeviceLedCount(config, d),
          settings: settings,
          analysis: analysis,
          seg: null,
          timeSec: timeSec,
          monitorSample: monitorSample,
        );
        buffers[devId] = pixels;
      }
    } else {
      for (final seg in segments) {
        var devId = seg.deviceId;
        if (devId == null || devId == 'primary') {
          if (devices.isNotEmpty) {
            devId = devices.first.id;
          }
        }
        final buf = buffers[devId];
        if (buf == null) continue;

        final numLeds = (seg.ledEnd - seg.ledStart).abs() + 1;
        if (numLeds <= 0) continue;

        var pixels = MusicSegmentRenderer.render(
          effect: effectForSegment(seg),
          numLeds: numLeds,
          settings: settings,
          analysis: analysis,
          seg: seg,
          timeSec: timeSec,
          monitorSample: monitorSample,
        );
        if (seg.reverse) {
          pixels = pixels.reversed.toList();
        }
        final start = seg.ledStart;
        final count = numLeds < pixels.length ? numLeds : pixels.length;
        for (var i = 0; i < count; i++) {
          final idx = start + i;
          if (idx >= 0 && idx < buf.length) {
            buf[idx] = pixels[i];
          }
        }
      }
    }

    final out = <(int, int, int)>[];
    for (final d in devices) {
      final b = buffers[d.id]!;
      final dn = ScreenColorPipeline.effectiveDeviceLedCount(config, d);
      for (var i = 0; i < dn; i++) {
        out.add(i < b.length ? b[i] : (0, 0, 0));
      }
    }
    return out;
  }
}
