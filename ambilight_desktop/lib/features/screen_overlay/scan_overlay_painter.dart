import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Radius, Rect, RRect, Size;

import 'package:flutter/rendering.dart';

/// Kreslí tmavý příkrov a zvýrazněné okraje (modrá výplň, cyan okraj) jako PyQt `ScanningAreaOverlay.paintEvent`.
class ScanOverlayPainter extends CustomPainter {
  ScanOverlayPainter({required this.regions});

  final List<Rect> regions;

  static const _dim = Color.fromARGB(120, 0, 0, 0);
  static const _fill = Color.fromARGB(180, 10, 132, 255);
  static const _stroke = Color.fromARGB(255, 10, 255, 255);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _dim);
    final fill = Paint()..color = _fill;
    final border = Paint()
      ..color = _stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (final r in regions) {
      if (r.width <= 0 || r.height <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1)),
        border,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter oldDelegate) =>
      oldDelegate.regions != regions;
}
