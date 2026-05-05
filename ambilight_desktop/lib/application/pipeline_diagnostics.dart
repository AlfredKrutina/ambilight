import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:logging/logging.dart';

final _log = Logger('PipelineDiag');

/// Zapnuto: `kDebugMode` nebo `--dart-define=AMBI_PIPELINE_DIAGNOSTICS=true`.
/// End-to-end časová osa screen→isolate→UDP a segment / serial audit (viz diagnostický plán).
bool get ambilightPipelineDiagnosticsEnabled =>
    kDebugMode || const bool.fromEnvironment('AMBI_PIPELINE_DIAGNOSTICS', defaultValue: false);

void pipelineDiagLog(String phase, String detail) {
  if (!ambilightPipelineDiagnosticsEnabled) return;
  final ts = DateTime.now().toUtc().toIso8601String();
  _log.info('[PIPELINE_DIAG $ts] $phase $detail');
}

void pipelineDiagIsolatePrint(String message) {
  if (!ambilightPipelineDiagnosticsEnabled) return;
  // Worker isolate nemá app Logger — stdout je záměr (viz diagnostický plán).
  // ignore: avoid_print
  print('[PIPELINE_DIAG] $message');
}

/// Poslední [markCapture] — pro odhad mezery capture → UDP v hláškách `udp_emit_done`.
class PipelineDiagCaptureTimeline {
  PipelineDiagCaptureTimeline._();

  static int? _lastCaptureMicros;

  static void markCapture() {
    if (!ambilightPipelineDiagnosticsEnabled) return;
    _lastCaptureMicros = DateTime.now().microsecondsSinceEpoch;
  }

  /// Mikrosekundy od posledního [markCapture], nebo `null` pokud ještě nebylo.
  static int? elapsedSinceCaptureMicros() {
    final t = _lastCaptureMicros;
    if (t == null) return null;
    return DateTime.now().microsecondsSinceEpoch - t;
  }
}

/// Agregované počítadla UDP transportu — okénko se v controlleru periodicky vypíše a [resetWindow] vyčistí.
class PipelineUdpDiagStats {
  PipelineUdpDiagStats._();
  static int sendColorsCalls = 0;
  static int jobSupersededWhileQueued = 0;
  static int emitCompleted = 0;
  static int ephemeralWindowsBatches = 0;
  static int path0x02Bulk = 0;
  static int path0x06Chunked = 0;
  static int emitTotalMs = 0;
  static int emitSamples = 0;
  static int ephemeralBindTotalMs = 0;
  static int ephemeralBindSamples = 0;

  static void resetWindow() {
    sendColorsCalls = 0;
    jobSupersededWhileQueued = 0;
    emitCompleted = 0;
    ephemeralWindowsBatches = 0;
    path0x02Bulk = 0;
    path0x06Chunked = 0;
    emitTotalMs = 0;
    emitSamples = 0;
    ephemeralBindTotalMs = 0;
    ephemeralBindSamples = 0;
  }

  static String formatWindowSummary() {
    final avgEmit = emitSamples > 0 ? (emitTotalMs / emitSamples).toStringAsFixed(1) : '-';
    final avgBind = ephemeralBindSamples > 0 ? (ephemeralBindTotalMs / ephemeralBindSamples).toStringAsFixed(1) : '-';
    return 'udp_sendColors=$sendColorsCalls superseded=$jobSupersededWhileQueued emitDone=$emitCompleted '
        'ephemeralBatches=$ephemeralWindowsBatches path0x02=$path0x02Bulk path0x06=$path0x06Chunked '
        'emitAvgMs=$avgEmit ephemeralBindAvgMs=$avgBind';
  }

  static void recordEmitMs(int ms) {
    emitTotalMs += ms;
    emitSamples++;
  }

  static void recordEphemeralBindMs(int ms) {
    ephemeralBindTotalMs += ms;
    ephemeralBindSamples++;
  }
}

/// Krátký hex náhled pro serial / firmware audit.
String pipelineDiagHexPrefix(Uint8List bytes, {int maxBytes = 48}) {
  final n = bytes.length < maxBytes ? bytes.length : maxBytes;
  final sb = StringBuffer();
  for (var i = 0; i < n; i++) {
    if (i > 0) sb.write(' ');
    sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  if (bytes.length > n) sb.write(' …');
  return sb.toString();
}
