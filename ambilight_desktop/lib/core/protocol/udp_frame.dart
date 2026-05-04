import 'dart:typed_data';

/// Wi-Fi UDP payloads compatible with `ambilight.c` `task_udp`.
class UdpAmbilightProtocol {
  UdpAmbilightProtocol._();

  /// ESP `rx_buffer[1500]` → platný rámec `0x02` + `bri` + 3×N musí mít `2 + 3*N <= 1499`.
  static const int maxRgbPixelsPerUdpDatagram = 499;

  /// Rámec `0x06`: `[cmd, idx_hi, idx_lo]` + RGB×M — max M aby `3 + 3*M <= 1499` (lampa FW).
  /// Volitelně držíme ≤400 LED (~1203 B) pro méně datagramů na snímek na Windows.
  static const int maxRgbPixelsPerUdpOpcode06Chunk = 400;

  /// Počet RGB pixelů vhodný pro jeden datagram `0x02` (bez výpočtu přesné délky bytu).
  static bool isRgbPixelCountValidForBulkFrame(int n) =>
      n >= 0 && n <= maxRgbPixelsPerUdpDatagram;

  static bool isRgbPixelCountValidForOpcode06Chunk(int n) =>
      n >= 1 && n <= maxRgbPixelsPerUdpOpcode06Chunk;

  /// Bulk RGB frame: 0x02 + brightness + flat r,g,b,...
  static Uint8List buildRgbFrame(
    List<(int r, int g, int b)> pixels, {
    int brightness = 255,
  }) {
    if (!isRgbPixelCountValidForBulkFrame(pixels.length)) {
      throw ArgumentError.value(
        pixels.length,
        'pixels.length',
        'must be 0…$maxRgbPixelsPerUdpDatagram for one 0x02 datagram',
      );
    }
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

  /// Chunk od indexu [startIndex]: `0x06` + BE index + RGB×N (bez refresh pásku — viz `0x08`).
  static Uint8List buildRgbChunkOpcode06(int startIndex, List<(int r, int g, int b)> pixels) {
    if (startIndex < 0 || startIndex > 0xFFFF) {
      throw ArgumentError.value(startIndex, 'startIndex', 'must be 0…65535');
    }
    if (!isRgbPixelCountValidForOpcode06Chunk(pixels.length)) {
      throw ArgumentError.value(
        pixels.length,
        'pixels.length',
        'must be 1…$maxRgbPixelsPerUdpOpcode06Chunk for one 0x06 datagram',
      );
    }
    final hi = (startIndex >> 8) & 0xFF;
    final lo = startIndex & 0xFF;
    final b = BytesBuilder(copy: false)
      ..addByte(0x06)
      ..addByte(hi)
      ..addByte(lo);
    for (final (r, g, bl) in pixels) {
      b
        ..addByte(r.clamp(0, 255))
        ..addByte(g.clamp(0, 255))
        ..addByte(bl.clamp(0, 255));
    }
    return b.toBytes();
  }

  /// Po sérii `0x06`: `0x08` + jas + BE počet pixelů → FW udělá `clear_tail_leds(total)` a `update_leds(bri)`.
  static Uint8List buildFlushOpcode08(int brightness, int totalPixelCount) {
    final bri = brightness.clamp(0, 255);
    final t = totalPixelCount.clamp(0, 0xFFFF);
    final hi = (t >> 8) & 0xFF;
    final lo = t & 0xFF;
    return Uint8List.fromList([0x08, bri, hi, lo]);
  }

  /// Lamp FW u `0x03` volá `update_leds(255)`; u bulk `0x02` škáluje podle bajtu jasu.
  /// Pro Wi‑Fi ocas (>499 LED) proto přenásob RGB, aby vizuálně odpovídalo stejnému jasu jako bulk.
  static (int r, int g, int b) scaleRgbForUdp03Tail(int r, int g, int b, int bulkBrightness) {
    final bri = bulkBrightness.clamp(0, 255);
    if (bri >= 255) {
      return (r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    }
    final s = bri / 255.0;
    return (
      (r * s).round().clamp(0, 255),
      (g * s).round().clamp(0, 255),
      (b * s).round().clamp(0, 255),
    );
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
