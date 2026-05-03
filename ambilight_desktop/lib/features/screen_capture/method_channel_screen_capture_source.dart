import 'dart:typed_data';

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
  Future<ScreenFrame?> captureFrame(int monitorIndex) async {
    _clearError();
    try {
      final Object? raw = await _channel.invokeMethod<Object?>('capture', <String, Object?>{
        'monitorIndex': monitorIndex,
      });
      if (raw is! Map) return null;
      final map = Map<Object?, Object?>.from(raw);
      final w = _asInt(map['width']);
      final h = _asInt(map['height']);
      final idx = _asInt(map['monitorIndex']);
      final bytes = map['rgba'];
      if (w == null || h == null || idx == null) return null;
      Uint8List? rgba;
      if (bytes is Uint8List) {
        rgba = bytes;
      } else if (bytes is List) {
        rgba = Uint8List.fromList(bytes.cast<int>());
      }
      if (rgba == null) return null;
      return ScreenFrame(width: w, height: h, monitorIndex: idx, rgba: rgba);
    } on MissingPluginException catch (e) {
      _lastError = e.message;
      return null;
    } on PlatformException catch (e) {
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
