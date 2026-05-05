// Diagnostika nativního capture na Windows — stdout.
// ignore_for_file: avoid_print

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../../application/pipeline_diagnostics.dart';
import '../../core/models/config_models.dart';
import 'screen_capture_source.dart';
import 'screen_frame.dart';

/// Nativní capture přes `ambilight/screen_capture` (Windows, Linux, macOS).
///
/// Na Windows capture běží na worker vlákně; výsledek přes message pump.
class MethodChannelScreenCaptureSource implements ScreenCaptureSource {
  MethodChannelScreenCaptureSource({
    MethodChannel channel = ScreenCaptureSource.defaultChannel,
    BinaryMessenger? messenger,
    EventChannel? captureStreamChannel,
  })  : _channel = messenger != null
            ? MethodChannel(channel.name, channel.codec, messenger)
            : channel,
        _captureStream = captureStreamChannel ?? const EventChannel('ambilight/screen_capture_stream');

  final MethodChannel _channel;
  final EventChannel _captureStream;

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

  /// Windows: DXGI push stream (EventChannel). Argumenty viz C++ `InternalRegister…`.
  Stream<Object?> windowsCaptureBroadcastStream(Map<String, Object?> arguments) {
    if (kIsWeb || !Platform.isWindows) {
      return const Stream<Object?>.empty();
    }
    return _captureStream.receiveBroadcastStream(arguments);
  }

  /// Parsování výsledku `capture` / stream eventu → [ScreenFrame]; `noUpdate` → `null`.
  static ScreenFrame? parseCaptureMap(Map<Object?, Object?> map, {required bool markDiagTimeline}) {
    void dbgCapture(String msg) {
      if (!kIsWeb && Platform.isWindows) {
        print('[CAPTURE Dart] $msg');
      }
    }

    final noUpdateRaw = map['noUpdate'];
    if (noUpdateRaw == true || noUpdateRaw == 1) {
      if (ambilightPipelineDiagnosticsEnabled) {
        PipelineStreamDiagStats.noUpdateEvents++;
        pipelineDiagLog('capture_stream_noop', '');
      }
      return null;
    }
    final w = _asInt(map['width']);
    final h = _asInt(map['height']);
    final idx = _asInt(map['monitorIndex']);
    final bytes = map['rgba'];
    if (w == null || h == null || idx == null) {
      dbgCapture('parseCaptureMap: missing width/height/monitorIndex');
      return null;
    }
    Uint8List? rgba;
    if (bytes is Uint8List) {
      rgba = bytes;
    } else if (bytes is List) {
      rgba = Uint8List.fromList(bytes.cast<int>());
    }
    if (rgba == null) {
      dbgCapture('parseCaptureMap: rgba missing');
      return null;
    }
    final lw = _asInt(map['layoutWidth']);
    final lh = _asInt(map['layoutHeight']);
    final ox = _asInt(map['bufferOriginX']);
    final oy = _asInt(map['bufferOriginY']);
    final nbw = _asInt(map['nativeBufferWidth']);
    final nbh = _asInt(map['nativeBufferHeight']);
    final hasLayout = lw != null && lh != null && nbw != null && nbh != null;
    final frame = ScreenFrame(
      width: w,
      height: h,
      monitorIndex: idx,
      rgba: rgba,
      layoutWidth: hasLayout ? lw : null,
      layoutHeight: hasLayout ? lh : null,
      bufferOriginX: ox ?? 0,
      bufferOriginY: oy ?? 0,
      nativeBufferWidth: hasLayout ? nbw : null,
      nativeBufferHeight: hasLayout ? nbh : null,
    );
    if (ambilightPipelineDiagnosticsEnabled && frame.isValid) {
      var rgbSum = 0;
      for (var i = 0; i < rgba.length; i += 4) {
        rgbSum += rgba[i] + rgba[i + 1] + rgba[i + 2];
      }
      if (markDiagTimeline) {
        PipelineDiagCaptureTimeline.markCapture();
      }
      pipelineDiagLog(
        'capture_frame',
        'w=$w h=$h monitorIndex=$idx rgbaBytes=${rgba.length} rgbSum=$rgbSum '
        'layout=${frame.layoutW}x${frame.layoutH} cropMeta=${frame.hasBufferLayoutMeta}',
      );
    }
    return frame;
  }

  @override
  Future<ScreenFrame?> captureFrame(
    int monitorIndex, {
    String? windowsCaptureBackend,
    Map<String, Object?>? windowsCaptureExtras,
  }) async {
    _clearError();
    try {
      final args = <String, Object?>{'monitorIndex': monitorIndex};
      if (!kIsWeb && Platform.isWindows) {
        args['captureBackend'] = normalizeWindowsScreenCaptureBackend(
          windowsCaptureBackend ?? 'dxgi',
        );
        if (windowsCaptureExtras != null && windowsCaptureExtras.isNotEmpty) {
          args.addAll(windowsCaptureExtras);
        }
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
      final frame = parseCaptureMap(map, markDiagTimeline: true);
      if (frame != null && !frame.isValid) {
        dbgCapture('ScreenFrame.isValid == false');
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
