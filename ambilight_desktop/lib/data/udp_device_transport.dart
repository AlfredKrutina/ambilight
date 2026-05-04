import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../application/build_environment.dart';
import '../application/debug_trace.dart';
import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../core/protocol/udp_frame.dart';
import 'device_transport.dart';
import 'udp_device_commands.dart';
import 'udp_socket_bind.dart';

final _log = Logger('UdpTransport');

/// Minimální odstup mezi bulk `0x02` rámci — lamp FW v `ambilight.c` zahazuje rámce blíž než ~15 ms.
const Duration _kMinBulkRgbUdpInterval = Duration(milliseconds: 16);

class UdpDeviceTransport extends DeviceTransport {
  UdpDeviceTransport(super.device);

  RawDatagramSocket? _socket;
  InternetAddress? _addr;
  bool _ready = false;
  bool _loggedUdpOversize = false;
  bool _connecting = false;

  /// Po [disconnect]/[dispose] se zvýší — [connect] po `await` nesmí pokračovat se starým socketem.
  int _lifecycleGen = 0;

  Timer? _bulkFlushTimer;
  List<(int r, int g, int b)>? _pendingRgb;
  int _pendingBri = 255;
  DateTime? _lastBulkSentWallClock;
  int _coalesceReplaceCount = 0;
  int _bulkSentCount = 0;
  DateTime? _lastUdpMetricsLog;
  DateTime? _lastPartialSendLog;

  /// Windows: vícedatagramové `0x06`+`0x08` nesmí běžet paralelně — jinak se pakety dvou snímků propletou a `send` vrací 0.
  Future<void>? _windowsOversizedSendChain;

  /// Lokální bind z [connect] — stejná větev jako úspěšný UDP probe na Windows.
  InternetAddress? _udpBindAddrUsed;

  @override
  bool get isConnected => _ready && _socket != null && _addr != null;

  static Future<InternetAddress?> _resolveTarget(String raw) async {
    final host = raw.replaceAll(',', '.').trim();
    if (host.isEmpty) return null;
    final direct = InternetAddress.tryParse(host);
    if (direct != null) return direct;
    try {
      final list = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      if (list.isEmpty) return null;
      for (final a in list) {
        if (a.type == InternetAddressType.IPv4) return a;
      }
      return list.first;
    } catch (e) {
      _log.fine('UDP lookup $host: $e');
      return null;
    }
  }

  int get _udpPort => device.udpPort.clamp(1, 65535);

  void _sendUdp(RawDatagramSocket sock, Uint8List pkt, InternetAddress addr, int port) {
    if (pkt.isEmpty) return;
    if (Platform.isWindows) {
      var n = sock.send(pkt, addr, port);
      if (n == 0) {
        n = sock.send(pkt, addr, port);
      }
      if (n == pkt.length) {
        return;
      }
      // Krátký životní cyklus socketu jako při probe — na některých Windows buildích Flutter/Dart
      // dlouho držení RawDatagramSocket + send vrací 0 a RawSocketEvent.write nepřijde.
      unawaited(_sendUdpEphemeralWindows(Uint8List.fromList(pkt), addr, port));
      return;
    }
    var n = sock.send(pkt, addr, port);
    if (n == 0) {
      n = sock.send(pkt, addr, port);
    }
    _logUdpSendFailureIfNeeded(n, pkt.length, addr, port);
  }

  Future<void> _sendUdpEphemeralWindows(Uint8List pkt, InternetAddress addr, int port) async {
    await _sendPreparedPacketsEphemeralWindows(<Uint8List>[pkt], addr, port);
  }

  /// Jeden krátký UDP socket na celý „snímek“ — zachová pořadí `0x06`×N + `0x08` (Windows / Flutter).
  Future<void> _sendPreparedPacketsEphemeralWindows(
    List<Uint8List> packets,
    InternetAddress addr,
    int port,
  ) async {
    if (packets.isEmpty) {
      return;
    }
    final genEnter = _lifecycleGen;
    try {
      InternetAddress bindAddr;
      if (addr.type == InternetAddressType.IPv6) {
        bindAddr = InternetAddress.anyIPv6;
      } else {
        bindAddr = _udpBindAddrUsed ??
            await udpBindAddressForOutgoingTo(addr, probeDestinationPort: port);
      }
      if (genEnter != _lifecycleGen) {
        return;
      }
      final s = await RawDatagramSocket.bind(bindAddr, 0, reuseAddress: true);
      try {
        if (genEnter != _lifecycleGen) {
          return;
        }
        s.broadcastEnabled = false;
        for (var i = 0; i < packets.length; i++) {
          final pkt = packets[i];
          await _sendOneEphemeralDatagramWindows(s, pkt, addr, port);
        }
        if (ambilightVerboseLogsEnabled && packets.isNotEmpty) {
          final bytes = packets.fold<int>(0, (a, p) => a + p.length);
          _log.fine(
            'UDP Windows: ephemeral socket odesláno ${packets.length} pkt / $bytes B (persistent socket vrací 0)',
          );
        }
      } finally {
        s.close();
      }
    } catch (e, st) {
      _log.fine('UDP Windows ephemeral: $e', e, st);
    }
  }

  Future<void> _sendOneEphemeralDatagramWindows(
    RawDatagramSocket s,
    Uint8List pkt,
    InternetAddress addr,
    int port,
  ) async {
    const maxAttempts = 16;
    const retryDelay = Duration(milliseconds: 2);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final n = s.send(pkt, addr, port);
      if (n == pkt.length) {
        return;
      }
      await Future<void>.delayed(retryDelay);
    }
    _logUdpSendFailureIfNeeded(0, pkt.length, addr, port);
  }

  void _logUdpSendFailureIfNeeded(int n, int expected, InternetAddress addr, int port) {
    if (n == expected) return;
    final now = DateTime.now();
    if (_lastPartialSendLog == null ||
        now.difference(_lastPartialSendLog!) > const Duration(seconds: 5)) {
      _lastPartialSendLog = now;
      ambilightDebugTrace(
        'UdpTransport send vrátilo $n/$expected B → ${device.name} ${addr.address}:$port',
      );
      _log.warning(
        'UDP send selhal ($n/$expected B) → ${device.name} ${addr.address}:$port '
        '(firewall / síť; rámce jsou << MTU a pod limitem lampy)',
      );
    }
  }

  @override
  Future<void> connect() async {
    if (_connecting || isConnected) return;
    _connecting = true;
    _loggedUdpOversize = false;
    try {
      disconnect();
      final gen = _lifecycleGen;
      final raw = device.ipAddress;
      _addr = await _resolveTarget(raw);
      if (gen != _lifecycleGen) {
        _addr = null;
        return;
      }
      if (_addr == null) {
        _log.warning('UDP: neplatná adresa nebo DNS selhalo: $raw');
        return;
      }
      final bindAddr =
          await udpBindAddressForOutgoingTo(_addr!, probeDestinationPort: _udpPort);
      final sock = await RawDatagramSocket.bind(bindAddr, 0, reuseAddress: true);
      if (gen != _lifecycleGen) {
        try {
          sock.close();
        } catch (_) {}
        _addr = null;
        return;
      }
      _socket = sock;
      _udpBindAddrUsed = bindAddr;
      // Unicast na konkrétní IP — broadcast true umí na některých Windows driverech kazit send().
      _socket!.broadcastEnabled = false;
      _ready = true;
      traceDeviceBindings('UdpTransport.connect OK: ${device.id} → ${_addr!.address}:$_udpPort');
      ambilightDebugTrace(
        'UdpTransport socket dev=${device.id} local=${bindAddr.address} remote=${_addr!.address}:$_udpPort '
        'broadcast=${_socket!.broadcastEnabled}',
      );
      _log.info('UDP ready local=${bindAddr.address} → remote=${_addr!.address}:$_udpPort');
    } catch (e, st) {
      traceDeviceBindingsWarning(
        'UdpTransport.connect FAIL ${device.id} ${device.ipAddress}',
        e,
        st,
      );
      _log.warning('UDP connect failed: $e', e, st);
      disconnect();
    } finally {
      _connecting = false;
    }
  }

  @override
  void disconnect() {
    _bulkFlushTimer?.cancel();
    _bulkFlushTimer = null;
    _pendingRgb = null;
    _lifecycleGen++;
    _udpBindAddrUsed = null;
    _ready = false;
    _socket?.close();
    _socket = null;
    _addr = null;
    _windowsOversizedSendChain = null;
  }

  void _maybeLogUdpCoalesceMetrics() {
    if (!ambilightVerboseLogsEnabled) return;
    if (_coalesceReplaceCount == 0) return;
    final now = DateTime.now();
    if (_lastUdpMetricsLog != null && now.difference(_lastUdpMetricsLog!) < const Duration(seconds: 8)) {
      return;
    }
    _lastUdpMetricsLog = now;
    _log.info(
      '[UDP pacing ${device.name}] bulk_out=$_bulkSentCount coalesced_incoming=$_coalesceReplaceCount '
      '(FW ~15 ms limit — sloučení zabraňuje zahazování 0x02)',
    );
    _coalesceReplaceCount = 0;
    _bulkSentCount = 0;
  }

  void _scheduleBulkFlush() {
    if (_bulkFlushTimer?.isActive == true) return;
    final last = _lastBulkSentWallClock;
    final now = DateTime.now();
    final delay = last == null
        ? Duration.zero
        : (() {
            final elapsed = now.difference(last);
            return elapsed >= _kMinBulkRgbUdpInterval ? Duration.zero : _kMinBulkRgbUdpInterval - elapsed;
          })();
    _bulkFlushTimer = Timer(delay, _onBulkFlushTimer);
  }

  void _onBulkFlushTimer() {
    _bulkFlushTimer = null;
    if (!_ready) {
      _pendingRgb = null;
      return;
    }
    final colors = _pendingRgb;
    if (colors == null || colors.isEmpty) return;
    _pendingRgb = null;
    _sendColorsImmediateWithCompletion(
      colors,
      _pendingBri,
      onFullySent: _completeBulkFlushCycle,
    );
  }

  void _completeBulkFlushCycle() {
    _lastBulkSentWallClock = DateTime.now();
    _bulkSentCount++;
    _maybeLogUdpCoalesceMetrics();
    if (_pendingRgb != null && _pendingRgb!.isNotEmpty) {
      _scheduleBulkFlush();
    }
  }

  /// [onFullySent] po všech odchozích datagramech — Windows oversize čeká na ephemeral řetězec,
  /// aby další bulk nezačal dřív (FW sdílený 15ms throttle mezi 0x08 / 0x02).
  void _sendColorsImmediateWithCompletion(
    List<(int r, int g, int b)> colors,
    int brightnessScalar, {
    required void Function() onFullySent,
  }) {
    final sock = _socket;
    final addr = _addr;
    if (!_ready || sock == null || addr == null || colors.isEmpty) {
      onFullySent();
      return;
    }
    final bri = brightnessScalar.clamp(0, 255);
    final port = _udpPort;
    final cap = UdpAmbilightProtocol.maxRgbPixelsPerUdpDatagram;
    try {
      if (colors.length <= cap) {
        final pkt = UdpAmbilightProtocol.buildRgbFrame(colors, brightness: bri);
        _sendUdp(sock, pkt, addr, port);
        onFullySent();
        return;
      }
      if (!_loggedUdpOversize) {
        _loggedUdpOversize = true;
        _log.info(
          'UDP ${colors.length} LED > $cap — chunky 0x06 + jeden flush 0x08 (${device.name}). '
          'Vyžaduje aktuální lamp FW; kalibrace jedním pixelem stále 0x03.',
        );
      }
      final chunkMax = UdpAmbilightProtocol.maxRgbPixelsPerUdpOpcode06Chunk;
      if (Platform.isWindows) {
        final packets = <Uint8List>[];
        var offset = 0;
        while (offset < colors.length) {
          final take = colors.length - offset > chunkMax ? chunkMax : colors.length - offset;
          final sub = colors.sublist(offset, offset + take);
          packets.add(UdpAmbilightProtocol.buildRgbChunkOpcode06(offset, sub));
          offset += take;
        }
        packets.add(UdpAmbilightProtocol.buildFlushOpcode08(bri, colors.length));
        _windowsOversizedSendChain =
            (_windowsOversizedSendChain ?? Future<void>.value()).then((_) async {
          try {
            await _sendPreparedPacketsEphemeralWindows(packets, addr, port);
          } finally {
            onFullySent();
          }
        });
        unawaited(_windowsOversizedSendChain);
        return;
      }
      var offset = 0;
      while (offset < colors.length) {
        final take = colors.length - offset > chunkMax ? chunkMax : colors.length - offset;
        final sub = colors.sublist(offset, offset + take);
        final pkt = UdpAmbilightProtocol.buildRgbChunkOpcode06(offset, sub);
        _sendUdp(sock, pkt, addr, port);
        offset += take;
      }
      _sendUdp(
        sock,
        UdpAmbilightProtocol.buildFlushOpcode08(bri, colors.length),
        addr,
        port,
      );
      onFullySent();
    } catch (e, st) {
      _log.fine('sendColors: $e', e, st);
      onFullySent();
    }
  }

  @override
  Future<void> sendColorsNow(List<(int r, int g, int b)> colors, int brightnessPercent) async {
    if (!_ready || _socket == null || _addr == null || colors.isEmpty) {
      return;
    }
    _bulkFlushTimer?.cancel();
    _bulkFlushTimer = null;
    _pendingRgb = null;
    final completer = Completer<void>();
    _sendColorsImmediateWithCompletion(
      colors,
      brightnessPercent.clamp(0, 255),
      onFullySent: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
    return completer.future;
  }

  @override
  void sendColors(List<(int r, int g, int b)> colors, int brightnessScalar) {
    if (!_ready || _socket == null || _addr == null || colors.isEmpty) return;
    if (_pendingRgb != null) {
      _coalesceReplaceCount++;
    }
    _pendingRgb = List<(int, int, int)>.from(colors, growable: false);
    _pendingBri = brightnessScalar.clamp(0, 255);
    _scheduleBulkFlush();
  }

  @override
  void sendPixel(int index, int r, int g, int b) {
    final sock = _socket;
    final addr = _addr;
    if (!_ready || sock == null || addr == null) return;
    try {
      final pkt = Uint8List.fromList(UdpAmbilightProtocol.buildSinglePixel(index, r, g, b));
      final port = _udpPort;
      // Windows: persistent RawDatagramSocket často vrací 0 — vždy ephemeral; zařadit za
      // [_windowsOversizedSendChain], ať 0x03 neproběhne před dokončeným 0x06/0x08.
      if (Platform.isWindows) {
        _windowsOversizedSendChain =
            (_windowsOversizedSendChain ?? Future<void>.value()).then((_) async {
          await _sendUdpEphemeralWindows(pkt, addr, port);
        });
        unawaited(_windowsOversizedSendChain);
        return;
      }
      _sendUdp(sock, pkt, addr, port);
    } catch (e, st) {
      _log.fine('pixel send: $e', e, st);
    }
  }

  @override
  void syncDeviceSnapshot(DeviceSettings next) {
    device = next;
  }

  @override
  void dispose() => disconnect();

  /// Modré bliknutí na pásku (viz `ambilight.c` IDENTIFY).
  Future<bool> sendIdentify() async {
    final ip = device.ipAddress;
    final port = _udpPort;
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendIdentify(ip, port, logContext: device.name);
  }

  /// Po potvrzení v UI — smaže Wi‑Fi credentials a restartuje ESP.
  Future<bool> sendResetWifi() async {
    final ip = device.ipAddress;
    final port = _udpPort;
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendResetWifi(ip, port, logContext: device.name);
  }
}
