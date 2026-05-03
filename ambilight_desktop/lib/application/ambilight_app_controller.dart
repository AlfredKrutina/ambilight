import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:logging/logging.dart';

import 'app_error_safety.dart';
import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../core/models/custom_hotkey_models.dart';
import '../core/protocol/serial_frame.dart';
import '../data/config_repository.dart';
import '../data/device_transport.dart';
import '../data/serial_device_transport.dart';
import '../data/udp_device_transport.dart';
import '../engine/ambilight_engine.dart';
import '../engine/fallback_modes.dart' show brightnessForMode;
import '../engine/screen/screen_color_pipeline.dart';
import '../engine/screen/screen_frame.dart';
import '../features/screen_capture/screen_capture_source.dart';
import '../features/pc_health/pc_health_collector.dart';
import '../features/pc_health/pc_health_smoother.dart';
import '../features/pc_health/pc_health_snapshot.dart';
import '../features/spotify/spotify_service.dart';
import '../features/system_media/system_media_now_playing_service.dart';
import '../features/smart_lights/ha_token_store.dart';
import '../features/smart_lights/smart_light_coordinator.dart';
import '../services/music/music_audio_service.dart';
import '../core/ambilight_presets.dart';

final _log = Logger('AmbiController');

Map<String, List<(int, int, int)>> _cloneDeviceRgbMap(Map<String, List<(int, int, int)>> src) {
  final out = <String, List<(int, int, int)>>{};
  for (final e in src.entries) {
    out[e.key] = List<(int, int, int)>.from(e.value);
  }
  return out;
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

/// Globální stav: konfigurace, transporty, hlavní smyčka (~33 Hz / ~25 Hz v performance módu).
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
  /// Perioda hlavní smyčky (ms); null = timer ještě neběžel.
  int? _loopPeriodMs;
  int _animationTick = 0;
  bool _startupActive = true;
  int _startupFrame = 0;
  bool _enabled = true;
  final ScreenPipelineRuntime _screenPipeline = ScreenPipelineRuntime();
  ScreenCaptureSource? _screenCapture;
  bool _screenCaptureInFlight = false;
  ScreenFrame? _screenFrameLatest;
  ScreenSessionInfo _captureSessionInfo = ScreenSessionInfo.unknown;
  final MusicAudioService _musicAudio = MusicAudioService();
  int? _pendingShellIndex;
  /// Po přechodu na Nastavení (2) — index záložky v [SettingsPage] (0…6), vyzvedne ji jen Settings.
  int? _pendingSettingsTabIndex;
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

  AmbilightAppController() {
    spotify.addListener(notifyListeners);
    systemMediaNowPlaying.addListener(notifyListeners);
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

  /// Po [applyConfigAndPersist] / [load] — např. hotkeys + autostart.
  Future<void> Function()? onAfterConfigApplied;

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
  Map<String, bool> get connectionSnapshot {
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
    return m;
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
          p.port != n.port ||
          p.ipAddress != n.ipAddress ||
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
          a.port != b.port ||
          a.ipAddress != b.ipAddress ||
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
    final perf = _config.globalSettings.performanceMode;
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

  static bool _hotkeysOrAutostartChanged(AppConfig prev, AppConfig next) {
    final ga = prev.globalSettings;
    final gb = next.globalSettings;
    if (ga.autostart != gb.autostart) return true;
    if (ga.hotkeysEnabled != gb.hotkeysEnabled) return true;
    if (ga.hotkeyToggle != gb.hotkeyToggle) return true;
    if (ga.hotkeyModeLight != gb.hotkeyModeLight) return true;
    if (ga.hotkeyModeScreen != gb.hotkeyModeScreen) return true;
    if (ga.hotkeyModeMusic != gb.hotkeyModeMusic) return true;
    if (ga.customHotkeys.length != gb.customHotkeys.length) return true;
    for (var i = 0; i < ga.customHotkeys.length; i++) {
      final ca = ga.customHotkeys[i];
      final cb = gb.customHotkeys[i];
      if (ca.key != cb.key || ca.action != cb.action) return true;
    }
    return false;
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
      _config = stripOrphanScreenSegmentDeviceIds(await ConfigRepository.load());
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
      _screenPipeline.resetSmoothing();
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
    _screenPipeline.resetSmoothing();
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

  /// Globální hotkey — přepnutí výstupu (bez zápisu do JSON, stejně jako Python `app_state.enabled`).
  void toggleEnabledHotkey() {
    _enabled = !_enabled;
    if (!_enabled) _clearTransientLedOutputs();
    if (kDebugMode) {
      _log.fine('hotkey: enabled=$_enabled');
    }
    _restartPcHealthTimer();
    notifyListeners();
  }

  Future<void> setStartModeHotkey(String mode) async {
    await setStartMode(mode);
  }

  Future<void> handleCustomHotkeyAction(
    CustomAmbilightAction action,
    Map<String, dynamic> payload,
  ) async {
    switch (action) {
      case CustomAmbilightAction.brightUp:
        await _adjustBrightness(10);
        break;
      case CustomAmbilightAction.brightDown:
        await _adjustBrightness(-10);
        break;
      case CustomAmbilightAction.brightMax:
        await _setBrightnessAbsolute(255);
        break;
      case CustomAmbilightAction.brightMin:
        await _setBrightnessAbsolute(25);
        break;
      case CustomAmbilightAction.togglePower:
        toggleEnabledHotkey();
        break;
      case CustomAmbilightAction.modeMusic:
        await setStartMode('music');
        break;
      case CustomAmbilightAction.modeScreen:
        await setStartMode('screen');
        break;
      case CustomAmbilightAction.modeLight:
        await setStartMode('light');
        break;
      case CustomAmbilightAction.modeNext:
        await _modeNext();
        break;
      case CustomAmbilightAction.effectNext:
        await _cycleEffectHotkey();
        break;
      case CustomAmbilightAction.presetNext:
        break;
      case CustomAmbilightAction.calibAuto:
        _config = _config.copyWith(screenMode: _config.screenMode.withClearedCalibration());
        await save();
        notifyListeners();
        if (kDebugMode) _log.fine('hotkey: calibration cleared');
        break;
      case CustomAmbilightAction.unknown:
        break;
    }
  }

  Future<void> _modeNext() async {
    const modes = ['screen', 'music', 'light'];
    final cur = _config.globalSettings.startMode;
    var idx = modes.indexOf(cur);
    if (idx < 0) idx = 0;
    await setStartMode(modes[(idx + 1) % modes.length]);
  }

  Future<void> _adjustBrightness(int delta) async {
    final mode = _config.globalSettings.startMode;
    AppConfig next;
    switch (mode) {
      case 'light':
        final v = (_config.lightMode.brightness + delta).clamp(0, 255);
        next = _config.copyWith(lightMode: _config.lightMode.copyWith(brightness: v));
        break;
      case 'screen':
        final v = (_config.screenMode.brightness + delta).clamp(0, 255);
        next = _config.copyWith(screenMode: _config.screenMode.withBrightness(v));
        break;
      case 'music':
        final v = (_config.musicMode.brightness + delta).clamp(0, 255);
        next = _config.copyWith(musicMode: _config.musicMode.withBrightness(v));
        break;
      case 'pchealth':
        final v = (_config.pcHealth.brightness + delta).clamp(0, 255);
        next = _config.copyWith(pcHealth: _config.pcHealth.withBrightness(v));
        break;
      default:
        return;
    }
    _config = next;
    await save();
    notifyListeners();
  }

  Future<void> _setBrightnessAbsolute(int val) async {
    final cur = brightnessForMode(_config);
    await _adjustBrightness(val - cur);
  }

  Future<void> _cycleEffectHotkey() async {
    final mode = _config.globalSettings.startMode;
    AppConfig next;
    if (mode == 'light') {
      const effs = ['rainbow', 'chase', 'breathing', 'static'];
      final curr = _config.lightMode.effect;
      var i = effs.indexOf(curr);
      if (i < 0) i = 0;
      final ne = effs[(i + 1) % effs.length];
      next = _config.copyWith(lightMode: _config.lightMode.copyWith(effect: ne));
    } else if (mode == 'music') {
      const effs = ['smart_music', 'spectrum', 'energy', 'strobe', 'vumeter'];
      final curr = _config.musicMode.effect;
      var i = effs.indexOf(curr);
      if (i < 0) i = 0;
      final ne = effs[(i + 1) % effs.length];
      next = _config.copyWith(musicMode: _config.musicMode.withEffect(ne));
    } else {
      return;
    }
    _config = next;
    await save();
    notifyListeners();
  }

  Future<void> setStartMode(String mode) async {
    final prev = _config.globalSettings.startMode;
    _config = _config.copyWith(
      globalSettings: _config.globalSettings.copyWith(startMode: mode),
    );
    _clearMusicPaletteLockOutsideMusicMode(mode);
    if (prev == 'screen' && mode != 'screen') {
      _screenPipeline.resetSmoothing();
      _screenFrameLatest = null;
    }
    if (prev == 'pchealth' && mode != 'pchealth') {
      _pcHealthSmoother.reset();
    }
    unawaited(_musicAudio.syncWithConfig(_config));
    _restartPcHealthTimer();
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
    }
  }

  Future<void> applyConfigAndPersist(AppConfig next) {
    traceDeviceBindings('applyConfigAndPersist: vstup (řetěz serializovaných apply)');
    traceConfigBindings('applyConfigAndPersist PŘED (aktuální _config)', _config);
    traceConfigBindings('applyConfigAndPersist POŽADAVEK (next)', next);
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
  }) async {
    _mainLoopTickHold = true;
    final prev = _config;
    // Před změnou [_config] zastav výstupní tick — jinak mezi `await _musicAudio…` a dispose COM
    // může [_tick] posílat na starý transport s už prázdným seznamem zařízení → pád na Windows.
    if (rebuildTransports) {
      _transportsRebuilding = true;
    }
    try {
      traceDeviceBindings(
        '_applyConfigCore: start rebuildTransports=$rebuildTransports clearTransient=$clearTransient '
        '(transportBarrier=${rebuildTransports ? "ON" : "off"})',
      );
      if (clearTransient) _clearTransientLedOutputs();
      _config = stripOrphanScreenSegmentDeviceIds(next);
      traceConfigBindings('_applyConfigCore: po stripOrphan', _config);
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
      _pruneWizardLedPreviewForConfig(_config);
      final topologyChanged =
          _screenPipelineTopologySignature(prev) != _screenPipelineTopologySignature(_config);
      if (rebuildTransports || topologyChanged) {
        _screenPipeline.resetSmoothing();
      }
      final wrote = await save();
      _restartPcHealthTimer();
      spotify.startPollingIfNeeded(_config);
      systemMediaNowPlaying.startPollingIfNeeded(_config);
      if (wrote || rebuildTransports || topologyChanged) {
        _configPersistGeneration++;
      }
      notifyListeners();
      _ensureMainLoopTimer();
      if (runAfterConfigHook) {
        await onAfterConfigApplied?.call();
      }
      traceConfigBindings('_applyConfigCore: HOTOVO (úspěch)', _config);
    } catch (e, st) {
      traceDeviceBindingsSevere('_applyConfigCore: CHYBA', e, st);
      _log.warning('applyConfigCore: $e', e, st);
      reportAppFault('Nastavení se nepodařilo aplikovat: ${e.toString().split('\n').first}');
      notifyListeners();
    } finally {
      if (rebuildTransports) {
        _transportsRebuilding = false;
        traceDeviceBindings('_applyConfigCore: transportBarrier OFF');
      }
      _mainLoopTickHold = false;
    }
  }

  /// Okamžitě promítne [next] do [_config] a výstupní smyčky (pokud nejde o COM/IP/hotkeys),
  /// disk se uloží až po ~220 ms klidu — bez „posunu a až pak změna“ u posuvníků.
  ///
  /// Na rozdíl od [applyConfigAndPersist] po debounci znovu neotevírá sériový port / UDP, pokud
  /// se nezměnily vazby zařízení.
  bool _canApplyConfigLive(AppConfig next) {
    return _transportsBindingUnchanged(_config, next) && !_hotkeysOrAutostartChanged(_config, next);
  }

  void _applyConfigLiveOnly(AppConfig next) {
    _mainLoopTickHold = true;
    final prev = _config;
    try {
      _config = stripOrphanScreenSegmentDeviceIds(next);
      _clearMusicPaletteLockOutsideMusicMode(_config.globalSettings.startMode);
      if (_screenPipelineTopologySignature(prev) != _screenPipelineTopologySignature(_config)) {
        _screenPipeline.resetSmoothing();
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
    } finally {
      _mainLoopTickHold = false;
    }
  }

  void _scheduleCoalescedLiveNotify() {
    if (_coalescedLiveNotifyScheduled) return;
    _coalescedLiveNotifyScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
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
    final debounceMs = next.globalSettings.performanceMode ? 280 : 220;
    _applyDebounceTimer = Timer(Duration(milliseconds: debounceMs), () async {
      final p = _applyDebouncePending;
      _applyDebouncePending = null;
      _applyDebounceTimer = null;
      if (p == null) return;
      try {
        final prev = _config;
        final sameBindings = _transportsBindingUnchanged(prev, p);
        final hotkeysDirty = _hotkeysOrAutostartChanged(prev, p);
        if (kDebugMode) {
          _log.fine(
            '[staging] debounced config: sameBindings=$sameBindings hotkeysOrAutostart=$hotkeysDirty',
          );
        }
        await _runConfigApplySerialized(
          () => _applyConfigCore(
            p,
            rebuildTransports: !sameBindings,
            clearTransient: false,
            runAfterConfigHook: hotkeysDirty,
          ),
        );
      } catch (e, st) {
        traceDeviceBindingsSevere('queueConfigApply debounced timer: selhalo', e, st);
        _log.warning('debounced apply failed: $e', e, st);
        reportAppFault('Automatické uložení nastavení selhalo: ${e.toString().split('\n').first}');
      }
    });
  }

  void _restartPcHealthTimer() {
    _pcHealthTimer?.cancel();
    _pcHealthTimer = null;
    if (!_enabled || _config.globalSettings.startMode != 'pchealth' || !_config.pcHealth.enabled) {
      return;
    }
    var ms = _config.pcHealth.updateRate.clamp(200, 10000);
    if (_config.globalSettings.performanceMode && ms < 800) {
      ms = 800;
    }
    Future<void> tick() async {
      try {
        final raw = await _pcHealthCollector.collect();
        _pcHealthSnapshot = _pcHealthSmoother.apply(raw);
        notifyListeners();
      } catch (e, st) {
        if (kDebugMode) _log.fine('pc health: $e', e, st);
      }
    }

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
      await Future.wait(toDispose.map((t) => t.flushPendingDispose()));
      traceDeviceBindings('_rebuildTransports: dispose hotovo ($disposed), clear()');
      _transports.clear();
      // Uvolnění COM/UDP socketů na Windows může chvíli trvat — před novým bindem počkáme déle.
      await Future<void>.delayed(const Duration(milliseconds: 220));
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
              writeQueuePeriodMs: _config.globalSettings.performanceMode ? 8 : 4,
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
    }
    traceDeviceBindings('_rebuildTransports: KONEC (barieru drží volající)');
  }

  void _ensureMainLoopTimer() {
    final want = _config.globalSettings.performanceMode ? 40 : 30;
    if (_timer != null && _loopPeriodMs == want) return;
    _timer?.cancel();
    _loopPeriodMs = want;
    _timer = Timer.periodic(Duration(milliseconds: want), (_) => _tick());
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
    if (_screenCaptureInFlight) return;
    final mode = _config.globalSettings.startMode;
    final musicMonitor = mode == 'music' && _config.musicMode.colorSource == 'monitor';
    if (mode != 'screen' && !musicMonitor) return;
    _screenCaptureInFlight = true;
    try {
      _ensureScreenCapture();
      if (_screenCapture == null) return;
      final idx = _config.screenMode.monitorIndex;
      final f = await _screenCapture!.captureFrame(idx);
      final mode2 = _config.globalSettings.startMode;
      final musicMon2 = mode2 == 'music' && _config.musicMode.colorSource == 'monitor';
      if (mode2 != 'screen' && !musicMon2) return;
      if (f != null && f.isValid) {
        _screenFrameLatest = f;
      }
    } catch (e, st) {
      if (kDebugMode) _log.fine('screen capture: $e', e, st);
    } finally {
      _screenCaptureInFlight = false;
    }
  }

  void _tick() {
    if (_transportsRebuilding || _mainLoopTickHold) return;
    try {
    spotify.attachPollConfig(_config);
    systemMediaNowPlaying.attachPollConfig(_config);
    _animationTick++;
    final startupBlackout = _startupActive && _startupFrame < 61;
    final needScreenCapture = _config.globalSettings.startMode == 'screen' ||
        (_config.globalSettings.startMode == 'music' && _config.musicMode.colorSource == 'monitor');
    if (needScreenCapture) {
      final skipCap = _config.globalSettings.performanceMode && (_animationTick % 3) != 0;
      if (!skipCap) {
        unawaited(_captureScreenFrameAsync());
      }
    } else {
      _screenFrameLatest = null;
    }

    if (_tickErrorStripUntilAnimationTick != null &&
        _animationTick > _tickErrorStripUntilAnimationTick!) {
      _tickErrorStripUntilAnimationTick = null;
    }

    final bri = brightnessForMode(_config);
    final homeKitHold =
        _config.globalSettings.startMode == 'light' && _config.lightMode.homekitEnabled;
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
          applyWizardOverlay: false,
          smartLightsFrame: _screenFrameLatest,
          smartLightsAppEnabled: _enabled,
        );
      }
      _advanceTickPhase();
      return;
    }

    try {
      final liveDeviceColors = AmbilightEngine.computeFrame(
        _config,
        _animationTick,
        startupBlackout: startupBlackout,
        enabled: _enabled,
        screenFrame: needScreenCapture ? _screenFrameLatest : null,
        screenPipeline: _screenPipeline,
        musicSnapshot:
            _config.globalSettings.startMode == 'music' ? _musicAudio.currentSnapshot : null,
        pcHealthSnapshot: _pcHealthSnapshot,
        musicAlbumDominantRgb: _musicAlbumArtDominantRgb(),
      );
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
        _distribute(
          perDevice,
          bri,
          smartLightsFrame: _screenFrameLatest,
          smartLightsAppEnabled: _enabled,
        );
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
        if (_startupFrame < 61) {
          _startupFrame++;
          if (_startupFrame > 60) {
            _startupActive = false;
          }
        }
      }
      final notifyEvery = _config.globalSettings.performanceMode ? 72 : 36;
      if (_animationTick % notifyEvery == 0) {
        notifyListeners();
      }
      _reconnectCounter++;
      final reconnectEvery = _config.globalSettings.performanceMode ? 125 : 150;
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
      _log.fine('reconnect transport: $e', e, st);
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

  void _distribute(
    Map<String, List<(int, int, int)>> perDevice,
    int brightnessScalar, {
    bool applyWizardOverlay = true,
    /// `false` jen u kalibrace — nezkracovat buffer na `device.ledCount`, aby šly rozsvítit vysoké indexy.
    bool clipToDeviceLedCount = true,
    ScreenFrame? smartLightsFrame,
    bool smartLightsAppEnabled = true,
  }) {
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
            // Jako Python: krátký „off“ rámec + jeden pixel (UDP 0x03).
            t.sendColors([(0, 0, 0)], 0);
            t.sendPixel(idx, r, g, b);
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
      _applyDebounceTimer?.cancel();
      _applyDebounceTimer = null;
      _applyDebouncePending = null;
      _clearTransientLedOutputs();
      spotify.removeListener(notifyListeners);
      spotify.stopPolling();
      systemMediaNowPlaying.removeListener(notifyListeners);
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
