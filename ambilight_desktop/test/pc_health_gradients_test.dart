import 'package:ambilight_desktop/features/pc_health/pc_health_gradients.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blue_green_red low is blue', () {
    final c = PcHealthGradients.gradientColor(0, 0, 100, 'blue_green_red');
    expect(c.$3, greaterThan(200));
    expect(c.$2, lessThan(50));
  });

  test('blue_green_red high is red', () {
    final c = PcHealthGradients.gradientColor(100, 0, 100, 'blue_green_red');
    expect(c.$1, greaterThan(200));
  });
}
