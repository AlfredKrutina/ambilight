import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../application/build_environment.dart';
import '../application/debug_trace.dart';

final _log = Logger('UdpBind');

bool _hasAddr(List<InternetAddress> list, InternetAddress a) =>
    list.any((x) => x.address == a.address);

/// Seřazení: stejná /24 jako [dest], pak ostatní ne‑loopback IPv4.
Future<List<InternetAddress>> _ipv4BindCandidates(InternetAddress dest) async {
  final dr = dest.rawAddress;
  final same = <InternetAddress>[];
  final other = <InternetAddress>[];
  if (dr.length != 4) return const [];
  try {
    final ifs =
        await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);
    for (final ni in ifs) {
      for (final a in ni.addresses) {
        if (a.type != InternetAddressType.IPv4 || a.isLoopback) continue;
        final raw = a.rawAddress;
        if (raw.length != 4) continue;
        if (raw[0] == dr[0] && raw[1] == dr[1] && raw[2] == dr[2]) {
          if (!_hasAddr(same, a)) same.add(a);
        } else {
          if (!_hasAddr(other, a)) other.add(a);
        }
      }
    }
  } catch (e, st) {
    ambilightDebugTrace('UdpBind: NetworkInterface.list selhalo', e, st);
  }
  return [...same, ...other];
}

/// Krátký odchozí datagram — ověření, že stack na Windows skutečně odešle (ne 0 B).
///
/// [destPort] musí odpovídat skutečnému provozu (např. 4210). Probe na „cizí“ port (42101)
/// může projít i když firewall blokuje jen lampový port.
Future<bool> _udpOutboundProbe(
  InternetAddress bindAddr,
  InternetAddress dest,
  int destPort, {
  bool broadcastEnabled = false,
}) async {
  final port = destPort.clamp(1, 65535);
  RawDatagramSocket? s;
  try {
    s = await RawDatagramSocket.bind(bindAddr, 0, reuseAddress: true);
    s.broadcastEnabled = broadcastEnabled;
    final n = s.send(Uint8List(1), dest, port);
    return n == 1;
  } catch (e, st) {
    ambilightDebugTrace(
      'UdpBind: probe výjimka bind=${bindAddr.address} → ${dest.address}',
      e,
      st,
    );
    return false;
  } finally {
    try {
      s?.close();
    } catch (_) {}
  }
}

/// Lokální adresa pro [RawDatagramSocket.bind] před odesláním na [dest].
///
/// Na Windows umí `send` vracet **0**, když není vybrané rozhraní — zkusíme kandidáty
/// krátkým probe na [probeDestinationPort] (stejný port jako produkční UDP).
///
/// [probeDestinationPort]: např. lampa `4210`. Bez shody může probe lhát (viz dokumentace výše).
Future<InternetAddress> udpBindAddressForOutgoingTo(
  InternetAddress dest, {
  /// Musí souhlasit s reálným UDP portem zařízení (např. 4210). Jinak probe na Windows klame.
  int probeDestinationPort = 4210,
}) async {
  if (dest.type != InternetAddressType.IPv4) {
    return InternetAddress.anyIPv6;
  }
  final probePort = probeDestinationPort.clamp(1, 65535);
  final candidates = await _ipv4BindCandidates(dest);
  if (candidates.isEmpty) {
    ambilightDebugTrace('UdpBind: žádná lokální IPv4 → 0.0.0.0');
    if (ambilightDetailedLogsEnabled) {
      _log.fine('Žádná lokální IPv4 pro cíl ${dest.address} → bind 0.0.0.0');
    }
    return InternetAddress.anyIPv4;
  }
  if (Platform.isWindows) {
    for (final c in candidates) {
      final ok = await _udpOutboundProbe(c, dest, probePort, broadcastEnabled: false);
      if (ok) {
        ambilightDebugTrace(
          'UdpBind: probe OK ${c.address} → ${dest.address}:$probePort',
        );
        if (ambilightDetailedLogsEnabled) {
          _log.fine(
            'Windows UDP bind vybráno ${c.address} (probe OK) → ${dest.address}:$probePort',
          );
        }
        return c;
      }
      ambilightDebugTrace(
        'UdpBind: probe fail ${c.address} → ${dest.address}:$probePort',
      );
    }
    final fallback = candidates.first;
    ambilightDebugTrace(
      'UdpBind: žádný probe na port $probePort neuspěl — používám první kandidát ${fallback.address} '
      '(ne 0.0.0.0); zkontroluj Windows Firewall výstup UDP na $probePort pro aplikaci)',
    );
    if (ambilightDetailedLogsEnabled) {
      _log.fine(
        'Windows UDP: probe na :$probePort selhal pro všechny rozhraní → bind ${fallback.address} '
        '(tip: výjimka firewall jen pro cílový UDP port)',
      );
    }
    return fallback;
  }
  final chosen = candidates.first;
  if (ambilightDetailedLogsEnabled) {
    _log.fine('UDP bind ${chosen.address} → ${dest.address} (bez probe, ${Platform.operatingSystem})');
  }
  return chosen;
}
