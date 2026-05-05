// ignore_for_file: avoid_print
/// Spuštění z kořene balíčku: `dart run tool/fw_protocol_hex_samples.dart`
/// Výpis hexů pro ruční porovnání s Wireshark / logic analyzer.
import 'dart:convert';

import 'package:ambilight_desktop/core/protocol/serial_frame.dart';
import 'package:ambilight_desktop/core/protocol/udp_frame.dart';

String hex(Iterable<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

void main() {
  print('=== UTF-8 discovery / commands (ESP task_udp) ===');
  for (final s in [
    UdpAmbilightProtocol.discoverPayload,
    'IDENTIFY',
    'RESET_WIFI',
    'OTA_HTTP https://example.com/firmware.bin',
  ]) {
    final u = utf8.encode(s);
    print('$s (${u.length} B)');
    print(hex(u));
    print('');
  }

  print('=== UDP 0x02 bri=200 3 LED ===');
  print(hex(UdpAmbilightProtocol.buildRgbFrame([(1, 2, 3), (4, 5, 6), (7, 8, 9)], brightness: 200)));

  print('=== UDP 0x03 index 1000 ===');
  print(hex(UdpAmbilightProtocol.buildSinglePixel(1000, 11, 22, 33)));

  print('=== Serial ping ===');
  print(hex([SerialAmbilightProtocol.ping]));

  print('=== Serial announce 512 LED (0xA5 0x5A LE) ===');
  print(hex(SerialAmbilightProtocol.buildLedCountCommand(512)));

  print('=== Serial legacy frame start/end 2 LED ===');
  print(hex(SerialAmbilightProtocol.buildColorFrame([(10, 20, 30), (40, 50, 60)], stripLength: 2)));

  print('=== Serial wide frame 260 LED (first 3 only non-black) ===');
  final wideColors = List<(int, int, int)>.generate(260, (i) => i < 3 ? (i + 1, 0, 0) : (0, 0, 0));
  final wf = SerialAmbilightProtocol.buildColorFrame(wideColors, stripLength: 260);
  print('length=${wf.length} head=${hex(wf.take(16))} ... tail=${hex(wf.skip(wf.length - 8))}');
}
