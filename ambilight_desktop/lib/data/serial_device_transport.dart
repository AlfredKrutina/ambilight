import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import '../application/build_environment.dart';
import '../application/debug_trace.dart';
import '../application/pipeline_diagnostics.dart';
import '../core/models/config_models.dart';
import '../core/protocol/serial_frame.dart';
import 'device_transport.dart';
import 'serial_native_gate.dart';

final _log = Logger('SerialTransport');

/// [SerialPort.dispose] → `sp_free_port`; druhé volání na stejný objekt = Debug CRT assert
/// na Windows. Objekt po [dispose] nesmí zůstat v [Set] — při dalším [add]/rehash CRT hlásí
/// `_CrtIsValidHeapPointer` / `is_block_type_valid`.
final Set<SerialPort> _releasedSerialPortsOnce = <SerialPort>{};

/// Uvolnění bez vlastní fronty — volat jen v rámci již drženého [SerialNativeGate.synchronized]
/// (např. krátký blok [openReadWrite]), jinak použij [releaseSerialPortOnce].
Future<void> disposeSerialPortNativeOnce(SerialPort port) async {
  if (!_releasedSerialPortsOnce.add(port)) {
    if (kDebugMode) {
      _log.fine('SerialPort: přeskakuji druhé uvolnění (stejná instance)');
    }
    return;
  }
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
    _log.fine('disposeSerialPortNativeOnce: $e', e, st);
  } finally {
    _releasedSerialPortsOnce.removeWhere((e) => identical(e, port));
  }
}

/// Frontované uvolnění — bezpečné z libovolného async kontextu (disconnect, chyby po [open]).
Future<void> releaseSerialPortOnce(SerialPort port) {
  return SerialNativeGate.synchronized(() => disposeSerialPortNativeOnce(port));
}

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
    int writeQueuePeriodMs = 2,
  }) : _writeQueuePeriodMs = writeQueuePeriodMs;

  /// Musí odpovídat `global_settings.baud_rate` v JSON (jako Python `SerialHandler.baud_rate`).
  final int baudRate;
  /// Perioda vyprázdnění fronty zápisů (ms); v performance módu vyšší = méně wake-upů.
  int _writeQueuePeriodMs;

  /// Řídký vzorek rámců při [AMBI_PIPELINE_DIAGNOSTICS].
  int _diagSerialColorSampleCounter = 0;

  /// Jednorázový odběh [_drain] hned po enqueue — bez čekání na periodic timer (nižší latence na pásku).
  bool _drainKickScheduled = false;

  int _debugDrainSample = 0;

  SerialPort? _port;
  bool _connected = false;
  /// [true] hned na začátku [disconnect] — [_drain] a [announceLogicalStripLength] nepíšou na port
  /// souběžně s uvolněním (Windows).
  bool _closingPort = false;
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
      SerialPort? opened;
      await SerialNativeGate.synchronized(() async {
        final p = SerialPort(portName);
        provisional = p;
        if (!p.openReadWrite()) {
          _log.fine('openReadWrite failed $portName: ${SerialPort.lastError}');
          await disposeSerialPortNativeOnce(p);
          provisional = null;
          return;
        }
        // ESP32-C3 USB-JTAG CDC: RTS i DTR musí být asserted, jinak host nepřijímá RX.
        // Klasické USB-UART bridge často stačí RTS on + DTR off (Python); zde výchozí oba ON.
        _applySerialConfig(p);
        try {
          final usbLines = p.config;
          usbLines.rts = SerialPortRts.on;
          usbLines.dtr = SerialPortDtr.on;
          p.config = usbLines;
        } catch (e, st) {
          _log.fine('USB-JTAG DTR/RTS reassert: $e', e, st);
        }
        try {
          p.flush(SerialPortBuffer.both);
        } catch (e, st) {
          _log.fine('flush after open: $e', e, st);
        }
        opened = p;
      });
      if (opened == null) {
        _armReconnectBackoff();
        return;
      }
      final port = opened!;
      _closingPort = false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (gen != _lifecycleGen) {
        await releaseSerialPortOnce(port);
        provisional = null;
        return;
      }
      var okHs = await _handshakeAsync(port);
      if (gen != _lifecycleGen) {
        await releaseSerialPortOnce(port);
        provisional = null;
        return;
      }
      if (!okHs) {
        await _hardResetEspSerial(port);
        if (gen != _lifecycleGen) {
          await releaseSerialPortOnce(port);
          provisional = null;
          return;
        }
        okHs = await _handshakeAsync(port);
        if (gen != _lifecycleGen) {
          await releaseSerialPortOnce(port);
          provisional = null;
          return;
        }
        if (!okHs) {
          _log.fine('Handshake failed on $portName (after hard reset)');
          await releaseSerialPortOnce(port);
          provisional = null;
          _armReconnectBackoff();
          return;
        }
      }
      if (gen != _lifecycleGen) {
        await releaseSerialPortOnce(port);
        provisional = null;
        return;
      }
      _port = port;
      provisional = null;
      _connected = true;
      _reconnectNotBefore = null;
      ambilightDebugTrace(
        'SerialTransport connected dev=${device.id} port=$portName baud=$baudRate '
        'queueMs=${_writeQueuePeriodMs.clamp(2, 32)} led=${device.ledCount}',
      );
      _log.info('Serial connected $portName');
      if (ambilightPipelineDiagnosticsEnabled) {
        pipelineDiagLog(
          'serial_open',
          'dev=${device.id} port=$portName baud=$baudRate wire=8N1 flow=none intended_Rts=on Dtr=on '
          '(ESP USB-JTAG CDC; viz [_applySerialConfig])',
        );
        final ping = Uint8List.fromList([SerialAmbilightProtocol.ping]);
        pipelineDiagLog('serial_handshake', 'ping_hex=${pipelineDiagHexPrefix(ping)} pong_expected=0x${SerialAmbilightProtocol.pong.toRadixString(16)}');
        final ann = SerialAmbilightProtocol.buildLedCountCommand(device.ledCount);
        pipelineDiagLog(
          'serial_announce_led_count',
          'hex=${pipelineDiagHexPrefix(ann)} ledCount=${device.ledCount} wideFrame=${device.ledCount > SerialAmbilightProtocol.legacyFrameMaxLeds}',
        );
      }
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
        await releaseSerialPortOnce(provisional!);
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
      ..dtr = dtr ?? SerialPortDtr.on;
    try {
      port.config = cfg;
    } catch (e, st) {
      _log.fine('applySerialConfig: $e', e, st);
      try {
        cfg.dispose();
      } catch (_) {}
      rethrow;
    }
    // Úspěšné [port.config = cfg]: nevolat [cfg.dispose] — port ho uvolní v [dispose] (dvojí
    // sp_free_config shodí Windows Debug heap, issue flutter_libserialport #148).
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
    _closingPort = true;
    _lifecycleGen++;
    _drainKickScheduled = false;
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
      scheduleMicrotask(() async {
        try {
          await releaseSerialPortOnce(p);
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
    if (_closingPort) return;
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
      if (ambilightDebugTraceEnabled) {
        _debugDrainSample++;
        if (_debugDrainSample % 128 == 0) {
          ambilightDebugTrace(
            'SerialTransport drain dev=${device.id} frame=${frame.bytes.length} B '
            'queue=${_queue.length}',
          );
        }
      }
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

  void _kickDrain() {
    if (_drainKickScheduled) return;
    _drainKickScheduled = true;
    scheduleMicrotask(() {
      _drainKickScheduled = false;
      var n = 0;
      while (_queue.isNotEmpty && _connected && !_closingPort && n < 3) {
        _drain();
        n++;
      }
    });
  }

  @override
  void announceLogicalStripLength(int ledCount) {
    if (_closingPort) return;
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
    final nextMs = performanceMode ? 8 : 2;
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
    _diagSerialColorSampleCounter++;
    if (ambilightPipelineDiagnosticsEnabled && _diagSerialColorSampleCounter % 120 == 0) {
      pipelineDiagLog(
        'serial_color_frame_sample',
        'start=0x${packet.isNotEmpty ? packet[0].toRadixString(16) : '?'} len=${packet.length} strip=$strip',
      );
    }
    while (_queue.length >= 2) {
      _queue.removeFirst();
    }
    _queue.addLast(_Frame(packet));
    _kickDrain();
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
