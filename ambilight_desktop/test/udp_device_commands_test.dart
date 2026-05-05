import 'dart:convert';
import 'dart:io';

import 'package:ambilight_desktop/data/udp_device_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sendOtaHttpUrl rejects URL shorter than 12 chars', () async {
    final ok = await UdpDeviceCommands.sendOtaHttpUrl('127.0.0.1', 4210, 'https://x');
    expect(ok, isFalse);
  });

  test('rejectReason flags non-http(s) schemes like firmware', () {
    expect(
      UdpDeviceCommands.rejectReasonForOtaHttpCommand(
        '127.0.0.1',
        4210,
        'ftp://example.com/file.bin',
      ),
      OtaHttpCommandRejectReason.urlSchemeNotHttp,
    );
    expect(UdpDeviceCommands.rejectReasonForOtaHttpCommand('127.0.0.1', 4210, 'https://ex.com/x.bin'), isNull);
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

  test('versionFromOtaOkDatagram accepts reply from lamp IP only', () {
    final lamp = InternetAddress('192.168.1.5');
    final other = InternetAddress('192.168.1.6');
    final ok = Datagram(utf8.encode('AMBILIGHT OTA_OK 1.2.3\n'), lamp, 5555);
    expect(UdpDeviceCommands.versionFromOtaOkDatagram(ok, lamp), '1.2.3');
    final wrongHost = Datagram(utf8.encode('AMBILIGHT OTA_OK 1.2.3\n'), other, 5555);
    expect(UdpDeviceCommands.versionFromOtaOkDatagram(wrongHost, lamp), isNull);
    final noise = Datagram(utf8.encode('ESP32_PONG|x'), lamp, 5555);
    expect(UdpDeviceCommands.versionFromOtaOkDatagram(noise, lamp), isNull);
  });
}
