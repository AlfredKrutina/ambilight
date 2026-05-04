import 'dart:math' as math;
import 'dart:typed_data';

/// Zjednodušený port `melody_detector.py` nad již spočteným FFT magnitudes (bez druhé FFT).
class MusicMelodyAnalyzer {
  Float64List? _prevMags;
  final List<double> _energyHist = [];
  double _maxEnergy = 0.1;
  int _lastBeatMs = 0;

  /// [df] = sampleRate / fftSize, [mags] = discardConjugates magnitudes.
  MelodyFrameData update(Float64List mags, double df, int sampleRate) {
    if (mags.isEmpty) {
      return MelodyFrameData.empty;
    }
    final n = mags.length;
    var norm = 0.0;
    for (var i = 0; i < n; i++) {
      final v = mags[i];
      if (v > norm) norm = v;
    }
    if (norm < 1e-10) norm = 1e-10;
    final s = Float64List(n);
    for (var i = 0; i < n; i++) {
      s[i] = mags[i] / norm;
    }

    var onset = false;
    if (_prevMags != null && _prevMags!.length == n) {
      var flux = 0.0;
      for (var i = 0; i < n; i++) {
        final d = s[i] - _prevMags![i];
        if (d > 0) flux += d;
      }
      onset = flux > 0.02;
    }
    final next = Float64List(n);
    for (var i = 0; i < n; i++) {
      final old = (_prevMags != null && _prevMags!.length == n) ? _prevMags![i] : s[i];
      next[i] = s[i] * 0.9 + old * 0.1;
    }
    _prevMags = next;

    final peaks = _detectPeaks(s, df);
    final primary = peaks.isEmpty ? 0.0 : peaks.first.$1;
    final confidence = peaks.isEmpty ? 0.0 : peaks.first.$2;
    final noteClass = primary > 20 ? _freqToNoteClass(primary) : -1;

    var e = 0.0;
    for (var i = 0; i < n; i++) {
      e += s[i] * s[i];
    }
    e /= math.max(1, n);
    _energyHist.add(e);
    if (_energyHist.length > 30) _energyHist.removeAt(0);
    _maxEnergy = math.max(_maxEnergy * 0.99, e);
    final dynamics = math.min(1.0, e / (_maxEnergy + 1e-10));

    final now = DateTime.now().millisecondsSinceEpoch;
    var beat = false;
    if (_energyHist.length >= 5) {
      var sum = 0.0;
      for (final v in _energyHist) {
        sum += v;
      }
      final avg = sum / _energyHist.length;
      if (e > avg * 1.8 && now - _lastBeatMs > 150) {
        beat = true;
        _lastBeatMs = now;
      }
    }

    return MelodyFrameData(
      onset: onset,
      beat: beat,
      pitchHz: primary,
      noteClass: noteClass,
      pitchConfidence: confidence,
      dynamics: dynamics,
    );
  }

  int _freqToNoteClass(double freq) {
    if (freq < 20 || freq > 4000) return -1;
    const a4 = 440.0;
    final halfSteps = 12 * math.log(freq / a4) / math.ln2; // log2
    final idx = (halfSteps.round() + 9) % 12;
    return idx < 0 ? (idx + 12) % 12 : idx;
  }

  /// Návrat [(freq, strength), ...] max 3, seřazeno podle síly.
  List<(double, double)> _detectPeaks(Float64List spectrum, double df) {
    const minF = 60.0;
    const maxF = 2000.0;
    final i0 = math.max(1, (minF / df).floor());
    final i1 = math.min(spectrum.length - 1, (maxF / df).ceil());
    if (i1 <= i0) return const [];

    final work = Float64List.fromList(Float64List.sublistView(spectrum, i0, i1 + 1));
    final freqs = List<double>.generate(work.length, (j) => (i0 + j) * df);
    final out = <(double, double)>[];
    for (var k = 0; k < 3; k++) {
      var bestI = 0;
      var bestV = 0.0;
      for (var j = 0; j < work.length; j++) {
        if (work[j] > bestV) {
          bestV = work[j];
          bestI = j;
        }
      }
      if (bestV < 0.1) break;
      out.add((freqs[bestI], bestV));
      const z = 20;
      final lo = math.max(0, bestI - z);
      final hi = math.min(work.length, bestI + z);
      for (var j = lo; j < hi; j++) {
        work[j] = 0;
      }
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }
}

class MelodyFrameData {
  const MelodyFrameData({
    required this.onset,
    required this.beat,
    required this.pitchHz,
    required this.noteClass,
    required this.pitchConfidence,
    required this.dynamics,
  });

  final bool onset;
  final bool beat;
  final double pitchHz;
  /// 0–11 chromatic, nebo -1 žádná.
  final int noteClass;
  final double pitchConfidence;
  final double dynamics;

  bool get hasMelody => pitchConfidence > 0.4 && noteClass >= 0;

  static const MelodyFrameData empty = MelodyFrameData(
    onset: false,
    beat: false,
    pitchHz: 0,
    noteClass: -1,
    pitchConfidence: 0,
    dynamics: 0,
  );
}
