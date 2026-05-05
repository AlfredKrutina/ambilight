import 'dart:typed_data';

/// Časové vyhlazení RGB výstupů v light módu — stejný vzorec jako [ScreenPipelineRuntime.applyTemporalSmoothing].
final class LightRgbSmoothingRuntime {
  LightRgbSmoothingRuntime();

  final Map<String, Float64List> _smooth = {};
  DateTime? _lastSmooth;
  bool _smoothPrimed = false;

  void reset() {
    _smooth.clear();
    _lastSmooth = null;
    _smoothPrimed = false;
  }

  Map<String, List<(int, int, int)>> applyTemporalSmoothing({
    required Map<String, List<(int, int, int)>> targets,
    required int smoothMs,
    double? dtMsOverride,
  }) {
    if (smoothMs <= 0) {
      _syncSmoothFromTargets(targets);
      return targets;
    }

    final dtMs = dtMsOverride ?? _consumeDtMs();
    var alpha = (dtMs / smoothMs).clamp(0.0, 1.0);
    if (alpha <= 0) alpha = 1.0;

    if (!_smoothPrimed) {
      _smoothPrimed = true;
      _syncSmoothFromTargets(targets);
      return _quantizeSmooth(targets.keys.toList());
    }

    for (final e in targets.entries) {
      final id = e.key;
      final tgt = e.value;
      var state = _smooth[id];
      final n3 = tgt.length * 3;
      if (state == null || state.length != n3) {
        state = Float64List(n3);
        _smooth[id] = state;
        for (var i = 0; i < tgt.length; i++) {
          state[i * 3] = tgt[i].$1.toDouble();
          state[i * 3 + 1] = tgt[i].$2.toDouble();
          state[i * 3 + 2] = tgt[i].$3.toDouble();
        }
      } else {
        for (var i = 0; i < tgt.length; i++) {
          final tr = tgt[i].$1.toDouble();
          final tg = tgt[i].$2.toDouble();
          final tb = tgt[i].$3.toDouble();
          final o = i * 3;
          state[o] += (tr - state[o]) * alpha;
          state[o + 1] += (tg - state[o + 1]) * alpha;
          state[o + 2] += (tb - state[o + 2]) * alpha;
        }
      }
    }

    return _quantizeSmooth(targets.keys.toList());
  }

  void _syncSmoothFromTargets(Map<String, List<(int, int, int)>> targets) {
    for (final e in targets.entries) {
      final tgt = e.value;
      final state = Float64List(tgt.length * 3);
      for (var i = 0; i < tgt.length; i++) {
        state[i * 3] = tgt[i].$1.toDouble();
        state[i * 3 + 1] = tgt[i].$2.toDouble();
        state[i * 3 + 2] = tgt[i].$3.toDouble();
      }
      _smooth[e.key] = state;
    }
  }

  Map<String, List<(int, int, int)>> _quantizeSmooth(List<String> keys) {
    final out = <String, List<(int, int, int)>>{};
    for (final id in keys) {
      final state = _smooth[id];
      if (state == null) continue;
      final n = state.length ~/ 3;
      final list = List<(int, int, int)>.generate(
        n,
        (i) => (
          state[i * 3].round().clamp(0, 255),
          state[i * 3 + 1].round().clamp(0, 255),
          state[i * 3 + 2].round().clamp(0, 255),
        ),
        growable: false,
      );
      out[id] = list;
    }
    return out;
  }

  double _consumeDtMs() {
    final now = DateTime.now();
    if (_lastSmooth == null) {
      _lastSmooth = now;
      return 33.0;
    }
    final dt = now.difference(_lastSmooth!).inMicroseconds / 1000.0;
    _lastSmooth = now;
    if (dt <= 0.5 || dt > 500) return 33.0;
    return dt;
  }
}
