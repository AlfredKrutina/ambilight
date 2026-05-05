import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../core/protocol/udp_frame.dart';
import '../data/udp_socket_bind.dart';

final _log = Logger('LedDiscovery');

/// Odvozené directed broadcast (/24) pro běžné Wi‑Fi — doplňuje 255.255.255.255 (Win/Linux někdy jen jedno z toho).
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

  trySend(InternetAddress('255.255.255.255'), 'global-broadcast');
  await Future<void>.delayed(const Duration(milliseconds: 20));

  try {
    final ifs = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);
    final seen = <String>{'255.255.255.255'};
    for (final ni in ifs) {
      for (final a in ni.addresses) {
        if (a.type != InternetAddressType.IPv4 || a.isLoopback) continue;
        final raw = a.rawAddress;
        if (raw.length != 4) continue;
        final bcastStr = '${raw[0]}.${raw[1]}.${raw[2]}.255';
        if (!seen.add(bcastStr)) continue;
        trySend(InternetAddress(bcastStr), 'subnet-${ni.name}');
      }
    }
  } catch (e) {
    _log.fine('directed broadcast list: $e');
  }
}

/// One ESP32 answering `DISCOVER_ESP32` (see `ambilight.c`).
class DiscoveredLedController {
  const DiscoveredLedController({
    required this.ip,
    required this.macSuffix,
    required this.name,
    required this.ledCount,
    required this.version,
  });

  final String ip;
  final String macSuffix;
  final String name;
  final int ledCount;
  final String version;

  @override
  String toString() => '$name ($ip) leds=$ledCount';
}

/// Parsování odpovědi z `ambilight.c` (`sprintf` … `ESP32_PONG|…`).
DiscoveredLedController? parseEsp32PongDatagram(String sourceIp, String utf8Text) {
  final text = utf8Text.trim();
  if (!text.startsWith('ESP32_PONG')) return null;
  final parts = text.split('|');
  if (parts.length < 5) return null;
  return DiscoveredLedController(
    ip: sourceIp,
    macSuffix: parts[1],
    name: parts[2],
    ledCount: int.tryParse(parts[3]) ?? 0,
    version: parts[4].trim(),
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
