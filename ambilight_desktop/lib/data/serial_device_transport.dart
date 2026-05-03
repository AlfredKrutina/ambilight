import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import '../core/models/config_models.dart';
import '../core/protocol/serial_frame.dart';
import 'device_transport.dart';

final _log = Logger('SerialTransport');

/// Omezí čtení z portu — špatný driver může hlásit extrémní [SerialPort.bytesAvailable].
const int _kSerialReadChunkMax = 65536;

int _clampBytesToRead(int n) {
  if (n <= 0) return 0;
  return n > _kSerialReadChunkMax ? _kSerialReadChunkMax : n;
}

/// USB-serial to ESP32: handshake + framed RGB (see Python `SerialHandler`).
class SerialDeviceTransport extends DeviceTransport {
  SerialDeviceTransport(
    super.device, {
    this.baudRate = 115200,
    int writeQueuePeriodMs = 4,
  }) : _writeQueuePeriodMs = writeQueuePeriodMs;

  /// Musí odpovídat `global_settings.baud_rate` v JSON (jako Python `SerialHandler.baud_rate`).
  final int baudRate;
  /// Perioda vyprázdnění fronty zápisů (ms); v performance módu vyšší = méně wake-upů.
  int _writeQueuePeriodMs;

  SerialPort? _port;
  bool _connected = false;
  final Queue<_Frame> _queue = Queue();
  Timer? _drainTimer;
  bool _connecting = false;
  /// Po chybě zápisu / odpojení USB — krátká pauza před dalším [connect], aby se driver na Windows nezahltil.
  DateTime? _reconnectNotBefore;

  /// Zvýší se při každém [disconnect]/[dispose] — [connect] po `await` musí skončit,
  /// jinak hrozí použití uvolněného `SerialPort` (heap assert / pád na Windows).
  int _lifecycleGen = 0;

  /// Uvolnění COM běží v microtasku — controller na tom čeká, aby se nekrývalo s dalšími nativními voláními.
  final List<Completer<void>> _pendingPortReleases = [];

  static void _releaseSerialPort(SerialPort port) {
    try {
      try {
        if (port.isOpen) {
          port.close();
        }
      } catch (e, st) {
        _log.fine('serial close: $e', e, st);
      }
      try {
        port.dispose();
      } catch (e, st) {
        _log.fine('serial dispose: $e', e, st);
      }
    } catch (e, st) {
      _log.fine('releaseSerialPort: $e', e, st);
    }
  }

  void _armReconnectBackoff() {
    _reconnectNotBefore = DateTime.now().add(const Duration(seconds: 2));
  }

  @override
  bool get isConnected {
    try {
      return _connected && (_port?.isOpen ?? false);
    } catch (e, st) {
      _log.fine('isConnected: $e', e, st);
      return false;
    }
  }

  @override
  Future<void> connect() async {
    if (_connecting || isConnected) return;
    final notBefore = _reconnectNotBefore;
    if (notBefore != null && DateTime.now().isBefore(notBefore)) {
      return;
    }
    _connecting = true;
    SerialPort? provisional;
    try {
      disconnect();
      await flushPendingDispose();
      final gen = _lifecycleGen;
      final portName = device.port;
      if (_isPlaceholderPort(portName)) {
        return;
      }
      final port = SerialPort(portName);
      provisional = port;
      if (!port.openReadWrite()) {
        _log.fine('openReadWrite failed $portName: ${SerialPort.lastError}');
        _releaseSerialPort(port);
        provisional = null;
        _armReconnectBackoff();
        return;
      }
      // Stejné signály jako Python `SerialHandler._connect`: RTS on, DTR off,
      // plná 8N1 + bez flow control (Win/macOS driver parity).
      _applySerialConfig(port);
      try {
        port.flush(SerialPortBuffer.both);
      } catch (e, st) {
        _log.fine('flush after open: $e', e, st);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (gen != _lifecycleGen) {
        _releaseSerialPort(port);
        provisional = null;
        return;
      }
      var okHs = await _handshakeAsync(port);
      if (gen != _lifecycleGen) {
        _releaseSerialPort(port);
        provisional = null;
        return;
      }
      if (!okHs) {
        await _hardResetEspSerial(port);
        if (gen != _lifecycleGen) {
          _releaseSerialPort(port);
          provisional = null;
          return;
        }
        okHs = await _handshakeAsync(port);
        if (gen != _lifecycleGen) {
          _releaseSerialPort(port);
          provisional = null;
          return;
        }
        if (!okHs) {
          _log.fine('Handshake failed on $portName (after hard reset)');
          _releaseSerialPort(port);
          provisional = null;
          _armReconnectBackoff();
          return;
        }
      }
      if (gen != _lifecycleGen) {
        _releaseSerialPort(port);
        provisional = null;
        return;
      }
      _port = port;
      provisional = null;
      _connected = true;
      _reconnectNotBefore = null;
      _log.info('Serial connected $portName');
      announceLogicalStripLength(device.ledCount);
      final qMs = _writeQueuePeriodMs.clamp(2, 32);
      _drainTimer ??= Timer.periodic(Duration(milliseconds: qMs), (_) => _drain());
    } on SerialPortError catch (e, st) {
      _log.warning('SerialPortError: $e', e, st);
      // [disconnect] uvolní _port — nesmíme pak v [finally] uvolnit stejný objekt jako [provisional].
      if (identical(provisional, _port)) {
        provisional = null;
      }
      disconnect();
      _armReconnectBackoff();
    } catch (e, st) {
      _log.warning('Serial connect: $e', e, st);
      if (identical(provisional, _port)) {
        provisional = null;
      }
      disconnect();
      _armReconnectBackoff();
    } finally {
      if (provisional != null) {
        _releaseSerialPort(provisional!);
      }
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
    try {
      port.config = cfg;
    } catch (e, st) {
      _log.fine('applySerialConfig: $e', e, st);
      rethrow;
    } finally {
      try {
        cfg.dispose();
      } catch (_) {}
    }
  }

  /// Jako Python `SerialHandler._connect` po neúspěšném handshake.
  Future<void> _hardResetEspSerial(SerialPort port) async {
    try {
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
    } catch (e, st) {
      _log.fine('hardResetEspSerial: $e', e, st);
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
      } catch (e, st) {
        _log.fine('handshake flush: $e', e, st);
      }
      port.write(Uint8List.fromList([SerialAmbilightProtocol.ping]), timeout: 100);
      port.drain();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      final buf = <int>[];
      while (DateTime.now().isBefore(deadline)) {
        int n;
        try {
          n = _clampBytesToRead(port.bytesAvailable);
        } catch (e, st) {
          _log.fine('handshake bytesAvailable: $e', e, st);
          return false;
        }
        if (n > 0) {
          try {
            buf.addAll(port.read(n, timeout: 100));
          } catch (e, st) {
            _log.fine('handshake read: $e', e, st);
            return false;
          }
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
    } catch (e, st) {
      _log.fine('handshake: $e', e, st);
    }
    return false;
  }

  @override
  void disconnect() {
    _lifecycleGen++;
    _drainTimer?.cancel();
    _drainTimer = null;
    _connected = false;
    _queue.clear();
    final p = _port;
    _port = null;
    if (p != null) {
      // Nezavírat port synchronně v tom samém „tiku“ jako probíhající [_drain] z periodic
      // timeru — na Windows může souběh close + write shodit proces. Microtask běží až po
      // dokončení aktuálního Dart callstacku včetně rozjetého [_drain].
      final done = Completer<void>();
      _pendingPortReleases.add(done);
      scheduleMicrotask(() {
        try {
          _releaseSerialPort(p);
        } finally {
          if (!done.isCompleted) done.complete();
        }
      });
    }
  }

  @override
  Future<void> flushPendingDispose() async {
    for (;;) {
      if (_pendingPortReleases.isEmpty) return;
      final batch = List<Completer<void>>.from(_pendingPortReleases);
      _pendingPortReleases.clear();
      await Future.wait(batch.map((c) => c.future));
    }
  }

  void _drain() {
    final genAtEnter = _lifecycleGen;
    final port = _port;
    if (!_connected || port == null || _queue.isEmpty) return;
    try {
      if (!port.isOpen) return;
    } catch (e, st) {
      _log.fine('drain isOpen: $e', e, st);
      _connected = false;
      disconnect();
      _armReconnectBackoff();
      return;
    }
    final frame = _queue.removeFirst();
    // Po dequeue: před zápisem znovu generaci (disconnect mohl doběhnout uprostřed _drain).
    if (genAtEnter != _lifecycleGen) return;
    try {
      port.write(frame.bytes, timeout: 200);
    } on SerialPortError catch (e) {
      _log.warning('write failed: $e');
      _connected = false;
      disconnect();
      _armReconnectBackoff();
    } catch (e, st) {
      _log.warning('serial drain: $e', e, st);
      _connected = false;
      disconnect();
      _armReconnectBackoff();
    }
  }

  @override
  void announceLogicalStripLength(int ledCount) {
    final port = _port;
    if (!_connected || port == null || !port.isOpen) return;
    final n = ledCount.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice);
    try {
      port.write(SerialAmbilightProtocol.buildLedCountCommand(n), timeout: 100);
    } on SerialPortError catch (e) {
      _log.fine('announceLogicalStripLength: $e');
    } catch (e, st) {
      _log.fine('announceLogicalStripLength: $e', e, st);
    }
  }

  @override
  void syncDeviceSnapshot(DeviceSettings next) {
    device = next;
  }

  @override
  void applyPerformanceMode(bool performanceMode) {
    final nextMs = performanceMode ? 8 : 4;
    if (_writeQueuePeriodMs == nextMs) return;
    _writeQueuePeriodMs = nextMs;
    if (_drainTimer != null) {
      _drainTimer!.cancel();
      _drainTimer = null;
    }
    if (_connected) {
      final q = _writeQueuePeriodMs.clamp(2, 32);
      _drainTimer = Timer.periodic(Duration(milliseconds: q), (_) => _drain());
    }
  }

  @override
  void sendColors(List<(int r, int g, int b)> colors, int brightnessScalar) {
    if (!isConnected) return;
    if (colors.isEmpty) return;
    final maxL = SerialAmbilightProtocol.maxLedsPerDevice;
    final fromDevice = device.ledCount.clamp(1, maxL);
    final fromList = colors.length.clamp(1, maxL);
    // Průvodce / kalibrace posílá delší buffer než uložený `led_count` — délka rámce musí
    // pokrýt index zelené LED, jinak se nad `device.ledCount` vůbec nevyšle.
    final strip = math.max(fromList, fromDevice);
    final packet = SerialAmbilightProtocol.buildColorFrame(
      colors,
      stripLength: strip,
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
    if (index < 0) return;
    final maxL = SerialAmbilightProtocol.maxLedsPerDevice;
    final n = math.max(index + 1, device.ledCount).clamp(1, maxL);
    final buf = List<(int, int, int)>.generate(n, (_) => (0, 0, 0));
    if (index < n) {
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
