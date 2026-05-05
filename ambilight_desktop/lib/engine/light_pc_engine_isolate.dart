import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/models/config_models.dart';
import '../features/pc_health/pc_health_snapshot.dart';
import 'ambilight_engine.dart';
import 'screen/screen_color_pipeline.dart';
import 'screen/screen_pipeline_isolate.dart';

/// Výsledek workeru — formát jako screen pipeline (`unpackDeviceColors`).
class LightPcEngineIsolateResult {
  LightPcEngineIsolateResult({required this.seq, required this.packed});

  final int seq;
  final Map<String, Uint8List> packed;
}

/// Worker pro režimy **light** a **pc_health** (`AmbilightEngine.computeFrame` bez screen/music vstupů).
final class LightPcEngineIsolateBridge {
  Isolate? _isolate;
  ReceivePort? _mainRx;
  SendPort? _workerSend;
  Completer<void>? _ready;
  StreamSubscription? _sub;
  bool _dead = false;

  void Function(LightPcEngineIsolateResult result)? onResult;

  void Function(int seq)? onSkip;

  bool get isReady => _workerSend != null && !_dead;

  Future<void> start() async {
    if (_dead) return;
    if (_isolate != null) return;
    _ready = Completer<void>();
    _mainRx = ReceivePort();

    try {
      _isolate = await Isolate.spawn(
        _lightPcEngineIsolateEntry,
        _mainRx!.sendPort,
        debugName: 'ambi_light_pc',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('LightPcEngineIsolateBridge.spawn failed: $e\n$st');
      }
      _mainRx?.close();
      _mainRx = null;
      _isolate = null;
      _ready?.completeError(e, st);
      _ready = null;
      rethrow;
    }

    var gotWorker = false;
    _sub = _mainRx!.listen((Object? msg) {
      if (!gotWorker) {
        if (msg is SendPort) {
          _workerSend = msg;
          gotWorker = true;
          if (!(_ready?.isCompleted ?? true)) {
            _ready!.complete();
          }
          _ready = null;
        }
        return;
      }
      if (msg is Map) {
        final m = Map<String, Object?>.from(msg);
        final tag = m['t'];
        if (tag == 'out') {
          final seq = m['seq'];
          final packedRaw = m['packed'];
          if (seq is int && packedRaw is Map) {
            final packed = <String, Uint8List>{};
            packedRaw.forEach((k, v) {
              if (k is String && v is Uint8List) {
                packed[k] = v;
              }
            });
            onResult?.call(LightPcEngineIsolateResult(seq: seq, packed: packed));
          }
        } else if (tag == 'skip') {
          final seq = m['seq'];
          if (seq is int) {
            onSkip?.call(seq);
          }
        }
      }
    });

    await _ready?.future.timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('light/pc engine isolate handshake');
    });
  }

  void pushConfig(AppConfig config) {
    final send = _workerSend;
    if (send == null || _dead) return;
    send.send(<String, Object?>{
      't': 'cfg',
      'cfg': config.toJson(),
    });
  }

  void submitJob({
    required int seq,
    required int animationTick,
    required Map<String, Object?> pcHealthPortable,
  }) {
    final send = _workerSend;
    if (send == null || _dead) return;
    send.send(<String, Object?>{
      't': 'job',
      'seq': seq,
      'tick': animationTick,
      'pc': pcHealthPortable,
    });
  }

  Future<void> dispose() async {
    _dead = true;
    onResult = null;
    onSkip = null;
    try {
      _workerSend?.send(<String, Object?>{'t': 'shutdown'});
    } catch (_) {}
    _workerSend = null;
    await _sub?.cancel();
    _sub = null;
    _mainRx?.close();
    _mainRx = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

@pragma('vm:entry-point')
void _lightPcEngineIsolateEntry(SendPort replyToMain) {
  final workerRx = ReceivePort();
  replyToMain.send(workerRx.sendPort);

  AppConfig? cfg;
  final screenPipeline = ScreenPipelineRuntime();

  workerRx.listen((Object? msg) {
    if (msg is! Map) return;
    final m = Map<String, Object?>.from(msg);
    final t = m['t']?.toString();
    switch (t) {
      case 'cfg':
        final raw = m['cfg'];
        if (raw is Map) {
          cfg = AppConfig.fromJson(Map<String, dynamic>.from(raw));
        }
        return;
      case 'shutdown':
        workerRx.close();
        Isolate.exit();
      case 'job':
        final seq = m['seq'];
        if (seq is! int) return;
        final c = cfg;
        void ackSkip() {
          replyToMain.send(<String, Object?>{'t': 'skip', 'seq': seq});
        }
        if (c == null) {
          ackSkip();
          return;
        }
        final mode = c.globalSettings.startMode;
        if (mode != 'light' && mode != 'pchealth' && mode != 'pc_health') {
          ackSkip();
          return;
        }
        final tick = m['tick'];
        final pcRaw = m['pc'];
        if (tick is! int) {
          ackSkip();
          return;
        }
        final pcSnap = pcRaw is Map
            ? pcHealthSnapshotFromPortableMap(Map<String, Object?>.from(pcRaw))
            : PcHealthSnapshot.empty;
        try {
          final colors = AmbilightEngine.computeFrame(
            c,
            tick,
            startupBlackout: false,
            enabled: true,
            screenFrame: null,
            screenPipeline: screenPipeline,
            musicSnapshot: null,
            pcHealthSnapshot: pcSnap,
            musicAlbumDominantRgb: null,
          );
          replyToMain.send(<String, Object?>{
            't': 'out',
            'seq': seq,
            'packed': packDeviceRgbMap(colors),
          });
        } catch (_) {
          ackSkip();
        }
        return;
      default:
        return;
    }
  });
}
