import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/desktop_chrome_stub.dart'
    if (dart.library.io) '../../application/desktop_chrome_io.dart'
    as desktop_chrome;
import '../../application/tray_themed_popup.dart';
import '../app_navigator.dart';

/// Zaregistruje Flutter tray menu ve stylu aktuálního tématu (desktop IO).
class TrayMenuHost extends StatefulWidget {
  const TrayMenuHost({super.key, required this.child});

  final Widget child;

  @override
  State<TrayMenuHost> createState() => _TrayMenuHostState();
}

class _TrayMenuHostState extends State<TrayMenuHost> {
  @override
  void initState() {
    super.initState();
    desktop_chrome.registerTrayThemedPopup(_showThemedTrayMenu);
  }

  @override
  void dispose() {
    desktop_chrome.registerTrayThemedPopup(null);
    super.dispose();
  }

  void _showThemedTrayMenu() {
    final nav = ambiNavigatorKey.currentState;
    final overlay = nav?.overlay;
    // Kontext přímo z Overlay — `navigatorKey.currentContext` při skrytém okně / některých fázích buildu nemusí mít [Overlay].
    final ctx = overlay?.context ?? nav?.context;
    if (ctx == null || !ctx.mounted) {
      unawaited(desktop_chrome.trayPopNativeContextMenu());
      return;
    }
    if (Overlay.maybeOf(ctx, rootOverlay: true) == null) {
      unawaited(desktop_chrome.trayPopNativeContextMenu());
      return;
    }
    unawaited(() async {
      final ok = await tryShowAmbilightTrayPopup(
        ctx,
        onQuit: desktop_chrome.trayQuitFromMenu,
        onOpenSettings: desktop_chrome.trayOpenSettingsFromMenu,
      );
      if (!ok) {
        await desktop_chrome.trayPopNativeContextMenu();
      }
    }());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
