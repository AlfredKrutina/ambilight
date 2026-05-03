import 'package:ambilight_desktop/core/protocol/serial_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serial frame length matches protocol', () {
    final colors = List<(int, int, int)>.generate(66, (i) => (i, 10, 20));
    final frame = SerialAmbilightProtocol.buildColorFrame(colors, brightnessScalar: 100);
    expect(frame.length, 1 + SerialAmbilightProtocol.targetLeds * 4 + 1);
    expect(frame.first, 0xFF);
    expect(frame.last, 0xFE);
  });
}
