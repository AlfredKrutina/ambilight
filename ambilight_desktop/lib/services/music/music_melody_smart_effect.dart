import 'dart:math' as math;

/// Port `app.py` `melody_smart` (4 zóny, onset flash + decay) — stav mezi snímky.
class MusicMelodySmartEffect {
  MusicMelodySmartEffect._();

  static final _bass = _BandState();
  static final _lowMid = _BandState();
  static final _mid = _BandState();
  static final _high = _BandState();

  static List<(int, int, int)> render({
    required int numLeds,
    required double vSub,
    required double vBass,
    required double vLmid,
    required double vMid,
    required double vHmid,
    required double vHigh,
    required double vBril,
    required double highSensFactor,
  }) {
    final gain = (highSensFactor / 100.0) * 2.5;
    double curve(double v) {
      var x = v * gain;
      if (x < 0.05) x = 0;
      return x.clamp(0.0, 1.0);
    }

    final vs = curve(vSub);
    final vb = curve(vBass);
    final vl = curve(vLmid);
    final vm = curve(vMid);
    final vh = curve(vHmid);
    final vx = curve(vHigh);
    final vr = curve(vBril);

    final bassEnergy = math.min(((vs * 2.5 + vb * 2.0 + vl * 1.5) / 6.0) * 1.5, 1.0);
    _bass.update(bassEnergy);

    final lmidEnergy = math.min(((vl * 1.5 + vm * 1.0) / 2.5) * 1.5, 1.0);
    _lowMid.update(lmidEnergy);

    final midEnergy = math.min(((vm * 1.0 + vh * 1.5) / 2.5) * 1.5, 1.0);
    _mid.update(midEnergy);

    final highEnergy = math.min(((vh * 1.0 + vx * 1.5 + vr * 2.0) / 4.5) * 1.5, 1.0);
    _high.update(highEnergy);

    const bandColors = <(int, int, int)>[
      (255, 0, 0),
      (255, 128, 0),
      (0, 255, 128),
      (128, 0, 255),
    ];
    final bands = [_bass, _lowMid, _mid, _high];
    final zoneSize = math.max(1, numLeds ~/ 4);
    final out = List<(int, int, int)>.filled(numLeds, (0, 0, 0), growable: false);
    for (var ledIdx = 0; ledIdx < numLeds; ledIdx++) {
      final zoneIdx = math.min(ledIdx ~/ zoneSize, 3);
      final band = bands[zoneIdx];
      final flashComp = band.flash * 0.7;
      final energyComp = band.energy * 0.3;
      var brightness = math.max(flashComp + energyComp, 0.1).clamp(0.0, 1.0);
      final c = bandColors[zoneIdx];
      out[ledIdx] = (
        (c.$1 * brightness).round().clamp(0, 255),
        (c.$2 * brightness).round().clamp(0, 255),
        (c.$3 * brightness).round().clamp(0, 255),
      );
    }
    return out;
  }
}

class _BandState {
  double energy = 0;
  double flash = 0;
  double avg = 0.5;

  void update(double e) {
    final delta = e - avg;
    if (delta > 0.02 && e > 0.20) {
      flash = 1.0;
    }
    energy = e;
    avg = avg * 0.995 + e * 0.005;
    flash *= 0.70;
  }
}
