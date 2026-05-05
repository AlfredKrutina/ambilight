import 'package:ambilight_desktop/engine/light_rgb_smoothing_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EMA moves toward new target over fixed dt steps', () {
    final rt = LightRgbSmoothingRuntime();
    final blue = {'d': const [(0, 0, 255)]};
    final red = {'d': const [(255, 0, 0)]};
    rt.applyTemporalSmoothing(targets: blue, smoothMs: 200, dtMsOverride: 33.0);
    final mid = rt.applyTemporalSmoothing(targets: red, smoothMs: 200, dtMsOverride: 100.0);
    final r0 = mid['d']![0].$1;
    expect(r0, greaterThan(0));
    expect(r0, lessThan(255));
    final end = rt.applyTemporalSmoothing(targets: red, smoothMs: 200, dtMsOverride: 100.0);
    expect(end['d']![0].$1, greaterThan(r0));
  });

  test('smoothMs zero passes targets through', () {
    final rt = LightRgbSmoothingRuntime();
    final red = {'d': const [(255, 0, 0)]};
    expect(rt.applyTemporalSmoothing(targets: red, smoothMs: 0), red);
  });
}
