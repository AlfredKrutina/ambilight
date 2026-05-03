import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect, Size;

import 'package:flutter/rendering.dart';

/// Jen pruhy oblasti skenu (žádná „clona“ přes celé okno) — střed zůstává zcela průhledný.
class ScanOverlayPainter extends CustomPainter {
  ScanOverlayPainter({required this.regions});

  final List<Rect> regions;

  static const _fill = Color(0x5528B4FF);
  static const _stroke = Color(0xFF5EC8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final union = Path();
    var any = false;
    for (final r in regions) {
      if (r.width <= 0 || r.height <= 0) continue;
      union.addRect(r);
      any = true;
    }
    if (!any) return;

    canvas.drawPath(
      union,
      Paint()
        ..color = _fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      union,
      Paint()
        ..color = _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter oldDelegate) =>
      oldDelegate.regions != regions;
}
