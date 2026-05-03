import 'dart:typed_data';

/// Wi-Fi UDP payloads compatible with `ambilight.c` `task_udp`.
class UdpAmbilightProtocol {
  UdpAmbilightProtocol._();

  /// Bulk RGB frame: 0x02 + brightness + flat r,g,b,...
  static Uint8List buildRgbFrame(
    List<(int r, int g, int b)> pixels, {
    int brightness = 255,
  }) {
    final b = BytesBuilder(copy: false)
      ..addByte(0x02)
      ..addByte(brightness.clamp(0, 255));
    for (final (r, g, bl) in pixels) {
      b
        ..addByte(r.clamp(0, 255))
        ..addByte(g.clamp(0, 255))
        ..addByte(bl.clamp(0, 255));
    }
    return b.toBytes();
  }

  /// Single pixel (wizard / calibration): 0x03, idx hi, lo, r, g, b
  static Uint8List buildSinglePixel(int index, int r, int g, int b) {
    final hi = (index >> 8) & 0xFF;
    final lo = index & 0xFF;
    return Uint8List.fromList([
      0x03,
      hi,
      lo,
      r.clamp(0, 255),
      g.clamp(0, 255),
      b.clamp(0, 255),
    ]);
  }

  static const String discoverPayload = 'DISCOVER_ESP32';
}
