import 'package:ambilight_desktop/features/smart_lights/ha_rgb_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applySaturationPercent 100 is identity', () {
    final o = HaRgbTransform.applySaturationPercent(200, 40, 80, 100);
    expect(o.$1, 200);
    expect(o.$2, 40);
    expect(o.$3, 80);
  });

  test('applySaturationPercent 0 pulls toward neutral gray', () {
    final o = HaRgbTransform.applySaturationPercent(255, 0, 0, 0);
    expect(o.$1, o.$2);
    expect(o.$2, o.$3);
  });
}
