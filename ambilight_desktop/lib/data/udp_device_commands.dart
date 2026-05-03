import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger('UdpCommands');

/// Textové UDP příkazy z `ambilight.c` `task_udp` (port dle zařízení, výchozí 4210).
abstract final class UdpDeviceCommands {
  static const String identifyPayload = 'IDENTIFY';
  static const String resetWifiPayload = 'RESET_WIFI';

  static InternetAddress? _parseIp(String raw) {
    final ip = raw.replaceAll(',', '.').trim();
    return InternetAddress.tryParse(ip);
  }

  /// Jednorázové odeslání UTF-8 řetězce na [ip]:[port] (ephemeral socket).
  static Future<bool> sendUtf8Text(
    String ip,
    int port,
    String text, {
    String? logContext,
  }) async {
    final safePort = port.clamp(1, 65535);
    final addr = _parseIp(ip);
    if (addr == null) {
      _log.warning('sendUtf8Text: invalid IP "$ip" ${logContext ?? ''}');
      return false;
    }
    RawDatagramSocket? socket;
    try {
      final bindAddr =
          addr.type == InternetAddressType.IPv6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4;
      socket = await RawDatagramSocket.bind(bindAddr, 0);
      socket.broadcastEnabled = true;
      final bytes = Uint8List.fromList(utf8.encode(text));
      final n = socket.send(bytes, addr, safePort);
      final ok = n == bytes.length;
      _log.info('UDP → ${addr.address}:$safePort "$text" (${bytes.length} B) ok=$ok ${logContext ?? ''}');
      return ok;
    } catch (e) {
      _log.warning('sendUtf8Text failed $e ${logContext ?? ''}');
      return false;
    } finally {
      socket?.close();
    }
  }

  static Future<bool> sendIdentify(String ip, int port, {String? logContext}) =>
      sendUtf8Text(ip, port, identifyPayload, logContext: logContext ?? 'IDENTIFY');

  static Future<bool> sendResetWifi(String ip, int port, {String? logContext}) =>
      sendUtf8Text(ip, port, resetWifiPayload, logContext: logContext ?? 'RESET_WIFI');

  /// Příkaz `OTA_HTTP <url>` — firmware musí mít HTTPS OTA (viz `ambilight.c` + `ota_update.c`).
  /// [url] typicky přímý odkaz na `.bin` z manifestu (`ota_http_url`).
  static Future<bool> sendOtaHttpUrl(
    String ip,
    int port,
    String url, {
    String? logContext,
  }) {
    final u = url.trim();
    if (u.length < 12 || u.length > 1300) {
      _log.warning('sendOtaHttpUrl: URL příliš krátká nebo dlouhá');
      return Future.value(false);
    }
    final payload = 'OTA_HTTP $u';
    return sendUtf8Text(ip, port, payload, logContext: logContext ?? 'OTA_HTTP');
  }
}
