import 'package:flutter_test/flutter_test.dart';

import 'package:ambilight_desktop/features/smart_lights/ha_api_client.dart';

void main() {
  test('haRgbToHsColor primaries', () {
    final red = haRgbToHsColor(255, 0, 0);
    expect(red[0].round(), 0);
    expect(red[1].round(), 100);

    final green = haRgbToHsColor(0, 255, 0);
    expect(green[0].round(), 120);
    expect(green[1].round(), 100);

    final blue = haRgbToHsColor(0, 0, 255);
    expect(blue[0].round(), 240);
    expect(blue[1].round(), 100);
  });

  test('haRgbToHsColor gray', () {
    final g = haRgbToHsColor(128, 128, 128);
    expect(g[1], lessThan(1.0));
  });
}
