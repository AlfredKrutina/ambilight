import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import '../core/protocol/serial_frame.dart';

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
  static Future<String?> findAmbilightPort({int baudRate = 115200}) async {
    List<String> names;
    try {
      names = SerialPort.availablePorts;
    } catch (e, st) {
      _log.fine('availablePorts: $e', e, st);
      return null;
    }
    for (final name in names) {
      SerialPort? port;
      try {
        port = SerialPort(name);
        if (!port.openReadWrite()) {
          _log.fine('skip $name: openReadWrite failed ${SerialPort.lastError}');
          continue;
        }
        final cfg = SerialPortConfig()..baudRate = baudRate;
        port.config = cfg;
        cfg.dispose();
        port.flush();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (await _handshake(port)) {
          _log.info('Ambilight handshake OK on $name');
          return name;
        }
      } catch (e, st) {
        _log.fine('$name: $e', e, st);
      } finally {
        if (port != null) {
          try {
            if (port.isOpen) port.close();
          } catch (_) {}
          try {
            port.dispose();
          } catch (_) {}
        }
      }
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
