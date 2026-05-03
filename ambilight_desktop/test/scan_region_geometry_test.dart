import 'dart:ui' show Rect;

import 'package:ambilight_desktop/features/screen_overlay/scan_region_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculateRegions returns four rects like PyQt scan_overlay', () {
    final r = ScanRegionGeometry.calculateRegions(
      monitorWidth: 1000,
      monitorHeight: 800,
      depthTopPct: 10,
      depthBottomPct: 10,
      depthLeftPct: 10,
      depthRightPct: 10,
      padTopPct: 5,
      padBottomPct: 5,
      padLeftPct: 5,
      padRightPct: 5,
    );
    expect(r.length, 4);
    expect(r[0], const Rect.fromLTWH(50, 40, 900, 80));
    expect(r[1], const Rect.fromLTWH(50, 680, 900, 80));
    expect(r[2], const Rect.fromLTWH(50, 120, 100, 560));
    expect(r[3], const Rect.fromLTWH(850, 120, 100, 560));
  });
}
