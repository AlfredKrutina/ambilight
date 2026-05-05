import '../../core/models/config_models.dart';

/// Piecewise-linear RGB path along the seven analysis bands (music preset).
class MusicSpectrumPalette {
  MusicSpectrumPalette._();

  static (int, int, int) _tuple(List<int> rgb) {
    if (rgb.length >= 3) {
      return (
        rgb[0].clamp(0, 255),
        rgb[1].clamp(0, 255),
        rgb[2].clamp(0, 255),
      );
    }
    return (255, 255, 255);
  }

  static List<(int, int, int)> stopsFrom(MusicModeSettings s) => [
        _tuple(s.subBassColor),
        _tuple(s.bassColor),
        _tuple(s.lowMidColor),
        _tuple(s.midColor),
        _tuple(s.highMidColor),
        _tuple(s.presenceColor),
        _tuple(s.brillianceColor),
      ];

  static int _clamp255(num v) => v.round().clamp(0, 255);

  static (int, int, int) lerpRgb((int, int, int) a, (int, int, int) b, double t) {
    t = t.clamp(0.0, 1.0);
    return (
      _clamp255(a.$1 + (b.$1 - a.$1) * t),
      _clamp255(a.$2 + (b.$2 - a.$2) * t),
      _clamp255(a.$3 + (b.$3 - a.$3) * t),
    );
  }

  /// [t] in [0, 1] from sub-bass toward brilliance.
  static (int, int, int) at(List<(int, int, int)> stops, double t) {
    if (stops.isEmpty) {
      return (255, 255, 255);
    }
    if (stops.length == 1) {
      return stops.first;
    }
    t = t.clamp(0.0, 1.0);
    final maxI = stops.length - 1;
    final x = t * maxI;
    final i = x.floor().clamp(0, maxI - 1);
    final frac = x - i;
    return lerpRgb(stops[i], stops[i + 1], frac);
  }
}
