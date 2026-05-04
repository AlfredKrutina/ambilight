import 'dart:convert';

import 'package:ambilight_desktop/core/protocol/udp_frame.dart';
import 'package:ambilight_desktop/data/udp_device_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery payload byte length', () {
    final d = utf8.encode(UdpAmbilightProtocol.discoverPayload);
    expect(d.length, 14);
    expect(UdpAmbilightProtocol.discoverPayload, 'DISCOVER_ESP32');
  });

  test('command UTF-8 lengths within maxSafeUtf8PayloadBytes', () {
    expect(utf8.encode(UdpDeviceCommands.identifyPayload).length <= UdpDeviceCommands.maxSafeUtf8PayloadBytes, isTrue);
    expect(utf8.encode(UdpDeviceCommands.resetWifiPayload).length <= UdpDeviceCommands.maxSafeUtf8PayloadBytes, isTrue);
    final ota = 'OTA_HTTP https://example.com/${'x' * 200}.bin';
    expect(utf8.encode(ota).length <= UdpDeviceCommands.maxSafeUtf8PayloadBytes, isTrue);
  });

  test('sendOtaHttpUrl rejects extreme URL lengths', () async {
    expect(await UdpDeviceCommands.sendOtaHttpUrl('127.0.0.1', 4210, ''), isFalse);
    expect(await UdpDeviceCommands.sendOtaHttpUrl('127.0.0.1', 4210, 'x' * 1400), isFalse);
  });

  test('isOtaUrlCompatibleWithLampFirmware matches FW ota_url_chars_valid', () {
    expect(UdpDeviceCommands.isOtaUrlCompatibleWithLampFirmware('https://a.com/x.bin'), isTrue);
    expect(UdpDeviceCommands.isOtaUrlCompatibleWithLampFirmware('   '), isFalse);
    expect(UdpDeviceCommands.isOtaUrlCompatibleWithLampFirmware('https://x\n'), isFalse);
    expect(UdpDeviceCommands.isOtaUrlCompatibleWithLampFirmware('https://x\u0000y'), isFalse);
  });
}
