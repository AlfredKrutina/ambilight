import '../../engine/screen/screen_frame.dart';

/// Dominantní RGB z RGBA snímku (rychlý downsample — parita s Python „center pixel“ / průměr).
(int, int, int) dominantRgbFromFrame(ScreenFrame frame, {int step = 32}) {
  if (!frame.isValid) return (128, 128, 128);
  final rgba = frame.rgba;
  final w = frame.width;
  final h = frame.height;
  var r = 0, g = 0, b = 0, n = 0;
  for (var y = 0; y < h; y += step) {
    for (var x = 0; x < w; x += step) {
      final o = (y * w + x) * 4;
      if (o + 2 >= rgba.length) continue;
      r += rgba[o];
      g += rgba[o + 1];
      b += rgba[o + 2];
      n++;
    }
  }
  if (n == 0) return (128, 128, 128);
  return ((r / n).round().clamp(0, 255), (g / n).round().clamp(0, 255), (b / n).round().clamp(0, 255));
}
