import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:desktop_audio_capture/audio_capture.dart' hide InputDevice;
import 'package:flutter/foundation.dart' show ValueNotifier, kDebugMode, kIsWeb;
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
///
/// Na **Windows** lze při výchozím vstupu (bez výběru zařízení) a vypnutém „preferovat mikrofon“
/// zachytit **výstup výchozího přehrávacího zařízení** (WASAPI loopback) — zvuk z aplikací / prohlížeče,
/// ne nutně fyzický mikrofon ani Stereo Mix.
///
/// Na **macOS** dnes nemáme nativní loopback — capture jede přes `record` ze zvoleného vstupního zařízení
/// (defaultně mikrofon nebo virtuální vstup typu BlackHole / Aggregate). [inputLevelNotifier] dává UI
/// real‑time peak, aby uživatel viděl, jestli signál vůbec přichází.
class MusicAudioService {
  MusicAudioService();

  MusicFftAnalyzer? _fallbackAnalyzer;
  MusicFftIsolateBridge? _fftBridge;
  bool _fftIsolateReady = false;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  SystemAudioCapture? _systemCapture;
  StreamSubscription<Uint8List>? _systemSub;
  MusicAnalysisSnapshot _latest = MusicAnalysisSnapshot.silent();
  AppConfig? _lastConfig;
  bool _running = false;
  bool _busy = false;
  final BytesBuilder _pcmAcc = BytesBuilder(copy: false);
  static const _frameBytes = 4096 * 2;
  /// Strop pro PCM frontu (~6 framů = ~0.5 s při 48 kHz mono / int16). Nad limit zahodíme nejstarší
  /// data — bez toho buffer drží sekundy zvuku, FFT zaostává a UI vidí „mrtvou“ analýzu.
  static const _pcmAccMaxBytes = _frameBytes * 6;
  bool _audioStartFaultBannerShown = false;

  /// Real‑time peak (0..1) z PCM bytů. Slouží UI jako diagnostika — když je dlouhodobě pod ~0.005,
  /// vstupní zařízení nepřijímá zvuk (špatně zvolený vstup, ztlumený mic, zařízení neprodukuje signál).
  final ValueNotifier<double> inputLevelNotifier = ValueNotifier<double>(0);
  double _inputLevelPeak = 0;
  DateTime _lastInputLevelEmit = DateTime.fromMillisecondsSinceEpoch(0);

  /// Stručný popis aktivní capture cesty (kdo / jaký formát / loopback?). Pomáhá při diagnostice
  /// „LED skoro nesvítí na macOS“ — uživatel vidí, zda chytl loopback nebo náhradní mikrofon.
  final ValueNotifier<MusicCaptureInfo> captureInfoNotifier =
      ValueNotifier<MusicCaptureInfo>(const MusicCaptureInfo.idle());

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

  /// Heuristika „systémový mix“ / loopback (Windows Stereo Mix, VB-Cable, macOS BlackHole, …).
  static bool labelLooksLikeSystemLoopback(String raw) {
    final label = raw.toLowerCase();
    return label.contains('loopback') ||
        label.contains('stereo mix') ||
        label.contains('vb-audio') ||
        label.contains('cable output') ||
        label.contains('cable input') ||
        label.contains('blackhole') ||
        label.contains('black hole') ||
        label.contains('aggregate') ||
        label.contains('multi-output') ||
        label.contains('wave out mix') ||
        label.contains('what u hear') ||
        label.contains('stereo out');
  }

  static bool _shouldUseWindowsWasapiLoopback(MusicModeSettings mm) {
    if (kIsWeb) return false;
    try {
      if (!Platform.isWindows) return false;
    } catch (_) {
      return false;
    }
    return !mm.micEnabled && mm.audioDeviceIndex == null;
  }

  static Future<List<MusicCaptureDeviceInfo>> listDevices() async {
    try {
      final r = AudioRecorder();
      final inputs = await r.listInputDevices();
      final out = <MusicCaptureDeviceInfo>[];
      for (var i = 0; i < inputs.length; i++) {
        final d = inputs[i];
        final loopHint = labelLooksLikeSystemLoopback(d.label);
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

  Future<bool> _tryStartWindowsWasapiLoopback(MusicModeSettings mm) async {
    try {
      final cap = SystemAudioCapture(
        config: SystemAudioConfig(sampleRate: 48000, channels: 1),
      );
      await cap.startCapture(
        config: SystemAudioConfig(sampleRate: 48000, channels: 1),
      );
      final stream = cap.audioStream;
      if (stream == null) {
        await cap.stopCapture();
        return false;
      }
      _systemCapture = cap;
      _systemSub = stream.listen(
        _onPcm,
        onError: (Object e, StackTrace st) {
          if (kDebugMode || ambilightVerboseLogsEnabled) {
            _log.warning('music WASAPI stream: $e', e, st);
          }
        },
      );
      _log.info('music: Windows WASAPI loopback capture started (default render device)');
      captureInfoNotifier.value = const MusicCaptureInfo(
        active: true,
        backend: MusicCaptureBackend.windowsWasapiLoopback,
        deviceLabel: 'Default render device',
        sampleRate: 48000,
        channels: 1,
        isLoopback: true,
      );
      return true;
    } catch (e, st) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning('music: WASAPI loopback start failed, falling back to record: $e', e, st);
      }
      await _disposeWindowsWasapiOnly();
      return false;
    }
  }

  Future<void> _disposeWindowsWasapiOnly() async {
    await _systemSub?.cancel();
    _systemSub = null;
    try {
      if (_systemCapture != null && _systemCapture!.isRecording) {
        await _systemCapture!.stopCapture();
      }
    } catch (_) {}
    _systemCapture = null;
  }

  Future<void> _restartCapture(MusicModeSettings mm) async {
    await _stopInternal();
    _running = true;
    try {
      await _ensureFftIsolate();
      _pushAnalyzerConfig(mm);

      if (_shouldUseWindowsWasapiLoopback(mm)) {
        final ok = await _tryStartWindowsWasapiLoopback(mm);
        if (ok) {
          _pcmAcc.clear();
          _audioStartFaultBannerShown = false;
          return;
        }
      }

      await _startRecordCapture(mm);
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

  Future<void> _startRecordCapture(MusicModeSettings mm) async {
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
          if (!labelLooksLikeSystemLoopback(d.label)) {
            device = d;
            break;
          }
        }
      }
      if (device == null) {
        for (final d in inputs) {
          if (labelLooksLikeSystemLoopback(d.label)) {
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

    final loopbackish = device != null && labelLooksLikeSystemLoopback(device.label);
    final platformLabel = _platformLabel();
    // Záměrně INFO i mimo debug — když uživatel hlásí „LED nesvítí“, log řekne hned, čí vstup chytáme.
    _log.info(
      'music capture started platform=$platformLabel '
      'device="${device?.label ?? '<system default>'}" '
      'micPreferred=${mm.micEnabled} loopbackish=$loopbackish '
      'sr=48000 channels=$channels',
    );
    captureInfoNotifier.value = MusicCaptureInfo(
      active: true,
      backend: MusicCaptureBackend.recordPackage,
      deviceLabel: device?.label ?? 'System default',
      sampleRate: 48000,
      channels: channels,
      isLoopback: loopbackish,
    );

    _pcmAcc.clear();
    _audioStartFaultBannerShown = false;
    _sub = stream.listen(_onPcm, onError: (Object e, StackTrace st) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning('music stream: $e', e, st);
      }
    });
  }

  static String _platformLabel() {
    try {
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {}
    return 'unknown';
  }

  void _onPcm(Uint8List data) {
    if (_busy) {
      // Reentrance ze stejné event‑loop nehrozí, ale pojistka kdyby plugin posílal sync v jiném vláknu.
      return;
    }
    _busy = true;
    try {
      _updateInputLevel(data);
      _pcmAcc.add(data);

      // Drop nejstarších dat při zaostávání FFT — bez toho buffer drží sekundy zvuku
      // a UI vidí „mrtvou“ analýzu ještě dlouho po tom, co skladba ztichne.
      if (_pcmAcc.length > _pcmAccMaxBytes) {
        final all = _pcmAcc.takeBytes();
        final keep = Uint8List.sublistView(all, all.length - _pcmAccMaxBytes);
        _pcmAcc.add(keep);
        if (kDebugMode || ambilightVerboseLogsEnabled) {
          _log.fine('music: PCM acc overflow, dropped ${all.length - keep.length} bytes');
        }
      }

      if (_pcmAcc.length < _frameBytes) return;

      final all = _pcmAcc.takeBytes();
      var offset = 0;
      while (all.length - offset >= _frameBytes) {
        final frame = Uint8List.sublistView(all, offset, offset + _frameBytes);
        offset += _frameBytes;
        if (_fftIsolateReady && _fftBridge != null) {
          _fftBridge!.submitPcm16MonoFrame(frame);
        } else {
          _fallbackAnalyzer ??= MusicFftAnalyzer();
          _latest = _fallbackAnalyzer!.processPcmInt16Le(frame, 1);
        }
      }
      if (offset < all.length) {
        _pcmAcc.add(Uint8List.sublistView(all, offset));
      }
    } finally {
      _busy = false;
    }
  }

  /// Spočítá rychlý peak (max |sample| / 32768) z chunku a notifikuje UI maximálně 30×/s,
  /// aby Notifier nezahltil rebuild.
  void _updateInputLevel(Uint8List data) {
    if (data.length < 2) return;
    var peak = 0;
    final n = data.length & ~1;
    for (var i = 0; i < n; i += 2) {
      final lo = data[i];
      final hi = data[i + 1];
      var s = lo | (hi << 8);
      if (s >= 32768) s -= 65536;
      final a = s < 0 ? -s : s;
      if (a > peak) peak = a;
    }
    final norm = peak / 32768.0;
    if (norm > _inputLevelPeak) {
      _inputLevelPeak = norm;
    } else {
      _inputLevelPeak *= 0.85;
      if (norm > _inputLevelPeak) _inputLevelPeak = norm;
    }
    final now = DateTime.now();
    if (now.difference(_lastInputLevelEmit).inMilliseconds < 33) return;
    _lastInputLevelEmit = now;
    inputLevelNotifier.value = _inputLevelPeak.clamp(0.0, 1.0);
  }

  Future<void> _stopInternal() async {
    _running = false;
    await _disposeWindowsWasapiOnly();
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _recorder?.dispose();
    _recorder = null;
    _pcmAcc.clear();
    _latest = MusicAnalysisSnapshot.silent();
    _inputLevelPeak = 0;
    inputLevelNotifier.value = 0;
    captureInfoNotifier.value = const MusicCaptureInfo.idle();
  }

  Future<void> dispose() async {
    await _stopInternal();
    await _fftBridge?.dispose();
    _fftBridge = null;
    _fftIsolateReady = false;
    _fallbackAnalyzer = null;
    inputLevelNotifier.dispose();
    captureInfoNotifier.dispose();
  }
}
