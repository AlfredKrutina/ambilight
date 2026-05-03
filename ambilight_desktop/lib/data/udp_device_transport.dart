import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../core/protocol/udp_frame.dart';
import 'device_transport.dart';
import 'udp_device_commands.dart';

final _log = Logger('UdpTransport');

class UdpDeviceTransport extends DeviceTransport {
  UdpDeviceTransport(super.device);

  RawDatagramSocket? _socket;
  InternetAddress? _addr;
  bool _ready = false;
  bool _loggedUdpOversize = false;
  bool _connecting = false;

  /// Po [disconnect]/[dispose] se zvýší — [connect] po `await` nesmí pokračovat se starým socketem.
  int _lifecycleGen = 0;

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
      return list.first;
    } catch (e) {
      _log.fine('UDP lookup $host: $e');
      return null;
    }
  }

  int get _udpPort => device.udpPort.clamp(1, 65535);

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
      // IPv4 cíl → anyIPv4; IPv6 → anyIPv6 (jinak send na macOS/Win může selhat).
      final bindAddr = _addr!.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4;
      final sock = await RawDatagramSocket.bind(bindAddr, 0);
      if (gen != _lifecycleGen) {
        try {
          sock.close();
        } catch (_) {}
        _addr = null;
        return;
      }
      _socket = sock;
      _socket!.broadcastEnabled = true;
      _ready = true;
      traceDeviceBindings('UdpTransport.connect OK: ${device.id} → ${_addr!.address}:$_udpPort');
      _log.info('UDP ready → ${_addr!.address}:$_udpPort');
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
    _lifecycleGen++;
    _ready = false;
    _socket?.close();
    _socket = null;
    _addr = null;
  }

  @override
  void sendColors(List<(int r, int g, int b)> colors, int brightnessScalar) {
    final sock = _socket;
    final addr = _addr;
    if (!_ready || sock == null || addr == null || colors.isEmpty) return;
    final bri = brightnessScalar.clamp(0, 255);
    final port = _udpPort;
    final cap = UdpAmbilightProtocol.maxRgbPixelsPerUdpDatagram;
    try {
      if (colors.length <= cap) {
        final pkt = UdpAmbilightProtocol.buildRgbFrame(colors, brightness: bri);
        sock.send(pkt, addr, port);
        return;
      }
      if (!_loggedUdpOversize) {
        _loggedUdpOversize = true;
        _log.info(
          'UDP rámec ${colors.length} LED > $cap — posílám $cap jako 0x02 a zbytek jako 0x03 (${device.name})',
        );
      }
      final head = colors.sublist(0, cap);
      final pkt = UdpAmbilightProtocol.buildRgbFrame(head, brightness: bri);
      sock.send(pkt, addr, port);
      /// Další LED jen přes 0x03 (`update_leds` na ESP je drahé) — strop navíc k 0x02 rámcům.
      const maxTail = 32;
      final limit = colors.length > cap + maxTail ? cap + maxTail : colors.length;
      for (var i = cap; i < limit; i++) {
        final (r, g, b) = colors[i];
        sock.send(UdpAmbilightProtocol.buildSinglePixel(i, r, g, b), addr, port);
      }
    } catch (e, st) {
      _log.fine('sendColors: $e', e, st);
    }
  }

  @override
  void sendPixel(int index, int r, int g, int b) {
    final sock = _socket;
    final addr = _addr;
    if (!_ready || sock == null || addr == null) return;
    try {
      final pkt = UdpAmbilightProtocol.buildSinglePixel(index, r, g, b);
      sock.send(pkt, addr, _udpPort);
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
