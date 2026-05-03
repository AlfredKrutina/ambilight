import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:record/record.dart';

import '../../core/models/config_models.dart';
import 'music_fft_analyzer.dart';
import 'music_types.dart';

final _log = Logger('MusicAudio');

/// Capture přes `record` + analýza mimo UI (stream callback → krátký výpočet, drop při zpoždění).
///
/// **Loopback (Windows WASAPI exclusive v Pythonu):** balíček `record` typicky nabízí
/// standardní vstupy (mikrofon, „Stereo Mix“, virtuální kabel). Skutečný WASAPI loopback
/// bez ovladače v systému Flutter **není** v tomto PR — viz `context/MUSIC_PORT_STATUS.md`.
class MusicAudioService {
  MusicAudioService() : _analyzer = MusicFftAnalyzer();

  final MusicFftAnalyzer _analyzer;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  MusicAnalysisSnapshot _latest = MusicAnalysisSnapshot.silent();
  AppConfig? _lastConfig;
  bool _running = false;
  bool _busy = false;
  final List<int> _pcmAcc = [];

  MusicAnalysisSnapshot get currentSnapshot => _latest;

  static Future<List<MusicCaptureDeviceInfo>> listDevices() async {
    try {
      final r = AudioRecorder();
      final inputs = await r.listInputDevices();
      final out = <MusicCaptureDeviceInfo>[];
      for (var i = 0; i < inputs.length; i++) {
        final d = inputs[i];
        final label = d.label.toLowerCase();
        final loopHint = label.contains('loopback') ||
            label.contains('stereo mix') ||
            label.contains('vb-audio') ||
            label.contains('cable output');
        out.add(MusicCaptureDeviceInfo(
          index: i,
          id: d.id,
          label: d.label,
          isLoopback: loopHint,
        ));
      }
      return out;
    } catch (e, st) {
      _log.warning('listDevices: $e', e, st);
      return [];
    }
  }

  /// Drží capture v souladu s režimem / zařízením; při přepnutí z music [await] uvolní hardware před serial rebuild.
  Future<void> syncWithConfig(AppConfig config) async {
    final mode = config.globalSettings.startMode;
    if (mode != 'music') {
      await _stopInternal();
      _lastConfig = config;
      return;
    }
    final mm = config.musicMode;
    _analyzer.setBeatDetection(
      enabled: mm.beatDetectionEnabled,
      thresholdMultiplier: mm.beatThreshold,
    );
    _analyzer.setSampleRate(48000);

    final prev = _lastConfig;
    final needRestart = !_running ||
        prev?.musicMode.audioDeviceIndex != mm.audioDeviceIndex ||
        prev?.musicMode.micEnabled != mm.micEnabled;
    _lastConfig = config;
    if (needRestart) {
      await _restartCapture(mm);
    }
  }

  Future<void> _restartCapture(MusicModeSettings mm) async {
    await _stopInternal();
    _running = true;
    try {
      _recorder = AudioRecorder();
      final has = await _recorder!.hasPermission();
      if (has != true) {
        if (kDebugMode) {
          _log.warning('music: microphone permission denied');
        }
        _running = false;
        return;
      }

      InputDevice? device;
      final inputs = await _recorder!.listInputDevices();
      if (inputs.isNotEmpty) {
        MusicCaptureDeviceInfo? preferred;
        final listed = await MusicAudioService.listDevices();
        if (mm.audioDeviceIndex != null &&
            mm.audioDeviceIndex! >= 0 &&
            mm.audioDeviceIndex! < listed.length) {
          preferred = listed[mm.audioDeviceIndex!];
        }
        if (preferred != null) {
          for (final d in inputs) {
            if (d.id == preferred.id) {
              device = d;
              break;
            }
          }
        }
        if (device == null && mm.micEnabled) {
          for (final d in inputs) {
            if (!d.label.toLowerCase().contains('loopback')) {
              device = d;
              break;
            }
          }
        }
        if (device == null) {
          for (final d in inputs) {
            final l = d.label.toLowerCase();
            if (l.contains('loopback') || l.contains('stereo mix') || l.contains('cable')) {
              device = d;
              break;
            }
          }
        }
        device ??= inputs.first;
      }

      const channels = 1;
      const rate = 48000;
      _analyzer.setSampleRate(rate);

      final stream = await _recorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: channels,
          sampleRate: rate,
          device: device,
        ),
      );

      if (kDebugMode) {
        _log.fine('music stream started device=${device?.label} mic=${mm.micEnabled}');
      }

      _pcmAcc.clear();
      _sub = stream.listen(_onPcm, onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          _log.warning('music stream: $e', e, st);
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        _log.warning('music start failed: $e', e, st);
      }
      _running = false;
    }
  }

  void _onPcm(Uint8List data) {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      _pcmAcc.addAll(data);
      const frameBytes = 4096 * 2;
      while (_pcmAcc.length >= frameBytes) {
        final chunk = Uint8List(frameBytes);
        for (var i = 0; i < frameBytes; i++) {
          chunk[i] = _pcmAcc[i];
        }
        _pcmAcc.removeRange(0, frameBytes);
        _latest = _analyzer.processPcmInt16Le(chunk, 1);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _stopInternal() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _recorder?.dispose();
    _recorder = null;
    _pcmAcc.clear();
    _latest = MusicAnalysisSnapshot.silent();
  }

  Future<void> dispose() => _stopInternal();
}
