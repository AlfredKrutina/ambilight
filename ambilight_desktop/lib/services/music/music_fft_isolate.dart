import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'music_fft_analyzer.dart';
import 'music_snapshot_codec.dart';
import 'music_types.dart';

/// Worker pro FFT — drží [MusicFftAnalyzer] mimo hlavní izolát.
final class MusicFftIsolateBridge {
  Isolate? _isolate;
  ReceivePort? _mainRx;
  SendPort? _workerSend;
  Completer<void>? _ready;
  StreamSubscription? _sub;
  bool _dead = false;

  void Function(MusicAnalysisSnapshot encoded)? onResult;

  Future<void> start() async {
    if (_dead) return;
    if (_isolate != null) return;
    _ready = Completer<void>();
    _mainRx = ReceivePort();
    try {
      _isolate = await Isolate.spawn(_musicFftIsolateEntry, _mainRx!.sendPort, debugName: 'ambi_music_fft');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('MusicFftIsolateBridge.spawn failed: $e\n$st');
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
        if (m['t'] == 'snap') {
          final raw = m['d'];
          if (raw is Map) {
            onResult?.call(musicSnapshotFromMap(Map<String, Object?>.from(raw)));
          }
        }
      }
    });

    await _ready?.future.timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('music fft isolate handshake');
    });
  }

  void pushAnalyzerConfig({
    required bool beatDetectionEnabled,
    required double beatThreshold,
    required int sampleRate,
  }) {
    final send = _workerSend;
    if (send == null || _dead) return;
    send.send(<String, Object?>{
      't': 'cfg',
      'bd': beatDetectionEnabled,
      'bt': beatThreshold,
      'sr': sampleRate,
    });
  }

  void submitPcm16MonoFrame(Uint8List pcm4096) {
    final send = _workerSend;
    if (send == null || _dead) return;
    send.send(Uint8List.fromList(pcm4096));
  }

  Future<void> dispose() async {
    _dead = true;
    onResult = null;
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
void _musicFftIsolateEntry(SendPort replyToMain) {
  final workerRx = ReceivePort();
  replyToMain.send(workerRx.sendPort);

  MusicFftAnalyzer? analyzer;

  workerRx.listen((Object? msg) {
    if (msg is Map) {
      final m = Map<String, Object?>.from(msg);
      if (m['t'] == 'shutdown') {
        workerRx.close();
        return;
      }
      if (m['t'] == 'cfg') {
        final sr = (m['sr'] as num?)?.toInt() ?? 48000;
        analyzer ??= MusicFftAnalyzer(sampleRate: sr);
        analyzer!.setSampleRate(sr);
        analyzer!.setBeatDetection(
          enabled: m['bd'] == true,
          thresholdMultiplier: (m['bt'] as num?)?.toDouble() ?? 1.5,
        );
      }
      return;
    }
    if (msg is Uint8List && analyzer != null) {
      try {
        final snap = analyzer!.processPcmInt16Le(msg, 1);
        replyToMain.send(<String, Object?>{
          't': 'snap',
          'd': musicSnapshotToMap(snap),
        });
      } catch (_) {}
    }
  });
}
