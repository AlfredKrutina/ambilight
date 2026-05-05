import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../core/protocol/udp_frame.dart';
import '../data/udp_socket_bind.dart';

final _log = Logger('LedDiscovery');

/// Odvozené directed broadcast (/24) pro běžné Wi‑Fi — doplňuje 255.255.255.255 (Win/Linux někdy jen jedno z toho).
///
/// V režimu **ESP SoftAP** (typicky 192.168.4.1/24) Windows často opožďuje nebo vynechá rozhraní
/// v [NetworkInterface.list]; proto navíc `192.168.4.255` a unicast `192.168.4.1:udpPort`.
Future<void> _sendDiscoveryBroadcasts(RawDatagramSocket sock, int udpPort, Uint8List payload) async {
  void trySend(InternetAddress host, String label) {
    try {
      final n = sock.send(payload, host, udpPort);
      if (n != payload.length) {
        _log.fine('discover $label → ${host.address}: partial send $n/${payload.length}');
      }
    } catch (e) {
      _log.fine('discover $label → ${host.address}: $e');
    }
  }

  final seenSubnetBcast = <String>{};

  trySend(InternetAddress('255.255.255.255'), 'global-broadcast');
  seenSubnetBcast.add('255.255.255.255');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  try {
    final ifs = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);
    for (final ni in ifs) {
      for (final a in ni.addresses) {
        if (a.type != InternetAddressType.IPv4 || a.isLoopback) continue;
        final raw = a.rawAddress;
        if (raw.length != 4) continue;
        final bcastStr = '${raw[0]}.${raw[1]}.${raw[2]}.255';
        if (!seenSubnetBcast.add(bcastStr)) continue;
        trySend(InternetAddress(bcastStr), 'subnet-${ni.name}');
      }
    }
  } catch (e) {
    _log.fine('directed broadcast list: $e');
  }

  // Výchozí ESP-IDF SoftAP (/24 na 192.168.4.x) — doplnění když list rozhraní ještě neobsahuje hotspot.
  if (seenSubnetBcast.add('192.168.4.255')) {
    trySend(InternetAddress('192.168.4.255'), 'esp-softap-default-broadcast');
  }
  // Unicast na IP AP (spolehlivější než jen broadcast při „Public“ Wi‑Fi profilu na Windows).
  trySend(InternetAddress('192.168.4.1'), 'esp-softap-default-unicast');
}

/// One ESP32 answering `DISCOVER_ESP32` (see `ambilight.c`).
class DiscoveredLedController {
  const DiscoveredLedController({
    required this.ip,
    required this.macSuffix,
    required this.name,
    required this.ledCount,
    required this.version,
    this.fwTemporalSmoothingMode,
    this.fwDebugRejectSubnet19216888,
  });

  final String ip;
  final String macSuffix;
  final String name;
  final int ledCount;
  final String version;
  /// Z nového `ESP32_PONG|…|FW_VER|2.1|<0–2>`; u starého FW (`…|2.1|mode` bez FW pole) je `null`.
  final int? fwTemporalSmoothingMode;
  /// Z 8‑polového PONG (`…|2.2|0|0|0|1`); u starších odpovědí `null`.
  final bool? fwDebugRejectSubnet19216888;

  @override
  String toString() => '$name ($ip) leds=$ledCount';
}

/// Parsování odpovědi z `ambilight.c` (`ESP32_PONG|…`).
///
/// Nový tvar (7+ polí): `…|ledCount|FW_VER|2.1|temporal` — [version] = FW z image.
/// Legacy (5–6 polí): `…|ledCount|2.0` nebo `…|ledCount|2.1|temporal` — [version] bylo pole protokolu.
/// 8 polí: `…|led|2.2|0|0|temporal|rej88` — ladící přepínač odmítnutí 192.168.88.0/24.
DiscoveredLedController? parseEsp32PongDatagram(String sourceIp, String utf8Text) {
  final text = utf8Text.trim();
  if (!text.startsWith('ESP32_PONG')) return null;
  final parts = text.split('|');
  if (parts.length < 5) return null;

  final String versionStr;
  final int? temporal;
  bool? reject88;
  if (parts.length >= 8) {
    versionStr = parts[4].trim();
    temporal = int.tryParse(parts[6].trim());
    final r = int.tryParse(parts[7].trim());
    if (r == 0) {
      reject88 = false;
    } else if (r == 1) {
      reject88 = true;
    } else {
      reject88 = null;
    }
  } else if (parts.length >= 7) {
    versionStr = parts[4].trim();
    temporal = int.tryParse(parts[6].trim());
    reject88 = null;
  } else {
    versionStr = parts[4].trim();
    temporal = parts.length >= 6 ? int.tryParse(parts[5].trim()) : null;
    reject88 = null;
  }

  return DiscoveredLedController(
    ip: sourceIp,
    macSuffix: parts[1],
    name: parts[2],
    ledCount: int.tryParse(parts[3]) ?? 0,
    version: versionStr,
    fwTemporalSmoothingMode: temporal != null && temporal >= 0 && temporal <= 2 ? temporal : null,
    fwDebugRejectSubnet19216888: reject88,
  );
}

/// Broadcast discovery on [udpPort] (default 4210).
class LedDiscoveryService {
  LedDiscoveryService._();

  static Future<List<DiscoveredLedController>> scan({
    Duration timeout = const Duration(seconds: 3),
    int udpPort = 4210,
  }) async {
    final out = <String, DiscoveredLedController>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final sock = socket;
      late StreamSubscription sub;
      sub = sock.listen((event) {
        try {
          if (event != RawSocketEvent.read) return;
          final dg = sock.receive();
          if (dg == null) return;
          String text;
          try {
            text = utf8.decode(dg.data);
          } catch (_) {
            return;
          }
          final ip = dg.address.address;
          final parsed = parseEsp32PongDatagram(ip, text);
          if (parsed == null) return;
          out[ip] = parsed;
          _log.fine('PONG $parsed');
        } catch (e, st) {
          _log.fine('discovery listen: $e', e, st);
        }
      });
      final payload = Uint8List.fromList(utf8.encode(UdpAmbilightProtocol.discoverPayload));
      await _sendDiscoveryBroadcasts(sock, udpPort, payload);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _sendDiscoveryBroadcasts(sock, udpPort, payload);
      await Future<void>.delayed(timeout);
      await sub.cancel();
    } catch (e) {
      _log.warning('discovery: $e');
    } finally {
      socket?.close();
    }
    return out.values.toList();
  }

  /// Unicast `DISCOVER_ESP32` na konkrétní IP (např. ověření / firmware z PONG).
  static Future<DiscoveredLedController?> queryPong(
    String ip, {
    int udpPort = 4210,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final addr = InternetAddress.tryParse(ip.replaceAll(',', '.').trim());
    if (addr == null) return null;
    RawDatagramSocket? socket;
    try {
      final bindAddr = addr.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : await udpBindAddressForOutgoingTo(addr, probeDestinationPort: udpPort);
      socket = await RawDatagramSocket.bind(bindAddr, 0);
      socket.broadcastEnabled = true;
      DiscoveredLedController? found;
      final completer = Completer<void>();
      late StreamSubscription<RawSocketEvent> sub;
      sub = socket.listen((event) {
        try {
          if (event != RawSocketEvent.read) return;
          final dg = socket!.receive();
          if (dg == null) return;
          if (dg.address.address != addr.address) return;
          String text;
          try {
            text = utf8.decode(dg.data);
          } catch (_) {
            return;
          }
          found = parseEsp32PongDatagram(dg.address.address, text);
          if (found == null) return;
          if (!completer.isCompleted) completer.complete();
        } catch (e, st) {
          _log.fine('queryPong listen: $e', e, st);
        }
      });
      final payload = Uint8List.fromList(utf8.encode(UdpAmbilightProtocol.discoverPayload));
      socket.send(payload, addr, udpPort);
      await completer.future.timeout(timeout, onTimeout: () {});
      await sub.cancel();
      return found;
    } catch (e) {
      _log.fine('queryPong: $e');
      return null;
    } finally {
      socket?.close();
    }
  }
}
