import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';

import '../core/ambilight_presets.dart';
import '../l10n/context_ext.dart';
import 'ambilight_app_controller.dart';

/// Kontextové menu tray ikony ve stylu aktuálního [ThemeData].
///
/// Vrací `false`, pokud nelze najít [Overlay] (např. špatný kontext) nebo [showMenu] selže —
/// volající má zobrazit nativní tray menu.
Future<bool> tryShowAmbilightTrayPopup(
  BuildContext context, {
  required Future<void> Function() onQuit,
  required Future<void> Function(AmbilightAppController c) onOpenSettings,
}) async {
  if (!context.mounted) return false;

  final overlayState = Overlay.maybeOf(context, rootOverlay: true);
  if (overlayState == null) return false;

  final overlayRo = overlayState.context.findRenderObject();
  if (overlayRo is! RenderBox || !overlayRo.hasSize) return false;

  final AmbilightAppController c;
  try {
    c = context.read<AmbilightAppController>();
  } catch (_) {
    return false;
  }

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  final topLeft = overlayRo.localToGlobal(Offset.zero);
  final oSize = overlayRo.size;
  final overlayRect =
      Rect.fromLTWH(topLeft.dx, topLeft.dy, oSize.width, oSize.height);
  final mqFallback = MediaQuery.sizeOf(context);

  RelativeRect position;
  try {
    final bounds = await trayManager.getBounds();
    if (!context.mounted) return false;
    if (bounds != null && bounds.width >= 1 && bounds.height >= 1) {
      final anchor = Offset(bounds.left, bounds.bottom + 2);
      position = RelativeRect.fromRect(
        Rect.fromLTWH(anchor.dx, anchor.dy, 1, 1),
        overlayRect,
      );
    } else {
      position = RelativeRect.fromLTRB(
        mqFallback.width - 8,
        mqFallback.height - 8,
        mqFallback.width - 8,
        mqFallback.height - 8,
      );
    }
  } catch (_) {
    if (!context.mounted) return false;
    position = RelativeRect.fromLTRB(
      mqFallback.width - 8,
      mqFallback.height - 8,
      mqFallback.width - 8,
      mqFallback.height - 8,
    );
  }

  if (!context.mounted) return false;

  try {
    await showMenu<void>(
      context: context,
      position: position,
      color: scheme.surfaceContainerHigh,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      items: _trayEntries(
        context,
        c,
        theme,
        onQuit: onQuit,
        onOpenSettings: onOpenSettings,
      ),
    );
    return true;
  } catch (e, st) {
    assert(() {
      debugPrint('tryShowAmbilightTrayPopup: $e\n$st');
      return true;
    }());
    return false;
  }
}

List<PopupMenuEntry<void>> _trayEntries(
  BuildContext context,
  AmbilightAppController c,
  ThemeData theme, {
  required Future<void> Function() onQuit,
  required Future<void> Function(AmbilightAppController c) onOpenSettings,
}) {
  final l10n = context.l10n;
  final scheme = theme.colorScheme;
  final menuTextStyle = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface);
  final labelSmall = theme.textTheme.labelSmall?.copyWith(
    color: scheme.primary,
    fontWeight: FontWeight.w600,
  );
  Text menuText(String text, {Color? color}) => Text(
        text,
        style: menuTextStyle?.copyWith(color: color ?? scheme.onSurface),
      );

  PopupMenuItem<void> hdr(String text) => PopupMenuItem<void>(
        enabled: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        height: 30,
        child: Text(text, style: labelSmall),
      );

  void modeTap(String mode) {
    unawaited(c.setStartMode(mode));
  }

  return [
    PopupMenuItem<void>(
      onTap: () => c.toggleEnabled(),
      child: menuText(c.enabled ? l10n.trayDisableOutput : l10n.trayEnableOutput),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<void>(
      onTap: () => modeTap('light'),
      child: menuText(l10n.trayModeLine(l10n.modeLightTitle)),
    ),
    PopupMenuItem<void>(
      onTap: () => modeTap('screen'),
      child: menuText(l10n.trayModeLine(l10n.modeScreenTitle)),
    ),
    PopupMenuItem<void>(
      onTap: () => modeTap('music'),
      child: menuText(l10n.trayModeLine(l10n.modeMusicTitle)),
    ),
    PopupMenuItem<void>(
      onTap: () => modeTap('pchealth'),
      child: menuText(l10n.trayModeLine(l10n.modePcHealthTitle)),
    ),
    const PopupMenuDivider(height: 1),
    hdr(l10n.trayScreenPresetsSection),
    for (final name in AmbilightPresets.screenNames)
      PopupMenuItem<void>(
        padding: const EdgeInsets.only(left: 28, right: 16),
        onTap: () => unawaited(c.applyQuickScreenPreset(name)),
        child: menuText(name),
      ),
    hdr(l10n.trayMusicPresetsSection),
    for (final name in AmbilightPresets.musicNames)
      PopupMenuItem<void>(
        padding: const EdgeInsets.only(left: 28, right: 16),
        onTap: () => unawaited(c.applyQuickMusicPreset(name)),
        child: menuText(name),
      ),
    const PopupMenuDivider(height: 1),
    CheckedPopupMenuItem<void>(
      checked: c.config.globalSettings.performanceMode,
      onTap: () {
        c.queueConfigApply(
          c.config.copyWith(
            globalSettings: c.config.globalSettings.copyWith(
              performanceMode: !c.config.globalSettings.performanceMode,
            ),
          ),
        );
      },
      child: menuText(l10n.performanceModeTitle),
    ),
    CheckedPopupMenuItem<void>(
      checked: c.config.globalSettings.autostart,
      onTap: () {
        c.queueConfigApply(
          c.config.copyWith(
            globalSettings: c.config.globalSettings.copyWith(
              autostart: !c.config.globalSettings.autostart,
            ),
          ),
        );
      },
      child: menuText(l10n.autostartTitle),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<void>(
      onTap: () => c.toggleMusicPaletteLock(),
      child: Text(
        c.musicPaletteLocked
            ? l10n.trayMusicUnlockColors
            : (c.musicPaletteLockCapturePending
                ? l10n.trayMusicCancelLockPending
                : l10n.trayMusicLockColorsShort),
        style: menuTextStyle,
      ),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<void>(
      onTap: () => unawaited(onOpenSettings(c)),
      child: menuText(l10n.traySettingsEllipsis),
    ),
    PopupMenuItem<void>(
      onTap: () => unawaited(onQuit()),
      child: menuText(l10n.trayQuit, color: scheme.error),
    ),
  ];
}
