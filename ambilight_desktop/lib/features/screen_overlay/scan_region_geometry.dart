import 'dart:ui' show Rect;

/// Parita s PyQt `scan_overlay.py` — `calculate_regions` (per-edge depth + padding, bez překryvu středu).
abstract final class ScanRegionGeometry {
  ScanRegionGeometry._();

  /// Souřadnice ve **lokálním** systému monitoru (0…w, 0…h), stejně jako `QRect` v Pythonu.
  static List<Rect> calculateRegions({
    required double monitorWidth,
    required double monitorHeight,
    required double depthTopPct,
    required double depthBottomPct,
    required double depthLeftPct,
    required double depthRightPct,
    required double padTopPct,
    required double padBottomPct,
    required double padLeftPct,
    required double padRightPct,
  }) {
    final w = monitorWidth;
    final h = monitorHeight;
    if (w <= 0 || h <= 0) return const [];

    final depthTop = (h * depthTopPct / 100.0).floorToDouble();
    final depthBottom = (h * depthBottomPct / 100.0).floorToDouble();
    final depthLeft = (w * depthLeftPct / 100.0).floorToDouble();
    final depthRight = (w * depthRightPct / 100.0).floorToDouble();

    final pTop = (h * padTopPct / 100.0).floorToDouble();
    final pBot = (h * padBottomPct / 100.0).floorToDouble();
    final pLeft = (w * padLeftPct / 100.0).floorToDouble();
    final pRight = (w * padRightPct / 100.0).floorToDouble();

    final top = Rect.fromLTWH(pLeft, pTop, w - pLeft - pRight, depthTop);
    final bottom = Rect.fromLTWH(pLeft, h - pBot - depthBottom, w - pLeft - pRight, depthBottom);

    final leftY = pTop + depthTop;
    final leftH = h - pTop - pBot - depthTop - depthBottom;
    final left = Rect.fromLTWH(pLeft, leftY, depthLeft, leftH);

    final rightY = pTop + depthTop;
    final rightH = leftH;
    final right = Rect.fromLTWH(w - pRight - depthRight, rightY, depthRight, rightH);

    return <Rect>[top, bottom, left, right];
  }
}
