import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/ambilight_presets.dart';
import '../l10n/app_locale_bridge.dart';
import 'ambilight_app_controller.dart';
import 'startup_crash_guard.dart';
import 'tray_mode_icon.dart';

final _log = Logger('DesktopChrome');

AmbilightAppController? _controller;
Timer? _trayClickTimer;
int? _trayFirstTapMs;
Timer? _trayMenuDebounce;
TrayListener? _trayClickListener;
WindowListener? _windowListener;
void Function()? _controllerListener;
String? _lastTrayVisualKey;
Timer? _shellOcclusionDebounce;
Timer? _shellOcclusionPollTimer;

bool get _inFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

/// Dříve Flutter themed tray popup; ponecháno jako no-op API (menu je nativní).
void registerTrayThemedPopup(void Function()? fn) {}

Future<void> trayQuitFromMenu() => _quitApp();

Future<void> trayOpenSettingsFromMenu(AmbilightAppController c) =>
    _openSettings(c);

Future<void> trayPopNativeContextMenu() async {
  try {
    await trayManager.popUpContextMenu();
  } catch (e, st) {
    if (kDebugMode) {
      _log.fine('tray popUpContextMenu: $e', e, st);
    }
  }
}

Future<void> _syncShellOcclusionNow() async {
  final c = _controller;
  if (c == null || _inFlutterTest) return;
  try {
    final vis = await windowManager.isVisible();
    final min = await windowManager.isMinimized();
    final occluded = !vis || min;
    c.syncAmbilightOcclusionFromShell(occluded: occluded);
  } catch (e, st) {
    _log.fine('shell occlusion sync: $e', e, st);
  }
}

void _scheduleShellOcclusionSync() {
  _shellOcclusionDebounce?.cancel();
  _shellOcclusionDebounce = Timer(const Duration(milliseconds: 120), () {
    unawaited(_syncShellOcclusionNow());
  });
}

/// Hned po [WidgetsFlutterBinding.ensureInitialized], před těžkou prací / [runApp].
/// Zajistí registraci HWND ve window_manager dřív než zbytek aplikace — na Windows snižuje
/// riziko nesouladu souřadnic myši vs. hit-test po scan overlay / DPI.
Future<void> initWindowManagerEarly() async {
  if (_inFlutterTest) return;
  await windowManager.ensureInitialized();
  try {
    await windowManager.setIgnoreMouseEvents(false);
  } catch (e, st) {
    _log.fine('initWindowManagerEarly reset mouse: $e', e, st);
  }
}

Future<void> _showMainWindow() async {
  try {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  } catch (e, st) {
    _log.fine('showMainWindow: $e', e, st);
  }
}

/// Levý klik na tray: zobrazit okno, nebo ho schovat zpět do tray (toggle).
Future<void> _toggleMainWindow() async {
  try {
    final visible = await windowManager.isVisible();
    final minimized = await windowManager.isMinimized();
    if (visible && !minimized) {
      await windowManager.hide();
      return;
    }
    await _showMainWindow();
  } catch (e, st) {
    _log.fine('toggleMainWindow: $e', e, st);
  }
}

Future<void> _openSettings(AmbilightAppController c) async {
  try {
    await _showMainWindow();
    c.requestOpenSettingsTab();
  } catch (e, st) {
    _log.fine('openSettings: $e', e, st);
  }
}

Future<void> _quitApp() async {
  AmbilightAppController? ctrl;
  try {
    ctrl = _controller;
    if (ctrl != null) {
      await ctrl.prepareQuitShutdownAsync();
      await ctrl.flushPersistToDisk();
    }
    await disposeDesktopShell();
    ctrl?.dispose();
  } catch (e, st) {
    _log.warning('_quitApp disposeDesktopShell: $e', e, st);
  }
  try {
    await trayManager.destroy();
  } catch (e, st) {
    _log.fine('tray destroy: $e', e, st);
  }
  try {
    await StartupCrashGuard.markSessionClean();
  } catch (e, st) {
    _log.fine('markSessionClean: $e', e, st);
  }
  exit(0);
}

String _trayOutputsSummary(AmbilightAppController c) {
  final snap = c.connectionSnapshot;
  final devs =
      c.config.globalSettings.devices.where((d) => !d.controlViaHa).toList();
  if (devs.isEmpty) return '';
  var on = 0;
  for (final d in devs) {
    if (snap[d.id] == true) on++;
  }
  return ' · výstupy $on/${devs.length}';
}

Future<void> _pushTrayMenu() async {
  final c = _controller;
  if (c == null) return;
  try {
    final visualKey = '${c.enabled}|${c.config.globalSettings.startMode}';
    if (visualKey != _lastTrayVisualKey) {
      _lastTrayVisualKey = visualKey;
      await syncTrayIconForMode(
        startMode: c.config.globalSettings.startMode,
        enabled: c.enabled,
      );
    }
    await trayManager.setToolTip(
      'AmbiLight — ${c.enabled ? "zapnuto" : "vypnuto"} · ${c.config.globalSettings.startMode}'
      '${_trayOutputsSummary(c)}\n'
      'Presety Screen/Music mění jen vybrané parametry daného režimu.',
    );
    await trayManager.setContextMenu(_buildTrayMenu(c));
  } catch (e, st) {
    _log.warning('tray menu: $e', e, st);
  }
}

void _scheduleTrayMenu() {
  _trayMenuDebounce?.cancel();
  _trayMenuDebounce = Timer(const Duration(milliseconds: 100), () {
    unawaited(_pushTrayMenu());
  });
}

Menu _buildTrayMenu(AmbilightAppController c) {
  final l10n = AppLocaleBridge.strings;
  final mode = c.config.globalSettings.startMode;

  MenuItem modeItem(String label, String id) {
    final active = mode == id;
    return MenuItem(
      label: active ? '✓ $label' : label,
      onClick: (_) => unawaited(c.setStartMode(id)),
    );
  }

  final screenSub = Menu(
    items: AmbilightPresets.screenNames
        .map(
          (name) => MenuItem(
            label: AmbilightPresets.trayDisplayLabelForScreenPreset(name),
            onClick: (_) => unawaited(c.applyQuickScreenPreset(name)),
          ),
        )
        .toList(),
  );
  final musicSub = Menu(
    items: AmbilightPresets.musicNames
        .map(
          (name) => MenuItem(
            label: AmbilightPresets.trayDisplayLabelForMusicPreset(name),
            onClick: (_) => unawaited(c.applyQuickMusicPreset(name)),
          ),
        )
        .toList(),
  );

  return Menu(
    items: [
      MenuItem(
        label: c.enabled ? l10n.trayDisableOutput : l10n.trayEnableOutput,
        onClick: (_) => c.toggleEnabled(),
      ),
      MenuItem.separator(),
      modeItem(l10n.modeLightTitle, 'light'),
      modeItem(l10n.modeScreenTitle, 'screen'),
      modeItem(l10n.modeMusicTitle, 'music'),
      modeItem(l10n.modePcHealthTitle, 'pchealth'),
      MenuItem.separator(),
      MenuItem(label: l10n.trayScreenPresetsSection, submenu: screenSub),
      MenuItem(label: l10n.trayMusicPresetsSection, submenu: musicSub),
      MenuItem.separator(),
      MenuItem(
        label: c.config.globalSettings.performanceMode
            ? '✓ ${l10n.performanceModeTitle}'
            : l10n.performanceModeTitle,
        onClick: (_) => c.queueConfigApply(
          c.config.copyWith(
            globalSettings: c.config.globalSettings.copyWith(
              performanceMode: !c.config.globalSettings.performanceMode,
            ),
          ),
        ),
      ),
      MenuItem(
        label: c.config.globalSettings.autostart
            ? '✓ ${l10n.autostartTitle}'
            : l10n.autostartTitle,
        onClick: (_) => c.queueConfigApply(
          c.config.copyWith(
            globalSettings: c.config.globalSettings.copyWith(
              autostart: !c.config.globalSettings.autostart,
            ),
          ),
        ),
      ),
      MenuItem.separator(),
      MenuItem(
        label: c.musicPaletteLocked
            ? l10n.trayMusicUnlockColors
            : (c.musicPaletteLockCapturePending
                ? l10n.trayMusicCancelLockPending
                : l10n.trayMusicLockColorsShort),
        onClick: (_) => c.toggleMusicPaletteLock(),
      ),
      MenuItem.separator(),
      MenuItem(
        label: l10n.trayOpenWindow,
        onClick: (_) => unawaited(_showMainWindow()),
      ),
      MenuItem(
        label: l10n.traySettingsEllipsis,
        onClick: (_) => unawaited(_openSettings(c)),
      ),
      MenuItem(
        label: l10n.trayQuit,
        onClick: (_) => unawaited(_quitApp()),
      ),
    ],
  );
}

class _TrayTapListener with TrayListener {
  _TrayTapListener(this._c);
  final AmbilightAppController _c;

  /// Pravý klik → nativní systémové menu u tray ikony (ne Flutter overlay v okně).
  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayPopNativeContextMenu());
  }

  /// Levý klik → toggle okno; dvojklik → nastavení.
  @override
  void onTrayIconMouseDown() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_trayFirstTapMs != null && now - _trayFirstTapMs! < 400) {
      _trayClickTimer?.cancel();
      _trayFirstTapMs = null;
      unawaited(_openSettings(_c));
      return;
    }
    _trayFirstTapMs = now;
    _trayClickTimer?.cancel();
    _trayClickTimer = Timer(const Duration(milliseconds: 400), () {
      _trayFirstTapMs = null;
      unawaited(_toggleMainWindow());
    });
  }
}

class _DesktopShellWindowListener with WindowListener {
  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }

  @override
  void onWindowMinimize() => _scheduleShellOcclusionSync();

  @override
  void onWindowRestore() => _scheduleShellOcclusionSync();

  @override
  void onWindowFocus() => _scheduleShellOcclusionSync();

  @override
  void onWindowBlur() => _scheduleShellOcclusionSync();

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'show' || eventName == 'hide') {
      _scheduleShellOcclusionSync();
    }
  }
}

/// Okno (skrytí místo zavření) + systémová lišta. Neběží ve `flutter test`.
Future<void> initDesktopShell(AmbilightAppController controller) async {
  if (_inFlutterTest) return;

  _controller = controller;
  await windowManager.ensureInitialized();
  try {
    await windowManager.setIgnoreMouseEvents(false);
  } catch (e, st) {
    _log.fine('initDesktopShell reset mouse: $e', e, st);
  }

  _windowListener ??= _DesktopShellWindowListener();
  windowManager.addListener(_windowListener!);
  await windowManager.setPreventClose(true);

  const opts = WindowOptions(
    size: Size(960, 720),
    minimumSize: Size(480, 360),
    center: true,
    title: 'AmbiLight',
  );

  await windowManager.waitUntilReadyToShow(opts, () async {
    try {
      if (controller.config.globalSettings.startMinimized) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
      try {
        await windowManager.setIgnoreMouseEvents(false);
      } catch (e, st) {
        _log.fine('post-show reset mouse: $e', e, st);
      }
    } catch (e, st) {
      _log.warning('waitUntilReadyToShow: $e', e, st);
    }
  });

  _scheduleShellOcclusionSync();
  _shellOcclusionPollTimer?.cancel();
  _shellOcclusionPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    unawaited(_syncShellOcclusionNow());
  });
  unawaited(Future<void>.delayed(
      const Duration(milliseconds: 500), _syncShellOcclusionNow));

  _controllerListener = _scheduleTrayMenu;
  controller.addListener(_controllerListener!);

  SchedulerBinding.instance.addPostFrameCallback((_) async {
    try {
      _trayClickListener ??= _TrayTapListener(controller);
      trayManager.addListener(_trayClickListener!);
      _lastTrayVisualKey = null;
      await _pushTrayMenu();
    } catch (e, st) {
      _log.warning('tray post-frame init: $e', e, st);
    }
  });
}

/// Po [AppLifecycleState.resumed] — obnovení tray tooltipu a reset mouse hit-test po sleep/DPI změnách.
Future<void> onDesktopAppResumed() async {
  if (_inFlutterTest) return;
  try {
    await windowManager.setIgnoreMouseEvents(false);
  } catch (e, st) {
    _log.fine('onDesktopAppResumed mouse: $e', e, st);
  }
  _scheduleTrayMenu();
  unawaited(_syncShellOcclusionNow());
}

Future<void> disposeDesktopShell() async {
  registerTrayThemedPopup(null);
  _shellOcclusionDebounce?.cancel();
  _shellOcclusionDebounce = null;
  _shellOcclusionPollTimer?.cancel();
  _shellOcclusionPollTimer = null;
  _trayMenuDebounce?.cancel();
  _trayClickTimer?.cancel();
  final c = _controller;
  final l = _controllerListener;
  if (c != null && l != null) {
    c.removeListener(l);
  }
  _controllerListener = null;
  _controller = null;
  if (_windowListener != null) {
    windowManager.removeListener(_windowListener!);
  }
  if (_trayClickListener != null) {
    trayManager.removeListener(_trayClickListener!);
  }
  try {
    await trayManager.destroy();
  } catch (_) {}
}
