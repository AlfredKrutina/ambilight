import 'dart:math' as math;

import '../../core/models/config_models.dart';
import 'music_types.dart';

/// Reaktivní „smart“ vizualizace: spektrum, beaty, melodie a plynulý stav mezi snímky
/// (deterministické mapování v reálném čase — bez externího ML API).
class MusicSmartMusicEffect {
  MusicSmartMusicEffect._();

  static double _drive = 0;
  static double _hue = 0.42;
  static double _flash = 0;
  static double _sparkPos = 0.5;

  static List<(int, int, int)> render({
    required int numLeds,
    required MusicModeSettings settings,
    required MusicAnalysisSnapshot analysis,
    required double timeSec,
    required String role,
    required (int, int, int) cBass,
    required (int, int, int) cMid,
    required (int, int, int) cHigh,
    required double vSub,
    required double vBass,
    required double vLowMid,
    required double vMid,
    required double vHighMid,
    required double vHigh,
    required double vBril,
  }) {
    final minV = (settings.minBrightness / 255.0).clamp(0.0, 1.0);

    final beatHit = analysis.bass.isBeat ||
        analysis.lowMid.isBeat ||
        analysis.mid.isBeat ||
        analysis.brilliance.isBeat ||
        analysis.melodyBeat ||
        analysis.melodyOnset;
    if (beatHit) {
      _flash = math.min(1.0, _flash + 0.5);
    } else {
      _flash *= 0.86;
    }

    var composite = 0.18 * vSub + 0.32 * vBass + 0.18 * vLowMid + 0.22 * vMid + 0.10 * vBril;
    if (role == 'bass') {
      composite = 0.28 * vSub + 0.42 * vBass + 0.18 * vLowMid + 0.12 * vMid;
    } else if (role == 'high' || role == 'highs') {
      composite = 0.12 * vMid + 0.22 * vHighMid + 0.38 * vHigh + 0.28 * vBril;
    } else if (role == 'mid' || role == 'mids') {
      composite = 0.12 * vBass + 0.28 * vLowMid + 0.38 * vMid + 0.22 * vHighMid;
    } else if (role == 'ambience') {
      composite = 0.2 * vLowMid + 0.35 * vMid + 0.25 * vHighMid + 0.2 * vBril;
    }
    composite = composite.clamp(0.0, 1.0);
    _drive += (composite - _drive) * 0.22;

    var targetHue = _hue;
    final conf = analysis.melodyPitchConfidence.clamp(0.0, 1.0);
    final nc = analysis.melodyNoteClass;
    if (conf > 0.22 && nc >= 0 && nc <= 11) {
      targetHue = nc / 12.0 + conf * 0.04 * math.sin(timeSec * 2.1);
    } else {
      targetHue += (0.0028 + 0.0065 * _drive) * (1.0 + 0.35 * math.sin(timeSec * 0.55));
    }
    targetHue %= 1.0;
    var dh = targetHue - _hue;
    if (dh > 0.5) {
      dh -= 1.0;
    } else if (dh < -0.5) {
      dh += 1.0;
    }
    _hue = (_hue + dh * 0.085) % 1.0;
    if (_hue < 0) {
      _hue += 1.0;
    }

    _sparkPos += 0.0038 + vHigh * 0.014 + _drive * 0.009 + _flash * 0.004;
    _sparkPos %= 1.0;

    final n = math.max(1, numLeds - 1);
    final out = List<(int, int, int)>.filled(numLeds, (0, 0, 0), growable: false);
    final phase = timeSec * (1.85 + 3.6 * _drive);

    for (var i = 0; i < numLeds; i++) {
      final pos = i / n;
      double local;
      switch (role) {
        case 'bass':
          local = (vSub * (1.0 - pos) + vBass * (1.0 - pos * 0.6) + vLowMid * pos * 0.5).clamp(0.0, 1.0);
          break;
        case 'high':
        case 'highs':
          local = (vMid * 0.25 + vHighMid * 0.35 + vHigh * (0.35 + pos * 0.45) + vBril * (0.5 + pos * 0.5)).clamp(0.0, 1.0);
          break;
        case 'mid':
        case 'mids':
          local = (vLowMid * (1.0 - pos) * 0.35 + vMid * 0.45 + vHighMid * pos * 0.45).clamp(0.0, 1.0);
          break;
        case 'ambience':
          local = (0.2 * vLowMid + 0.35 * vMid + 0.3 * vHighMid + 0.25 * vBril) *
              (0.55 + 0.45 * math.sin(pos * math.pi * 2 + phase * 0.5));
          local = local.clamp(0.0, 1.0);
          break;
        default:
          local = (vBass * (1.0 - pos) * 0.35 + vMid * 0.4 + vHigh * pos * 0.35 + vBril * 0.25 * math.sin(pos * math.pi)).clamp(0.0, 1.0);
      }

      final w =
          0.5 + 0.5 * math.sin(pos * math.pi * 4.2 + phase) * (0.28 + 0.72 * vBass.clamp(0.0, 1.0));
      final w2 = 0.5 + 0.5 * math.cos(pos * math.pi * 7.0 - phase * 1.15) * (0.2 + 0.8 * vMid.clamp(0.0, 1.0));
      final dSpark = pos - _sparkPos;
      final spark = math.exp(-dSpark * dSpark * 110) * (0.55 * vBril + 0.35 * _flash);

      final sat = (0.52 + 0.43 * math.min(1.0, _drive + _flash * 0.35)).clamp(0.0, 1.0);
      final hue = (_hue + pos * 0.11 + vMid * 0.06 * math.sin(pos * math.pi * 6)) % 1.0;
      var val = minV +
          (1.0 - minV) *
              ((0.12 + 0.88 * _drive) * (0.5 + 0.5 * w * w2) + 0.42 * _flash * (0.35 + spark) + 0.32 * spark).clamp(0.0, 1.0);
      val = val.clamp(minV, 1.0);

      final ai = _hsvToRgb(hue, sat, val);

      final cUser = _interpolate3(cBass, cMid, cHigh, pos);
      final u = _valScale(cUser, local.clamp(0.0, 1.0));
      final mix = (0.26 + 0.34 * _drive + 0.18 * _flash).clamp(0.0, 0.82);
      out[i] = _lerpRgb(ai, u, mix);
    }
    return out;
  }

  static (int, int, int) _interpolate3(
    (int, int, int) a,
    (int, int, int) b,
    (int, int, int) c,
    double t,
  ) {
    if (t < 0.5) {
      return _lerpRgb(a, b, t * 2.0);
    }
    return _lerpRgb(b, c, (t - 0.5) * 2.0);
  }

  static (int, int, int) _lerpRgb((int, int, int) p, (int, int, int) q, double t) {
    t = t.clamp(0.0, 1.0);
    return (
      _clamp255(p.$1 + (q.$1 - p.$1) * t),
      _clamp255(p.$2 + (q.$2 - p.$2) * t),
      _clamp255(p.$3 + (q.$3 - p.$3) * t),
    );
  }

  static (int, int, int) _valScale((int, int, int) c, double v) => (
        _clamp255(c.$1 * v),
        _clamp255(c.$2 * v),
        _clamp255(c.$3 * v),
      );

  static int _clamp255(num v) => v.round().clamp(0, 255);

  static (int, int, int) _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h * 6) % 2 - 1).abs());
    final m = v - c;
    double rp = 0, gp = 0, bp = 0;
    final region = (h * 6).floor() % 6;
    switch (region) {
      case 0:
        rp = c;
        gp = x;
        break;
      case 1:
        rp = x;
        gp = c;
        break;
      case 2:
        gp = c;
        bp = x;
        break;
      case 3:
        gp = x;
        bp = c;
        break;
      case 4:
        rp = x;
        bp = c;
        break;
      default:
        rp = c;
        bp = x;
    }
    int q(double t) => ((t + m) * 255).round().clamp(0, 255);
    return (q(rp), q(gp), q(bp));
  }
}
