import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:logging/logging.dart';

final _log = Logger('Autostart');

/// Obal nad `launch_at_startup` (Registry / .desktop / Launch Agent podle platformy).
class AutostartService {
  AutostartService._();

  static bool _setupDone = false;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static void _ensureSetup() {
    if (_setupDone) return;
    if (!_isDesktop) return;
    try {
      launchAtStartup.setup(
        appName: 'AmbiLight',
        appPath: Platform.resolvedExecutable,
      );
      _setupDone = true;
    } catch (e, st) {
      _log.warning('launchAtStartup.setup: $e', e, st);
    }
  }

  /// Zarovná OS autostart s [wantEnabled] z configu.
  static Future<void> syncFromConfig(bool wantEnabled) async {
    if (!_isDesktop) return;
    _ensureSetup();
    if (!_setupDone) return;
    try {
      final cur = await launchAtStartup.isEnabled();
      if (wantEnabled && !cur) {
        await launchAtStartup.enable();
        if (kDebugMode) _log.info('autostart enabled');
      } else if (!wantEnabled && cur) {
        await launchAtStartup.disable();
        if (kDebugMode) _log.info('autostart disabled');
      }
    } catch (e, st) {
      _log.warning('syncFromConfig: $e', e, st);
    }
  }

  static Future<bool?> isEnabled() async {
    if (!_isDesktop) return null;
    _ensureSetup();
    if (!_setupDone) return null;
    try {
      return launchAtStartup.isEnabled();
    } catch (e, st) {
      _log.fine('isEnabled: $e', e, st);
      return null;
    }
  }
}
