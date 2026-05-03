import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import '../core/models/config_models.dart';
import '../core/protocol/serial_frame.dart';
import 'device_transport.dart';

final _log = Logger('SerialTransport');

/// USB-serial to ESP32: handshake + framed RGB (see Python `SerialHandler`).
class SerialDeviceTransport extends DeviceTransport {
  SerialDeviceTransport(
    super.device, {
    this.baudRate = 115200,
    this.writeQueuePeriodMs = 4,
  });

  /// Musí odpovídat `global_settings.baud_rate` v JSON (jako Python `SerialHandler.baud_rate`).
  final int baudRate;
  /// Perioda vyprázdnění fronty zápisů (ms); v performance módu vyšší = méně wake-upů.
  final int writeQueuePeriodMs;

  SerialPort? _port;
  bool _connected = false;
  final Queue<_Frame> _queue = Queue();
  Timer? _drainTimer;
  bool _connecting = false;

  @override
  bool get isConnected => _connected && (_port?.isOpen ?? false);

  @override
  Future<void> connect() async {
    if (_connecting || isConnected) return;
    _connecting = true;
    try {
      disconnect();
      final portName = device.port;
      if (_isPlaceholderPort(portName)) {
        return;
      }
      final port = SerialPort(portName);
      if (!port.openReadWrite()) {
        _log.fine('openReadWrite failed $portName: ${SerialPort.lastError}');
        port.dispose();
        return;
      }
      // Stejné signály jako Python `SerialHandler._connect`: RTS on, DTR off,
      // plná 8N1 + bez flow control (Win/macOS driver parity).
      _applySerialConfig(port);
      try {
        port.flush(SerialPortBuffer.both);
      } on SerialPortError catch (e) {
        _log.fine('flush after open: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await _handshakeAsync(port)) {
        await _hardResetEspSerial(port);
        if (!await _handshakeAsync(port)) {
          _log.fine('Handshake failed on $portName (after hard reset)');
          try {
            if (port.isOpen) port.close();
          } on SerialPortError catch (_) {}
          port.dispose();
          return;
        }
      }
      _port = port;
      _connected = true;
      _log.info('Serial connected $portName');
      _drainTimer ??= Timer.periodic(const Duration(milliseconds: 4), (_) => _drain());
    } on SerialPortError catch (e) {
      _log.warning('SerialPortError: $e');
    } finally {
      _connecting = false;
    }
  }

  /// Konfigurace portu po [openReadWrite] (knihovna vyžaduje otevřený port).
  /// Volitelně přepíše RTS/DTR (např. hard reset sekvence).
  void _applySerialConfig(
    SerialPort port, {
    int? rts,
    int? dtr,
  }) {
    final br = baudRate.clamp(9600, 921600);
    final cfg = SerialPortConfig()
      ..baudRate = br
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none)
      ..rts = rts ?? SerialPortRts.on
      ..dtr = dtr ?? SerialPortDtr.off;
    port.config = cfg;
    cfg.dispose();
  }

  /// Jako Python `SerialHandler._connect` po neúspěšném handshake.
  Future<void> _hardResetEspSerial(SerialPort port) async {
    _log.fine('Serial: attempting ESP hard reset (DTR/RTS)');
    _applySerialConfig(port, rts: SerialPortRts.on, dtr: SerialPortDtr.off);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _applySerialConfig(port, rts: SerialPortRts.on, dtr: SerialPortDtr.on);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _applySerialConfig(port, rts: SerialPortRts.on, dtr: SerialPortDtr.off);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    try {
      port.flush(SerialPortBuffer.input);
    } on SerialPortError catch (e) {
      _log.fine('flush after hard reset: $e');
    }
  }

  static bool _isPlaceholderPort(String portName) {
    final p = portName.trim();
    if (p.isEmpty) return true;
    if (p.toUpperCase() == 'COMX') return true;
    return false;
  }

  Future<bool> _handshakeAsync(SerialPort port) async {
    try {
      try {
        port.flush(SerialPortBuffer.input);
      } on SerialPortError catch (_) {}
      port.write(Uint8List.fromList([SerialAmbilightProtocol.ping]), timeout: 100);
      port.drain();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      final buf = <int>[];
      while (DateTime.now().isBefore(deadline)) {
        final n = port.bytesAvailable;
        if (n > 0) {
          buf.addAll(port.read(n, timeout: 100));
          if (buf.contains(SerialAmbilightProtocol.pong)) {
            return true;
          }
          if (buf.length > 1000) {
            buf.removeRange(0, buf.length - 1000);
          }
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    } on SerialPortError catch (e) {
      _log.fine('handshake: $e');
    }
    return false;
  }

  @override
  void disconnect() {
    _drainTimer?.cancel();
    _drainTimer = null;
    _connected = false;
    _queue.clear();
    final p = _port;
    _port = null;
    if (p != null) {
      try {
        if (p.isOpen) {
          p.close();
        }
        p.dispose();
      } on SerialPortError catch (e) {
        _log.fine('dispose: $e');
      }
    }
  }

  void _drain() {
    final port = _port;
    if (!_connected || port == null || !port.isOpen || _queue.isEmpty) return;
    final frame = _queue.removeFirst();
    try {
      port.write(frame.bytes, timeout: 200);
    } on SerialPortError catch (e) {
      _log.warning('write failed: $e');
      _connected = false;
      disconnect();
    }
  }

  @override
  void sendColors(List<(int r, int g, int b)> colors, int brightnessScalar) {
    if (!isConnected) return;
    final packet = SerialAmbilightProtocol.buildColorFrame(
      colors,
      brightnessScalar: brightnessScalar,
    );
    while (_queue.length >= 2) {
      _queue.removeFirst();
    }
    _queue.addLast(_Frame(packet));
  }

  @override
  void sendPixel(int index, int r, int g, int b) {
    if (!isConnected) return;
    final n = device.ledCount.clamp(1, 512);
    final buf = List<(int, int, int)>.generate(n, (_) => (0, 0, 0));
    if (index >= 0 && index < n) {
      buf[index] = (r, g, b);
    }
    sendColors(buf, 255);
  }

  @override
  void dispose() {
    disconnect();
  }
}

class _Frame {
  _Frame(this.bytes);
  final Uint8List bytes;
}
