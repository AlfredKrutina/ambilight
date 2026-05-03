import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

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

  @override
  bool get isConnected => _ready && _socket != null && _addr != null;

  @override
  Future<void> connect() async {
    disconnect();
    final ip = device.ipAddress.replaceAll(',', '.');
    _addr = InternetAddress.tryParse(ip);
    if (_addr == null) {
      _log.warning('Bad IP: $ip');
      return;
    }
    try {
      // IPv4 cíl → anyIPv4; IPv6 → anyIPv6 (jinak send na macOS/Win může selhat).
      final bindAddr = _addr!.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4;
      _socket = await RawDatagramSocket.bind(bindAddr, 0);
      _socket!.broadcastEnabled = true;
      _ready = true;
      _log.info('UDP ready → ${_addr!.address}:${device.udpPort}');
    } catch (e) {
      _log.warning('UDP bind failed: $e');
    }
  }

  @override
  void disconnect() {
    _ready = false;
    _socket?.close();
    _socket = null;
    _addr = null;
  }

  @override
  void sendColors(List<(int r, int g, int b)> colors, int brightnessScalar) {
    if (!isConnected) return;
    final bri = brightnessScalar.clamp(0, 255);
    final pkt = UdpAmbilightProtocol.buildRgbFrame(colors, brightness: bri);
    try {
      _socket!.send(pkt, _addr!, device.udpPort);
    } catch (e) {
      _log.fine('send failed: $e');
    }
  }

  @override
  void sendPixel(int index, int r, int g, int b) {
    if (!isConnected) return;
    final pkt = UdpAmbilightProtocol.buildSinglePixel(index, r, g, b);
    try {
      _socket!.send(pkt, _addr!, device.udpPort);
    } catch (e) {
      _log.fine('pixel send: $e');
    }
  }

  @override
  void dispose() => disconnect();

  /// Modré bliknutí na pásku (viz `ambilight.c` IDENTIFY).
  Future<bool> sendIdentify() async {
    final ip = device.ipAddress;
    final port = device.udpPort;
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendIdentify(ip, port, logContext: device.name);
  }

  /// Po potvrzení v UI — smaže Wi‑Fi credentials a restartuje ESP.
  Future<bool> sendResetWifi() async {
    final ip = device.ipAddress;
    final port = device.udpPort;
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendResetWifi(ip, port, logContext: device.name);
  }
}
