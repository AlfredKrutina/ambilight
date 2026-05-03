import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/ambilight_presets.dart';
import 'ambilight_app_controller.dart';
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

bool get _inFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

Future<void> _showMainWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

Future<void> _openSettings(AmbilightAppController c) async {
  await _showMainWindow();
  c.requestOpenSettingsTab();
}

Future<void> _quitApp() async {
  try {
    await trayManager.destroy();
  } catch (e, st) {
    _log.fine('tray destroy: $e', e, st);
  }
  exit(0);
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
      'AmbiLight — ${c.enabled ? "zapnuto" : "vypnuto"} · ${c.config.globalSettings.startMode}',
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
  MenuItem modeItem(String label, String mode) => MenuItem(
        label: label,
        onClick: (_) => unawaited(c.setStartMode(mode)),
      );

  final screenSub = Menu(
    items: AmbilightPresets.screenNames
        .map(
          (name) => MenuItem(
            label: name,
            onClick: (_) => unawaited(c.applyQuickScreenPreset(name)),
          ),
        )
        .toList(),
  );
  final musicSub = Menu(
    items: AmbilightPresets.musicNames
        .map(
          (name) => MenuItem(
            label: name,
            onClick: (_) => unawaited(c.applyQuickMusicPreset(name)),
          ),
        )
        .toList(),
  );

  return Menu(
    items: [
      MenuItem(
        label: c.enabled ? 'Vypnout výstup' : 'Zapnout výstup',
        onClick: (_) => c.toggleEnabled(),
      ),
      MenuItem.separator(),
      modeItem('Režim: Light', 'light'),
      modeItem('Režim: Screen', 'screen'),
      modeItem('Režim: Music', 'music'),
      modeItem('Režim: PC Health', 'pchealth'),
      MenuItem.separator(),
      MenuItem(label: 'Screen — presety', submenu: screenSub),
      MenuItem(label: 'Music — presety', submenu: musicSub),
      MenuItem.separator(),
      MenuItem(
        label: c.musicPaletteLocked
            ? 'Odemknout barvy (hudba)'
            : (c.musicPaletteLockCapturePending
                ? 'Zrušit zamykání barev (čeká na snímek)'
                : 'Zamknout barvy (hudba)'),
        onClick: (_) => c.toggleMusicPaletteLock(),
      ),
      MenuItem.separator(),
      MenuItem(
        label: 'Nastavení…',
        onClick: (_) => unawaited(_openSettings(c)),
      ),
      MenuItem(
        label: 'Ukončit',
        onClick: (_) => unawaited(_quitApp()),
      ),
    ],
  );
}

class _TrayTapListener with TrayListener {
  _TrayTapListener(this._c);
  final AmbilightAppController _c;

  @override
  void onTrayIconMouseDown() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_trayFirstTapMs != null && now - _trayFirstTapMs! < 450) {
      _trayClickTimer?.cancel();
      _trayFirstTapMs = null;
      unawaited(_openSettings(_c));
      return;
    }
    _trayFirstTapMs = now;
    _trayClickTimer?.cancel();
    _trayClickTimer = Timer(const Duration(milliseconds: 450), () {
      _trayFirstTapMs = null;
      unawaited(_showMainWindow());
    });
  }
}

class _HideOnCloseListener with WindowListener {
  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }
}

/// Okno (skrytí místo zavření) + systémová lišta. Neběží ve `flutter test`.
Future<void> initDesktopShell(AmbilightAppController controller) async {
  if (_inFlutterTest) return;

  _controller = controller;
  await windowManager.ensureInitialized();

  _windowListener ??= _HideOnCloseListener();
  windowManager.addListener(_windowListener!);
  await windowManager.setPreventClose(true);

  const opts = WindowOptions(
    size: Size(960, 720),
    minimumSize: Size(480, 360),
    center: true,
    title: 'AmbiLight',
  );

  await windowManager.waitUntilReadyToShow(opts, () async {
    if (controller.config.globalSettings.startMinimized) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  _controllerListener = _scheduleTrayMenu;
  controller.addListener(_controllerListener!);

  SchedulerBinding.instance.addPostFrameCallback((_) async {
    _trayClickListener ??= _TrayTapListener(controller);
    trayManager.addListener(_trayClickListener!);
    _lastTrayVisualKey = null;
    await _pushTrayMenu();
  });
}

Future<void> disposeDesktopShell() async {
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
