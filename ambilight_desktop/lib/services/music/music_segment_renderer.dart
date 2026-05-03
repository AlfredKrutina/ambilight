import 'dart:math' as math;

import '../../core/models/config_models.dart';
import '../../engine/screen/screen_frame.dart';
import 'music_melody_smart_effect.dart';
import 'music_monitor_palette.dart';
import 'music_types.dart';

/// Port `app.py` `_render_segment_effect` (základní efekty + role podle segmentu).
class MusicSegmentRenderer {
  MusicSegmentRenderer._();

  static double _agcPeak = 0.1;

  static List<(int, int, int)> render({
    required String effect,
    required int numLeds,
    required MusicModeSettings settings,
    required MusicAnalysisSnapshot analysis,
    required LedSegment? seg,
    required double timeSec,
    ScreenFrame? monitorSample,
  }) {
    var role = 'all';
    var edge = 'unknown';
    if (seg != null) {
      role = seg.role;
      edge = seg.edge;
      if (role == 'auto') {
        if (edge == 'bottom') {
          role = 'bass';
        } else if (edge == 'top') {
          role = 'high';
        } else if (edge == 'left' || edge == 'right') {
          role = 'mid';
        } else {
          role = 'all';
        }
      }
    }

    final globalGain = settings.globalSensitivity / 50.0;
    var sensBass = (settings.bassSensitivity / 50.0) * globalGain;
    var sensMid = (settings.midSensitivity / 50.0) * globalGain;
    var sensHigh = (settings.highSensitivity / 50.0) * globalGain;

    if (settings.autoMid) {
      sensMid *= 1.0 + (1.0 - analysis.mid.smoothed) * 0.5;
    }
    if (settings.autoHigh) {
      final t = _trebleSmoothed(analysis);
      sensHigh *= 1.0 + (1.0 - t) * 0.5;
    }

    var agcGain = 1.0;
    if (settings.autoGain) {
      final rawMax = [
        analysis.subBass.smoothed,
        analysis.bass.smoothed,
        analysis.lowMid.smoothed,
        analysis.mid.smoothed,
        analysis.highMid.smoothed,
        analysis.presence.smoothed,
        analysis.brilliance.smoothed,
      ].reduce(math.max);
      _agcPeak = math.max(_agcPeak * 0.96, rawMax);
      if (_agcPeak < 0.10) {
        _agcPeak = 0.10;
      }
      agcGain = 1.0 / _agcPeak;
    }

    double getBand(String name, double mult) {
      var raw = analysis.named(name).smoothed * agcGain;
      if (settings.autoGain && raw < 0.05) {
        raw = 0;
      }
      return math.min(1.0, raw * mult);
    }

    final vSub = getBand('sub_bass', sensBass);
    final vBass = getBand('bass', sensBass);
    final vMid = getBand('mid', sensMid);
    final vHigh = _trebleSmoothed(analysis) * sensHigh;

    var cBass = (255, 255, 255);
    var cMid = (255, 255, 255);
    var cHigh = (255, 255, 255);
    final colSource = settings.colorSource;
    if (colSource == 'fixed') {
      final fc = settings.fixedColor;
      if (fc.length >= 3) {
        cBass = cMid = cHigh = (fc[0], fc[1], fc[2]);
      }
    } else if (colSource == 'monitor') {
      if (monitorSample != null && monitorSample.isValid) {
        final rgb = dominantRgbFromFrame(monitorSample);
        cBass = cMid = cHigh = rgb;
      } else {
        final p = settings.presenceColor;
        if (p.length >= 3) {
          cBass = cMid = cHigh = (p[0], p[1], p[2]);
        }
      }
    } else {
      if (settings.bassColor.length >= 3) {
        cBass = (settings.bassColor[0], settings.bassColor[1], settings.bassColor[2]);
      }
      if (settings.midColor.length >= 3) {
        cMid = (settings.midColor[0], settings.midColor[1], settings.midColor[2]);
      }
      if (settings.presenceColor.length >= 3) {
        cHigh = (settings.presenceColor[0], settings.presenceColor[1], settings.presenceColor[2]);
      }
    }

    int clamp255(num v) => v.round().clamp(0, 255);

    (int, int, int) valScale((int, int, int) c, double v) => (
          clamp255(c.$1 * v),
          clamp255(c.$2 * v),
          clamp255(c.$3 * v),
        );

    (int, int, int) interpolate((int, int, int) c1, (int, int, int) c2, double t) {
      t = t.clamp(0.0, 1.0);
      return (
        clamp255(c1.$1 + (c2.$1 - c1.$1) * t),
        clamp255(c1.$2 + (c2.$2 - c1.$2) * t),
        clamp255(c1.$3 + (c2.$3 - c1.$3) * t),
      );
    }

    final targets = List<(int, int, int)>.filled(numLeds, (0, 0, 0), growable: false);

    if (effect.contains('melody_smart')) {
      return MusicMelodySmartEffect.render(
        numLeds: numLeds,
        vSub: vSub,
        vBass: vBass,
        vLmid: getBand('low_mid', sensMid),
        vMid: vMid,
        vHmid: getBand('high_mid', sensHigh),
        vHigh: _trebleSmoothed(analysis) * sensHigh,
        vBril: getBand('brilliance', sensHigh),
        highSensFactor: settings.highSensitivity.toDouble(),
      );
    }

    if (effect.contains('melody')) {
      final rgb = _melodyNoteRgb(analysis, vBass, vMid, vHigh);
      return List<(int, int, int)>.filled(numLeds, rgb, growable: false);
    }

    if (effect.contains('spectrum')) {
      var hueOffset = 0.0;
      if (effect.contains('rotate')) {
        final speed = settings.rotationSpeed / 100.0;
        hueOffset = (timeSec * speed) % 1.0;
      }
      var contrast = 1.0;
      var preGain = 1.0;
      if (effect.contains('punchy')) {
        contrast = 2.0;
        preGain = 1.5;
      }
      var startF = 0.0;
      var endF = 1.0;
      if (role == 'bass') {
        endF = 0.4;
      } else if (role == 'mid') {
        startF = 0.3;
        endF = 0.8;
      } else if (role == 'high') {
        startF = 0.6;
      }
      final rangeF = endF - startF;

      for (var i = 0; i < numLeds; i++) {
        final relPos = i / math.max(1, numLeds - 1);
        final absPos = startF + (relPos * rangeF);
        var effPos = (absPos + hueOffset) % 1.0;
        late final (int, int, int) baseC;
        if (effPos < 0.5) {
          baseC = interpolate(cBass, cMid, effPos * 2.0);
        } else {
          baseC = interpolate(cMid, cHigh, (effPos - 0.5) * 2.0);
        }
        final wBass = math.max(0.0, 1.0 - (absPos - 0.0).abs() * 3.0);
        final wMid = math.max(0.0, 1.0 - (absPos - 0.5).abs() * 3.0);
        final wHigh = math.max(0.0, 1.0 - (absPos - 1.0).abs() * 3.0);
        var rawIntensity = (vBass * wBass + vMid * wMid + vHigh * wHigh) * preGain;
        rawIntensity = math.min(1.0, rawIntensity);
        final intensity = math.pow(rawIntensity, contrast).toDouble();
        targets[i] = valScale(baseC, intensity);
      }
      return targets.toList();
    }

    if (effect.contains('vumeter')) {
      var targetVol = 0.0;
      var gradStart = cBass;
      var gradEnd = cHigh;
      if (role == 'bass') {
        targetVol = math.max(vSub, vBass);
        gradEnd = cMid;
      } else if (role == 'mid') {
        targetVol = vMid;
        gradStart = cBass;
        gradEnd = cHigh;
      } else if (role == 'high') {
        targetVol = vHigh;
        gradStart = cHigh;
        gradEnd = (255, 255, 255);
      } else {
        targetVol = math.max(vBass, math.max(vMid, vHigh));
      }
      targetVol = math.min(1.0, targetVol * 1.5);
      final fill = (targetVol * numLeds).floor();
      var invertOrder = false;
      if (edge == 'right') {
        invertOrder = true;
      }
      for (var i = 0; i < numLeds; i++) {
        var logicalIdx = i;
        if (invertOrder) {
          logicalIdx = numLeds - 1 - i;
        }
        if (logicalIdx < fill) {
          final pos = logicalIdx / math.max(1, numLeds - 1);
          if (effect.contains('spectrum')) {
            late final (int, int, int) c;
            if (pos < 0.5) {
              c = interpolate(cBass, cMid, pos * 2);
            } else {
              c = interpolate(cMid, cHigh, (pos - 0.5) * 2);
            }
            targets[i] = c;
          } else {
            targets[i] = interpolate(gradStart, gradEnd, pos);
          }
        } else {
          targets[i] = (0, 0, 0);
        }
      }
      return targets.toList();
    }

    if (effect == 'strobe') {
      const thresh = 0.60;
      var val = 0.0;
      var strobeColor = (255, 255, 255);
      if (role == 'bass') {
        val = vBass;
        strobeColor = cBass;
      } else if (role == 'mid') {
        val = vMid;
        strobeColor = cMid;
      } else if (role == 'high') {
        val = vHigh;
        strobeColor = cHigh;
      } else {
        val = math.max(vBass, vHigh);
      }
      if (val > thresh) {
        return List<(int, int, int)>.filled(numLeds, strobeColor, growable: false);
      }
      return targets.toList();
    }

    if (effect == 'pulse') {
      var vol = math.max(vBass, math.max(vMid, vHigh));
      vol *= (sensBass * 1.5);
      vol = math.min(1.0, vol);
      final gamma = 1.0 + (sensMid * 2.5);
      var intensity = math.pow(vol, gamma).toDouble();
      final minBrite = math.min(0.4, sensHigh * 0.2);
      intensity = minBrite + (intensity * (1.0 - minBrite));
      final c = valScale(cBass, intensity);
      return List<(int, int, int)>.filled(numLeds, c, growable: false);
    }

    if (effect == 'reactive_bass') {
      var intensity = vBass * 2.0;
      if (intensity > 1.0) {
        intensity = 1.0;
      }
      intensity = math.pow(intensity, 1.5).toDouble();
      if (role == 'mid') {
        intensity *= 0.7;
      } else if (role == 'high') {
        intensity *= 0.4;
      }
      const minWidthPct = 0.15;
      final width = (minWidthPct + (intensity * (1.0 - minWidthPct))) * (numLeds / 2);
      final center = numLeds / 2.0;
      var cShock = cBass;
      if (vBass > 0.7) {
        cShock = interpolate(cBass, (255, 255, 255), (vBass - 0.7) * 3);
      }
      final finalC = valScale(cShock, math.min(1.0, intensity * 2.0));
      for (var i = 0; i < numLeds; i++) {
        final dist = (i - center).abs();
        if (dist < width) {
          final relDist = dist / width;
          final falloff = 1.0 - (relDist * relDist);
          targets[i] = valScale(finalC, falloff);
        } else {
          targets[i] = (0, 0, 0);
        }
      }
      return targets.toList();
    }

    // energy (default / else v Pythonu)
    final t = timeSec;
    for (var i = 0; i < numLeds; i++) {
      final pos = i / math.max(1, numLeds);
      final w1 = math.sin((pos * 3.0) + (t * 1.0)) * 0.5 + 0.5;
      final w2 = math.sin((pos * 5.0) - (t * 2.0)) * 0.5 + 0.5;
      final w3 = math.sin((pos * 10.0) + (t * 4.0)) * 0.5 + 0.5;
      final energyBass = vBass * 2.0 * w1;
      final energyMid = vMid * 1.5 * w2;
      final energyHigh = vHigh * 1.5 * w3;
      var r = 0.0;
      var g = 0.0;
      var b = 0.0;
      final bc = valScale(cBass, energyBass);
      final mc = valScale(cMid, energyMid);
      final hc = valScale(cHigh, energyHigh);
      r += bc.$1;
      g += bc.$2;
      b += bc.$3;
      r += mc.$1;
      g += mc.$2;
      b += mc.$3;
      r += hc.$1;
      g += hc.$2;
      b += hc.$3;
      targets[i] = (clamp255(r), clamp255(g), clamp255(b));
    }
    return targets.toList();
  }

  /// Python `_render_segment_effect` používá neexistující klíč `high` — mapujeme na „treble“.
  static double _trebleSmoothed(MusicAnalysisSnapshot a) {
    return (a.highMid.smoothed + a.presence.smoothed * 1.2 + a.brilliance.smoothed * 1.2) / 2.4;
  }

  static (int, int, int) _melodyNoteRgb(MusicAnalysisSnapshot a, double vBass, double vMid, double vHigh) {
    final nc = a.melodyNoteClass;
    if (nc < 0 || nc > 11) {
      final v = (vBass * 0.4 + vMid * 0.35 + vHigh * 0.25).clamp(0.0, 1.0);
      final g = (32 + 80 * v).round().clamp(0, 255);
      return (g ~/ 3, g ~/ 3, g ~/ 3);
    }
    final hue = nc / 12.0;
    final sat = 0.55 + 0.45 * a.melodyPitchConfidence.clamp(0.0, 1.0);
    final val = math.min(
      1.0,
      a.melodyDynamics * 1.8 + vBass * 0.45 + (a.melodyOnset ? 0.25 : 0.0),
    );
    return _hsvToRgb(hue, sat, val);
  }

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
