// Diagnostika workeru — výjimky přes [debugPrint], pipeline přes [pipelineDiagIsolatePrint].

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../application/pipeline_diagnostics.dart';
import '../../core/models/config_models.dart';
import '../ambilight_engine.dart';
import 'screen_color_pipeline.dart';
import 'screen_frame.dart';

/// Zpráva výsledku — [packed] je `deviceId → rgb bytes` (délka `ledCount * 3`).
class ScreenPipelineIsolateResult {
  ScreenPipelineIsolateResult({required this.seq, required this.packed});

  final int seq;
  final Map<String, Uint8List> packed;
}

/// Most mezi hlavním izolátem a workerem pro [ScreenColorPipeline] + EMA vyhlazení.
final class ScreenPipelineIsolateBridge {
  Isolate? _isolate;
  ReceivePort? _mainRx;
  SendPort? _workerSend;
  Completer<void>? _ready;
  StreamSubscription? _sub;
  bool _dead = false;

  /// Externí posluchač na hlavním izolátu (např. controller).
  void Function(ScreenPipelineIsolateResult result)? onResult;

  /// Transientní stav (chybí cfg, špatný frame, …) — UI drží poslední platné barvy.
  void Function(int seq)? onSkip;

  bool get isReady => _workerSend != null && !_dead;

  Future<void> start() async {
    if (_dead) return;
    if (_isolate != null) return;
    _ready = Completer<void>();
    _mainRx = ReceivePort();

    try {
      _isolate = await Isolate.spawn(_screenPipelineIsolateEntry, _mainRx!.sendPort, debugName: 'ambi_screen_pipe');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ScreenPipelineIsolateBridge.spawn failed: $e\n$st');
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
            onResult?.call(ScreenPipelineIsolateResult(seq: seq, packed: packed));
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
      throw TimeoutException('screen pipeline isolate handshake');
    });
  }

  void pushConfig(AppConfig config) {
    final send = _workerSend;
    if (send == null || _dead) return;
    if (ambilightPipelineDiagnosticsEnabled) {
      final ds = config.globalSettings.devices;
      final summary =
          ds.map((d) => '${d.id}:lc=${d.ledCount}:ha=${d.controlViaHa}').join('|');
      pipelineDiagLog(
        'isolate_cfg_push_main',
        'devices=${ds.length} {$summary} segments=${config.screenMode.segments.length} '
        'screenMon=${config.screenMode.monitorIndex}',
      );
    }
    send.send(<String, Object?>{
      't': 'cfg',
      'cfg': config.toJson(),
    });
  }

  void resetSmoothing() {
    final send = _workerSend;
    if (send == null || _dead) return;
    send.send(<String, Object?>{'t': 'reset'});
  }

  /// Jedna kopie pixelů napříč hranicí izolátů ([TransferableTypedData.fromList]); na workeru
  /// se po [materialize] použije přímo materializovaný buffer bez druhé plné kopie.
  void submitFrame({
    required int seq,
    required ScreenFrame frame,
    bool rainbowSynthBypassCapture = false,
  }) {
    final send = _workerSend;
    if (send == null || _dead) return;
    if (!frame.isValid) {
      return;
    }
    final td = TransferableTypedData.fromList(<TypedData>[frame.rgba]);
    send.send(<String, Object?>{
      't': 'frame',
      'seq': seq,
      'rainbowSynth': rainbowSynthBypassCapture,
      'w': frame.width,
      'h': frame.height,
      'mon': frame.monitorIndex,
      'td': td,
      if (frame.layoutWidth != null) 'lw': frame.layoutWidth,
      if (frame.layoutHeight != null) 'lh': frame.layoutHeight,
      'bx': frame.bufferOriginX,
      'by': frame.bufferOriginY,
      if (frame.nativeBufferWidth != null) 'nbw': frame.nativeBufferWidth,
      if (frame.nativeBufferHeight != null) 'nbh': frame.nativeBufferHeight,
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

Map<String, Uint8List> packDeviceRgbMap(Map<String, List<(int, int, int)>> src) {
  final out = <String, Uint8List>{};
  for (final e in src.entries) {
    final buf = Uint8List(e.value.length * 3);
    for (var i = 0; i < e.value.length; i++) {
      final c = e.value[i];
      final o = i * 3;
      buf[o] = c.$1;
      buf[o + 1] = c.$2;
      buf[o + 2] = c.$3;
    }
    out[e.key] = buf;
  }
  return out;
}

/// unpack na hlavním izolátu — délka seznamu = min(bajtů v paketu, [ScreenColorPipeline.effectiveDeviceLedCount]),
/// aby se z krátkého worker výstupu nedělal umělý „dlouhý“ buffer (např. 2000× černá) při špatně uloženém `ledCount`.
/// Syntetické barvy podél pásku — **nečte** snímek obrazovky (diagnostika lagů).
///
/// Fáze v čase + prostorový offset po LED: stejný tvar výstupu jako [ScreenColorPipeline.processFrameToDevices].
/// Zařízení s `controlViaHa` dostanou černou (jako při přeskakování výstupu v distribuci).
Map<String, List<(int, int, int)>> rainbowSynthDeviceColors(AppConfig config, double tSec) {
  final out = <String, List<(int, int, int)>>{};
  for (final d in config.globalSettings.devices) {
    final n = ScreenColorPipeline.effectiveDeviceLedCount(config, d);
    if (n <= 0) {
      out[d.id] = const [];
      continue;
    }
    if (d.controlViaHa) {
      out[d.id] = List<(int, int, int)>.filled(n, (0, 0, 0), growable: false);
      continue;
    }
    final omega = tSec * math.pi * 2.0 * 4.0;
    final list = <(int, int, int)>[];
    for (var i = 0; i < n; i++) {
      final phase = omega + (i / math.max(n, 1)) * math.pi * 2.0;
      final r = ((math.sin(phase) + 1.0) * 127.5).round().clamp(0, 255);
      final g = ((math.sin(phase + 2.0 * math.pi / 3.0) + 1.0) * 127.5).round().clamp(0, 255);
      final b = ((math.sin(phase + 4.0 * math.pi / 3.0) + 1.0) * 127.5).round().clamp(0, 255);
      list.add((r, g, b));
    }
    out[d.id] = list;
  }
  return out;
}

/// Worker [packed] musí mít klíč pro každé zařízení s přímým výstupem (ne HA-only).
/// Jinak [unpackDeviceColors] nechá mapu v černé a [_distributeSync] svítí samé nuly.
bool packedRgbMapCoversWifiAndSerialOutputs(
  AppConfig config,
  Map<String, Uint8List> packed,
) {
  for (final d in config.globalSettings.devices) {
    if (d.controlViaHa) continue;
    final p = packed[d.id];
    if (p == null || p.isEmpty || p.length % 3 != 0) {
      return false;
    }
  }
  return true;
}

Map<String, List<(int, int, int)>> unpackDeviceColors(
  AppConfig config,
  Map<String, Uint8List> packed,
) {
  final out = AmbilightEngine.blackoutPerDevice(config);
  for (final d in config.globalSettings.devices) {
    final p = packed[d.id];
    if (p == null) continue;
    final fromPack = p.length ~/ 3;
    if (fromPack <= 0) continue;
    final maxTriplets = ScreenColorPipeline.effectiveDeviceLedCount(config, d);
    final n = math.min(fromPack, maxTriplets);
    final list = List<(int, int, int)>.generate(
      n,
      (i) {
        final o = i * 3;
        return (p[o], p[o + 1], p[o + 2]);
      },
      growable: false,
    );
    out[d.id] = list;
  }
  return out;
}

@pragma('vm:entry-point')
void _screenPipelineIsolateEntry(SendPort replyToMain) {
  final workerRx = ReceivePort();
  replyToMain.send(workerRx.sendPort);

  AppConfig? cfg;
  final runtime = ScreenPipelineRuntime();
  var rainbowSynthLogged = false;

  workerRx.listen((Object? msg) {
    if (msg is! Map) return;
    final m = Map<String, Object?>.from(msg);
    final t = m['t']?.toString();
    switch (t) {
      case 'cfg':
        final raw = m['cfg'];
        if (raw is Map) {
          final parsed = AppConfig.fromJson(Map<String, dynamic>.from(raw));
          cfg = parsed;
          rainbowSynthLogged = false;
          if (ambilightPipelineDiagnosticsEnabled) {
            final ds = parsed.globalSettings.devices;
            final summary =
                ds.map((d) => '${d.id}:lc=${d.ledCount}').join('|');
            pipelineDiagIsolatePrint(
              'isolate_cfg_rx devices=${ds.length} {$summary} '
              'segments=${parsed.screenMode.segments.length} '
              'screenMon=${parsed.screenMode.monitorIndex}',
            );
          }
        }
        return;
      case 'reset':
        runtime.resetSmoothing();
        return;
      case 'shutdown':
        workerRx.close();
        Isolate.exit();
      case 'frame':
        final seq = m['seq'];
        if (seq is! int) {
          debugPrint(
            'ISOLATE FRAME DROP: seq is not int (type=${seq.runtimeType}, value=$seq)',
          );
          return;
        }
        final c = cfg;
        void ackSkip(String reason) {
          if (ambilightPipelineDiagnosticsEnabled) {
            pipelineDiagIsolatePrint('isolate_skip seq=$seq $reason');
          }
          replyToMain.send(<String, Object?>{'t': 'skip', 'seq': seq});
        }
        if (c == null) {
          ackSkip('cfg is null (pushConfig not applied yet?)');
          return;
        }
        final td = m['td'];
        if (td is! TransferableTypedData) {
          ackSkip('bad frame message types (td=${td.runtimeType})');
          return;
        }

        // Diagnostika (jen když hlavní izolát pošle rainbowSynth=true): obejde ROI — stejný pack + transport.
        final rainbowSynth = m['rainbowSynth'] == true;
        if (rainbowSynth) {
          if (!rainbowSynthLogged) {
            rainbowSynthLogged = true;
            pipelineDiagIsolatePrint(
              'rainbow_synth worker: ignoring capture RGBA (Nastavení → Obrazovka)',
            );
          }
          try {
            td.materialize();
          } catch (e, st) {
            ackSkip('rainbow_synth materialize failed: $e $st');
            return;
          }
          // Fáze vázaná na [seq], ne na wall clock — capture/tick mají jitter; stejný hash + UDP dedupe
          // pak vypadaly jako „sekání“ a nerovnoměrný krok na pásku.
          final tSec = seq * (1.0 / 60.0);
          final isolateSw = ambilightPipelineDiagnosticsEnabled ? (Stopwatch()..start()) : null;
          try {
            final rawColors = rainbowSynthDeviceColors(c, tSec);
            final packed = packDeviceRgbMap(rawColors);
            if (isolateSw != null) {
              isolateSw.stop();
              pipelineDiagIsolatePrint(
                'rainbow_synth_frame_done seq=$seq processMs=${isolateSw.elapsedMilliseconds}',
              );
            }
            replyToMain.send(<String, Object?>{
              't': 'out',
              'seq': seq,
              'packed': packed,
            });
          } catch (e, st) {
            isolateSw?.stop();
            debugPrint('ISOLATE RAINBOW_SYNTH EXCEPTION seq=$seq: $e\n$st');
            ackSkip('exception in rainbowSynthDeviceColors (see ISOLATE RAINBOW_SYNTH EXCEPTION)');
          }
          return;
        }

        final w = m['w'];
        final h = m['h'];
        final mon = m['mon'];
        if (w is! int || h is! int || mon is! int) {
          ackSkip(
            'bad frame message types (w=${w.runtimeType}, h=${h.runtimeType}, '
            'mon=${mon.runtimeType})',
          );
          return;
        }
        final mat = td.materialize();
        final view = mat.asUint8List();
        final need = w * h * 4;
        if (view.lengthInBytes < need) {
          ackSkip('materialized buffer too short (${view.lengthInBytes} < $need)');
          return;
        }
        final Uint8List rgba =
            view.lengthInBytes == need ? view : Uint8List.sublistView(view, 0, need);
        final lw = m['lw'];
        final lh = m['lh'];
        final bx = m['bx'];
        final by = m['by'];
        final nbw = m['nbw'];
        final nbh = m['nbh'];
        int? asIntOrNull(Object? o) {
          if (o is int) return o;
          if (o is num) return o.toInt();
          return null;
        }
        final frame = ScreenFrame(
          width: w,
          height: h,
          monitorIndex: mon,
          rgba: rgba,
          layoutWidth: asIntOrNull(lw),
          layoutHeight: asIntOrNull(lh),
          bufferOriginX: asIntOrNull(bx) ?? 0,
          bufferOriginY: asIntOrNull(by) ?? 0,
          nativeBufferWidth: asIntOrNull(nbw),
          nativeBufferHeight: asIntOrNull(nbh),
        );
        if (!frame.isValid) {
          final expected = w * h * 4;
          ackSkip(
            'frame is invalid (width=$w height=$h monitorIndex=$mon '
            'rgba.length=${rgba.length} expectedBytes=$expected)',
          );
          return;
        }
        final isolateSw = ambilightPipelineDiagnosticsEnabled ? (Stopwatch()..start()) : null;
        if (ambilightPipelineDiagnosticsEnabled && seq % 30 == 0) {
          ScreenColorPipeline.logSegmentDiagnosticsForFrame(c, frame);
        }
        try {
          final rawColors = ScreenColorPipeline.processFrameToDevices(c, frame, runtime);
          // Zero-latency diagnostika: bez časového EMA ([interpolationMs] ignorováno).
          final packed = packDeviceRgbMap(rawColors);
          if (ambilightPipelineDiagnosticsEnabled) {
            isolateSw!.stop();
            var rgbSum = 0;
            for (final buf in packed.values) {
              for (var i = 0; i < buf.length; i++) {
                rgbSum += buf[i];
              }
            }
            final packedBytes =
                packed.values.fold<int>(0, (a, b) => a + b.length);
            pipelineDiagIsolatePrint(
              'isolate_frame_done seq=$seq processMs=${isolateSw.elapsedMilliseconds} '
              'rgbSum=$rgbSum packedRgbBytes=$packedBytes devices=${packed.length}',
            );
          }
          replyToMain.send(<String, Object?>{
            't': 'out',
            'seq': seq,
            'packed': packed,
          });
        } catch (e, st) {
          isolateSw?.stop();
          debugPrint('ISOLATE EXCEPTION seq=$seq: $e\n$st');
          ackSkip('exception in processFrameToDevices / smoothing (see ISOLATE EXCEPTION)');
        }
        return;
      default:
        return;
    }
  });
}
