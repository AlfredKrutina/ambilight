import '../../core/json/json_utils.dart';

/// Parita s `app.py` `_get_gradient_color` / `_interpolate_rgb`.
class PcHealthGradients {
  PcHealthGradients._();

  static (int, int, int) interpolateRgb((int, int, int) a, (int, int, int) b, double t) {
    final u = t.clamp(0.0, 1.0);
    return (
      (a.$1 + (b.$1 - a.$1) * u).round().clamp(0, 255),
      (a.$2 + (b.$2 - a.$2) * u).round().clamp(0, 255),
      (a.$3 + (b.$3 - a.$3) * u).round().clamp(0, 255),
    );
  }

  static (int, int, int) gradientColor(
    double value,
    double minVal,
    double maxVal,
    String scaleType, {
    List<dynamic>? colorLow,
    List<dynamic>? colorMid,
    List<dynamic>? colorHigh,
  }) {
    final t = maxVal != minVal
        ? ((value - minVal) / (maxVal - minVal)).clamp(0.0, 1.0)
        : 0.5;

    if (scaleType == 'custom') {
      final low = _rgbTuple(colorLow, (0, 0, 255));
      final mid = _rgbTuple(colorMid, (0, 255, 0));
      final high = _rgbTuple(colorHigh, (255, 0, 0));
      if (t < 0.5) {
        return interpolateRgb(low, mid, t * 2);
      }
      return interpolateRgb(mid, high, (t - 0.5) * 2);
    }

    if (scaleType == 'blue_green_red') {
      if (t < 0.5) {
        return interpolateRgb((0, 0, 255), (0, 255, 0), t * 2);
      }
      return interpolateRgb((0, 255, 0), (255, 0, 0), (t - 0.5) * 2);
    }

    if (scaleType == 'cool_warm') {
      if (t < 0.5) {
        return interpolateRgb((0, 255, 255), (255, 255, 255), t * 2);
      }
      return interpolateRgb((255, 255, 255), (255, 128, 0), (t - 0.5) * 2);
    }

    if (scaleType == 'cyan_yellow') {
      return interpolateRgb((0, 255, 255), (255, 255, 0), t);
    }

    if (scaleType == 'rainbow') {
      final h = t;
      return _hsvToRgbByte(h, 1.0, 1.0);
    }

    return (255, 255, 255);
  }

  static (int, int, int) _rgbTuple(List<dynamic>? raw, (int, int, int) fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    final rgb = asRgb(raw);
    return (rgb[0], rgb[1], rgb[2]);
  }

  static (int, int, int) _hsvToRgbByte(double h, double s, double v) {
    final rgb = _hsvToRgbFloat(h, s, v);
    return (
      (rgb.$1 * 255).round().clamp(0, 255),
      (rgb.$2 * 255).round().clamp(0, 255),
      (rgb.$3 * 255).round().clamp(0, 255),
    );
  }

  static (double, double, double) _hsvToRgbFloat(double h, double s, double v) {
    final hh = (h % 1.0) * 6.0;
    final i = hh.floor();
    final f = hh - i;
    final p = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));
    switch (i) {
      case 0:
        return (v, t, p);
      case 1:
        return (q, v, p);
      case 2:
        return (p, v, t);
      case 3:
        return (p, q, v);
      case 4:
        return (t, p, v);
      default:
        return (v, p, q);
    }
  }
}
