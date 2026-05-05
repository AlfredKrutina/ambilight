import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/models/config_models.dart';
import '../../engine/ambilight_engine.dart';
import '../../engine/screen/screen_frame.dart';
import '../../engine/screen/screen_pipeline_isolate.dart';
import 'music_snapshot_codec.dart';
import 'music_types.dart';

/// Výsledek workeru — stejný formát jako screen pipeline (`unpackDeviceColors`).
class MusicFlatStripIsolateResult {
  MusicFlatStripIsolateResult({required this.seq, required this.packed});

  final int seq;
  final Map<String, Uint8List> packed;
}

/// Worker pro [MusicGranularEngine] + mapování na zařízení při `musicMode.colorSource == monitor'`.
final class MusicFlatStripIsolateBridge {
  Isolate? _isolate;
  ReceivePort? _mainRx;
  SendPort? _workerSend;
  Completer<void>? _ready;
  StreamSubscription? _sub;
  bool _dead = false;

  void Function(MusicFlatStripIsolateResult result)? onResult;

  void Function(int seq)? onSkip;

  bool get isReady => _workerSend != null && !_dead;

  Future<void> start() async {
    if (_dead) return;
    if (_isolate != null) return;
    _ready = Completer<void>();
    _mainRx = ReceivePort();

    try {
      _isolate = await Isolate.spawn(
        _musicFlatStripIsolateEntry,
        _mainRx!.sendPort,
        debugName: 'ambi_music_flat',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('MusicFlatStripIsolateBridge.spawn failed: $e\n$st');
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
            onResult?.call(MusicFlatStripIsolateResult(seq: seq, packed: packed));
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
      throw TimeoutException('music flat strip isolate handshake');
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
    required MusicAnalysisSnapshot snapshot,
    required double timeSec,
    required int width,
    required int height,
    required int monitorIndex,
    required Uint8List rgba,
  }) {
    final send = _workerSend;
    if (send == null || _dead) return;
    final copy = Uint8List.fromList(rgba);
    final td = TransferableTypedData.fromList(<TypedData>[copy]);
    send.send(<String, Object?>{
      't': 'job',
      'seq': seq,
      'snap': musicSnapshotToMap(snapshot),
      'time': timeSec,
      'w': width,
      'h': height,
      'mon': monitorIndex,
      'td': td,
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
void _musicFlatStripIsolateEntry(SendPort replyToMain) {
  final workerRx = ReceivePort();
  replyToMain.send(workerRx.sendPort);

  AppConfig? cfg;

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
        final snapRaw = m['snap'];
        final timeVal = m['time'];
        final w = m['w'];
        final h = m['h'];
        final mon = m['mon'];
        final td = m['td'];
        if (snapRaw is! Map ||
            timeVal is! num ||
            w is! int ||
            h is! int ||
            mon is! int ||
            td is! TransferableTypedData) {
          ackSkip();
          return;
        }
        final snap = musicSnapshotFromMap(Map<String, Object?>.from(snapRaw));
        final timeSec = timeVal.toDouble();
        final mat = td.materialize();
        final rgba = Uint8List.fromList(mat.asUint8List());
        final frame = ScreenFrame(width: w, height: h, monitorIndex: mon, rgba: rgba);
        if (!frame.isValid) {
          ackSkip();
          return;
        }
        try {
          final monitorSample = c.musicMode.colorSource == 'monitor' ? frame : null;
          final colors = AmbilightEngine.computeMusicDeviceColorsFromAnalysis(
            c,
            snap,
            monitorSample,
            timeSec,
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
