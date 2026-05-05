import 'dart:typed_data';

import 'package:logging/logging.dart';

final _log = Logger('PipelineDiag');

/// Zapnuto jen explicitně: `--dart-define=AMBI_PIPELINE_DIAGNOSTICS=true` (v `flutter run` bez define žádný PIPELINE spam).
/// End-to-end časová osa screen→isolate→UDP a segment / serial audit (viz diagnostický plán).
bool get ambilightPipelineDiagnosticsEnabled =>
    const bool.fromEnvironment('AMBI_PIPELINE_DIAGNOSTICS', defaultValue: false);

/// Min. odstup mezi řádky z [pipelineDiagLog] / [pipelineDiagIsolatePrint] (~5/s celkem na stranu).
const int _kPipelineDiagMinIntervalMicros = 200000;

int? _pipelineDiagMainLogLastMicros;
int? _pipelineDiagIsolatePrintLastMicros;

/// Po výstupu z screen worker izolátu okamžitě zavolat [_distribute] (bez čekání na další tick).
/// Vypnutí: `--dart-define=AMBI_SCREEN_EAGER_DISTRIBUTE=false`.
bool get ambilightScreenEagerDistributeEnabled =>
    const bool.fromEnvironment('AMBI_SCREEN_EAGER_DISTRIBUTE', defaultValue: true);

void pipelineDiagLog(String phase, String detail) {
  if (!ambilightPipelineDiagnosticsEnabled) return;
  final now = DateTime.now().microsecondsSinceEpoch;
  final last = _pipelineDiagMainLogLastMicros;
  if (last != null && now - last < _kPipelineDiagMinIntervalMicros) {
    return;
  }
  _pipelineDiagMainLogLastMicros = now;
  final ts = DateTime.now().toUtc().toIso8601String();
  _log.info('[PIPELINE_DIAG $ts] $phase $detail');
}

void pipelineDiagIsolatePrint(String message) {
  if (!ambilightPipelineDiagnosticsEnabled) return;
  final now = DateTime.now().microsecondsSinceEpoch;
  final last = _pipelineDiagIsolatePrintLastMicros;
  if (last != null && now - last < _kPipelineDiagMinIntervalMicros) {
    return;
  }
  _pipelineDiagIsolatePrintLastMicros = now;
  // Worker isolate nemá app Logger — stdout je záměr (viz diagnostický plán).
  // ignore: avoid_print
  print('[PIPELINE_DIAG] $message');
}

/// Push stream z Windows EventChannel — pro baseline / porovnání s pull capture.
class PipelineStreamDiagStats {
  PipelineStreamDiagStats._();

  static int framesReceived = 0;
  static int noUpdateEvents = 0;

  static void resetWindow() {
    framesReceived = 0;
    noUpdateEvents = 0;
  }

  static String formatWindowSummary() {
    return 'stream_frames=$framesReceived stream_noUpdate=$noUpdateEvents';
  }
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

  /// Absolutní čas posledního [markCapture] (pro scheduler metriky).
  static int? get lastCaptureWallMicros => _lastCaptureMicros;

  /// Poslední přijatý submit do screen izolátu — pro UDP diag (`sinceSubmitMs`), když DXGI
  /// dlouho neposílá snímek a `sinceCaptureMs` by jinak matně rostl bez změny pipeline.
  static int? _lastSubmitWallMicros;

  static void markSubmitWallForDiag() {
    if (!ambilightPipelineDiagnosticsEnabled) return;
    _lastSubmitWallMicros = DateTime.now().microsecondsSinceEpoch;
  }

  static int? elapsedSinceSubmitWallMicros() {
    final t = _lastSubmitWallMicros;
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

/// Scheduler / fronta hlavního izolátu — souhrn s [PipelineUdpDiagStats] v controlleru.
class PipelineSchedulerDiagStats {
  PipelineSchedulerDiagStats._();

  static int distributeCalls = 0;
  static int noopTickSmartLightsOnly = 0;
  static int eagerFlushFromIsolate = 0;
  static int screenSubmitMicrosBySeq = 0;
  static int _lastScreenSubmitSeq = 0;
  static int captureToIsolateOutTotalUs = 0;
  static int captureToIsolateOutSamples = 0;

  static void resetWindow() {
    distributeCalls = 0;
    noopTickSmartLightsOnly = 0;
    eagerFlushFromIsolate = 0;
    captureToIsolateOutTotalUs = 0;
    captureToIsolateOutSamples = 0;
  }

  /// Volat při odeslání snímku do screen izolátu ([seq] monotónně roste).
  static void markScreenSubmit(int seq) {
    if (!ambilightPipelineDiagnosticsEnabled) return;
    _lastScreenSubmitSeq = seq;
    screenSubmitMicrosBySeq = DateTime.now().microsecondsSinceEpoch;
    PipelineDiagCaptureTimeline.markSubmitWallForDiag();
  }

  /// Volat při [out] z workeru — odhad capture→izolát (pokud byl [markCapture] u submitu).
  static void recordIsolateOutForSubmit(int seq) {
    if (!ambilightPipelineDiagnosticsEnabled) return;
    if (seq != _lastScreenSubmitSeq) return;
    final cap = PipelineDiagCaptureTimeline.lastCaptureWallMicros;
    if (cap == null) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    final deltaUs = now - cap;
    if (deltaUs < 0 || deltaUs > 10 * 1000000) return;
    captureToIsolateOutTotalUs += deltaUs;
    captureToIsolateOutSamples++;
  }

  static String formatWindowSummary() {
    final avgCapIsoMs = captureToIsolateOutSamples > 0
        ? (captureToIsolateOutTotalUs / captureToIsolateOutSamples / 1000.0).toStringAsFixed(2)
        : '-';
    final distPerS = distributeCalls > 0 ? (distributeCalls / 5.0).toStringAsFixed(1) : '-';
    return 'distributeCalls=$distributeCalls (~$distPerS/s@5s) noopTickSmartOnly=$noopTickSmartLightsOnly '
        'eagerFlush=$eagerFlushFromIsolate capToIsolateAvgMs=$avgCapIsoMs '
        '(samples=$captureToIsolateOutSamples)';
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
