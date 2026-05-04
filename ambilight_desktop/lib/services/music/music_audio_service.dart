import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:record/record.dart';

import '../../application/app_error_safety.dart';
import '../../application/build_environment.dart';
import '../../core/models/config_models.dart';
import 'music_fft_analyzer.dart';
import 'music_fft_isolate.dart';
import 'music_types.dart';

final _log = Logger('MusicAudio');

/// Capture přes `record` + FFT analýza v samostatném izolátu (fallback na hlavní izolát při selhání spawn).
class MusicAudioService {
  MusicAudioService();

  MusicFftAnalyzer? _fallbackAnalyzer;
  MusicFftIsolateBridge? _fftBridge;
  bool _fftIsolateReady = false;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  MusicAnalysisSnapshot _latest = MusicAnalysisSnapshot.silent();
  AppConfig? _lastConfig;
  bool _running = false;
  bool _busy = false;
  final List<int> _pcmAcc = [];
  static const _frameBytes = 4096 * 2;
  final Uint8List _pcmFrameScratch = Uint8List(_frameBytes);
  bool _audioStartFaultBannerShown = false;

  MusicAnalysisSnapshot get currentSnapshot => _latest;

  Future<void> _ensureFftIsolate() async {
    if (_fftIsolateReady) return;
    final bridge = MusicFftIsolateBridge();
    bridge.onResult = (snap) {
      _latest = snap;
    };
    try {
      await bridge.start();
      _fftBridge = bridge;
      _fftIsolateReady = true;
      if (kDebugMode) {
        _log.fine('music FFT isolate started');
      }
    } catch (e, st) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning('music FFT isolate unavailable, main-isolate FFT: $e', e, st);
      }
      await bridge.dispose();
      _fallbackAnalyzer ??= MusicFftAnalyzer();
      _fftIsolateReady = false;
    }
  }

  void _pushAnalyzerConfig(MusicModeSettings mm) {
    final rate = 48000;
    if (_fftIsolateReady && _fftBridge != null) {
      _fftBridge!.pushAnalyzerConfig(
        beatDetectionEnabled: mm.beatDetectionEnabled,
        beatThreshold: mm.beatThreshold,
        sampleRate: rate,
      );
    } else {
      _fallbackAnalyzer ??= MusicFftAnalyzer(sampleRate: rate);
      _fallbackAnalyzer!.setSampleRate(rate);
      _fallbackAnalyzer!.setBeatDetection(
        enabled: mm.beatDetectionEnabled,
        thresholdMultiplier: mm.beatThreshold,
      );
    }
  }

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

  Future<void> syncWithConfig(AppConfig config) async {
    final mode = config.globalSettings.startMode;
    if (mode != 'music') {
      await _stopInternal();
      _lastConfig = config;
      return;
    }
    final mm = config.musicMode;
    await _ensureFftIsolate();
    _pushAnalyzerConfig(mm);

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
      await _ensureFftIsolate();
      _pushAnalyzerConfig(mm);

      _recorder = AudioRecorder();
      final has = await _recorder!.hasPermission();
      if (has != true) {
        if (kDebugMode) {
          _log.warning('music: microphone permission denied');
        }
        if (!_audioStartFaultBannerShown) {
          _audioStartFaultBannerShown = true;
          reportAppFault(
            'Záznam zvuku pro hudbu není povolený (oprávnění mikrofonu). Režim hudba poběží bez analýzy.',
          );
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

      final stream = await _recorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: channels,
          sampleRate: 48000,
          device: device,
        ),
      );

      if (kDebugMode) {
        _log.fine('music stream started device=${device?.label} mic=${mm.micEnabled}');
      }

      _pcmAcc.clear();
      _audioStartFaultBannerShown = false;
      _sub = stream.listen(_onPcm, onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          _log.warning('music stream: $e', e, st);
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        _log.warning('music start failed: $e', e, st);
      }
      if (!_audioStartFaultBannerShown) {
        _audioStartFaultBannerShown = true;
        reportAppFault(
          'Hudba: nepodařilo se spustit záznam zvuku (${e.toString().split('\n').first}).',
        );
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
      while (_pcmAcc.length >= _frameBytes) {
        for (var i = 0; i < _frameBytes; i++) {
          _pcmFrameScratch[i] = _pcmAcc[i];
        }
        _pcmAcc.removeRange(0, _frameBytes);
        if (_fftIsolateReady && _fftBridge != null) {
          _fftBridge!.submitPcm16MonoFrame(_pcmFrameScratch);
        } else {
          _fallbackAnalyzer ??= MusicFftAnalyzer();
          _latest = _fallbackAnalyzer!.processPcmInt16Le(_pcmFrameScratch, 1);
        }
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

  Future<void> dispose() async {
    await _stopInternal();
    await _fftBridge?.dispose();
    _fftBridge = null;
    _fftIsolateReady = false;
    _fallbackAnalyzer = null;
  }
}
