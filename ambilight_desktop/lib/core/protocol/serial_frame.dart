import 'dart:typed_data';

/// PC → ESP32 USB-serial frame compatible with [ambilight.c] `task_serial`.
///
/// - Handshake ping: single byte [0xAA], expect 0xBB in RX.
/// - Color frame: 0xFF + 200 × (idx, r, g, b) + 0xFE (matches Python `SerialHandler`).
/// - RGB components clamped to 0..253 on wire (same as Python).
class SerialAmbilightProtocol {
  SerialAmbilightProtocol._();

  static const int targetLeds = 200;
  static const int ping = 0xAA;
  static const int pong = 0xBB;

  static const int _frameStart = 0xFF;
  static const int _frameEnd = 0xFE;
  static const int _maxChannel = 253;

  /// Build one full frame; pads with black or truncates to [targetLeds].
  /// Indices on wire are 0 … [targetLeds]-1 (same as Python `enumerate(colors)`).
  ///
  /// [brightnessScalar] matches Python `SerialHandler.send_colors`: scale = value / 100
  /// (often 146–255 from `light_mode.brightness`).
  static Uint8List buildColorFrame(
    List<(int r, int g, int b)> colors, {
    int brightnessScalar = 100,
  }) {
    final scale = brightnessScalar / 100.0;
    final packet = BytesBuilder(copy: false);
    packet.addByte(_frameStart);

    for (var i = 0; i < targetLeds; i++) {
      final (r, g, b) = i < colors.length ? colors[i] : (0, 0, 0);
      final rs = (r * scale).round().clamp(0, _maxChannel);
      final gs = (g * scale).round().clamp(0, _maxChannel);
      final bs = (b * scale).round().clamp(0, _maxChannel);
      packet
        ..addByte(i & 0xFF)
        ..addByte(rs)
        ..addByte(gs)
        ..addByte(bs);
    }
    packet.addByte(_frameEnd);
    return packet.toBytes();
  }
}
