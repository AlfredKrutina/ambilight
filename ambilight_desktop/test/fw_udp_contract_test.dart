import 'dart:typed_data';

import 'package:ambilight_desktop/core/protocol/udp_frame.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden vektory shodné s `esp32c3_lamp_firmware/main/ambilight.c` task_udp.
void main() {
  group('UDP vs FW parser', () {
    test('0x02 bulk bri=255 two pixels', () {
      final b = UdpAmbilightProtocol.buildRgbFrame([(1, 2, 3), (4, 5, 6)], brightness: 255);
      expect(b, Uint8List.fromList([0x02, 0xFF, 1, 2, 3, 4, 5, 6]));
      expect((b.length - 2) % 3, 0);
    });

    test('0x03 single pixel BE index 516 (0x0204)', () {
      final b = UdpAmbilightProtocol.buildSinglePixel(516, 10, 20, 30);
      expect(b, Uint8List.fromList([0x03, 0x02, 0x04, 10, 20, 30]));
      expect(((b[1] << 8) | b[2]), 516);
    });

    test('0x03 index 0', () {
      final b = UdpAmbilightProtocol.buildSinglePixel(0, 255, 0, 128);
      expect(b, Uint8List.fromList([0x03, 0x00, 0x00, 255, 0, 128]));
    });

    test('max bulk length matches FW rx budget', () {
      final px = List<(int, int, int)>.generate(
        UdpAmbilightProtocol.maxRgbPixelsPerUdpDatagram,
        (i) => (i & 255, 0, 0),
      );
      final b = UdpAmbilightProtocol.buildRgbFrame(px, brightness: 200);
      expect(b.length, 2 + 499 * 3);
      expect(b.length <= 1499, isTrue);
    });

    test('0x06 chunk BE index 1000 + 2 pixels', () {
      final b = UdpAmbilightProtocol.buildRgbChunkOpcode06(1000, [(1, 2, 3), (4, 5, 6)]);
      expect(b, Uint8List.fromList([0x06, 0x03, 0xE8, 1, 2, 3, 4, 5, 6]));
      expect((b.length - 3) % 3, 0);
    });

    test('0x08 flush bri=128 total=600', () {
      final b = UdpAmbilightProtocol.buildFlushOpcode08(128, 600);
      expect(b, Uint8List.fromList([0x08, 128, 0x02, 0x58]));
    });

    test('default 0x06 emit chunk fits FW rx budget', () {
      final px = List<(int, int, int)>.generate(
        UdpAmbilightProtocol.maxRgbPixelsPerUdpOpcode06ChunkDefault,
        (i) => (0, 0, 0),
      );
      final b = UdpAmbilightProtocol.buildRgbChunkOpcode06(0, px);
      expect(b.length, 3 + 400 * 3);
      expect(b.length <= 1499, isTrue);
    });

    test('wire max 0x06 chunk fits FW rx budget', () {
      final px = List<(int, int, int)>.generate(
        UdpAmbilightProtocol.maxRgbPixelsPerUdpOpcode06Wire,
        (i) => (0, 0, 0),
      );
      final b = UdpAmbilightProtocol.buildRgbChunkOpcode06(0, px);
      expect(b.length, 3 + UdpAmbilightProtocol.maxRgbPixelsPerUdpOpcode06Wire * 3);
      expect(b.length <= 1499, isTrue);
    });

    test('udpOpcode06EmitChunkPixels matches default without define', () {
      expect(UdpAmbilightProtocol.udpOpcode06EmitChunkPixels, 400);
    });
  });

  group('App never emits invalid bulk lengths', () {
    test('buildRgbFrame always (len-2)%3==0', () {
      for (final n in [0, 1, 17, 499]) {
        final px = List<(int, int, int)>.generate(n, (i) => (i, i, i));
        final b = UdpAmbilightProtocol.buildRgbFrame(px);
        expect((b.length - 2) % 3, 0, reason: 'n=$n');
      }
    });
  });
}
