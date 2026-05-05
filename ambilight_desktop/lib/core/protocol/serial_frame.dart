import 'dart:typed_data';

/// PC → ESP32 USB-serial frame compatible with `ambilight.c` `task_serial`.
///
/// - Handshake ping: single byte [0xAA], expect 0xBB in RX.
/// - **Legacy** color frame: `0xFF` + N×(idx8, r, g, b) + `0xFE` — max **256** LED
///   (index v jednom bajtu, N ≤ 256).
/// - **Wide** color frame: `0xFC` + N×(idx_lo, idx_hi, r, g, b) + `0xFE` — až [maxLedsPerDevice]
///   LED (16bit LE index; ESP32 firmware v1.11+).
/// - **Kapacita pásku** (před průvodcem / po změně v nastavení): `0xA5 0x5A` + uint16 LE
///   (clamp na firmware max).
/// - RGB na drátě 0..253 (jako Python).
class SerialAmbilightProtocol {
  SerialAmbilightProtocol._();

  /// Shoda s kartou Zařízení (`led_count` clamp).
  static const int maxLedsPerDevice = 2000;

  /// Legacy rámec: nejvýše 256 tuple (index 0..255).
  static const int legacyFrameMaxLeds = 256;

  static const int ping = 0xAA;
  static const int pong = 0xBB;

  static const int _frameStartLegacy = 0xFF;
  static const int _frameStartWide = 0xFC;
  static const int _frameEnd = 0xFE;

  static const int _announceMagic0 = 0xA5;
  static const int _announceMagic1 = 0x5A;

  static const int _maxChannel = 253;

  /// Příkaz pro ESP: logický počet LED na pásku (little-endian), před mapováním / kalibrací.
  static Uint8List buildLedCountCommand(int ledCount) {
    final n = ledCount.clamp(1, maxLedsPerDevice);
    return Uint8List.fromList([
      _announceMagic0,
      _announceMagic1,
      n & 0xFF,
      (n >> 8) & 0xFF,
    ]);
  }

  /// Jeden plný rámec; doplní černou nebo ořízne podle [stripLength].
  ///
  /// Volí legacy vs wide podle [stripLength] (> [legacyFrameMaxLeds] ⇒ wide).
  /// [colors] může být kratší — zbytek je černá.
  static Uint8List buildColorFrame(
    List<(int r, int g, int b)> colors, {
    required int stripLength,
    int brightnessScalar = 100,
  }) {
    final n = stripLength.clamp(1, maxLedsPerDevice);
    final scale = brightnessScalar / 100.0;
    if (n <= legacyFrameMaxLeds) {
      return _buildLegacyFrame(colors, n, scale);
    }
    return _buildWideFrame(colors, n, scale);
  }

  static Uint8List _buildLegacyFrame(
    List<(int r, int g, int b)> colors,
    int n,
    double scale,
  ) {
    final packet = BytesBuilder(copy: false)..addByte(_frameStartLegacy);
    for (var i = 0; i < n; i++) {
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

  static Uint8List _buildWideFrame(
    List<(int r, int g, int b)> colors,
    int n,
    double scale,
  ) {
    final packet = BytesBuilder(copy: false)..addByte(_frameStartWide);
    for (var i = 0; i < n; i++) {
      final (r, g, b) = i < colors.length ? colors[i] : (0, 0, 0);
      final rs = (r * scale).round().clamp(0, _maxChannel);
      final gs = (g * scale).round().clamp(0, _maxChannel);
      final bs = (b * scale).round().clamp(0, _maxChannel);
      packet
        ..addByte(i & 0xFF)
        ..addByte((i >> 8) & 0xFF)
        ..addByte(rs)
        ..addByte(gs)
        ..addByte(bs);
    }
    packet.addByte(_frameEnd);
    return packet.toBytes();
  }

  /// Délka jednoho legacy rámce v bajtech (pro testy / logování).
  static int legacyWireByteLength(int stripLength) {
    final n = stripLength.clamp(1, legacyFrameMaxLeds);
    return 1 + n * 4 + 1;
  }

  /// Délka wide rámce v bajtech.
  static int wideWireByteLength(int stripLength) {
    final n = stripLength.clamp(legacyFrameMaxLeds + 1, maxLedsPerDevice);
    return 1 + n * 5 + 1;
  }
}
