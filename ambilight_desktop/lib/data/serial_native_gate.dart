import 'dart:async';

/// Jedna FIFO fronta pro všechna nativní COM volání (libserialport na Windows).
///
/// Souběh [SerialPort.openReadWrite] / [close] / [dispose] mezi discovery, [connect]
/// a uvolněním po [disconnect] umí shodit proces (CRT heap), ne jen Dart výjimku.
///
/// [synchronized] je **reentrantní** z jedné async větve: uvnitř kritické sekce smí
/// např. [releaseSerialPortOnce] znovu vstoupit bez deadlocku.
final class SerialNativeGate {
  SerialNativeGate._();

  static Future<void> _chain = Future<void>.value();
  static int _depth = 0;

  static Future<T> synchronized<T>(Future<T> Function() action) async {
    if (_depth > 0) {
      return action();
    }
    final previous = _chain;
    final gateDone = Completer<void>();
    _chain = gateDone.future;
    await previous;
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
      gateDone.complete();
    }
  }
}
