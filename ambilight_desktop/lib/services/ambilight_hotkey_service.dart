import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:logging/logging.dart';

import '../application/ambilight_app_controller.dart';
import '../core/models/custom_hotkey_models.dart';
import 'ambilight_hotkey_binding.dart';

final _log = Logger('Hotkeys');

/// Registrace globálních zkratek podle [GlobalSettings] (parita s Python `_init_hotkeys`).
class AmbilightHotkeyService {
  AmbilightHotkeyService(this._controller);

  final AmbilightAppController _controller;

  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static void _dispatch(void Function() fn) {
    scheduleMicrotask(fn);
  }

  Future<void> syncFromController() async {
    if (!_desktop) return;
    try {
      await hotKeyManager.unregisterAll();
    } catch (e, st) {
      _log.fine('unregisterAll: $e', e, st);
    }

    final g = _controller.config.globalSettings;
    if (!g.hotkeysEnabled) {
      if (kDebugMode) _log.fine('hotkeys disabled in config');
      return;
    }

    Future<void> reg(String combo, String id, void Function() action) async {
      final hk = hotKeyFromConfigString(combo, identifier: id);
      if (hk == null) return;
      try {
        await hotKeyManager.register(
          hk,
          keyDownHandler: (_) => _dispatch(action),
        );
        if (kDebugMode) _log.fine('registered $id');
      } catch (e, st) {
        _log.warning('invalid hotkey $id: $e', e, st);
      }
    }

    await reg(g.hotkeyToggle, 'ambi_toggle', () => _controller.toggleEnabledHotkey());
    await reg(g.hotkeyModeLight, 'ambi_mode_light', () {
      unawaited(_controller.setStartModeHotkey('light'));
    });
    await reg(g.hotkeyModeScreen, 'ambi_mode_screen', () {
      unawaited(_controller.setStartModeHotkey('screen'));
    });
    await reg(g.hotkeyModeMusic, 'ambi_mode_music', () {
      unawaited(_controller.setStartModeHotkey('music'));
    });

    var i = 0;
    for (final h in g.customHotkeys) {
      if (h.key.isEmpty || h.action == CustomAmbilightAction.unknown) continue;
      final idx = i++;
      final action = h.action;
      final payload = Map<String, dynamic>.from(h.payload);
      await reg(h.key, 'ambi_custom_$idx', () {
        unawaited(_controller.handleCustomHotkeyAction(action, payload));
      });
    }
  }
}
