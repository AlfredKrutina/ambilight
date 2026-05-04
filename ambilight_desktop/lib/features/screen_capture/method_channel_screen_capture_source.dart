// Diagnostika nativního capture na Windows — stdout.
// ignore_for_file: avoid_print

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'screen_capture_source.dart';
import 'screen_frame.dart';

/// Nativní capture přes `ambilight/screen_capture` (Windows, Linux, macOS).
///
/// Na Windows capture běží na worker vlákně; výsledek přes message pump.
class MethodChannelScreenCaptureSource implements ScreenCaptureSource {
  MethodChannelScreenCaptureSource({
    MethodChannel channel = ScreenCaptureSource.defaultChannel,
    BinaryMessenger? messenger,
  }) : _channel = messenger != null
            ? MethodChannel(channel.name, channel.codec, messenger)
            : channel;

  final MethodChannel _channel;

  String? _lastError;

  /// Poslední chyba z nativní vrstvy (PlatformException / MissingPlugin).
  String? get lastError => _lastError;

  void _clearError() => _lastError = null;

  void _setFromException(Object e) {
    if (e is PlatformException) {
      _lastError = e.message ?? e.code;
    } else {
      _lastError = e.toString();
    }
  }

  @override
  Future<ScreenSessionInfo> getSessionInfo() async {
    _clearError();
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('sessionInfo');
      if (raw is! Map) return ScreenSessionInfo.unknown;
      return ScreenSessionInfo.fromMap(Map<Object?, Object?>.from(raw));
    } on MissingPluginException catch (e) {
      _lastError = e.message;
      return ScreenSessionInfo.unknown;
    } on PlatformException catch (e) {
      _setFromException(e);
      return ScreenSessionInfo.unknown;
    }
  }

  @override
  Future<bool> requestScreenCapturePermission() async {
    _clearError();
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('requestPermission');
      if (raw is bool) return raw;
      return true;
    } on MissingPluginException catch (e) {
      _lastError = e.message;
      return false;
    } on PlatformException catch (e) {
      _setFromException(e);
      return false;
    }
  }

  @override
  Future<ScreenFrame?> captureFrame(int monitorIndex, {String? windowsCaptureBackend}) async {
    _clearError();
    try {
      final args = <String, Object?>{'monitorIndex': monitorIndex};
      if (!kIsWeb &&
          Platform.isWindows &&
          windowsCaptureBackend != null &&
          windowsCaptureBackend.isNotEmpty) {
        args['captureBackend'] = windowsCaptureBackend;
      }
      final Object? raw = await _channel.invokeMethod<Object?>('capture', args);
      void dbgCapture(String msg) {
        if (!kIsWeb && Platform.isWindows) {
          print('[CAPTURE Dart] $msg');
        }
      }
      if (raw is! Map) {
        dbgCapture(
          'invoke capture returned non-Map: type=${raw?.runtimeType} value=$raw '
          '(args monitorIndex=$monitorIndex backend=${windowsCaptureBackend ?? "(default)"})',
        );
        return null;
      }
      final map = Map<Object?, Object?>.from(raw);
      dbgCapture('map keys: ${map.keys.map((k) => "${k.runtimeType}:$k").join(", ")}');
      final w = _asInt(map['width']);
      final h = _asInt(map['height']);
      final idx = _asInt(map['monitorIndex']);
      final bytes = map['rgba'];
      if (w == null) {
        dbgCapture('width missing or not int (raw=${map['width']} type=${map['width']?.runtimeType})');
        return null;
      }
      if (h == null) {
        dbgCapture('height missing or not int (raw=${map['height']} type=${map['height']?.runtimeType})');
        return null;
      }
      if (idx == null) {
        dbgCapture(
          'monitorIndex missing or not int (raw=${map['monitorIndex']} type=${map['monitorIndex']?.runtimeType})',
        );
        return null;
      }
      Uint8List? rgba;
      if (bytes is Uint8List) {
        rgba = bytes;
      } else if (bytes is List) {
        rgba = Uint8List.fromList(bytes.cast<int>());
      }
      if (rgba == null) {
        dbgCapture(
          'rgba missing / wrong type: type=${bytes?.runtimeType} (need Uint8List or List<int>)',
        );
        return null;
      }
      final expected = w * h * 4;
      dbgCapture(
        'parsed width=$w height=$h monitorIndex=$idx rgba.length=${rgba.length} expectedBytes=$expected',
      );
      if (rgba.length != expected) {
        dbgCapture(
          'WARNING: rgba length mismatch — ScreenFrame.isValid will be false '
          '(got ${rgba.length}, need $expected)',
        );
      }
      final frame = ScreenFrame(width: w, height: h, monitorIndex: idx, rgba: rgba);
      if (!frame.isValid) {
        dbgCapture('ScreenFrame.isValid == false (see lengths above)');
      }
      return frame;
    } on MissingPluginException catch (e) {
      if (!kIsWeb && Platform.isWindows) {
        print('[CAPTURE Dart] MissingPluginException: ${e.message}');
      }
      _lastError = e.message;
      return null;
    } on PlatformException catch (e) {
      if (!kIsWeb && Platform.isWindows) {
        print(
          '[CAPTURE Dart] PlatformException code=${e.code} message=${e.message} '
          'details=${e.details}',
        );
      }
      _setFromException(e);
      return null;
    }
  }

  @override
  Future<List<MonitorInfo>> listMonitors() async {
    _clearError();
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('listMonitors');
      if (raw is! List) return const <MonitorInfo>[];
      final out = <MonitorInfo>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<Object?, Object?>.from(e);
        final idx = _asInt(m['mssStyleIndex']);
        final left = _asInt(m['left']);
        final top = _asInt(m['top']);
        final w = _asInt(m['width']);
        final h = _asInt(m['height']);
        if (idx == null || left == null || top == null || w == null || h == null) continue;
        final primary = m['isPrimary'] == true;
        out.add(MonitorInfo(
          mssStyleIndex: idx,
          left: left,
          top: top,
          width: w,
          height: h,
          isPrimary: primary,
        ));
      }
      return out;
    } on MissingPluginException catch (e) {
      _lastError = e.message;
      return const <MonitorInfo>[];
    } on PlatformException catch (e) {
      _setFromException(e);
      return const <MonitorInfo>[];
    }
  }

  @override
  void dispose() {}

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}
