import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../l10n/context_ext.dart';
import '../../ui/app_navigator.dart';
import 'desktop_update_service.dart';
import 'windows_desktop_updater.dart';

/// Po startu zkontroluje manifest; při novější verzi ukáže dialog (jako OTA success)
/// s odkazem na stránku Aktualizace.
abstract final class DesktopStartupUpdatePrompt {
  static void scheduleAfterStartup() {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_run());
    });
  }

  static Future<void> _run() async {
    // Nejdřív nech doběhnout OTA report dialog (polluje status soubor).
    await _waitForOtaStatusSettled();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final available = await _checkAvailable();
    if (available == null) return;

    // Počkej, až nebude otevřený jiný dialog (OTA výsledek).
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final ctx = ambiNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final nav = Navigator.of(ctx, rootNavigator: true);
        if (!nav.canPop()) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final ctx = ambiNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    await showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final l10n = dialogCtx.l10n;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.system_update_alt,
                color: Theme.of(dialogCtx).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.desktopUpdateAvailableTitle)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              l10n.desktopUpdateAvailableBody(
                available.manifest.version,
                available.currentVersion,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                dialogCtx.read<AmbilightAppController>().requestOpenUpdates(
                      autoCheckDesktopApp: true,
                    );
              },
              child: Text(l10n.desktopUpdateAvailableOpenPage),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _waitForOtaStatusSettled() async {
    if (!Platform.isWindows) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return;
    }
    final status = File(WindowsDesktopUpdater.statusPath);
    final deadline = DateTime.now().add(const Duration(seconds: 95));
    // Krátká pauza, ať OTA poll vůbec stihne začít.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    while (DateTime.now().isBefore(deadline)) {
      if (!await status.exists()) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  static Future<DesktopUpdateCheckAvailable?> _checkAvailable() async {
    final svc = DesktopUpdateService();
    try {
      final r = await svc.checkForUpdates();
      if (r is DesktopUpdateCheckAvailable) return r;
      return null;
    } catch (_) {
      return null;
    } finally {
      svc.close();
    }
  }
}
