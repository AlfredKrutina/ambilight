import '../core/models/config_models.dart';
import '../features/pc_health/pc_health_frame.dart';
import '../features/pc_health/pc_health_snapshot.dart';
import '../services/music/music_granular_engine.dart';
import '../services/music/music_types.dart';
import 'fallback_modes.dart';
import 'light_mode_logic.dart';
import 'screen/screen_color_pipeline.dart';
import 'screen/screen_frame.dart';

/// Jeden tick výpočtu barev (bez I/O). Výstup vždy [Map] `deviceId → RGB` jako optimalizovaná cesta u Python screen módu.
class AmbilightEngine {
  AmbilightEngine._();

  /// Součet délek LED všech zařízení — virtuální „strip“ pro light efekty (sekvenční mapování jako dřív `_distribute`).
  static int combinedDeviceLedLength(AppConfig config) {
    final ds = config.globalSettings.devices;
    if (ds.isEmpty) {
      return config.globalSettings.ledCount.clamp(1, 512);
    }
    var s = 0;
    for (final d in ds) {
      s += d.ledCount;
    }
    return s.clamp(1, 4096);
  }

  static Map<String, List<(int, int, int)>> _blackPerDevice(AppConfig config) {
    final m = <String, List<(int, int, int)>>{};
    for (final d in config.globalSettings.devices) {
      m[d.id] = List<(int, int, int)>.filled(d.ledCount, (0, 0, 0), growable: false);
    }
    return m;
  }

  /// Celý výstup zhasnutý po zařízeních (controller / náhledy).
  static Map<String, List<(int, int, int)>> blackoutPerDevice(AppConfig config) =>
      _blackPerDevice(config);

  static Map<String, List<(int, int, int)>> _mapFlatToDevices(
    List<(int, int, int)> flat,
    List<DeviceSettings> devices,
  ) {
    var offset = 0;
    final out = <String, List<(int, int, int)>>{};
    for (final d in devices) {
      out[d.id] = List<(int, int, int)>.generate(
        d.ledCount,
        (i) {
          final idx = offset + i;
          return idx < flat.length ? flat[idx] : (0, 0, 0);
        },
        growable: false,
      );
      offset += d.ledCount;
    }
    return out;
  }

  /// [screenFrame] jen pro `startMode == screen`; jinak ignorováno.
  static Map<String, List<(int, int, int)>> computeFrame(
    AppConfig config,
    int animationTick, {
    required bool startupBlackout,
    required bool enabled,
    ScreenFrame? screenFrame,
    required ScreenPipelineRuntime screenPipeline,
    MusicAnalysisSnapshot? musicSnapshot,
    PcHealthSnapshot pcHealthSnapshot = PcHealthSnapshot.empty,
    /// Sloučená dominantní barva z alba (Spotify API a/nebo OS média) — jen pokud to controller povolí.
    (int, int, int)? musicAlbumDominantRgb,
  }) {
    if (!enabled || startupBlackout) {
      return _blackPerDevice(config);
    }
    final mode = config.globalSettings.startMode;
    switch (mode) {
      case 'light':
        if (config.lightMode.homekitEnabled) {
          return _blackPerDevice(config);
        }
        final n = combinedDeviceLedLength(config);
        final flat = LightModeLogic.compute(
          config,
          animationTick,
          virtualLedCount: n,
        );
        return _mapFlatToDevices(flat, config.globalSettings.devices);
      case 'screen':
        final frame = screenFrame ??
            MockScreenFrame.gradient(
              monitorIndex: config.screenMode.monitorIndex,
              phase: animationTick % 200,
            );
        if (!frame.isValid) {
          return _blackPerDevice(config);
        }
        final raw = ScreenColorPipeline.processFrameToDevices(config, frame, screenPipeline);
        return screenPipeline.applyTemporalSmoothing(
          targets: raw,
          smoothMs: config.screenMode.interpolationMs,
        );
      case 'music':
        final nMusic = combinedDeviceLedLength(config);
        if (musicAlbumDominantRgb != null) {
          final flat =
              List<(int, int, int)>.filled(nMusic, musicAlbumDominantRgb, growable: false);
          return _mapFlatToDevices(flat, config.globalSettings.devices);
        }
        final snap = musicSnapshot ?? MusicAnalysisSnapshot.silent();
        final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
        final musicMonitor =
            config.musicMode.colorSource == 'monitor' ? screenFrame : null;
        final flat = MusicGranularEngine.computeFlatStrip(
          config,
          snap,
          t,
          monitorSample: musicMonitor,
        );
        return _mapFlatToDevices(flat, config.globalSettings.devices);
      case 'pchealth':
        final n = combinedDeviceLedLength(config);
        final flat = PcHealthFrame.compute(
          config,
          pcHealthSnapshot,
          virtualLedCount: n,
        );
        return _mapFlatToDevices(flat, config.globalSettings.devices);
      default:
        return _blackPerDevice(config);
    }
  }
}
