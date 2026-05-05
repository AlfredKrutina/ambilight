import 'dart:math' as math;

import '../../core/models/config_models.dart';
import '../../core/models/smart_lights_models.dart';
import '../../engine/screen/screen_frame.dart';
import '../../services/music/music_types.dart';

/// Vypočte RGB pro jednu [SmartFixture] z engine výstupu a případně snímku obrazovky.
abstract final class FixtureColorResolver {
  static (int r, int g, int b) resolve({
    required SmartFixture fixture,
    required AppConfig config,
    required Map<String, List<(int, int, int)>> perDevice,
    required ScreenFrame? frame,
    MusicAnalysisSnapshot? musicSnapshot,
  }) {
    final b = fixture.binding;
    switch (b.kind) {
      case SmartBindingKind.globalMean:
        return _globalMeanForSmartLights(perDevice, musicSnapshot, config.musicMode);
      case SmartBindingKind.virtualLedRange:
        return _virtualRange(perDevice, b.deviceId, b.ledStart, b.ledEnd, config);
      case SmartBindingKind.screenEdge:
        return _screenEdge(frame, b);
    }
  }

  static (int r, int g, int b) _globalMeanForSmartLights(
    Map<String, List<(int, int, int)>> perDevice,
    MusicAnalysisSnapshot? musicSnapshot,
    MusicModeSettings musicMode,
  ) {
    final base = _globalMean(perDevice);
    if (musicSnapshot == null) return base;
    // Monitor zdroj už nese obraz — nepřimíchávat spektrum (jinak barevný posuv).
    if (musicMode.colorSource == 'monitor') return base;
    final mixScale = musicMode.colorSource == 'spectrum' ? 0.52 : 1.0;
    return _blendMusicSpectrumAccent(base, musicSnapshot, mixScale: mixScale);
  }

  /// Posune barvu podle váženého „centroidu“ spektra — komplement k barvám na pásku v režimu hudba.
  static (int r, int g, int b) _blendMusicSpectrumAccent(
    (int r, int g, int b) base,
    MusicAnalysisSnapshot s, {
    required double mixScale,
  }) {
    final bands = <double>[
      s.subBass.smoothed.clamp(0.0, 1.0),
      s.bass.smoothed.clamp(0.0, 1.0),
      s.lowMid.smoothed.clamp(0.0, 1.0),
      s.mid.smoothed.clamp(0.0, 1.0),
      s.highMid.smoothed.clamp(0.0, 1.0),
      s.presence.smoothed.clamp(0.0, 1.0),
      s.brilliance.smoothed.clamp(0.0, 1.0),
    ];
    var sum = 0.0;
    for (final x in bands) {
      sum += x;
    }
    if (sum < 1e-5) return base;
    double centroid = 0;
    for (var i = 0; i < bands.length; i++) {
      centroid += i * bands[i];
    }
    centroid /= sum;
    final peak = bands.reduce(math.max);
    final mix = (peak * 0.40 * mixScale).clamp(0.0, 0.52);
    final accent = _spectralAccentRgb(centroid);
    return _lerpRgb(base, accent, mix);
  }

  /// [centroid] index 0=sub…6=brilliance → akcentová barva.
  static (int r, int g, int b) _spectralAccentRgb(double centroid) {
    const stops = <(int, int, int)>[
      (210, 55, 75),
      (255, 120, 55),
      (255, 210, 90),
      (130, 255, 130),
      (70, 210, 255),
      (110, 130, 255),
      (220, 120, 255),
    ];
    final t = (centroid / 6.0 * (stops.length - 1)).clamp(0.0, stops.length - 1.000001);
    final i0 = t.floor();
    final i1 = (i0 + 1).clamp(0, stops.length - 1);
    final f = t - i0;
    return _lerpRgb(stops[i0], stops[i1], f);
  }

  static (int r, int g, int b) _lerpRgb(
    (int r, int g, int b) a,
    (int r, int g, int b) b,
    double t,
  ) {
    final u = t.clamp(0.0, 1.0);
    return (
      (a.$1 + (b.$1 - a.$1) * u).round().clamp(0, 255),
      (a.$2 + (b.$2 - a.$2) * u).round().clamp(0, 255),
      (a.$3 + (b.$3 - a.$3) * u).round().clamp(0, 255),
    );
  }

  static (int r, int g, int b) _globalMean(Map<String, List<(int, int, int)>> perDevice) {
    var n = 0;
    var rs = 0, gs = 0, bs = 0;
    for (final list in perDevice.values) {
      for (final c in list) {
        rs += c.$1;
        gs += c.$2;
        bs += c.$3;
        n++;
      }
    }
    if (n == 0) return (0, 0, 0);
    return ((rs / n).round().clamp(0, 255), (gs / n).round().clamp(0, 255), (bs / n).round().clamp(0, 255));
  }

  static (int r, int g, int b) _virtualRange(
    Map<String, List<(int, int, int)>> perDevice,
    String? deviceId,
    int ledStart,
    int ledEnd,
    AppConfig config,
  ) {
    final id = deviceId ??
        (config.globalSettings.devices.isEmpty ? null : config.globalSettings.devices.first.id);
    if (id == null || id.isEmpty) return (0, 0, 0);
    final list = perDevice[id];
    if (list == null || list.isEmpty) return (0, 0, 0);
    final a = ledStart.clamp(0, list.length - 1);
    final b = ledEnd.clamp(0, list.length - 1);
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    var n = 0;
    var rs = 0, gs = 0, bs = 0;
    for (var i = lo; i <= hi; i++) {
      final c = list[i];
      rs += c.$1;
      gs += c.$2;
      bs += c.$3;
      n++;
    }
    if (n == 0) return (0, 0, 0);
    return ((rs / n).round().clamp(0, 255), (gs / n).round().clamp(0, 255), (bs / n).round().clamp(0, 255));
  }

  static (int r, int g, int b) _screenEdge(ScreenFrame? frame, SmartLightBinding b) {
    if (frame == null || !frame.isValid) return (0, 0, 0);
    if (frame.monitorIndex != b.monitorIndex) {
      // Nesoulad monitoru — bez snímku pro jiný index vrátit průměr celého snímku jen pokud index 0 desktop?
      if (b.monitorIndex != 0 && frame.monitorIndex != 0) {
        return (0, 0, 0);
      }
    }
    final rgba = frame.rgba;
    final w = frame.width;
    final h = frame.height;
    final depth = (b.depthPercent.clamp(1.0, 50.0) / 100.0);
    final t0 = b.t0.clamp(0.0, 1.0);
    final t1 = b.t1.clamp(0.0, 1.0);
    final loT = t0 <= t1 ? t0 : t1;
    final hiT = t0 <= t1 ? t1 : t0;

    int x0, x1, y0, y1;
    switch (b.edge) {
      case 'right':
        x0 = (w * (1 - depth)).floor().clamp(0, w - 1);
        x1 = w - 1;
        y0 = (h * loT).floor().clamp(0, h - 1);
        y1 = (h * hiT).ceil().clamp(0, h - 1);
        break;
      case 'top':
        y0 = 0;
        y1 = (h * depth).ceil().clamp(0, h - 1);
        x0 = (w * loT).floor().clamp(0, w - 1);
        x1 = (w * hiT).ceil().clamp(0, w - 1);
        break;
      case 'bottom':
        y0 = (h * (1 - depth)).floor().clamp(0, h - 1);
        y1 = h - 1;
        x0 = (w * loT).floor().clamp(0, w - 1);
        x1 = (w * hiT).ceil().clamp(0, w - 1);
        break;
      case 'left':
      default:
        x0 = 0;
        x1 = (w * depth).ceil().clamp(0, w - 1);
        y0 = (h * loT).floor().clamp(0, h - 1);
        y1 = (h * hiT).ceil().clamp(0, h - 1);
        break;
    }

    var n = 0;
    var rs = 0, gs = 0, bs = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final o = (y * w + x) * 4;
        if (o + 2 < rgba.length) {
          rs += rgba[o];
          gs += rgba[o + 1];
          bs += rgba[o + 2];
          n++;
        }
      }
    }
    if (n == 0) return (0, 0, 0);
    return ((rs / n).round().clamp(0, 255), (gs / n).round().clamp(0, 255), (bs / n).round().clamp(0, 255));
  }
}
