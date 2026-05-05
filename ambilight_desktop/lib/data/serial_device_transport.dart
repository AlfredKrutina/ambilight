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
        try {
          SerialDeviceTransport.stabilizeEspressifUsbLinesBeforeClose(port);
        } catch (_) {}
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
const int _kSerialWriteChunkMax = 512;
const int _kSerialDrainStrideChunks = 2;

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
  Uint8List? _pendingControlFrame;

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
        applyAmbilightPortPolicyAfterOpen(p, baudRate);
        opened = p;
      });
      if (opened == null) {
        _armReconnectBackoff();
        return;
      }
      final port = opened!;
      final nativeEspUsb = looksLikeEspressifUsbSerialJtag(port);
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
      // Po krátkém open/close (např. COM discovery) první handshake často selže — zkusit znovu,
      // než spustíme DTR/RTS hard reset (u klasického bridge; u Espressif USB-JTAG ne).
      final softRetries = nativeEspUsb ? 8 : 3;
      for (var retry = 0; !okHs && retry < softRetries; retry++) {
        await Future<void>.delayed(Duration(milliseconds: nativeEspUsb ? 280 : 220));
        if (gen != _lifecycleGen) {
          await releaseSerialPortOnce(port);
          provisional = null;
          return;
        }
        okHs = await _handshakeAsync(port);
      }
      if (!okHs && !nativeEspUsb) {
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
      } else if (!okHs && nativeEspUsb) {
        _log.info(
          'Serial: handshake failed on $portName (Espressif USB VID=0x303A) — '
          'skipping DTR/RTS hard reset (would reset chip / JTAG). Check cable or close other tools using this COM.',
        );
        await releaseSerialPortOnce(port);
        provisional = null;
        _armReconnectBackoff();
        return;
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
          'dev=${device.id} port=$portName baud=$baudRate wire=8N1 flow=none '
          'espUsbJtag=$nativeEspUsb (VID=0x${port.vendorId?.toRadixString(16) ?? "?"})',
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
      ..dtr = dtr ?? SerialPortDtr.off;
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

  /// Vestavěný USB Serial/JTAG (Espressif VID) nebo stejný device podle popisu — na Windows
  /// nesahat zbytečně na DTR (EN / GPIO0) ani při baudu ani při close.
  static bool looksLikeEspressifUsbSerialJtag(SerialPort port) {
    try {
      if (port.vendorId == 0x303A) return true;
      final s = '${port.description ?? ''} ${port.productName ?? ''}'.toLowerCase();
      if (s.contains('usb jtag') || s.contains('usb serial/jtag')) return true;
      if (s.contains('serial debug unit')) return true;
      if (s.contains('espressif') && s.contains('jtag')) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Po [openReadWrite]: u ESP USB-JTAG jen baud/8N1 bez přepisování modemových linek (driver default).
  /// U CP210x/CH340: RTS on + DTR off (klasické ESP desky — DTR často na EN přes kondenzátor).
  static void applyAmbilightPortPolicyAfterOpen(SerialPort port, int baudRate) {
    final br = baudRate.clamp(9600, 921600);
    final jtag = looksLikeEspressifUsbSerialJtag(port);
    try {
      if (jtag) {
        final cfg = port.config;
        cfg.baudRate = br;
        cfg.bits = 8;
        cfg.parity = SerialPortParity.none;
        cfg.stopBits = 1;
        cfg.setFlowControl(SerialPortFlowControl.none);
        port.config = cfg;
        try {
          port.flush(SerialPortBuffer.input);
        } catch (e, st) {
          _log.fine('flush input after open (esp usb): $e', e, st);
        }
      } else {
        final cfg = SerialPortConfig()
          ..baudRate = br
          ..bits = 8
          ..parity = SerialPortParity.none
          ..stopBits = 1
          ..setFlowControl(SerialPortFlowControl.none)
          ..rts = SerialPortRts.on
          ..dtr = SerialPortDtr.off;
        port.config = cfg;
        try {
          port.flush(SerialPortBuffer.both);
        } catch (e, st) {
          _log.fine('flush after open (bridge): $e', e, st);
        }
      }
    } catch (e, st) {
      _log.fine('applyAmbilightPortPolicyAfterOpen: $e', e, st);
      rethrow;
    }
  }

  /// Před [close] snížit riziko náhodného pulsu na EN při uvolnění CDC driveru (Windows).
  static void stabilizeEspressifUsbLinesBeforeClose(SerialPort port) {
    if (!looksLikeEspressifUsbSerialJtag(port)) return;
    try {
      if (!port.isOpen) return;
      final cfg = port.config;
      cfg.dtr = SerialPortDtr.off;
      cfg.rts = SerialPortRts.on;
      port.config = cfg;
    } catch (e, st) {
      _log.fine('stabilizeEspressifUsbLinesBeforeClose: $e', e, st);
    }
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
    _pendingControlFrame = null;
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
    final hasControlFrame = _pendingControlFrame != null;
    if (!_connected || port == null || (!hasControlFrame && _queue.isEmpty)) return;
    try {
      if (!port.isOpen) return;
    } catch (e, st) {
      _log.fine('drain isOpen: $e', e, st);
      _connected = false;
      disconnect();
      _armReconnectBackoff();
      return;
    }
    try {
      final controlFrame = _pendingControlFrame;
      if (controlFrame != null) {
        _writeFrameChunked(port, controlFrame, genAtEnter);
        _pendingControlFrame = null;
      }
      if (_queue.isEmpty) return;
      final frame = _queue.removeFirst();
      // Po dequeue: před zápisem znovu generaci (disconnect mohl doběhnout uprostřed _drain).
      if (genAtEnter != _lifecycleGen) return;
      _writeFrameChunked(port, frame.bytes, genAtEnter);
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

  void _writeFrameChunked(SerialPort port, Uint8List bytes, int genAtEnter) {
    var offset = 0;
    var chunkIx = 0;
    while (offset < bytes.length) {
      if (_closingPort || genAtEnter != _lifecycleGen) return;
      final end = math.min(offset + _kSerialWriteChunkMax, bytes.length);
      port.write(Uint8List.sublistView(bytes, offset, end), timeout: 250);
      offset = end;
      chunkIx++;
      // Dlouhé rámce (wide >256 LED) posíláme po menších dávkách s mezilehlým drainem.
      if (offset < bytes.length && chunkIx % _kSerialDrainStrideChunks == 0) {
        port.drain();
      }
    }
    // CDC/JTAG bridge mívá malý HW buffer; čekání na drain snižuje šanci přetečení a resetu ESP.
    port.drain();
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
    _pendingControlFrame = SerialAmbilightProtocol.buildLedCountCommand(n);
    _kickDrain();
  }

  @override
  void syncDeviceSnapshot(DeviceSettings next) {
    final prevLedCount = device.ledCount;
    device = next;
    if (next.ledCount != prevLedCount) {
      announceLogicalStripLength(next.ledCount);
    }
  }

  @override
  void applyPerformanceMode(bool performanceMode) {
    final nextMs = performanceMode ? 4 : 2;
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
    final fromList = colors.length.clamp(1, maxL);
    // Motor používá 0–255 jako UDP (`brightnessForMode`); serial_wire škáluje /100 jako Python.
    final serialBrightnessPct =
        ((brightnessScalar.clamp(0, 255) * 100) / 255).round().clamp(0, 100);
    // Délka rámce vychází z payloadu od pipeline/controlleru; tím držíme shodné mapování
    // pro USB i UDP a neinflatujeme rámec na historicky uložený `device.ledCount`.
    final strip = fromList;
    final packet = SerialAmbilightProtocol.buildColorFrame(
      colors,
      stripLength: strip,
      brightnessScalar: serialBrightnessPct,
    );
    _diagSerialColorSampleCounter++;
    if (ambilightPipelineDiagnosticsEnabled && _diagSerialColorSampleCounter % 120 == 0) {
      pipelineDiagLog(
        'serial_color_frame_sample',
        'start=0x${packet.isNotEmpty ? packet[0].toRadixString(16) : '?'} len=${packet.length} strip=$strip',
      );
    }
    while (_queue.length >= 3) {
      _queue.removeFirst();
    }
    _queue.addLast(_Frame(packet));
    _kickDrain();
  }

  @override
  void sendPcReleaseHandoff() {
    if (!_connected) return;
    final port = _port;
    if (port == null) return;
    try {
      if (!port.isOpen) return;
    } catch (e, st) {
      _log.fine('sendPcReleaseHandoff isOpen: $e', e, st);
      return;
    }
    try {
      port.write(Uint8List.fromList([SerialAmbilightProtocol.pcReleaseHandoff]), timeout: 200);
      port.drain();
    } catch (e, st) {
      _log.fine('sendPcReleaseHandoff: $e', e, st);
    }
  }

  @override
  Future<bool> sendFirmwareTemporalMode(int mode) async {
    if (!_connected) return false;
    final port = _port;
    if (port == null || _closingPort) return false;
    final pkt = SerialAmbilightProtocol.buildFirmwareTemporalModeFrame(mode);
    try {
      if (!port.isOpen) return false;
    } catch (e, st) {
      _log.fine('sendFirmwareTemporalMode isOpen: $e', e, st);
      return false;
    }
    try {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      port.write(pkt, timeout: 200);
      port.drain();
      return true;
    } catch (e, st) {
      _log.fine('sendFirmwareTemporalMode: $e', e, st);
      return false;
    }
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
