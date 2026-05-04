import 'package:ambilight_desktop/data/udp_device_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sendOtaHttpUrl rejects URL shorter than 12 chars', () async {
    final ok = await UdpDeviceCommands.sendOtaHttpUrl('127.0.0.1', 4210, 'https://x');
    expect(ok, isFalse);
  });

  test('sendOtaHttpUrl rejects URL over 1300 chars', () async {
    final long = 'https://example.com/${'a' * 1300}';
    expect(long.length, greaterThan(1300));
    final ok = await UdpDeviceCommands.sendOtaHttpUrl('127.0.0.1', 4210, long);
    expect(ok, isFalse);
  });

  test('sendUtf8Text rejects payload over maxSafeUtf8PayloadBytes', () async {
    final huge = 'Z' * (UdpDeviceCommands.maxSafeUtf8PayloadBytes + 1);
    final ok = await UdpDeviceCommands.sendUtf8Text('127.0.0.1', 4210, huge);
    expect(ok, isFalse);
  });

  test('sendUtf8Text rejects empty payload', () async {
    final ok = await UdpDeviceCommands.sendUtf8Text('127.0.0.1', 4210, '');
    expect(ok, isFalse);
  });
}
