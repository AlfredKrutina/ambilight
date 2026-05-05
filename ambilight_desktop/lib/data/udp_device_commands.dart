import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../application/debug_trace.dart';
import '../core/protocol/udp_frame.dart';
import 'udp_socket_bind.dart';

final _log = Logger('UdpCommands');

/// Důvod zamítnutí `OTA_HTTP` před odesláním — shodné kontroly jako [`ota_update.c`] `ambilight_start_ota`
/// + platná cílová IP pro socket.
enum OtaHttpCommandRejectReason {
  invalidTargetIp,
  urlTooShort,
  urlTooLong,
  urlSchemeNotHttp,
  invalidUrlCharacters,
  commandPayloadInvalid,
}

/// Textové UDP příkazy z `ambilight.c` `task_udp` (port dle zařízení, výchozí 4210).
abstract final class UdpDeviceCommands {
  static const String identifyPayload = 'IDENTIFY';
  static const String resetWifiPayload = 'RESET_WIFI';

  /// Horní mez UTF‑8 payloadu pro jeden datagram — ESP `rx_buffer` / bez fragmentace UDP.
  static const int maxSafeUtf8PayloadBytes = 1400;

  /// Shoda s lamp FW [`ota_update.c`] `ota_url_chars_valid`: žádné `\0`, řídicí znaky `<0x20`, ani `0x7F`;
  /// URL nesmí být jen mezery/tabulátory. Zároveň platí UTF‑8 bez vloženého NUL bajtu — FW vyžaduje `strlen(rx)==len` datagramu.
  static bool isOtaUrlCompatibleWithLampFirmware(String url) {
    if (url.isEmpty) {
      return false;
    }
    var seenNonSpace = false;
    for (final r in url.runes) {
      if (r == 0 || r < 0x20 || r == 0x7f) {
        return false;
      }
      if (r != 0x20 && r != 0x09) {
        seenNonSpace = true;
      }
    }
    return seenNonSpace;
  }

  /// Celý řetězec datagramu (např. `OTA_HTTP …`) — stejná pravidla jako [isOtaUrlCompatibleWithLampFirmware].
  static bool isUtf8DatagramCompatibleWithLampTaskUdp(String text) => isOtaUrlCompatibleWithLampFirmware(text);

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
      final bindAddr = addr.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : await udpBindAddressForOutgoingTo(addr, probeDestinationPort: safePort);
      socket = await RawDatagramSocket.bind(bindAddr, 0);
      socket.broadcastEnabled = false;
      ambilightDebugTrace(
        'UdpCommands sendUtf8 bind=${bindAddr.address} → ${addr.address}:$safePort'
        '${logContext != null ? " ($logContext)" : ""}',
      );
      final bytes = Uint8List.fromList(utf8.encode(text));
      if (bytes.contains(0)) {
        _log.warning('sendUtf8Text: payload obsahuje NUL — lamp FW textové příkazy odmítne ${logContext ?? ''}');
        return false;
      }
      if (bytes.isEmpty || bytes.length > maxSafeUtf8PayloadBytes) {
        _log.warning(
          'sendUtf8Text: délka payloadu ${bytes.length} B mimo rozsah 1…$maxSafeUtf8PayloadBytes ${logContext ?? ''}',
        );
        return false;
      }
      var n = socket.send(bytes, addr, safePort);
      if (n == 0) {
        n = socket.send(bytes, addr, safePort);
      }
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

  /// Binární `0xF1` + mode (0…2); lampa FW odpoví stejnými 2 bajty (ACK).
  static Future<bool> sendTemporalModeWithAck(
    String ip,
    int port,
    int mode, {
    Duration timeout = const Duration(milliseconds: 450),
    String? logContext,
  }) async {
    final m = mode.clamp(0, 2);
    final addr = _parseIp(ip);
    if (addr == null) {
      _log.warning('sendTemporalModeWithAck: invalid IP "$ip" ${logContext ?? ''}');
      return false;
    }
    final safePort = port.clamp(1, 65535);
    final pkt = UdpAmbilightProtocol.buildFirmwareTemporalModeFrame(m);
    RawDatagramSocket? socket;
    try {
      final bindAddr = addr.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : await udpBindAddressForOutgoingTo(addr, probeDestinationPort: safePort);
      socket = await RawDatagramSocket.bind(bindAddr, 0);
      socket.broadcastEnabled = false;
      var acked = false;
      final completer = Completer<void>();
      late StreamSubscription<RawSocketEvent> sub;
      sub = socket.listen((event) {
        try {
          if (event != RawSocketEvent.read) return;
          final dg = socket!.receive();
          if (dg == null) return;
          if (dg.address.address != addr.address) return;
          final d = dg.data;
          if (d.length == 2 &&
              d[0] == UdpAmbilightProtocol.firmwareTemporalModeOpcode &&
              d[1] == m) {
            acked = true;
            if (!completer.isCompleted) completer.complete();
          }
        } catch (e, st) {
          _log.fine('sendTemporalModeWithAck listen: $e', e, st);
        }
      });
      var n = socket.send(pkt, addr, safePort);
      if (n == 0) {
        n = socket.send(pkt, addr, safePort);
      }
      if (n != pkt.length) {
        _log.warning('sendTemporalModeWithAck: partial send $n/${pkt.length} ${logContext ?? ''}');
        await sub.cancel();
        return false;
      }
      await completer.future.timeout(timeout, onTimeout: () {});
      await sub.cancel();
      _log.fine('sendTemporalModeWithAck mode=$m ack=$acked ${logContext ?? ''}');
      return acked;
    } catch (e) {
      _log.warning('sendTemporalModeWithAck failed $e ${logContext ?? ''}');
      return false;
    } finally {
      socket?.close();
    }
  }

  /// Vrací důvod zamítnutí, nebo `null` pokud je v pořádku pokračovat na [sendOtaHttpUrl].
  static OtaHttpCommandRejectReason? rejectReasonForOtaHttpCommand(
    String ip,
    int port,
    String url,
  ) {
    if (port < 1 || port > 65535) {
      return OtaHttpCommandRejectReason.invalidTargetIp;
    }
    if (_parseIp(ip) == null) {
      return OtaHttpCommandRejectReason.invalidTargetIp;
    }
    final u = url.trim();
    if (u.length < 12) {
      return OtaHttpCommandRejectReason.urlTooShort;
    }
    if (u.length > 1300) {
      return OtaHttpCommandRejectReason.urlTooLong;
    }
    if (!u.startsWith('https://') && !u.startsWith('http://')) {
      return OtaHttpCommandRejectReason.urlSchemeNotHttp;
    }
    if (!isOtaUrlCompatibleWithLampFirmware(u)) {
      return OtaHttpCommandRejectReason.invalidUrlCharacters;
    }
    final payload = 'OTA_HTTP $u';
    if (!isUtf8DatagramCompatibleWithLampTaskUdp(payload)) {
      return OtaHttpCommandRejectReason.commandPayloadInvalid;
    }
    return null;
  }

  /// Příkaz `OTA_HTTP <url>` — lamp firmware (`esp32c3_lamp_firmware/main/ota_update.c`).
  /// [url] typicky přímý odkaz na `.bin` z manifestu (`ota_http_url`).
  static Future<bool> sendOtaHttpUrl(
    String ip,
    int port,
    String url, {
    String? logContext,
  }) {
    final reject = rejectReasonForOtaHttpCommand(ip, port, url);
    if (reject != null) {
      _log.warning('sendOtaHttpUrl: rejected $reject');
      return Future.value(false);
    }
    final u = url.trim();
    final payload = 'OTA_HTTP $u';
    return sendUtf8Text(ip, port, payload, logContext: logContext ?? 'OTA_HTTP');
  }
}
