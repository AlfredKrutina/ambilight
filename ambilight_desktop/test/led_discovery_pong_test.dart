import 'package:ambilight_desktop/services/led_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEsp32PongDatagram', () {
    test('parses lamp FW sprintf shape', () {
      final p = parseEsp32PongDatagram(
        '192.168.1.207',
        'ESP32_PONG|aabbcc|Ambilight_dd|512|2.0',
      );
      expect(p, isNotNull);
      expect(p!.ip, '192.168.1.207');
      expect(p.macSuffix, 'aabbcc');
      expect(p.name, 'Ambilight_dd');
      expect(p.ledCount, 512);
      expect(p.version, '2.0');
      expect(p.fwTemporalSmoothingMode, isNull);
    });

    test('parses legacy PONG: protocol 2.1 + temporal (6 fields)', () {
      final p = parseEsp32PongDatagram(
        '10.0.0.2',
        'ESP32_PONG|aabbcc|Ambilight_dd|300|2.1|1',
      );
      expect(p, isNotNull);
      expect(p!.version, '2.1');
      expect(p.fwTemporalSmoothingMode, 1);
    });

    test('parses new PONG: image FW version + proto 2.1 + temporal (7 fields)', () {
      final p = parseEsp32PongDatagram(
        '192.168.4.1',
        'ESP32_PONG|aabbcc|Ambilight_dd|2000|1.12.0|2.1|0',
      );
      expect(p, isNotNull);
      expect(p!.ip, '192.168.4.1');
      expect(p.ledCount, 2000);
      expect(p.version, '1.12.0');
      expect(p.fwTemporalSmoothingMode, 0);
      expect(p.fwDebugRejectSubnet19216888, isNull);
    });

    test('parses PONG with debug reject 192.168.88 flag (8 fields)', () {
      final p = parseEsp32PongDatagram(
        '10.0.0.5',
        'ESP32_PONG|aabbcc|Lamp|144|2.2|0|0|1',
      );
      expect(p, isNotNull);
      expect(p!.version, '2.2');
      expect(p.fwTemporalSmoothingMode, 0);
      expect(p.fwDebugRejectSubnet19216888, true);
      final off = parseEsp32PongDatagram('10.0.0.5', 'ESP32_PONG|aabbcc|Lamp|144|2.2|0|0|0');
      expect(off!.fwDebugRejectSubnet19216888, false);
    });

    test('rejects short string', () {
      expect(parseEsp32PongDatagram('1.1.1.1', 'ESP32_PONG|a|b'), isNull);
    });

    test('rejects non-PONG', () {
      expect(parseEsp32PongDatagram('1.1.1.1', 'NOISE'), isNull);
    });

    test('trims version whitespace', () {
      final p = parseEsp32PongDatagram('10.0.0.1', 'ESP32_PONG|01|Name|200|2.0 \n');
      expect(p!.version, '2.0');
    });
  });
}
