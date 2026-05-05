import 'package:ambilight_desktop/core/protocol/serial_frame.dart';
import 'package:ambilight_desktop/core/protocol/udp_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy serial frame length (≤256 LED)', () {
    const n = 66;
    final colors = List<(int, int, int)>.generate(n, (i) => (i, 10, 20));
    final frame = SerialAmbilightProtocol.buildColorFrame(
      colors,
      stripLength: n,
      brightnessScalar: 100,
    );
    expect(frame.length, SerialAmbilightProtocol.legacyWireByteLength(n));
    expect(frame.first, 0xFF);
    expect(frame.last, 0xFE);
  });

  test('wide serial frame uses 0xFC and 5 bytes per LED', () {
    const n = 300;
    final colors = List<(int, int, int)>.generate(n, (i) => (i & 255, 1, 2));
    final frame = SerialAmbilightProtocol.buildColorFrame(
      colors,
      stripLength: n,
      brightnessScalar: 100,
    );
    expect(frame.length, SerialAmbilightProtocol.wideWireByteLength(n));
    expect(frame.first, 0xFC);
    expect(frame.last, 0xFE);
  });

  test('LED count announce command is 4 bytes', () {
    final c = SerialAmbilightProtocol.buildLedCountCommand(424);
    expect(c, [0xA5, 0x5A, 0xA8, 0x01]);
  });

  test('wide frame tuple at index 300 is LE idx_lo idx_hi', () {
    const n = 301;
    final colors = List<(int, int, int)>.filled(n, (0, 0, 0));
    colors[300] = (9, 8, 7);
    final frame = SerialAmbilightProtocol.buildColorFrame(
      colors,
      stripLength: n,
      brightnessScalar: 100,
    );
    expect(frame.first, 0xFC);
    final tupleStart = 1 + 300 * 5;
    expect(frame[tupleStart], 300 & 0xFF);
    expect(frame[tupleStart + 1], (300 >> 8) & 0xFF);
    expect(frame[tupleStart + 2], 9);
    expect(frame[tupleStart + 3], 8);
    expect(frame[tupleStart + 4], 7);
    expect(frame.last, 0xFE);
  });

  test('PC release handoff opcode matches UDP', () {
    expect(SerialAmbilightProtocol.pcReleaseHandoff, 0xF0);
    expect(UdpAmbilightProtocol.pcReleaseHandoff, 0xF0);
    expect(SerialAmbilightProtocol.buildFirmwareTemporalModeFrame(2), orderedEquals([0xF1, 2]));
    expect(UdpAmbilightProtocol.buildFirmwareTemporalModeFrame(1), orderedEquals([0xF1, 1]));
  });
}
