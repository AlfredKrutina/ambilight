import 'package:flutter/material.dart';

/// Úprava RGB před odesláním do Home Assistant / HomeKit (HSV saturace).
class HaRgbTransform {
  HaRgbTransform._();

  /// [saturationPercent] 0–200: 100 = beze změny, 0 = šedá, 200 = max. posílení saturace.
  static (int r, int g, int b) applySaturationPercent(int r, int g, int b, int saturationPercent) {
    final p = saturationPercent.clamp(0, 200);
    if (p == 100) return (r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    final mul = p / 100.0;
    final hsv = HSVColor.fromColor(Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)));
    final s = (hsv.saturation * mul).clamp(0.0, 1.0);
    final c = hsv.withSaturation(s).toColor();
    return (c.red, c.green, c.blue);
  }
}
