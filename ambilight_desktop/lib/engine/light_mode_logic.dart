import 'dart:math' as math;

import '../core/models/config_models.dart';

/// Parita s `app.py` `_process_light_mode` (+ custom zóny / GRB).
class LightModeLogic {
  LightModeLogic._();

  static List<(int, int, int)> compute(
    AppConfig config,
    int animationTick, {
    int? virtualLedCount,
  }) {
    final settings = config.lightMode;
    final totalLeds = virtualLedCount ?? math.max(1, config.globalSettings.ledCount);
    final r0 = settings.color[0];
    final g0 = settings.color[1];
    final b0 = settings.color[2];
    var brightness = settings.brightness;
    final effect = settings.effect;

    if (effect == 'custom_zones') {
      return _customZones(totalLeds, settings);
    }

    if (effect == 'rainbow') {
      final leds = <(int, int, int)>[];
      final speedFactor = settings.speed / 10.0;
      final hueShift = (DateTime.now().millisecondsSinceEpoch / 1000.0 * speedFactor) % 1.0;
      final br = brightness / 255.0;
      for (var i = 0; i < totalLeds; i++) {
        final hue = (hueShift + (i / totalLeds)) % 1.0;
        final rgb = _hsvToRgb(hue, 1.0, 1.0);
        leds.add((
          (rgb.$1 * 255 * br).round().clamp(0, 255),
          (rgb.$2 * 255 * br).round().clamp(0, 255),
          (rgb.$3 * 255 * br).round().clamp(0, 255),
        ));
      }
      return leds;
    }

    if (effect == 'chase') {
      final leds = List<(int, int, int)>.generate(totalLeds, (_) => (0, 0, 0));
      final speed = settings.speed / 50.0;
      final pos = ((animationTick * speed * 0.5).floor()) % totalLeds;
      for (var i = 0; i < 10; i++) {
        final idx = (pos - i) % totalLeds;
        final fade = 1.0 - (i / 10.0);
        leds[idx] = (
          (r0 * fade).round().clamp(0, 255),
          (g0 * fade).round().clamp(0, 255),
          (b0 * fade).round().clamp(0, 255),
        );
      }
      return leds;
    }

    if (effect == 'breathing') {
      final periodSec = 5.0 - (settings.speed / 100.0 * 4.5);
      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final phase = (t % periodSec) / periodSec;
      final factor = (math.sin(phase * 2 * math.pi) + 1) / 2;
      final minBright = settings.extra / 255.0;
      final brFactor = minBright + (factor * (1.0 - minBright));
      brightness = (brightness * brFactor).round().clamp(0, 255);
    }

    final brFactor = brightness / 255.0;
    final rf = (r0 * brFactor).round().clamp(0, 255);
    final gf = (g0 * brFactor).round().clamp(0, 255);
    final bf = (b0 * brFactor).round().clamp(0, 255);
    return List<(int, int, int)>.filled(totalLeds, (rf, gf, bf), growable: false);
  }

  static List<(int, int, int)> _customZones(int ledCount, LightModeSettings settings) {
    final ledData = List<int>.filled(ledCount * 3, 0);
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (final zone in settings.customZones) {
      var startIdx = ((zone.start / 100.0) * ledCount).floor();
      var endIdx = ((zone.end / 100.0) * ledCount).floor();
      if (startIdx >= endIdx) continue;
      startIdx = startIdx.clamp(0, ledCount);
      endIdx = endIdx.clamp(0, ledCount);
      final r = zone.color[0];
      final g = zone.color[1];
      final b = zone.color[2];
      var brFactor = zone.brightness / 255.0;
      if (zone.effect == 'pulse') {
        var period = 2.0 - (zone.speed / 100.0 * 1.5);
        if (period <= 0) period = 0.1;
        final phase = (t % period) / period;
        final factor = (math.sin(phase * 2 * math.pi) + 1) / 2;
        brFactor *= (0.2 + 0.8 * factor);
      } else if (zone.effect == 'blink') {
        var period = 1.0 - (zone.speed / 100.0 * 0.9);
        if (period <= 0) period = 0.1;
        if ((t % period) >= (period / 2)) {
          brFactor = 0;
        }
      }
      final rF = (r * brFactor).round().clamp(0, 255);
      final gF = (g * brFactor).round().clamp(0, 255);
      final bF = (b * brFactor).round().clamp(0, 255);
      for (var i = startIdx; i < endIdx; i++) {
        ledData[i * 3] = gF;
        ledData[i * 3 + 1] = rF;
        ledData[i * 3 + 2] = bF;
      }
    }
    final mapped = <(int, int, int)>[];
    for (var i = 0; i < ledCount; i++) {
      mapped.add((
        ledData[i * 3 + 1],
        ledData[i * 3],
        ledData[i * 3 + 2],
      ));
    }
    return mapped;
  }

  /// HSV [0,1] → RGB [0,1] per component.
  static (double, double, double) _hsvToRgb(double h, double s, double v) {
    final hh = (h % 1.0) * 6.0;
    final sector = hh.floor();
    final f = hh - sector;
    final p = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));
    switch (sector) {
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
