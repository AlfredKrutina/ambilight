import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import 'app_error_safety.dart';
import 'async_failure.dart';
import 'build_environment.dart';
import 'debug_trace.dart';
import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../core/protocol/serial_frame.dart';
import '../data/config_repository.dart';
import '../data/device_transport.dart';
import '../data/serial_device_transport.dart';
import '../data/udp_device_transport.dart';
import '../engine/ambilight_engine.dart';
import '../engine/fallback_modes.dart' show brightnessForMode;
import '../engine/screen/screen_color_pipeline.dart';
import '../engine/screen/screen_frame.dart';
import '../engine/light_pc_engine_isolate.dart';
import '../engine/screen/screen_pipeline_isolate.dart';
import '../features/screen_capture/screen_capture_source.dart';
import '../features/pc_health/pc_health_collector.dart';
import '../features/pc_health/pc_health_smoother.dart';
import '../features/pc_health/pc_health_snapshot.dart';
import '../features/spotify/spotify_service.dart';
import '../features/system_media/system_media_now_playing_service.dart';
import '../features/smart_lights/ha_token_store.dart';
import '../features/smart_lights/smart_light_coordinator.dart';
import '../services/music/music_audio_service.dart';
import '../services/music/music_flat_strip_isolate.dart';
import '../core/ambilight_presets.dart';

final _log = Logger('AmbiController');

Map<String, List<(int, int, int)>> _cloneDeviceRgbMap(Map<String, List<(int, int, int)>> src) {
  final out = <String, List<(int, int, int)>>{};
  for (final e in src.entries) {
    out[e.key] = List<(int, int, int)>.from(e.value);
  }
  return out;
}

class _DistributeArgs {
  _DistributeArgs({
    required this.perDevice,
    required this.brightnessScalar,
    required this.applyWizardOverlay,
    required this.clipToDeviceLedCount,
    required this.smartLightsFrame,
    required this.smartLightsAppEnabled,
  });

  final Map<String, List<(int, int, int)>> perDevice;
  final int brightnessScalar;
  final bool applyWizardOverlay;
  final bool clipToDeviceLedCount;
  final ScreenFrame? smartLightsFrame;
  final bool smartLightsAppEnabled;
}

/// Po odebrání zařízení zůstává v segmentech `device_id` mimo seznam → pád Dropdown v editoru zón a nekonzistence pipeline.
AppConfig stripOrphanScreenSegmentDeviceIds(AppConfig cfg) {
  final ids = {for (final d in cfg.globalSettings.devices) d.id};
  final segs = cfg.screenMode.segments;
  if (segs.isEmpty) return cfg;
  var changed = false;
  final out = <LedSegment>[];
  for (final seg in segs) {
    final id = seg.deviceId;
    if (id != null && id.isNotEmpty && id != 'primary' && !ids.contains(id)) {
      traceStripOrphan(
        id,
        'edge=${seg.edge} led=${seg.ledStart}-${seg.ledEnd} mon=${seg.monitorIdx}',
      );
      out.add(seg.copyWith(nullifyDeviceId: true));
      changed = true;
    } else {
      out.add(seg);
    }
  }
  if (!changed) return cfg;
  return cfg.copyWith(screenMode: cfg.screenMode.copyWith(segments: out));
}

/// Globální stav: konfigurace, transporty, hlavní smyčka (60–240 Hz dle nastavení; při snímání ve výkonu 25 FPS).
///
/// Když je hlavní okno skryté (tray) nebo minimalizované, [syncAmbilightOcclusionFromShell]
/// zapne „boost“ — nevypíná se přeskakování snímku obrazovky ani výkonová fronta sériového portu.
/// Perioda hlavní smyčky — při snímání monitoru ve výkonovém režimu fixně 40 ms (25 FPS); jinak dle [GlobalSettings.screenRefreshRateHz].
class AmbilightAppController extends ChangeNotifier {
  AppConfig _config = AppConfig.defaults();
  /// Po každém úspěšném [applyConfigAndPersist] — pro remount záložek s `TextFormField.initialValue`.
  int _configPersistGeneration = 0;
  /// Poslední JSON odeslaný na disk — [save] přeskočí zápis, pokud se nic nezměnilo (debounce po live apply).
  String? _lastPersistedConfigJson;
  /// Synchronizace s [HaTokenStore] — JSON na disk je vždy bez tokenu.
  String _lastPersistedHaToken = '';
  Timer? _applyDebounceTimer;
  AppConfig? _applyDebouncePending;
  /// Odděleně od [_applyConfigCore] — jen zápis JSON, bez přestavby transportů (snížení smyčky save/reconnect).
  Timer? _persistDiskDebounceTimer;
  /// [_applyConfigLiveOnly] může přijít desítky za snímek při tažení posuvníku — jedna notifikace na frame stačí UI a šetří jank.
  bool _coalescedLiveNotifyScheduled = false;
  /// Fronta — paralelní [applyConfigAndPersist] + debounced [queueConfigApply] by rozbily dispose/bind COM a UDP.
  Future<void> _configApplyTail = Future<void>.value();

  /// Během dispose/connect transportů neposílat snímky (ochrana před závodem s COM/UDP).
  bool _transportsRebuilding = false;
  /// Během [queueConfigApply] / [_applyConfigCore] / live replace — zastaví [_tick], aby se nemíchal
  /// výstup s částečně nahozenou konfigurací (i když `rebuildTransports=false`).
  bool _mainLoopTickHold = false;
  final Map<String, DeviceTransport> _transports = {};
  Timer? _timer;
  /// Samostatný driver snímání obrazovky — nezávislý na délce [_tick] / výpočtech izolátu.
  Timer? _screenCaptureDriverTimer;
  int _captureDriverTick = 0;
  DateTime? _screenPipelineSubmitSince;
  /// Perioda hlavní smyčky (ms); null = timer ještě neběžel.
  int? _loopPeriodMs;
  /// `true` = okno není běžně vidět (minimalizované / schované do tray) → neomezovat výstup performance módem.
  bool _shellOcclusionBoost = false;
  Timer? _shellOcclusionDebounceTimer;
  bool _shellOcclusionPending = false;
  int _animationTick = 0;
  int _debugDistributeSeq = 0;
  bool _startupActive = true;
  int _startupFrame = 0;
  /// Krátká ochrana při startu — dříve ~61 ticků (~2 s černého výstupu / náhledu).
  static const int _startupBlackoutTicks = 6;
  bool _enabled = true;
  final ScreenPipelineRuntime _screenPipeline = ScreenPipelineRuntime();
  ScreenPipelineIsolateBridge? _screenPipelineIsolate;
  Future<void>? _screenIsolateBootFuture;
  /// Zvýší se při [_shutdownScreenPipelineIsolate] — zabrání dokončení zastaralého [_bootScreenPipelineIsolate].
  int _screenIsolateSessionId = 0;
  String? _lastScreenIsolatePushSig;
  String? _lastScreenIsolateTopo;
  int _screenPipelineSubmitSeq = 0;
  int _screenPipelineAppliedSeq = 0;
  /// Poslední seq, na který worker odpověl ([out] nebo [skip]); pro gate fronty (applied roste jen u [out]).
  int _screenPipelineLastAckSeq = 0;
  Map<String, List<(int, int, int)>>? _asyncScreenColors;

  /// Obnova UDP toku na lampě (FW „PC Data Stopped“) — periodický flush posledního platného snímku.
  DateTime? _lastPcStreamUdpKeepaliveSent;
  static const Duration _pcStreamUdpKeepaliveInterval = Duration(milliseconds: 100);

  /// Max. jobů „na cestě“ do izolátu bez odpovědi — `submitSeq - lastAckSeq` musí zůstat ≤ tomuto číslu.
  static const int _isolateQueueDepthMaxPending = 2;

  MusicFlatStripIsolateBridge? _musicFlatIsolate;
  String? _lastMusicFlatIsolatePushSig;
  int _musicFlatSubmitSeq = 0;
  int _musicFlatAppliedSeq = 0;
  int _musicFlatLastAckSeq = 0;
  DateTime? _musicFlatSubmitSince;
  Map<String, List<(int, int, int)>>? _asyncMusicColors;

  LightPcEngineIsolateBridge? _lightPcEngineIsolate;
  String? _lastLightPcIsolatePushSig;
  int _lightPcSubmitSeq = 0;
  int _lightPcAppliedSeq = 0;
  int _lightPcLastAckSeq = 0;
  DateTime? _lightPcSubmitSince;
  Map<String, List<(int, int, int)>>? _asyncLightPcColors;

  _DistributeArgs? _distributePending;
  bool _distributeFlushScheduled = false;
  bool _controllerDisposed = false;

  /// Úzký signál pro náhled snímku (overlay / nastavení) — bez [notifyListeners] na celý controller.
  final ValueNotifier<ScreenFrame?> previewFrameNotifier = ValueNotifier<ScreenFrame?>(null);

  /// Stav připojení zařízení — aktualizuje se jen při změně mapy (ne heartbeat každých N ticků).
  final ValueNotifier<Map<String, bool>> connectionSnapshotNotifier =
      ValueNotifier<Map<String, bool>>(<String, bool>{});

  /// Živé metriky PC Health — jen při změně hodnot (bez [notifyListeners] na celý controller).
  final ValueNotifier<PcHealthSnapshot> pcHealthSnapshotNotifier =
      ValueNotifier<PcHealthSnapshot>(PcHealthSnapshot.empty);

  ScreenCaptureSource? _screenCapture;
  bool _screenCaptureInFlight = false;
  bool _screenCaptureReplayPending = false;
  /// Po řadě výjimek ze snímání — jeden banner, reset při úspěchu.
  int _consecutiveScreenCaptureFailures = 0;
  bool _screenCaptureFaultBannerShown = false;
  /// Fáze 5.4 — při výkonovém throttlingu rozšiřuje krok snímání (max), když předchozí capture ještě běží.
  static const int _captureStrideMin = 3;
  static const int _captureStrideMax = 6;
  int _adaptiveCaptureStrideMod = _captureStrideMin;
  int _captureOverloadStreak = 0;
  int _captureIdleStreak = 0;
  /// Cache připojení transportů — přepočítává se ve smyčce; [notifyListeners] jen při změně (méně janku v UI).
  Map<String, bool> _connectionSnapshotCache = const {};
  DateTime? _lastScreenFrameUiNotify;
  static const Duration _minScreenFrameUiNotifyGap = Duration(milliseconds: 33);
  ScreenFrame? _screenFrameLatest;
  ScreenSessionInfo _captureSessionInfo = ScreenSessionInfo.unknown;
  final MusicAudioService _musicAudio = MusicAudioService();
  int? _pendingShellIndex;
  /// Po přechodu na Nastavení (2) — index záložky v [SettingsPage], vyzvedne ji jen Settings.
  int? _pendingSettingsTabIndex;

  /// Indexy záložek [SettingsPage] — musí odpovídat `tabChild` / `_tabCount` v `settings_page.dart`.
  static const int settingsTabSpotify = 6;
  static const int settingsTabSmartIntegration = 7;
  static const int settingsTabFirmware = 8;
  int _reconnectCounter = 0;
  final SpotifyService spotify = SpotifyService();
  final SystemMediaNowPlayingService systemMediaNowPlaying = SystemMediaNowPlayingService();
  final PcHealthCollector _pcHealthCollector = createPcHealthCollector();
  final PcHealthSmoother _pcHealthSmoother = PcHealthSmoother();
  PcHealthSnapshot _pcHealthSnapshot = PcHealthSnapshot.empty;
  Timer? _pcHealthTimer;

  /// C11 — zmrazí výstup do zařízení v music módu (parita `AppState.music_color_lock` / tray v PyQt).
  bool _musicPaletteLockCapturePending = false;
  Map<String, List<(int, int, int)>>? _musicPaletteFrozenDeviceColors;

  /// Jedna rozsvícená LED během průvodce mapování (`led_wizard.py` / `preview_pixel_override`).
  (String deviceId, int index, int r, int g, int b)? _wizardLedPreview;

  /// Plný pás jednou barvou (`preview_override_color` v `app.py`).
  (int r, int g, int b)? _stripColorPreviewRgb;
  int _stripColorPreviewTicksLeft = 0;

  /// Zelené značky v rozích (`show_calibration_led` v `app.py`). Buffer při výstupu ignoruje
  /// uživatelský `led_count` — max. délka pro transport (USB až [SerialAmbilightProtocol.maxLedsPerDevice], Wi‑Fi dle UDP).
  String? _calibrationCorner;

  /// Po výjimce ve smyčce — tlumená červená jako v Pythonu `[(10,0,0)] * n`.
  int? _tickErrorStripUntilAnimationTick;

  final SmartLightCoordinator _smartLights = SmartLightCoordinator();

  AmbilightAppController();

  void _resetScreenPipelineSmoothing() {
    _screenPipeline.resetSmoothing();
    _screenPipelineIsolate?.resetSmoothing();
  }

  String _screenIsolatePushSig(AppConfig c) {
    final dev =
        c.globalSettings.devices.map((d) => '${d.id}:${d.ledCount}:${d.controlViaHa}').join(';');
    return '$dev|${jsonEncode(c.screenMode.toJson())}';
  }

  Future<void> _ensureScreenPipelineIsolate() async {
    if (_screenPipelineIsolate != null) return;
    if (_screenIsolateBootFuture != null) {
      await _screenIsolateBootFuture!;
      return;
    }
    _screenIsolateBootFuture = _bootScreenPipelineIsolate();
    try {
      await _screenIsolateBootFuture!;
    } finally {
      _screenIsolateBootFuture = null;
    }
  }

  Future<void> _bootScreenPipelineIsolate() async {
    final session = _screenIsolateSessionId;
    final bridge = ScreenPipelineIsolateBridge();
    bridge.onResult = _onScreenPipelineIsolateResult;
    bridge.onSkip = _onScreenPipelineIsolateSkip;
    try {
      await bridge.start();
      if (session != _screenIsolateSessionId) {
        await bridge.dispose();
        return;
      }
      _screenPipelineIsolate = bridge;
      bridge.pushConfig(_config);
      _lastScreenIsolatePushSig = _screenIsolatePushSig(_config);
      _lastScreenIsolateTopo = _screenPipelineTopologySignature(_config);
      if (kDebugMode) {
        _log.fine('screen pipeline isolate started');
      }
    } catch (e, st) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning('screen pipeline isolate unavailable, sync fallback: $e', e, st);
      }
      await bridge.dispose();
    }
  }

  void _onScreenPipelineIsolateResult(ScreenPipelineIsolateResult r) {
    if (r.seq < _screenPipelineAppliedSeq) return;
    _screenPipelineAppliedSeq = r.seq;
    _screenPipelineLastAckSeq = r.seq;
    _screenPipelineSubmitSince = null;
    _asyncScreenColors = unpackDeviceColors(_config, r.packed);
  }

  void _onScreenPipelineIsolateSkip(int seq) {
    if (seq < _screenPipelineAppliedSeq) return;
    if (seq > _screenPipelineLastAckSeq) {
      _screenPipelineLastAckSeq = seq;
    }
    if (seq == _screenPipelineSubmitSeq) {
      _screenPipelineSubmitSince = null;
    }
  }

  void _syncScreenIsolateConfigIfNeeded() {
    final bridge = _screenPipelineIsolate;
    if (bridge == null || !bridge.isReady) return;
    final topo = _screenPipelineTopologySignature(_config);
    if (_lastScreenIsolateTopo != topo) {
      _lastScreenIsolateTopo = topo;
      bridge.resetSmoothing();
    }
    final sig = _screenIsolatePushSig(_config);
    if (_lastScreenIsolatePushSig == sig) return;
    _lastScreenIsolatePushSig = sig;
    bridge.pushConfig(_config);
  }

  void _shutdownScreenPipelineIsolate() {
    _screenIsolateSessionId++;
    _asyncScreenColors = null;
    _screenPipelineAppliedSeq = 0;
    _screenPipelineSubmitSeq = 0;
    _screenPipelineLastAckSeq = 0;
    _screenPipelineSubmitSince = null;
    _lastScreenIsolatePushSig = null;
    _lastScreenIsolateTopo = null;
    final b = _screenPipelineIsolate;
    _screenPipelineIsolate = null;
    if (b != null) {
      unawaited(b.dispose());
    }
  }

  String _musicFlatIsolatePushSig(AppConfig c) {
    final dev =
        c.globalSettings.devices.map((d) => '${d.id}:${d.ledCount}:${d.controlViaHa}').join(';');
    final segJson =
        jsonEncode([for (final s in c.screenMode.segments) s.toJson()]);
    return '$dev|${jsonEncode(c.musicMode.toJson())}|$segJson';
  }

  Future<void> _ensureMusicFlatStripIsolate() async {
    if (_musicFlatIsolate != null) return;
    final bridge = MusicFlatStripIsolateBridge();
    bridge.onResult = _onMusicFlatStripIsolateResult;
    bridge.onSkip = _onMusicFlatStripIsolateSkip;
    try {
      await bridge.start();
      _musicFlatIsolate = bridge;
      bridge.pushConfig(_config);
      _lastMusicFlatIsolatePushSig = _musicFlatIsolatePushSig(_config);
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.fine('music flat strip isolate started');
      }
    } catch (e, st) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning('music flat strip isolate unavailable, sync fallback: $e', e, st);
      }
      await bridge.dispose();
    }
  }

  void _onMusicFlatStripIsolateResult(MusicFlatStripIsolateResult r) {
    if (r.seq < _musicFlatAppliedSeq) return;
    _musicFlatAppliedSeq = r.seq;
    _musicFlatLastAckSeq = r.seq;
    _musicFlatSubmitSince = null;
    _asyncMusicColors = unpackDeviceColors(_config, r.packed);
  }

  void _onMusicFlatStripIsolateSkip(int seq) {
    if (seq < _musicFlatAppliedSeq) return;
    if (seq > _musicFlatLastAckSeq) {
      _musicFlatLastAckSeq = seq;
    }
    if (seq == _musicFlatSubmitSeq) {
      _musicFlatSubmitSince = null;
    }
  }

  void _syncMusicFlatIsolateConfigIfNeeded() {
    final bridge = _musicFlatIsolate;
    if (bridge == null || !bridge.isReady) return;
    final sig = _musicFlatIsolatePushSig(_config);
    if (_lastMusicFlatIsolatePushSig == sig) return;
    _lastMusicFlatIsolatePushSig = sig;
    bridge.pushConfig(_config);
  }

  void _shutdownMusicFlatStripIsolate() {
    _asyncMusicColors = null;
    _musicFlatAppliedSeq = 0;
    _musicFlatSubmitSeq = 0;
    _musicFlatLastAckSeq = 0;
    _musicFlatSubmitSince = null;
    _lastMusicFlatIsolatePushSig = null;
    final b = _musicFlatIsolate;
    _musicFlatIsolate = null;
    if (b != null) {
      unawaited(b.dispose());
    }
  }

  String _lightPcIsolatePushSig(AppConfig c) {
    final dev =
        c.globalSettings.devices.map((d) => '${d.id}:${d.ledCount}:${d.controlViaHa}').join(';');
    return '$dev|${jsonEncode(c.lightMode.toJson())}|${jsonEncode(c.pcHealth.toJson())}|${c.globalSettings.startMode}';
  }

  Future<void> _ensureLightPcEngineIsolate() async {
    if (_lightPcEngineIsolate != null) return;
    final bridge = LightPcEngineIsolateBridge();
    bridge.onResult = _onLightPcEngineIsolateResult;
    bridge.onSkip = _onLightPcEngineIsolateSkip;
    try {
      await bridge.start();
      _lightPcEngineIsolate = bridge;
      bridge.pushConfig(_config);
      _lastLightPcIsolatePushSig = _lightPcIsolatePushSig(_config);
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.fine('light/pc engine isolate started');
      }
    } catch (e, st) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning('light/pc engine isolate unavailable, sync fallback: $e', e, st);
      }
      await bridge.dispose();
    }
  }

  void _onLightPcEngineIsolateResult(LightPcEngineIsolateResult r) {
    if (r.seq < _lightPcAppliedSeq) return;
    _lightPcAppliedSeq = r.seq;
    _lightPcLastAckSeq = r.seq;
    _lightPcSubmitSince = null;
    _asyncLightPcColors = unpackDeviceColors(_config, r.packed);
  }

  void _onLightPcEngineIsolateSkip(int seq) {
    if (seq < _lightPcAppliedSeq) return;
    if (seq > _lightPcLastAckSeq) {
      _lightPcLastAckSeq = seq;
    }
    if (seq == _lightPcSubmitSeq) {
      _lightPcSubmitSince = null;
    }
  }

  void _syncLightPcIsolateConfigIfNeeded() {
    final bridge = _lightPcEngineIsolate;
    if (bridge == null || !bridge.isReady) return;
    final sig = _lightPcIsolatePushSig(_config);
    if (_lastLightPcIsolatePushSig == sig) return;
    _lastLightPcIsolatePushSig = sig;
    bridge.pushConfig(_config);
  }

  void _shutdownLightPcEngineIsolate() {
    _asyncLightPcColors = null;
    _lightPcAppliedSeq = 0;
    _lightPcSubmitSeq = 0;
    _lightPcLastAckSeq = 0;
    _lightPcSubmitSince = null;
    _lastLightPcIsolatePushSig = null;
    final b = _lightPcEngineIsolate;
    _lightPcEngineIsolate = null;
    if (b != null) {
      unawaited(b.dispose());
    }
  }

  Future<void> _submitLightPcEngineJobAsync() async {
    _recoverLightPcEngineIfStuck();
    if (_lightPcSubmitSeq - _lightPcLastAckSeq > _isolateQueueDepthMaxPending) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning(
          'light/pc engine: izolát nestíhá — zahazuji tick (submit=$_lightPcSubmitSeq '
          'lastAck=$_lightPcLastAckSeq)',
        );
      }
      return;
    }
    await _ensureLightPcEngineIsolate();
    final bridge = _lightPcEngineIsolate;
    if (bridge == null || !bridge.isReady) return;
    _syncLightPcIsolateConfigIfNeeded();
    _lightPcSubmitSeq++;
    _lightPcSubmitSince = DateTime.now();
    bridge.submitJob(
      seq: _lightPcSubmitSeq,
      animationTick: _animationTick,
      pcHealthPortable: pcHealthSnapshotToPortableMap(_pcHealthSnapshot),
    );
  }

  Future<void> _submitMusicFlatStripJobAsync(ScreenFrame f) async {
    _recoverMusicFlatStripIfStuck();
    if (_musicFlatSubmitSeq - _musicFlatLastAckSeq > _isolateQueueDepthMaxPending) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning(
          'music flat strip: izolát nestíhá — zahazuji snímek (submit=$_musicFlatSubmitSeq '
          'lastAck=$_musicFlatLastAckSeq)',
        );
      }
      return;
    }
    await _ensureMusicFlatStripIsolate();
    final bridge = _musicFlatIsolate;
    if (bridge == null || !bridge.isReady) return;
    _syncMusicFlatIsolateConfigIfNeeded();
    _musicFlatSubmitSeq++;
    _musicFlatSubmitSince = DateTime.now();
    bridge.submitJob(
      seq: _musicFlatSubmitSeq,
      snapshot: _musicAudio.currentSnapshot,
      timeSec: DateTime.now().millisecondsSinceEpoch / 1000.0,
      width: f.width,
      height: f.height,
      monitorIndex: f.monitorIndex,
      rgba: f.rgba,
    );
  }

  Future<void> _submitScreenPipelineFrameAsync(ScreenFrame f) async {
    _recoverScreenPipelineIfStuck();
    if (_screenPipelineSubmitSeq - _screenPipelineLastAckSeq > _isolateQueueDepthMaxPending) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning(
          'screen pipeline: izolát nestíhá — zahazuji snímek (submit=$_screenPipelineSubmitSeq '
          'lastAck=$_screenPipelineLastAckSeq)',
        );
      }
      return;
    }
    await _ensureScreenPipelineIsolate();
    final bridge = _screenPipelineIsolate;
    if (bridge == null || !bridge.isReady) return;
    _syncScreenIsolateConfigIfNeeded();
    _screenPipelineSubmitSeq++;
    _screenPipelineSubmitSince = DateTime.now();
    bridge.submitFrame(
      seq: _screenPipelineSubmitSeq,
      width: f.width,
      height: f.height,
      monitorIndex: f.monitorIndex,
      rgba: f.rgba,
    );
  }

  @override
  void notifyListeners() {
    try {
      super.notifyListeners();
    } catch (e, st) {
      _log.warning('notifyListeners: $e', e, st);
    }
  }

  (int, int, int)? _musicAlbumArtDominantRgb() {
    final sp = _config.spotify;
    if (sp.enabled && sp.useAlbumColors && spotify.dominantRgb != null) {
      return spotify.dominantRgb;
    }
    final sm = _config.systemMediaAlbum;
    if (sm.enabled && sm.useAlbumColors && systemMediaNowPlaying.dominantRgb != null) {
      return systemMediaNowPlaying.dominantRgb;
    }
    return null;
  }

  /// Po [applyConfigAndPersist] / [load] — např. autostart.
  Future<void> Function()? onAfterConfigApplied;

  /// Volá desktop shell (`window_manager`): tray / minimalizace → výstup bez throttlingu výkonového režimu.
  /// Debounce omezuje kolísání `isVisible()` / poll, které jinak přepínalo timer a ničilo capture.
  void syncAmbilightOcclusionFromShell({required bool occluded}) {
    _shellOcclusionPending = occluded;
    _shellOcclusionDebounceTimer?.cancel();
    _shellOcclusionDebounceTimer = Timer(const Duration(milliseconds: 320), () {
      _shellOcclusionDebounceTimer = null;
      _applyShellOcclusionBoost(_shellOcclusionPending);
    });
  }

  void _applyShellOcclusionBoost(bool boost) {
    if (_shellOcclusionBoost == boost) return;
    _shellOcclusionBoost = boost;
    if (kDebugMode) {
      _log.info(
        boost
            ? 'Shell: okno skryté/minimalizované → výstup bez omezení výkonového režimu (snímání + fronta)'
            : 'Shell: okno viditelné → výkon dle nastavení uživatele',
      );
    }
    _ensureMainLoopTimer();
    _syncPerformanceModeOnTransports();
    _restartPcHealthTimer();
    notifyListeners();
  }

  /// `performanceMode` z nastavení platí pro UI/jank; při [_shellOcclusionBoost] se výstup na LED neškrtí.
  bool get _effectiveThrottlePerformance =>
      _config.globalSettings.performanceMode && !_shellOcclusionBoost;

  AppConfig get config => _config;
  int get configPersistGeneration => _configPersistGeneration;
  /// Poslední platný snímek pro screen režim (náhled v nastavení / overlay).
  ScreenFrame? get latestScreenFrame => _screenFrameLatest;

  /// Poslední vyhlazené metriky pro PC Health (náhled v nastavení).
  PcHealthSnapshot get pcHealthSnapshot => _pcHealthSnapshot;

  /// Jednorázový sběr (náhled v nastavení i mimo režim PC Health).
  Future<PcHealthSnapshot> collectPcHealthNow() => _pcHealthCollector.collect();

  /// Nativní popis prostředí (Linux X11/Wayland, macOS backend, …).
  ScreenSessionInfo get captureSessionInfo => _captureSessionInfo;
  bool get enabled => _enabled;
  bool get startupActive => _startupActive;

  /// Paleta zamčená a posílá se poslední zmrazený snímek.
  bool get musicPaletteLocked => _musicPaletteFrozenDeviceColors != null;

  /// Uživatel požádal o zamčení; čeká na další tick s platným výstupem.
  bool get musicPaletteLockCapturePending => _musicPaletteLockCapturePending;
  int get animationTick => _animationTick;
  Map<String, bool> get connectionSnapshot =>
      Map<String, bool>.unmodifiable(_connectionSnapshotCache);

  bool _syncConnectionSnapshotCache() {
    final m = <String, bool>{};
    try {
      final entries = List<MapEntry<String, DeviceTransport>>.from(_transports.entries);
      for (final e in entries) {
        try {
          m[e.key] = e.value.isConnected;
        } catch (err, st) {
          if (kDebugMode) {
            traceDeviceBindingsWarning('connectionSnapshot isConnected ${e.key}: $err', err, st);
          }
          m[e.key] = false;
        }
      }
    } catch (e, st) {
      traceDeviceBindingsWarning('connectionSnapshot iteration', e, st);
    }
    if (mapEquals(_connectionSnapshotCache, m)) return false;
    _connectionSnapshotCache = m;
    connectionSnapshotNotifier.value = Map<String, bool>.from(m);
    return true;
  }

  /// `true` když je potřeba znovu vytvořit transporty (COM/UDP) — ne stačí [queueConfigApply].
  ///
  /// Změna jen [DeviceSettings.name] nebo [DeviceSettings.ledCount] vrací `false` (aby každý
  /// znak v poli „Počet LED“ nespouštěl dispose sériového portu na Windows).
  static bool devicesChangeRequiresTransportRebuild(
    List<DeviceSettings> prev,
    List<DeviceSettings> next,
  ) {
    if (prev.length != next.length) return true;
    final prevById = {for (final d in prev) d.id: d};
    for (final n in next) {
      final p = prevById[n.id];
      if (p == null) return true;
      if (p.type != n.type ||
          p.port.trim() != n.port.trim() ||
          p.ipAddress.trim() != n.ipAddress.trim() ||
          p.udpPort != n.udpPort ||
          p.controlViaHa != n.controlViaHa) {
        return true;
      }
    }
    for (final p in prev) {
      if (!next.any((n) => n.id == p.id)) return true;
    }
    return false;
  }

  /// Stejné vazby na hardware jako u existujících transportů → není nutné znovu otevírat COM/UDP.
  ///
  /// [GlobalSettings.performanceMode] záměrně **není** zahrnuto — přepnutí výkonu nesmí dělat
  /// dispose/reconnect sériového portu (na Windows často heap assert v nativní knihovně).
  static bool _transportsBindingUnchanged(AppConfig prev, AppConfig next) {
    if (prev.globalSettings.baudRate != next.globalSettings.baudRate) return false;
    final pm = {for (final d in prev.globalSettings.devices) d.id: d};
    final nm = {for (final d in next.globalSettings.devices) d.id: d};
    if (pm.length != nm.length) return false;
    for (final id in nm.keys) {
      final a = pm[id];
      final b = nm[id];
      if (a == null || b == null) return false;
      if (a.type != b.type ||
          a.port.trim() != b.port.trim() ||
          a.ipAddress.trim() != b.ipAddress.trim() ||
          a.udpPort != b.udpPort ||
          a.controlViaHa != b.controlViaHa) {
        return false;
      }
    }
    return true;
  }

  void _syncTransportDeviceSnapshots() {
    for (final e in _transports.entries) {
      final id = e.key;
      for (final d in _config.globalSettings.devices) {
        if (d.id == id) {
          e.value.syncDeviceSnapshot(d);
          break;
        }
      }
    }
  }

  void _syncSerialStripAnnouncements(AppConfig prev, AppConfig next) {
    for (final d in next.globalSettings.devices) {
      if (d.type != 'serial' || d.controlViaHa) continue;
      DeviceSettings? od;
      for (final x in prev.globalSettings.devices) {
        if (x.id == d.id) {
          od = x;
          break;
        }
      }
      if (od != null && od.ledCount == d.ledCount) continue;
      _transports[d.id]?.announceLogicalStripLength(
        d.ledCount.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice),
      );
    }
  }

  void _syncPerformanceModeOnTransports() {
    final perf = _effectiveThrottlePerformance;
    for (final t in _transports.values) {
      t.applyPerformanceMode(perf);
    }
  }

  /// Změna zařízení / segmentů obrazovky → reset EMA ve [ScreenPipelineRuntime] (jinak zbylé délky / mapování).
  static String _screenPipelineTopologySignature(AppConfig c) {
    final devBits = c.globalSettings.devices
        .map(
          (e) =>
              '${e.id}\t${e.type}\t${e.ledCount}\t${e.controlViaHa}\t${e.port}\t${e.ipAddress}\t${e.udpPort}',
        )
        .toList()
      ..sort();
    final segBits = c.screenMode.segments
        .map((s) => '${s.deviceId}:${s.ledStart}-${s.ledEnd}:${s.monitorIdx}:${s.edge}')
        .join('|');
    return '${devBits.join(';')}|$segBits';
  }

  void _pruneWizardLedPreviewForConfig(AppConfig c) {
    final w = _wizardLedPreview;
    if (w == null) return;
    DeviceSettings? dev;
    for (final x in c.globalSettings.devices) {
      if (x.id == w.$1) {
        dev = x;
        break;
      }
    }
    if (dev == null ||
        w.$2 < 0 ||
        w.$2 >= SerialAmbilightProtocol.maxLedsPerDevice) {
      _wizardLedPreview = null;
    }
  }

  static bool _autostartChanged(AppConfig prev, AppConfig next) {
    return prev.globalSettings.autostart != next.globalSettings.autostart;
  }

  static List<String> serialPorts() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      _log.fine('serialPorts: $e');
      return [];
    }
  }

  Future<void> load() async {
    _transportsRebuilding = true;
    try {
      final loaded = await ConfigRepository.loadDetailed();
      _config = stripOrphanScreenSegmentDeviceIds(loaded.config);
      logEspTransportBindingWarnings(_config);
      if (loaded.discardedUnreadableJson) {
        reportAppFault(
          'Konfigurační soubor je poškozený nebo nekompatibilní — používám výchozí nastavení. '
          'Obnov zálohu v části Import / export.',
        );
      }
      final haFromFile = await HaTokenStore.read();
      if (haFromFile != null && haFromFile.isNotEmpty) {
        _config = _config.copyWith(
          smartLights: _config.smartLights.copyWith(haLongLivedToken: haFromFile),
        );
      }
      _lastPersistedHaToken = _config.smartLights.haLongLivedToken.trim();
      _lastPersistedConfigJson = _config.sanitizedForPersistence().toJsonString();
      _pruneWizardLedPreviewForConfig(_config);
      await spotify.hydrateFromStorage(_config);
      spotify.startPollingIfNeeded(_config);
      systemMediaNowPlaying.startPollingIfNeeded(_config);
      await _rebuildTransports();
      _resetScreenPipelineSmoothing();
      await _musicAudio.syncWithConfig(_config);
      _restartPcHealthTimer();
      _configPersistGeneration++;
      notifyListeners();
      unawaited(refreshCaptureSessionInfo());
      _clearTransientLedOutputs();
      if (_timer != null) {
        _ensureMainLoopTimer();
      }
      await onAfterConfigApplied?.call();
    } catch (e, st) {
      _log.warning('load: $e', e, st);
      _lastPersistedConfigJson = null;
      _lastPersistedHaToken = '';
      notifyListeners();
    } finally {
      _transportsRebuilding = false;
    }
  }

  /// Načte `sessionInfo` z nativního kanálu (diagnostika Linux/macOS/Windows).
  Future<void> refreshCaptureSessionInfo() async {
    try {
      _ensureScreenCapture();
      if (_screenCapture == null) {
        _captureSessionInfo = ScreenSessionInfo.unknown;
        notifyListeners();
        return;
      }
      _captureSessionInfo = await _screenCapture!.getSessionInfo();
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) _log.fine('refreshCaptureSessionInfo: $e', e, st);
      _captureSessionInfo = ScreenSessionInfo.unknown;
      notifyListeners();
    }
  }

  /// macOS: TCC dialog pro nahrávání obrazovky; ostatní OS typicky no-op.
  Future<bool> requestOsScreenCapturePermission() async {
    try {
      _ensureScreenCapture();
      if (_screenCapture == null) return false;
      final ok = await _screenCapture!.requestScreenCapturePermission();
      await refreshCaptureSessionInfo();
      return ok;
    } catch (e, st) {
      if (kDebugMode) _log.fine('requestOsScreenCapturePermission: $e', e, st);
      return false;
    }
  }

  /// Vrátí `true`, pokud proběhl skutečný zápis na disk (jinak byl obsah stejný jako u posledního uložení).
  Future<bool> save() async {
    try {
      final sanitizedJson = _config.sanitizedForPersistence().toJsonString();
      final haTok = _config.smartLights.haLongLivedToken.trim();
      var wrote = false;
      if (haTok != _lastPersistedHaToken) {
        await HaTokenStore.write(haTok);
        _lastPersistedHaToken = haTok;
        wrote = true;
      }
      if (sanitizedJson != _lastPersistedConfigJson) {
        await ConfigRepository.save(_config);
        _lastPersistedConfigJson = sanitizedJson;
        wrote = true;
      }
      if (!wrote && kDebugMode) {
        _log.fine('save: skipped (JSON i HA token beze změny)');
      }
      return wrote;
    } catch (e, st) {
      _log.warning('save: $e', e, st);
      reportAppFault('Uložení konfigurace selhalo: ${e.toString().split('\n').first}');
      return false;
    }
  }

  void setEnabled(bool v) {
    _enabled = v;
    if (!v) _clearTransientLedOutputs();
    _restartPcHealthTimer();
    notifyListeners();
  }

  /// Přepnutí výstupu (stejné chování jako přepínač na přehledu / tray „Zap/Vyp“).
  void toggleEnabled() {
    _enabled = !_enabled;
    if (!_enabled) _clearTransientLedOutputs();
    _restartPcHealthTimer();
    notifyListeners();
  }

  /// Jednorázově požádá shell o přepnutí na stránku [index] v [AmbiShell] (např. 2 = Nastavení).
  int? takePendingShellIndex() {
    final v = _pendingShellIndex;
    _pendingShellIndex = null;
    return v;
  }

  /// Index záložky v Nastavení (0 = Globální, 1 = Zařízení, 2 = Světlo, …). Volá [SettingsPage] při startu.
  int? takePendingSettingsTabIndex() {
    final v = _pendingSettingsTabIndex;
    _pendingSettingsTabIndex = null;
    return v;
  }

  /// Tray / systémová nabídka — jen stránka Nastavení, výchozí záložka uživatele.
  void requestOpenSettingsTab() {
    _pendingShellIndex = 2;
    _pendingSettingsTabIndex = null;
    notifyListeners();
  }

  /// Otevře stránku Nastavení na konkrétní záložce (např. z přehledu Integrace).
  void requestOpenSettingsTabIndex(int tabIndex) {
    _pendingShellIndex = 2;
    _pendingSettingsTabIndex = tabIndex.clamp(0, settingsTabFirmware);
    notifyListeners();
  }

  /// Z přehledu: Nastavení + záložka odpovídající `start_mode` (`light` / `screen` / `music` / `pchealth`).
  void requestOpenSettingsForStartMode(String startModeId) {
    _pendingShellIndex = 2;
    _pendingSettingsTabIndex = switch (startModeId) {
      'light' => 2,
      'screen' => 3,
      'music' => 4,
      'pchealth' => 5,
      _ => null,
    };
    notifyListeners();
  }

  /// Index záložky Nastavení pro [startModeId] (bez změny stavu).
  static int? settingsTabIndexForStartMode(String startModeId) => switch (startModeId) {
        'light' => 2,
        'screen' => 3,
        'music' => 4,
        'pchealth' => 5,
        _ => null,
      };

  /// Náhled jedné LED na pásku (zelená apod.). Záporný [index] nebo prázdný [deviceId] vypne náhled.
  void setWizardLedPreview(String? deviceId, int index, int r, int g, int b) {
    if (deviceId == null || deviceId.isEmpty || index < 0) {
      _wizardLedPreview = null;
    } else {
      _wizardLedPreview = (deviceId, index, r, g, b);
    }
  }

  /// USB ESP: odešle logický počet LED (`0xA5 0x5A` + count) — zavolej před mapováním / po změně délky v nastavení.
  void announceStripLengthForDevice(String deviceId) {
    final t = _transports[deviceId];
    if (t == null) return;
    for (final d in _config.globalSettings.devices) {
      if (d.id == deviceId) {
        t.announceLogicalStripLength(
          d.ledCount.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice),
        );
        return;
      }
    }
  }

  void _clearTransientLedOutputs() {
    _stripColorPreviewRgb = null;
    _stripColorPreviewTicksLeft = 0;
    _calibrationCorner = null;
    _wizardLedPreview = null;
  }

  /// Náhled celého pásku barvou z nastavení (PyQt `preview_color` / `preview_override_color`).
  /// [durationTicks] — počet snímků smyčky (~33 ms), výchozí ~3 s.
  void previewStripColor(int r, int g, int b, {int durationTicks = 90}) {
    _stripColorPreviewRgb = (r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    _stripColorPreviewTicksLeft = durationTicks.clamp(1, 6000);
    notifyListeners();
  }

  void clearStripColorPreview() {
    _stripColorPreviewRgb = null;
    _stripColorPreviewTicksLeft = 0;
    notifyListeners();
  }

  /// Rohové značky pro kalibraci (`show_calibration_led`). [corner] `null` nebo `'off'` vypne.
  void setCalibrationLedMarkers(String? corner) {
    if (corner == null || corner == 'off') {
      _calibrationCorner = null;
    } else {
      _calibrationCorner = corner;
    }
    notifyListeners();
  }

  /// JSON konfigurace pro zálohu / import (bez zápisu na disk).
  String exportConfigJsonString() => _config.sanitizedForPersistence().toJsonString();

  /// Načte konfiguraci z JSON řetězce a uloží (jako uložení z nastavení).
  Future<void> importConfigFromJsonString(String json) async {
    late final AppConfig next;
    try {
      next = AppConfig.parse(json);
    } catch (e, st) {
      _log.warning('importConfig parse: $e', e, st);
      reportAppFault('Neplatný JSON konfigurace: ${e.toString().split('\n').first}');
      rethrow;
    }
    await applyConfigAndPersist(next);
  }

  /// Rychlé screen presety (viz Python `SCREEN_PRESETS`).
  Future<void> applyQuickScreenPreset(String name) async {
    final patch = AmbilightPresets.screenPatch(name);
    if (patch == null) return;
    final gs = _config.globalSettings.startMode != 'screen'
        ? _config.globalSettings.copyWith(startMode: 'screen')
        : _config.globalSettings;
    _config = _config.copyWith(
      globalSettings: gs,
      screenMode: _config.screenMode.withQuickTuning(
        saturationBoost: patch.saturationBoost,
        minBrightness: patch.minBrightness,
        interpolationMs: patch.interpolationMs,
        gamma: patch.gamma,
        activePreset: patch.activePresetLabel,
      ),
    );
    _resetScreenPipelineSmoothing();
    notifyListeners();
    await save();
    await _musicAudio.syncWithConfig(_config);
  }

  /// Rychlé music presety (viz Python `MUSIC_PRESETS`).
  Future<void> applyQuickMusicPreset(String name) async {
    final patch = AmbilightPresets.musicPatch(name);
    if (patch == null) return;
    final nextGs =
        _config.globalSettings.startMode != 'music' ? _config.globalSettings.copyWith(startMode: 'music') : _config.globalSettings;
    _config = _config.copyWith(
      globalSettings: nextGs,
      musicMode: _config.musicMode.withBandSensitivity(
        bass: patch.bass,
        mid: patch.mid,
        high: patch.high,
        activePreset: patch.activePresetLabel,
      ),
    );
    notifyListeners();
    await save();
    await _musicAudio.syncWithConfig(_config);
  }

  /// C11 — tray / přehled: první stisk požádá o zmražení při dalším snímku, druhý uvolní.
  void toggleMusicPaletteLock() {
    if (_musicPaletteFrozenDeviceColors != null) {
      _musicPaletteFrozenDeviceColors = null;
      _musicPaletteLockCapturePending = false;
    } else if (_musicPaletteLockCapturePending) {
      _musicPaletteLockCapturePending = false;
    } else {
      _musicPaletteLockCapturePending = true;
    }
    notifyListeners();
  }

  void _clearMusicPaletteLockOutsideMusicMode(String mode) {
    if (mode != 'music') {
      _musicPaletteFrozenDeviceColors = null;
      _musicPaletteLockCapturePending = false;
    }
  }

  Future<void> setStartMode(String mode) async {
    final normalized = normalizeAmbilightStartMode(mode);
    final prev = _config.globalSettings.startMode;
    _config = _config.copyWith(
      globalSettings: _config.globalSettings.copyWith(startMode: normalized),
    );
    _clearMusicPaletteLockOutsideMusicMode(mode);
    if (prev == 'screen' && mode != 'screen') {
      _resetScreenPipelineSmoothing();
      _screenFrameLatest = null;
      previewFrameNotifier.value = null;
      _shutdownScreenPipelineIsolate();
    }
    if (prev == 'pchealth' && mode != 'pchealth') {
      _pcHealthSmoother.reset();
    }
    unawaited(_musicAudio.syncWithConfig(_config));
    _restartPcHealthTimer();
    if (_timer != null) {
      _ensureMainLoopTimer();
    }
    spotify.startPollingIfNeeded(_config);
    systemMediaNowPlaying.startPollingIfNeeded(_config);
    notifyListeners();
    await save();
  }

  void replaceConfig(AppConfig next) {
    _mainLoopTickHold = true;
    try {
      _clearTransientLedOutputs();
      _config = stripOrphanScreenSegmentDeviceIds(next);
      _lastPersistedConfigJson = null;
      _lastPersistedHaToken = _config.smartLights.haLongLivedToken.trim();
      _clearMusicPaletteLockOutsideMusicMode(_config.globalSettings.startMode);
      unawaited(_musicAudio.syncWithConfig(_config));
      _restartPcHealthTimer();
      spotify.startPollingIfNeeded(_config);
      systemMediaNowPlaying.startPollingIfNeeded(_config);
      _configPersistGeneration++;
      notifyListeners();
    } finally {
      _mainLoopTickHold = false;
      if (_timer != null) {
        _ensureMainLoopTimer();
      }
    }
  }

  Future<void> applyConfigAndPersist(AppConfig next) {
    traceDeviceBindings('applyConfigAndPersist: vstup (řetěz serializovaných apply)');
    traceConfigBindings('applyConfigAndPersist PŘED (aktuální _config)', _config);
    traceConfigBindings('applyConfigAndPersist POŽADAVEK (next)', next);
    _persistDiskDebounceTimer?.cancel();
    _persistDiskDebounceTimer = null;
    _applyDebounceTimer?.cancel();
    _applyDebounceTimer = null;
    _applyDebouncePending = null;
    return _runConfigApplySerialized(
      () => _applyConfigCore(
        next,
        rebuildTransports: true,
        clearTransient: true,
        runAfterConfigHook: true,
      ),
    );
  }

  Future<void> _runConfigApplySerialized(Future<void> Function() body) {
    final run = _configApplyTail.then((_) => body());
    _configApplyTail = run.catchError((Object e, StackTrace st) {
      traceDeviceBindingsSevere('config apply chain (serialized): výjimka', e, st);
      _log.warning('config apply chain: $e', e, st);
    });
    return run;
  }

  Future<void> _applyConfigCore(
    AppConfig next, {
    required bool rebuildTransports,
    required bool clearTransient,
    required bool runAfterConfigHook,
    bool persistToDisk = true,
  }) async {
    final prev = _config;
    // Držet [_tick] jen během přestavby COM/UDP — zápis JSON na disk nesmí sekát výstup na pásek.
    if (rebuildTransports) {
      _transportsRebuilding = true;
      _mainLoopTickHold = true;
    }
    try {
      traceDeviceBindings(
        '_applyConfigCore: start rebuildTransports=$rebuildTransports clearTransient=$clearTransient '
        '(transportBarrier=${rebuildTransports ? "ON" : "off"})',
      );
      if (clearTransient) _clearTransientLedOutputs();
      _config = stripOrphanScreenSegmentDeviceIds(next);
      traceConfigBindings('_applyConfigCore: po stripOrphan', _config);
      logEspTransportBindingWarnings(_config);
      _clearMusicPaletteLockOutsideMusicMode(_config.globalSettings.startMode);
      await _musicAudio.syncWithConfig(_config);
      if (rebuildTransports) {
        traceDeviceBindings('_applyConfigCore: začínám _rebuildTransports()');
        await _rebuildTransports();
        traceDeviceBindings(
          '_applyConfigCore: _rebuildTransports dokončeno, transporty=${_transports.keys.join(",")}',
        );
      } else {
        _syncTransportDeviceSnapshots();
        _syncSerialStripAnnouncements(prev, _config);
        _syncPerformanceModeOnTransports();
      }
    } catch (e, st) {
      traceDeviceBindingsSevere('_applyConfigCore: CHYBA (transport)', e, st);
      _log.warning('applyConfigCore: $e', e, st);
      reportAppFault('Nastavení se nepodařilo aplikovat: ${e.toString().split('\n').first}');
      notifyListeners();
      return;
    } finally {
      if (rebuildTransports) {
        _transportsRebuilding = false;
        traceDeviceBindings('_applyConfigCore: transportBarrier OFF');
      }
      _mainLoopTickHold = false;
    }

    try {
      _pruneWizardLedPreviewForConfig(_config);
      final topologyChanged =
          _screenPipelineTopologySignature(prev) != _screenPipelineTopologySignature(_config);
      if (rebuildTransports || topologyChanged) {
        _resetScreenPipelineSmoothing();
      }
      final wrote = persistToDisk ? await save() : false;
      _restartPcHealthTimer();
      spotify.startPollingIfNeeded(_config);
      systemMediaNowPlaying.startPollingIfNeeded(_config);
      if ((persistToDisk && wrote) || rebuildTransports || topologyChanged) {
        _configPersistGeneration++;
      }
      notifyListeners();
      _ensureMainLoopTimer();
      if (runAfterConfigHook) {
        await onAfterConfigApplied?.call();
      }
      traceConfigBindings('_applyConfigCore: HOTOVO (úspěch)', _config);
    } catch (e, st) {
      traceDeviceBindingsSevere('_applyConfigCore: CHYBA (persist)', e, st);
      _log.warning('applyConfigCore persist: $e', e, st);
      reportAppFault('Uložení nastavení selhalo: ${e.toString().split('\n').first}');
      notifyListeners();
    }
  }

  /// Okamžitě promítne [next] do [_config] a výstupní smyčky (pokud nejde o COM/IP/autostart hook),
  /// disk se uloží až po krátké prodlevě klidu (~85 ms mimo výkonový režim) — bez sekání výstupu.
  ///
  /// Na rozdíl od [applyConfigAndPersist] po debounci znovu neotevírá sériový port / UDP, pokud
  /// se nezměnily vazby zařízení.
  bool _canApplyConfigLive(AppConfig next) {
    return _transportsBindingUnchanged(_config, next) && !_autostartChanged(_config, next);
  }

  void _applyConfigLiveOnly(AppConfig next) {
    final prev = _config;
    try {
      _config = stripOrphanScreenSegmentDeviceIds(next);
      _clearMusicPaletteLockOutsideMusicMode(_config.globalSettings.startMode);
      if (_screenPipelineTopologySignature(prev) != _screenPipelineTopologySignature(_config)) {
        _resetScreenPipelineSmoothing();
      }
      _pruneWizardLedPreviewForConfig(_config);
      unawaited(_musicAudio.syncWithConfig(_config));
      _restartPcHealthTimer();
      _syncTransportDeviceSnapshots();
      _syncSerialStripAnnouncements(prev, _config);
      _syncPerformanceModeOnTransports();
      _scheduleCoalescedLiveNotify();
      _ensureMainLoopTimer();
    } catch (e, st) {
      _log.fine('applyConfigLiveOnly: $e', e, st);
    }
  }

  void _scheduleCoalescedLiveNotify() {
    if (_coalescedLiveNotifyScheduled) return;
    _coalescedLiveNotifyScheduled = true;
    scheduleMicrotask(() {
      _coalescedLiveNotifyScheduled = false;
      notifyListeners();
    });
  }

  void queueConfigApply(AppConfig next) {
    final prevD = formatDeviceBindingsList(_config.globalSettings.devices);
    final nextD = formatDeviceBindingsList(next.globalSettings.devices);
    final bindingsChanged = !_transportsBindingUnchanged(_config, next);
    if (prevD != nextD || bindingsChanged) {
      traceDeviceBindings(
        'queueConfigApply: seznamZměněn=${prevD != nextD} vazbyZměněny=$bindingsChanged '
        'canApplyLive=${_canApplyConfigLive(next)}',
      );
      traceConfigBindings('queueConfigApply PŘED', _config);
      traceConfigBindings('queueConfigApply NEXT', next);
    }
    _applyDebouncePending = next;
    if (_canApplyConfigLive(next)) {
      _applyConfigLiveOnly(next);
    }
    _applyDebounceTimer?.cancel();
    final debounceMs = next.globalSettings.performanceMode ? 260 : 85;
    _applyDebounceTimer = Timer(Duration(milliseconds: debounceMs), () async {
      final p = _applyDebouncePending;
      _applyDebouncePending = null;
      _applyDebounceTimer = null;
      if (p == null) return;
      try {
        final prev = _config;
        final sameBindings = _transportsBindingUnchanged(prev, p);
        final autostartDirty = _autostartChanged(prev, p);
        if (kDebugMode || ambilightVerboseLogsEnabled) {
          _log.fine(
            '[staging] debounced config: sameBindings=$sameBindings autostartChanged=$autostartDirty',
          );
        }
        await _runConfigApplySerialized(
          () async {
            await _applyConfigCore(
              p,
              rebuildTransports: !sameBindings,
              clearTransient: false,
              runAfterConfigHook: autostartDirty,
              persistToDisk: false,
            );
            _scheduleCoalescedDiskPersist();
          },
        );
      } catch (e, st) {
        traceDeviceBindingsSevere('queueConfigApply debounced timer: selhalo', e, st);
        _log.warning('debounced apply failed: $e', e, st);
        reportAppFault('Automatické uložení nastavení selhalo: ${e.toString().split('\n').first}');
      }
    });
  }

  /// Jen zápis profilu na disk — bez transportů a bez vázání na engine tick / izoláty.
  void _scheduleCoalescedDiskPersist() {
    if (_controllerDisposed) return;
    _persistDiskDebounceTimer?.cancel();
    _persistDiskDebounceTimer = Timer(const Duration(milliseconds: 2000), () async {
      _persistDiskDebounceTimer = null;
      if (_controllerDisposed) return;
      try {
        final wrote = await save();
        if (wrote) {
          _configPersistGeneration++;
          notifyListeners();
        }
      } catch (e, st) {
        _log.warning('coalesced disk persist: $e', e, st);
      }
    });
  }

  /// Když nepřijde ACK z workeru (kanál / pád), neblokovat další snímky navěky.
  void _recoverScreenPipelineIfStuck() {
    if (_screenPipelineSubmitSeq <= _screenPipelineAppliedSeq) {
      _screenPipelineSubmitSince = null;
      return;
    }
    final t = _screenPipelineSubmitSince;
    if (t == null) return;
    if (DateTime.now().difference(t) > const Duration(milliseconds: 900)) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning(
          'screen pipeline ACK timeout — unlocking (submit=$_screenPipelineSubmitSeq '
          'applied=$_screenPipelineAppliedSeq)',
        );
      }
      // Nezvedat applied na submit — opožděný „out“ se stejným seq by se pak zahodil.
      _screenPipelineSubmitSince = null;
    }
  }

  /// Analogicky k [_recoverScreenPipelineIfStuck]: timeout bez ACK uvolní jen čekání, bez úpravy applied seq.
  void _recoverMusicFlatStripIfStuck() {
    if (_musicFlatSubmitSeq <= _musicFlatAppliedSeq) {
      _musicFlatSubmitSince = null;
      return;
    }
    final t = _musicFlatSubmitSince;
    if (t == null) return;
    if (DateTime.now().difference(t) > const Duration(milliseconds: 900)) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning(
          'music flat strip ACK timeout — unlocking (submit=$_musicFlatSubmitSeq '
          'applied=$_musicFlatAppliedSeq)',
        );
      }
      _musicFlatSubmitSince = null;
    }
  }

  /// Jako [_recoverScreenPipelineIfStuck] / [_recoverMusicFlatStripIfStuck].
  void _recoverLightPcEngineIfStuck() {
    if (_lightPcSubmitSeq <= _lightPcAppliedSeq) {
      _lightPcSubmitSince = null;
      return;
    }
    final t = _lightPcSubmitSince;
    if (t == null) return;
    if (DateTime.now().difference(t) > const Duration(milliseconds: 900)) {
      if (kDebugMode || ambilightVerboseLogsEnabled) {
        _log.warning(
          'light/pc engine ACK timeout — unlocking (submit=$_lightPcSubmitSeq '
          'applied=$_lightPcAppliedSeq)',
        );
      }
      _lightPcSubmitSince = null;
    }
  }

  bool _hasWifiAmbilightStripDevice() {
    for (final d in _config.globalSettings.devices) {
      if (d.controlViaHa) continue;
      if (d.type == 'wifi' && d.ipAddress.isNotEmpty) return true;
    }
    return false;
  }

  void _restartPcHealthTimer() {
    _pcHealthTimer?.cancel();
    _pcHealthTimer = null;
    if (!_enabled || _config.globalSettings.startMode != 'pchealth' || !_config.pcHealth.enabled) {
      return;
    }
    var ms = _config.pcHealth.updateRate.clamp(200, 10000);
    if (_effectiveThrottlePerformance && ms < 800) {
      ms = 800;
    }
    Future<void> tick() async {
      try {
        final prev = _pcHealthSnapshot;
        final raw = await _pcHealthCollector.collect();
        final next = _pcHealthSmoother.apply(raw).finiteSanitized;
        if (next != prev) {
          _pcHealthSnapshot = next;
          pcHealthSnapshotNotifier.value = next;
        }
      } catch (e, st) {
        if (kDebugMode) _log.fine('pc health: $e', e, st);
      }
    }

    pcHealthSnapshotNotifier.value = _pcHealthSnapshot;
    unawaited(tick());
    _pcHealthTimer = Timer.periodic(Duration(milliseconds: ms), (_) => tick());
  }

  Future<void> spotifyConnect() async {
    try {
      await spotify.connectPkce(_config);
      if (spotify.isConnected) {
        _config = _config.copyWith(spotify: _config.spotify.copyWith(enabled: true));
        await save();
        spotify.startPollingIfNeeded(_config);
        systemMediaNowPlaying.startPollingIfNeeded(_config);
      }
      notifyListeners();
    } catch (e, st) {
      _log.warning('spotifyConnect: $e', e, st);
      notifyListeners();
    }
  }

  Future<void> spotifyDisconnect() async {
    try {
      await spotify.disconnect();
      _config = _config.copyWith(spotify: _config.spotify.copyWith(enabled: false));
      await save();
      spotify.stopPolling();
      systemMediaNowPlaying.startPollingIfNeeded(_config);
      notifyListeners();
    } catch (e, st) {
      _log.warning('spotifyDisconnect: $e', e, st);
      notifyListeners();
    }
  }

  Future<void> setSpotifyUseAlbumColors(bool v) async {
    try {
      _config = _config.copyWith(spotify: _config.spotify.copyWith(useAlbumColors: v));
      await save();
      spotify.startPollingIfNeeded(_config);
      notifyListeners();
    } catch (e, st) {
      _log.warning('setSpotifyUseAlbumColors: $e', e, st);
      notifyListeners();
    }
  }

  Future<void> setSpotifyIntegrationEnabled(bool v) async {
    try {
      _config = _config.copyWith(spotify: _config.spotify.copyWith(enabled: v));
      await save();
      if (v) {
        spotify.startPollingIfNeeded(_config);
      } else {
        spotify.stopPolling();
      }
      systemMediaNowPlaying.startPollingIfNeeded(_config);
      notifyListeners();
    } catch (e, st) {
      _log.warning('setSpotifyIntegrationEnabled: $e', e, st);
      notifyListeners();
    }
  }

  Future<void> _rebuildTransports() async {
    traceDeviceBindings(
      '_rebuildTransports: START staré klíče=[${_transports.keys.join(",")}] '
      'cíl=${formatDeviceBindingsList(_config.globalSettings.devices)}',
    );
    // [_transportsRebuilding] nastavuje volající (_applyConfigCore / load) před změnou [_config].
    try {
      var disposed = 0;
      final toDispose = List<DeviceTransport>.from(_transports.values);
      for (final t in toDispose) {
        try {
          t.dispose();
          disposed++;
        } catch (e, st) {
          traceDeviceBindingsWarning('_rebuildTransports: dispose jednoho transportu', e, st);
          _log.fine('transport dispose: $e', e, st);
        }
      }
      await Future.wait<void>(
        [for (final t in toDispose) t.flushPendingDispose()],
        eagerError: false,
      );
      traceDeviceBindings('_rebuildTransports: dispose hotovo ($disposed), clear()');
      _transports.clear();
      // Uvolnění COM/UDP socketů na Windows může chvíli trvat — před novým bindem počkáme déle.
      await Future<void>.delayed(const Duration(milliseconds: 220));
      traceDeviceBindingsDebug('_rebuildTransports: po 220 ms delay — nové sockety');
      for (final d in _config.globalSettings.devices) {
        if (d.controlViaHa) {
          traceDeviceBindings('_rebuildTransports: přeskočeno HA-only ${d.id}');
          continue;
        }
        try {
          if (d.type == 'serial' && d.port.isNotEmpty && d.port != 'COMx') {
            traceDeviceBindings('_rebuildTransports: vytvářím Serial ${d.id} port=${d.port}');
            _transports[d.id] = SerialDeviceTransport(
              d,
              baudRate: _config.globalSettings.baudRate,
              writeQueuePeriodMs: _effectiveThrottlePerformance ? 8 : 2,
            );
          } else if (d.type == 'wifi' && d.ipAddress.isNotEmpty) {
            traceDeviceBindings('_rebuildTransports: vytvářím UDP ${d.id} ${d.ipAddress}:${d.udpPort}');
            _transports[d.id] = UdpDeviceTransport(d);
          } else {
            traceDeviceBindings(
              '_rebuildTransports: žádný transport pro ${d.id} (typ=${d.type} port=${d.port} ip=${d.ipAddress})',
            );
          }
        } catch (e, st) {
          traceDeviceBindingsWarning('_rebuildTransports: create ${d.id}', e, st);
          _log.warning('transport create ${d.id}: $e', e, st);
        }
      }
      for (final e in _transports.entries) {
        try {
          traceDeviceBindings('_rebuildTransports: connect → ${e.key} (${e.value.runtimeType})');
          await e.value.connect();
          traceDeviceBindings('_rebuildTransports: connect OK ${e.key} connected=${e.value.isConnected}');
        } catch (err, st) {
          traceDeviceBindingsWarning('_rebuildTransports: connect FAIL ${e.key}', err, st);
          _log.warning('transport connect: $err', err, st);
        }
      }
    } catch (e, st) {
      traceDeviceBindingsSevere('_rebuildTransports: fatální', e, st);
      _log.warning('_rebuildTransports: $e', e, st);
    } finally {
      _syncConnectionSnapshotCache();
    }
    traceDeviceBindings('_rebuildTransports: KONEC (barieru drží volající)');
  }

  bool _mainLoopUsesScreenCapture() {
    final gs = _config.globalSettings;
    return gs.startMode == 'screen' ||
        (gs.startMode == 'music' && _config.musicMode.colorSource == 'monitor');
  }

  /// Výkonový režim při snímání monitoru = 25 FPS; světlo bez capture zůstává ~62 Hz. Mimo výkon: [GlobalSettings.screenRefreshRateHz].
  int _mainLoopPeriodMs() {
    final gs = _config.globalSettings;
    if (_effectiveThrottlePerformance) {
      if (_mainLoopUsesScreenCapture()) {
        return 40;
      }
      if (gs.startMode == 'light') {
        return 16;
      }
      return 40;
    }
    final hz = gs.screenRefreshRateHz;
    final ms = (1000.0 / hz).round().clamp(4, 500);
    return ms;
  }

  void _ensureMainLoopTimer() {
    // Nepřepínat na extrémně krátkou periodu při tray: async screen capture nestíhá
    // (_screenCaptureInFlight) a Flutter/OS při skrytém okně často stejně throttlují timer.
    final want = _mainLoopPeriodMs();
    if (_timer != null && _loopPeriodMs == want) {
      _ensureScreenCaptureDriverTimer();
      return;
    }
    _timer?.cancel();
    _loopPeriodMs = want;
    _timer = Timer.periodic(Duration(milliseconds: want), (_) => _tick());
    _ensureScreenCaptureDriverTimer();
  }

  void _ensureScreenCaptureDriverTimer() {
    _screenCaptureDriverTimer?.cancel();
    _screenCaptureDriverTimer = null;
    if (!_mainLoopUsesScreenCapture()) {
      _captureDriverTick = 0;
      return;
    }
    final ms = _effectiveThrottlePerformance ? 40 : _mainLoopPeriodMs().clamp(8, 500);
    _screenCaptureDriverTimer = Timer.periodic(Duration(milliseconds: ms), (_) => _screenCaptureDriverFire());
  }

  void _screenCaptureDriverFire() {
    if (_controllerDisposed) return;
    if (_transportsRebuilding || _mainLoopTickHold) return;
    if (!_mainLoopUsesScreenCapture()) return;
    _recoverScreenPipelineIfStuck();
    _recoverMusicFlatStripIfStuck();
    if (!_effectiveThrottlePerformance) {
      _adaptiveCaptureStrideMod = _captureStrideMin;
      _captureOverloadStreak = 0;
      _captureIdleStreak = 0;
      unawaited(_captureScreenFrameAsync());
      return;
    }
    if (_screenCaptureInFlight) {
      _captureOverloadStreak++;
      _captureIdleStreak = 0;
      if (_captureOverloadStreak >= 8) {
        _captureOverloadStreak = 0;
        if (_adaptiveCaptureStrideMod < _captureStrideMax) {
          _adaptiveCaptureStrideMod++;
          if (kDebugMode || ambilightVerboseLogsEnabled) {
            _log.fine(
              '[adaptive] screen capture stride → $_adaptiveCaptureStrideMod (capture overlap)',
            );
          }
        }
      }
    } else {
      _captureOverloadStreak = 0;
      _captureIdleStreak++;
      if (_captureIdleStreak >= 180 && _adaptiveCaptureStrideMod > _captureStrideMin) {
        _captureIdleStreak = 0;
        _adaptiveCaptureStrideMod--;
        if (kDebugMode || ambilightVerboseLogsEnabled) {
          _log.fine(
            '[adaptive] screen capture stride → $_adaptiveCaptureStrideMod (idle recovery)',
          );
        }
      }
    }
    _captureDriverTick++;
    final skipCap = (_captureDriverTick % _adaptiveCaptureStrideMod) != 0;
    if (!skipCap) {
      unawaited(_captureScreenFrameAsync());
    }
  }

  void startLoop() {
    unawaited(_musicAudio.syncWithConfig(_config));
    _loopPeriodMs = null;
    _ensureMainLoopTimer();
  }

  void stopLoop() {
    _timer?.cancel();
    _timer = null;
    _loopPeriodMs = null;
    _screenCaptureDriverTimer?.cancel();
    _screenCaptureDriverTimer = null;
  }

  void _ensureScreenCapture() {
    if (_screenCapture != null) return;
    try {
      _screenCapture = ScreenCaptureSource.platform();
    } catch (e, st) {
      _log.warning('ScreenCaptureSource.platform: $e', e, st);
    }
  }

  /// Jedna požadavka na snímek; při chybě nebo null zůstane poslední platný snímek (žádný pád pipeline).
  Future<void> _captureScreenFrameAsync() async {
    if (_screenCaptureInFlight) {
      _screenCaptureReplayPending = true;
      return;
    }
    final mode = _config.globalSettings.startMode;
    final musicMonitor = mode == 'music' && _config.musicMode.colorSource == 'monitor';
    if (mode != 'screen' && !musicMonitor) return;
    _screenCaptureInFlight = true;
    try {
      _ensureScreenCapture();
      if (_screenCapture == null) return;
      final idx = _config.screenMode.monitorIndex;
      final f = await _screenCapture!.captureFrame(
        idx,
        windowsCaptureBackend:
            (!kIsWeb && Platform.isWindows) ? _config.screenMode.windowsCaptureBackend : null,
      );
      final mode2 = _config.globalSettings.startMode;
      final musicMon2 = mode2 == 'music' && _config.musicMode.colorSource == 'monitor';
      if (mode2 != 'screen' && !musicMon2) return;
      if (f != null && f.isValid) {
        _screenFrameLatest = f;
        _consecutiveScreenCaptureFailures = 0;
        _screenCaptureFaultBannerShown = false;
        final now = DateTime.now();
        if (_lastScreenFrameUiNotify == null ||
            now.difference(_lastScreenFrameUiNotify!) >= _minScreenFrameUiNotifyGap) {
          _lastScreenFrameUiNotify = now;
          previewFrameNotifier.value = f;
        }
      }
    } catch (e, st) {
      _consecutiveScreenCaptureFailures++;
      logTransportBackgroundFailure('screen capture', e, st);
      if (kDebugMode) _log.fine('screen capture: $e', e, st);
      if (_consecutiveScreenCaptureFailures >= 12 && !_screenCaptureFaultBannerShown) {
        _screenCaptureFaultBannerShown = true;
        reportAppFault(
          'Snímání obrazovky opakovaně selhává. Zkontroluj oprávnění (Windows: nastavení soukromí) a výběr monitoru.',
        );
      }
    } finally {
      _screenCaptureInFlight = false;
      if (_screenCaptureReplayPending) {
        _screenCaptureReplayPending = false;
        unawaited(_captureScreenFrameAsync());
      }
    }
  }

  void _tick() {
    if (_transportsRebuilding || _mainLoopTickHold) return;
    try {
    spotify.attachPollConfig(_config);
    systemMediaNowPlaying.attachPollConfig(_config);
    _animationTick++;
    if (ambilightDebugTraceEnabled && _animationTick % 120 == 0) {
      ambilightDebugTrace(
        '_tick#$_animationTick mode=${_config.globalSettings.startMode} enabled=$_enabled '
        'transports=${_transports.length} rebuild=$_transportsRebuilding hold=$_mainLoopTickHold '
        'bri=${brightnessForMode(_config)}',
      );
    }
    final startupBlackout = _startupActive && _startupFrame < _startupBlackoutTicks;
    final needScreenCapture = _config.globalSettings.startMode == 'screen' ||
        (_config.globalSettings.startMode == 'music' && _config.musicMode.colorSource == 'monitor');
    if (!needScreenCapture) {
      _screenFrameLatest = null;
      previewFrameNotifier.value = null;
      _adaptiveCaptureStrideMod = _captureStrideMin;
      _captureOverloadStreak = 0;
      _captureIdleStreak = 0;
      _captureDriverTick = 0;
      _shutdownScreenPipelineIsolate();
    }

    final modeForSubmit = _config.globalSettings.startMode;
    final capFrame = _screenFrameLatest;
    final wantMusicFlatWorker = modeForSubmit == 'music' &&
        _config.musicMode.colorSource == 'monitor' &&
        _musicAlbumArtDominantRgb() == null &&
        _enabled &&
        !startupBlackout;

    if (wantMusicFlatWorker) {
      unawaited(_ensureMusicFlatStripIsolate());
    } else {
      _shutdownMusicFlatStripIsolate();
    }

    final wantLightPcWorker = _enabled &&
        !startupBlackout &&
        (modeForSubmit == 'light' ||
            ((modeForSubmit == 'pchealth' || modeForSubmit == 'pc_health') &&
                _config.pcHealth.enabled));

    if (wantLightPcWorker) {
      unawaited(_ensureLightPcEngineIsolate());
    } else {
      _shutdownLightPcEngineIsolate();
    }

    if (modeForSubmit == 'screen' &&
        capFrame != null &&
        capFrame.isValid &&
        !startupBlackout &&
        _enabled) {
      unawaited(_submitScreenPipelineFrameAsync(capFrame));
    }

    if (wantMusicFlatWorker &&
        capFrame != null &&
        capFrame.isValid &&
        !startupBlackout) {
      unawaited(_submitMusicFlatStripJobAsync(capFrame));
    }

    if (wantLightPcWorker) {
      unawaited(_submitLightPcEngineJobAsync());
    }

    if (_tickErrorStripUntilAnimationTick != null &&
        _animationTick > _tickErrorStripUntilAnimationTick!) {
      _tickErrorStripUntilAnimationTick = null;
    }

    final bri = brightnessForMode(_config);
    final homeKitHold = _config.globalSettings.startMode == 'light' &&
        _config.lightMode.homekitEnabled &&
        _config.globalSettings.devices.any((d) => d.controlViaHa);
    final allowOverrideSends = _wizardLedPreview != null ||
        _calibrationCorner != null ||
        (_stripColorPreviewRgb != null && _stripColorPreviewTicksLeft > 0);
    final skipAllSends = homeKitHold && !allowOverrideSends;

    if (!_enabled) {
      // Vždy zhasnout pásek (i při HomeKit hold — výstup musí jít vypnout).
      _distribute(
        AmbilightEngine.blackoutPerDevice(_config),
        0,
        applyWizardOverlay: false,
        smartLightsFrame: _screenFrameLatest,
        smartLightsAppEnabled: false,
        flushImmediately: true,
      );
      _advanceTickPhase();
      return;
    }

    if (_stripColorPreviewRgb != null && _stripColorPreviewTicksLeft > 0) {
      final solid = _solidColorPerDevice(_stripColorPreviewRgb!);
      if (!skipAllSends) {
        _distribute(
          solid,
          200,
          applyWizardOverlay: false,
          smartLightsFrame: _screenFrameLatest,
          smartLightsAppEnabled: _enabled,
          flushImmediately: true,
        );
      }
      _stripColorPreviewTicksLeft--;
      if (_stripColorPreviewTicksLeft <= 0) {
        _stripColorPreviewRgb = null;
      }
      _advanceTickPhase();
      return;
    }

    final cal = _calibrationCorner;
    if (cal != null) {
      if (!skipAllSends) {
        _distribute(
          _calibrationPreviewMap(cal),
          255,
          applyWizardOverlay: false,
          clipToDeviceLedCount: false,
          smartLightsFrame: _screenFrameLatest,
          smartLightsAppEnabled: _enabled,
          flushImmediately: true,
        );
      }
      _advanceTickPhase();
      return;
    }

    if (_wizardLedPreview != null) {
      final early = AmbilightEngine.blackoutPerDevice(_config);
      final w = _wizardLedPreview!;
      final list = early[w.$1];
      if (list != null && w.$2 >= 0 && w.$2 < list.length) {
        final copy = List<(int, int, int)>.from(list);
        copy[w.$2] = (w.$3, w.$4, w.$5);
        early[w.$1] = copy;
      }
      if (!skipAllSends) {
        _distribute(
          early,
          bri,
          applyWizardOverlay: true,
          smartLightsFrame: _screenFrameLatest,
          smartLightsAppEnabled: _enabled,
          flushImmediately: true,
        );
      }
      _advanceTickPhase();
      return;
    }

    try {
      final modeNow = _config.globalSettings.startMode;
      final bridge = _screenPipelineIsolate;
      final musicBridge = _musicFlatIsolate;
      final useScreenIsolate = modeNow == 'screen' &&
          bridge != null &&
          bridge.isReady &&
          !startupBlackout &&
          _screenFrameLatest != null &&
          _screenFrameLatest!.isValid;

      final useMusicIsolate = wantMusicFlatWorker &&
          musicBridge != null &&
          musicBridge.isReady &&
          capFrame != null &&
          capFrame.isValid;

      final lightPcBridge = _lightPcEngineIsolate;
      final useLightPcIsolate = wantLightPcWorker &&
          lightPcBridge != null &&
          lightPcBridge.isReady;

      final Map<String, List<(int, int, int)>> liveDeviceColors;
      if (startupBlackout) {
        liveDeviceColors = AmbilightEngine.blackoutPerDevice(_config);
      } else if (useScreenIsolate) {
        liveDeviceColors = _asyncScreenColors ??
            AmbilightEngine.computeFrame(
              _config,
              _animationTick,
              startupBlackout: startupBlackout,
              enabled: _enabled,
              screenFrame: needScreenCapture ? _screenFrameLatest : null,
              screenPipeline: _screenPipeline,
              musicSnapshot: modeNow == 'music' ? _musicAudio.currentSnapshot : null,
              pcHealthSnapshot: _pcHealthSnapshot,
              musicAlbumDominantRgb: _musicAlbumArtDominantRgb(),
            );
      } else if (useMusicIsolate) {
        liveDeviceColors = _asyncMusicColors ??
            AmbilightEngine.computeFrame(
              _config,
              _animationTick,
              startupBlackout: startupBlackout,
              enabled: _enabled,
              screenFrame: needScreenCapture ? _screenFrameLatest : null,
              screenPipeline: _screenPipeline,
              musicSnapshot: modeNow == 'music' ? _musicAudio.currentSnapshot : null,
              pcHealthSnapshot: _pcHealthSnapshot,
              musicAlbumDominantRgb: _musicAlbumArtDominantRgb(),
            );
      } else if (useLightPcIsolate) {
        liveDeviceColors = _asyncLightPcColors ??
            AmbilightEngine.computeFrame(
              _config,
              _animationTick,
              startupBlackout: startupBlackout,
              enabled: _enabled,
              screenFrame: needScreenCapture ? _screenFrameLatest : null,
              screenPipeline: _screenPipeline,
              musicSnapshot: modeNow == 'music' ? _musicAudio.currentSnapshot : null,
              pcHealthSnapshot: _pcHealthSnapshot,
              musicAlbumDominantRgb: _musicAlbumArtDominantRgb(),
            );
      } else {
        liveDeviceColors = AmbilightEngine.computeFrame(
          _config,
          _animationTick,
          startupBlackout: startupBlackout,
          enabled: _enabled,
          screenFrame: needScreenCapture ? _screenFrameLatest : null,
          screenPipeline: _screenPipeline,
          musicSnapshot: modeNow == 'music' ? _musicAudio.currentSnapshot : null,
          pcHealthSnapshot: _pcHealthSnapshot,
          musicAlbumDominantRgb: _musicAlbumArtDominantRgb(),
        );
      }
      var perDevice = liveDeviceColors;
      final inMusic = _config.globalSettings.startMode == 'music';
      if (_musicPaletteLockCapturePending && inMusic && !startupBlackout && _enabled) {
        _musicPaletteFrozenDeviceColors = _cloneDeviceRgbMap(liveDeviceColors);
        _musicPaletteLockCapturePending = false;
      }
      if (_musicPaletteFrozenDeviceColors != null && inMusic && !startupBlackout && _enabled) {
        perDevice = _cloneDeviceRgbMap(_musicPaletteFrozenDeviceColors!);
      }
      if (_tickErrorStripUntilAnimationTick != null &&
          _animationTick <= _tickErrorStripUntilAnimationTick!) {
        perDevice = _dimRedErrorStripMap();
      }
      if (!skipAllSends) {
        final isolatePcStream =
            useScreenIsolate || useMusicIsolate || useLightPcIsolate;
        final nowHb = DateTime.now();
        final udpKeepalive = isolatePcStream &&
            _hasWifiAmbilightStripDevice() &&
            (_lastPcStreamUdpKeepaliveSent == null ||
                nowHb.difference(_lastPcStreamUdpKeepaliveSent!) >=
                    _pcStreamUdpKeepaliveInterval);
        if (udpKeepalive) {
          _lastPcStreamUdpKeepaliveSent = nowHb;
          _distribute(
            perDevice,
            bri,
            smartLightsFrame: _screenFrameLatest,
            smartLightsAppEnabled: _enabled,
            flushImmediately: true,
          );
        } else {
          _distribute(
            perDevice,
            bri,
            smartLightsFrame: _screenFrameLatest,
            smartLightsAppEnabled: _enabled,
          );
        }
      }
    } catch (e, st) {
      _log.warning('tick: $e', e, st);
      _tickErrorStripUntilAnimationTick = _animationTick + 90;
      if (!skipAllSends) {
        try {
          _distribute(
            _dimRedErrorStripMap(),
            bri,
            applyWizardOverlay: false,
            smartLightsFrame: _screenFrameLatest,
            smartLightsAppEnabled: _enabled,
            flushImmediately: true,
          );
        } catch (e2, st2) {
          _log.fine('tick error strip distribute: $e2', e2, st2);
        }
      }
    }
    _advanceTickPhase();
    } catch (e, st) {
      _log.warning('_tick: $e', e, st);
      _tickErrorStripUntilAnimationTick ??= _animationTick + 90;
      try {
        _advanceTickPhase();
      } catch (e2, st2) {
        _log.fine('_advanceTickPhase: $e2', e2, st2);
      }
    }
  }

  void _advanceTickPhase() {
    try {
      if (_startupActive) {
        if (_startupFrame < _startupBlackoutTicks) {
          _startupFrame++;
          if (_startupFrame >= _startupBlackoutTicks) {
            _startupActive = false;
          }
        }
      }
      final connChanged = _syncConnectionSnapshotCache();
      if (connChanged) {
        notifyListeners();
      }
      _reconnectCounter++;
      final anyDisconnected = _transports.values.any((t) => !t.isConnected);
      final reconnectEvery = anyDisconnected
          ? (_effectiveThrottlePerformance ? 15 : 20)
          : (_effectiveThrottlePerformance ? 125 : 150);
      if (_reconnectCounter >= reconnectEvery) {
        _reconnectCounter = 0;
        if (!_transportsRebuilding) {
          for (final t in _transports.values) {
            if (!t.isConnected) {
              unawaited(_reconnectTransportSafe(t));
            }
          }
        }
      }
    } catch (e, st) {
      _log.warning('_advanceTickPhase: $e', e, st);
    }
  }

  Future<void> _reconnectTransportSafe(DeviceTransport t) async {
    try {
      await t.connect();
    } catch (e, st) {
      logTransportBackgroundFailure('reconnect transport (${t.device.id})', e, st);
    }
  }

  Map<String, List<(int, int, int)>> _solidColorPerDevice((int, int, int) rgb) {
    final m = <String, List<(int, int, int)>>{};
    for (final d in _config.globalSettings.devices) {
      if (d.controlViaHa) continue;
      m[d.id] = List<(int, int, int)>.filled(d.ledCount, rgb, growable: false);
    }
    return m;
  }

  Map<String, List<(int, int, int)>> _dimRedErrorStripMap() {
    final m = <String, List<(int, int, int)>>{};
    for (final d in _config.globalSettings.devices) {
      if (d.controlViaHa) continue;
      m[d.id] = List<(int, int, int)>.filled(d.ledCount, (10, 0, 0), growable: false);
    }
    return m;
  }

  static List<int> _calibrationIndices(String corner) {
    switch (corner) {
      case 'top_left':
        return const [11, 12];
      case 'top_right':
        return const [32, 33];
      case 'bottom_right':
        return const [44, 45];
      case 'bottom_left':
        return const [65, 0];
      default:
        return const [];
    }
  }

  /// Při kalibraci neomezovat délku výstupu na uživatelem zadaný `led_count` (mohl zadat 2).
  static int _calibrationStripLength(DeviceSettings d) {
    return d.ledCount.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice);
  }

  Map<String, List<(int, int, int)>> _calibrationPreviewMap(String corner) {
    final indices = _calibrationIndices(corner);
    final m = <String, List<(int, int, int)>>{};
    for (final d in _config.globalSettings.devices) {
      if (d.controlViaHa) continue;
      final len = _calibrationStripLength(d);
      final buf = List<(int, int, int)>.filled(len, (0, 0, 0), growable: false);
      for (final idx in indices) {
        if (idx >= 0 && idx < buf.length) {
          buf[idx] = (0, 255, 0);
        }
      }
      m[d.id] = buf;
    }
    return m;
  }

  void _flushDistributeMicrotask() {
    _distributeFlushScheduled = false;
    if (_controllerDisposed) return;
    final p = _distributePending;
    _distributePending = null;
    if (p == null) return;
    _distributeSync(
      p.perDevice,
      p.brightnessScalar,
      applyWizardOverlay: p.applyWizardOverlay,
      clipToDeviceLedCount: p.clipToDeviceLedCount,
      smartLightsFrame: p.smartLightsFrame,
      smartLightsAppEnabled: p.smartLightsAppEnabled,
    );
  }

  void _distribute(
    Map<String, List<(int, int, int)>> perDevice,
    int brightnessScalar, {
    bool applyWizardOverlay = true,
    /// `false` jen u kalibrace — nezkracovat buffer na `device.ledCount`, aby šly rozsvítit vysoké indexy.
    bool clipToDeviceLedCount = true,
    ScreenFrame? smartLightsFrame,
    bool smartLightsAppEnabled = true,
    /// Okamžitý výstup (vypnutí, kalibrace, průvodce) — bez čekání na microtask z hlavní smyčky.
    bool flushImmediately = false,
  }) {
    if (flushImmediately) {
      _distributePending = null;
      _distributeFlushScheduled = false;
      _distributeSync(
        perDevice,
        brightnessScalar,
        applyWizardOverlay: applyWizardOverlay,
        clipToDeviceLedCount: clipToDeviceLedCount,
        smartLightsFrame: smartLightsFrame,
        smartLightsAppEnabled: smartLightsAppEnabled,
      );
      return;
    }
    _distributePending = _DistributeArgs(
      perDevice: perDevice,
      brightnessScalar: brightnessScalar,
      applyWizardOverlay: applyWizardOverlay,
      clipToDeviceLedCount: clipToDeviceLedCount,
      smartLightsFrame: smartLightsFrame,
      smartLightsAppEnabled: smartLightsAppEnabled,
    );
    if (_distributeFlushScheduled) return;
    _distributeFlushScheduled = true;
    scheduleMicrotask(_flushDistributeMicrotask);
  }

  void _distributeSync(
    Map<String, List<(int, int, int)>> perDevice,
    int brightnessScalar, {
    bool applyWizardOverlay = true,
    /// `false` jen u kalibrace — nezkracovat buffer na `device.ledCount`, aby šly rozsvítit vysoké indexy.
    bool clipToDeviceLedCount = true,
    ScreenFrame? smartLightsFrame,
    bool smartLightsAppEnabled = true,
  }) {
    if (ambilightDebugTraceEnabled) {
      _debugDistributeSeq++;
      if (_debugDistributeSeq % 200 == 0) {
        ambilightDebugTrace(
          '_distributeSync#$_debugDistributeSeq bri=$brightnessScalar '
          'perDevice=${perDevice.keys.join(",")} wizardOverlay=$applyWizardOverlay '
          'clipLed=$clipToDeviceLedCount smartLights=$smartLightsAppEnabled',
        );
      }
    }
    final pv = applyWizardOverlay ? _wizardLedPreview : null;
    for (final dev in _config.globalSettings.devices) {
      if (dev.controlViaHa) continue;
      final t = _transports[dev.id];
      if (t == null) continue;
      try {
        if (pv != null && dev.id == pv.$1) {
          final idx = pv.$2;
          final r = pv.$3;
          final g = pv.$4;
          final b = pv.$5;
          if (dev.type == 'wifi') {
            final zeros = List<(int, int, int)>.filled(
              dev.ledCount,
              (0, 0, 0),
              growable: false,
            );
            unawaited(() async {
              try {
                await t.sendColorsNow(zeros, brightnessScalar);
                t.sendPixel(idx, r, g, b);
              } catch (e, st) {
                _log.fine('wizard wifi preview: $e', e, st);
              }
            }());
            continue;
          }
          // Serial: buffer až do [maxLedsPerDevice] (legacy / wide rámec podle délky).
          final cap = SerialAmbilightProtocol.maxLedsPerDevice;
          final clamped = idx.clamp(0, cap - 1);
          final buf = List<(int, int, int)>.filled(cap, (0, 0, 0), growable: false);
          buf[clamped] = (r, g, b);
          t.sendColors(buf, brightnessScalar);
          continue;
        }
        final chunk = perDevice[dev.id] ??
            List<(int, int, int)>.filled(dev.ledCount, (0, 0, 0), growable: false);
        if (!clipToDeviceLedCount) {
          t.sendColors(chunk, brightnessScalar);
        } else if (chunk.length != dev.ledCount) {
          final padded = List<(int, int, int)>.generate(
            dev.ledCount,
            (i) => i < chunk.length ? chunk[i] : (0, 0, 0),
            growable: false,
          );
          t.sendColors(padded, brightnessScalar);
        } else {
          t.sendColors(chunk, brightnessScalar);
        }
      } catch (e, st) {
        _log.fine('distribute ${dev.id}: $e', e, st);
      }
    }
    try {
      _smartLights.onFrame(
        config: _config,
        perDevice: perDevice,
        engineBrightness: brightnessScalar,
        frame: smartLightsFrame,
        appEnabled: smartLightsAppEnabled,
        animationTick: _animationTick,
      );
    } catch (e, st) {
      if (kDebugMode) {
        _log.fine('smartLights.onFrame: $e', e, st);
      }
    }
  }

  @override
  void dispose() {
    try {
      _controllerDisposed = true;
      _distributeFlushScheduled = false;
      final pend = _distributePending;
      _distributePending = null;
      if (pend != null) {
        _distributeSync(
          pend.perDevice,
          pend.brightnessScalar,
          applyWizardOverlay: pend.applyWizardOverlay,
          clipToDeviceLedCount: pend.clipToDeviceLedCount,
          smartLightsFrame: pend.smartLightsFrame,
          smartLightsAppEnabled: pend.smartLightsAppEnabled,
        );
      }
      _shellOcclusionDebounceTimer?.cancel();
      _shellOcclusionDebounceTimer = null;
      _applyDebounceTimer?.cancel();
      _applyDebounceTimer = null;
      _applyDebouncePending = null;
      _persistDiskDebounceTimer?.cancel();
      _persistDiskDebounceTimer = null;
      _clearTransientLedOutputs();
      previewFrameNotifier.dispose();
      connectionSnapshotNotifier.dispose();
      pcHealthSnapshotNotifier.dispose();
      spotify.stopPolling();
      systemMediaNowPlaying.stopPolling();
      _pcHealthTimer?.cancel();
      stopLoop();
      try {
        _screenCapture?.dispose();
      } catch (e, st) {
        _log.fine('screenCapture.dispose: $e', e, st);
      }
      _screenCapture = null;
      _screenFrameLatest = null;
      _shutdownScreenPipelineIsolate();
      _shutdownMusicFlatStripIsolate();
      _shutdownLightPcEngineIsolate();
      unawaited(_musicAudio.dispose());
      for (final t in _transports.values) {
        try {
          t.dispose();
        } catch (e, st) {
          _log.fine('transport.dispose: $e', e, st);
        }
      }
      _transports.clear();
      _smartLights.dispose();
    } catch (e, st) {
      _log.warning('dispose: $e', e, st);
    }
    super.dispose();
  }
}
