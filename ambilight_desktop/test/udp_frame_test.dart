import 'package:ambilight_desktop/core/protocol/udp_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isRgbPixelCountValidForBulkFrame', () {
    expect(UdpAmbilightProtocol.isRgbPixelCountValidForBulkFrame(-1), isFalse);
    expect(UdpAmbilightProtocol.isRgbPixelCountValidForBulkFrame(0), isTrue);
    expect(UdpAmbilightProtocol.isRgbPixelCountValidForBulkFrame(499), isTrue);
    expect(UdpAmbilightProtocol.isRgbPixelCountValidForBulkFrame(500), isFalse);
  });

  test('buildRgbFrame empty yields header only', () {
    final bytes = UdpAmbilightProtocol.buildRgbFrame([], brightness: 200);
    expect(bytes.length, 2);
    expect(bytes[0], 0x02);
    expect(bytes[1], 200);
  });

  test('scaleRgbForUdp03Tail matches bulk brightness semantics', () {
    final m = UdpAmbilightProtocol.scaleRgbForUdp03Tail(200, 100, 50, 128);
    expect(m.$1, (200 * 128 / 255).round());
    expect(m.$2, (100 * 128 / 255).round());
    expect(m.$3, (50 * 128 / 255).round());
    final full = UdpAmbilightProtocol.scaleRgbForUdp03Tail(10, 20, 30, 255);
    expect(full, (10, 20, 30));
  });

  test('buildRgbFrame rejects too many pixels', () {
    final pixels = List<(int, int, int)>.filled(500, (1, 2, 3));
    expect(() => UdpAmbilightProtocol.buildRgbFrame(pixels), throwsArgumentError);
  });
}
