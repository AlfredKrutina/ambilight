import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'music_melody_analyzer.dart';
import 'music_types.dart';

/// Odpovídá Python `audio_analyzer.BeatDetector`.
class _BeatDetector {
  _BeatDetector({required this.thresholdMultiplier});

  final double thresholdMultiplier;
  final List<double> _history = [];
  static const int _historySize = 43;

  (bool, double) detect(double frequencyBandEnergy) {
    _history.add(frequencyBandEnergy);
    if (_history.length > _historySize) {
      _history.removeAt(0);
    }
    var expected = 0.0;
    if (_history.isEmpty) {
      expected = 0.0;
    } else {
      var s = 0.0;
      for (final v in _history) {
        s += v;
      }
      expected = s / _history.length;
    }
    if (expected < 0.0001) {
      expected = 0.0001;
    }
    final isBeat = frequencyBandEnergy > (expected * thresholdMultiplier);
    final intensity = math.min(1.0, frequencyBandEnergy / (expected * 2));
    return (isBeat, intensity);
  }
}

/// Port `audio_analyzer.AudioAnalyzer` — FFT (fftea), 7 pásem, beat, smoothing.
class MusicFftAnalyzer {
  MusicFftAnalyzer({int sampleRate = 48000}) : _sr = sampleRate {
    _fft = FFT(_frameSize);
    _win = Window.hanning(_frameSize);
  }

  final MusicMelodyAnalyzer _melody = MusicMelodyAnalyzer();

  static const int _frameSize = 4096;

  int _sr;
  late final FFT _fft;
  late final Float64List _win;

  final Map<String, _BeatDetector> _beatDetectors = {
    'sub_bass': _BeatDetector(thresholdMultiplier: 1.4),
    'bass': _BeatDetector(thresholdMultiplier: 1.4),
    'low_mid': _BeatDetector(thresholdMultiplier: 1.5),
    'mid': _BeatDetector(thresholdMultiplier: 1.5),
    'high_mid': _BeatDetector(thresholdMultiplier: 1.5),
    'presence': _BeatDetector(thresholdMultiplier: 1.7),
    'brilliance': _BeatDetector(thresholdMultiplier: 1.9),
  };

  double _alphaAttack = 0.6;
  double _alphaDecay = 0.15;
  double _globalPeak = 0.5;
  static const double _peakDecay = 0.9992;

  final Map<String, double> _smoothVals = {
    'sub_bass': 0,
    'bass': 0,
    'low_mid': 0,
    'mid': 0,
    'high_mid': 0,
    'presence': 0,
    'brilliance': 0,
  };

  bool _beatDetectionEnabled = true;

  int get sampleRate => _sr;

  void setSampleRate(int sr) {
    if (sr > 0) {
      _sr = sr;
    }
  }

  void setBeatDetection({required bool enabled, required double thresholdMultiplier}) {
    _beatDetectionEnabled = enabled;
    final t = thresholdMultiplier.clamp(1.05, 3.0);
    _beatDetectors['sub_bass'] = _BeatDetector(thresholdMultiplier: t * 1.4 / 1.5);
    _beatDetectors['bass'] = _BeatDetector(thresholdMultiplier: t * 1.4 / 1.5);
    _beatDetectors['low_mid'] = _BeatDetector(thresholdMultiplier: t * 1.5 / 1.5);
    _beatDetectors['mid'] = _BeatDetector(thresholdMultiplier: t * 1.5 / 1.5);
    _beatDetectors['high_mid'] = _BeatDetector(thresholdMultiplier: t * 1.5 / 1.5);
    _beatDetectors['presence'] = _BeatDetector(thresholdMultiplier: t * 1.7 / 1.5);
    _beatDetectors['brilliance'] = _BeatDetector(thresholdMultiplier: t * 1.9 / 1.5);
  }

  void setSmoothing({double attack = 0.6, double decay = 0.15}) {
    _alphaAttack = attack;
    _alphaDecay = decay;
  }

  /// Převod PCM int16 LE (interleaved) na mono float -1..1, doplnění do [_frameSize].
  MusicAnalysisSnapshot processPcmInt16Le(Uint8List bytes, int channels) {
    if (bytes.length < 4 || channels < 1) {
      return MusicAnalysisSnapshot.silent(sampleRate: _sr);
    }
    final frameBytes = _frameSize * 2 * channels;
    final take = math.min(bytes.length, frameBytes);
    final nFrames = take ~/ (2 * channels);
    if (nFrames < 8) {
      return MusicAnalysisSnapshot.silent(sampleRate: _sr);
    }
    final mono = Float64List(_frameSize);
    final copy = math.min(nFrames, _frameSize);
    for (var f = 0; f < copy; f++) {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        final o = (f * channels + c) * 2;
        if (o + 1 >= take) break;
        final lo = bytes[o];
        final hi = bytes[o + 1];
        var s = lo | (hi << 8);
        if (s >= 32768) s -= 65536;
        sum += s;
      }
      mono[f] = (sum / channels) / 32768.0;
    }
    return processMonoFloat(mono);
  }

  MusicAnalysisSnapshot processMonoFloat(Float64List mono) {
    if (mono.length < _frameSize) {
      return MusicAnalysisSnapshot.silent(sampleRate: _sr);
    }
    final windowed = Float64List(_frameSize);
    for (var i = 0; i < _frameSize; i++) {
      windowed[i] = mono[i] * _win[i];
    }

    double loudness = 0;
    try {
      var s = 0.0;
      for (var i = 0; i < _frameSize; i++) {
        s += windowed[i] * windowed[i];
      }
      final rms = math.sqrt(s / _frameSize);
      loudness = math.min(1.0, rms / 0.5);
    } catch (_) {
      loudness = 0;
    }

    final fftOut = _fft.realFft(windowed);
    final mags = fftOut.discardConjugates().magnitudes();
    final nBins = mags.length;
    final df = _sr / _frameSize;

    double bandSum(double fLo, double fHi) {
      var loBin = (fLo / df).floor();
      var hiBin = (fHi / df).ceil();
      loBin = loBin.clamp(0, nBins - 1);
      hiBin = hiBin.clamp(0, nBins - 1);
      var e = 0.0;
      for (var b = loBin; b <= hiBin; b++) {
        e += mags[b];
      }
      return e / _frameSize * 2.0;
    }

    final energies = <String, double>{
      'sub_bass': bandSum(20, 60),
      'bass': bandSum(60, 150),
      'low_mid': bandSum(150, 400),
      'mid': bandSum(400, 1000),
      'high_mid': bandSum(1000, 2500),
      'presence': bandSum(2500, 6000),
      'brilliance': bandSum(6000, _sr / 2 - 1),
    };

    var maxE = 0.0;
    for (final v in energies.values) {
      if (v > maxE) maxE = v;
    }
    if (maxE > _globalPeak) {
      _globalPeak = maxE;
    } else {
      _globalPeak *= _peakDecay;
    }
    if (_globalPeak < 0.1) {
      _globalPeak = 0.1;
    }

    final finalVals = <String, double>{};
    for (final e in energies.entries) {
      var norm = math.min(1.0, e.value / _globalPeak);
      var gamma = 1.3;
      if (e.key.contains('sub') || e.key == 'bass') {
        gamma = 1.2;
      }
      if (e.key == 'presence' || e.key == 'brilliance') {
        gamma = 1.4;
      }
      finalVals[e.key] = math.pow(norm, gamma).toDouble();
    }

    MusicBandSnapshot pack(String name) {
      final val = finalVals[name] ?? 0.0;
      var isBeat = false;
      double intensity;
      if (_beatDetectionEnabled) {
        final r = _beatDetectors[name]!.detect(val);
        isBeat = r.$1;
        intensity = r.$2;
      } else {
        intensity = val;
      }
      final currS = _smoothVals[name] ?? 0.0;
      final newS = val > currS
          ? _alphaAttack * val + (1 - _alphaAttack) * currS
          : _alphaDecay * val + (1 - _alphaDecay) * currS;
      _smoothVals[name] = newS;
      return MusicBandSnapshot(
        isBeat: isBeat,
        intensity: intensity,
        smoothed: newS,
        energy: energies[name] ?? 0.0,
      );
    }

    final mel = _melody.update(mags, df, _sr);

    return MusicAnalysisSnapshot(
      subBass: pack('sub_bass'),
      bass: pack('bass'),
      lowMid: pack('low_mid'),
      mid: pack('mid'),
      highMid: pack('high_mid'),
      presence: pack('presence'),
      brilliance: pack('brilliance'),
      overallLoudness: loudness,
      sampleRate: _sr,
      melodyOnset: mel.onset,
      melodyBeat: mel.beat,
      melodyPitchHz: mel.pitchHz,
      melodyNoteClass: mel.noteClass,
      melodyPitchConfidence: mel.pitchConfidence,
      melodyDynamics: mel.dynamics,
    );
  }
}
