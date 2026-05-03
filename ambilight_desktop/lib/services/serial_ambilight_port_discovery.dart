import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import '../core/protocol/serial_frame.dart';
import '../data/serial_device_transport.dart';
import '../data/serial_native_gate.dart';

final _log = Logger('SerialPortDiscovery');

const int _kSerialReadChunkMax = 65536;

int _clampBytesToRead(int n) {
  if (n <= 0) return 0;
  return n > _kSerialReadChunkMax ? _kSerialReadChunkMax : n;
}

/// Projde [SerialPort.availablePorts], na každém zkusí handshake `0xAA` → očekává `0xBB` ([SerialAmbilightProtocol]).
class SerialAmbilightPortDiscovery {
  SerialAmbilightPortDiscovery._();

  /// Název portu (např. `COM3`, `/dev/ttyUSB0`) nebo `null`, pokud nic neodpovědělo.
  ///
  /// [skipPortNames] — porty, které už aplikace drží otevřené (jiné serial zařízení). Na Windows
  /// druhé `openReadWrite` na stejný COM často spadne procesem / CRT assert.
  static Future<String?> findAmbilightPort({
    int baudRate = 115200,
    Set<String>? skipPortNames,
  }) async {
    List<String> names;
    try {
      names = SerialPort.availablePorts;
    } catch (e, st) {
      _log.fine('availablePorts: $e', e, st);
      return null;
    }
    final skip = skipPortNames == null || skipPortNames.isEmpty
        ? null
        : skipPortNames.map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toSet();
    for (final name in names) {
      final skipKey = name.trim().toUpperCase();
      if (skip != null && skip.contains(skipKey)) {
        _log.fine('skip $name: port je v seznamu obsazených (aktivní serial v konfiguraci)');
        continue;
      }
      var handshakeOk = false;
      await SerialNativeGate.synchronized(() async {
        SerialPort? port;
        try {
          port = SerialPort(name);
          if (!port.openReadWrite()) {
            _log.fine('skip $name: openReadWrite failed ${SerialPort.lastError}');
            return;
          }
          // Po [port.config = cfg] NESMÍ následovat [cfg.dispose] — nativní config převezme port a
          // [SerialPort.dispose] ho uvolní jednou (jinak sp_free_config 2× → CRT heap assert, viz
          // https://github.com/jpnurmi/flutter_libserialport/issues/148 ).
          final cfg = SerialPortConfig()
            ..baudRate = baudRate
            ..bits = 8
            ..parity = SerialPortParity.none
            ..stopBits = 1
            ..setFlowControl(SerialPortFlowControl.none);
          port.config = cfg;
          port.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (await _handshake(port)) {
            _log.info('Ambilight handshake OK on $name');
            handshakeOk = true;
          }
        } catch (e, st) {
          _log.fine('$name: $e', e, st);
        } finally {
          if (port != null) {
            await disposeSerialPortNativeOnce(port);
          }
        }
      });
      if (handshakeOk) {
        return name;
      }
      // Krátká prodleva mezi porty — driver na Windows po close někdy potřebuje okamžik.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  static Future<bool> _handshake(SerialPort port) async {
    try {
      try {
        port.flush();
      } catch (e, st) {
        _log.fine('discovery flush: $e', e, st);
      }
      port.write(Uint8List.fromList([SerialAmbilightProtocol.ping]), timeout: 100);
      port.drain();
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      final buf = <int>[];
      while (DateTime.now().isBefore(deadline)) {
        int n;
        try {
          n = _clampBytesToRead(port.bytesAvailable);
        } catch (e, st) {
          _log.fine('discovery bytesAvailable: $e', e, st);
          return false;
        }
        if (n > 0) {
          try {
            buf.addAll(port.read(n, timeout: 100));
          } catch (e, st) {
            _log.fine('discovery read: $e', e, st);
            return false;
          }
          if (buf.contains(SerialAmbilightProtocol.pong)) {
            return true;
          }
          if (buf.length > 1000) {
            buf.removeRange(0, buf.length - 1000);
          }
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    } catch (e, st) {
      _log.fine('handshake: $e', e, st);
    }
    return false;
  }
}
