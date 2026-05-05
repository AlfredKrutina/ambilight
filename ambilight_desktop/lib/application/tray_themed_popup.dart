import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';

import '../core/ambilight_presets.dart';
import '../core/models/config_models.dart';
import '../l10n/context_ext.dart';
import '../ui/app_theme.dart';
import 'ambilight_app_controller.dart';

Widget _trayMenuThemed(ThemeData menuTheme, Widget child) =>
    Theme(data: menuTheme, child: child);

/// Pravý klik na tray během [showMenu] — druhý klik zavře menu místo otevření druhého.
bool _trayPopupBusy = false;
bool _trayFlutterMenuVisible = false;

/// Kontextové menu tray ikony ve stylu aktuálního [ThemeData].
///
/// Vrací `false`, pokud nelze najít [Overlay] (např. špatný kontext) nebo [showMenu] selže —
/// volající má zobrazit nativní tray menu.
///
/// Když je menu už otevřené, znovu pravý klik na tray ho zavře ([Navigator.maybePop]) a vrátí `true`.
Future<bool> tryShowAmbilightTrayPopup(
  BuildContext context, {
  required Future<void> Function() onQuit,
  required Future<void> Function(AmbilightAppController c) onOpenSettings,
}) async {
  if (!context.mounted) return false;

  if (_trayPopupBusy && _trayFlutterMenuVisible) {
    try {
      Navigator.of(context, rootNavigator: true).maybePop();
    } catch (_) {}
    return true;
  }
  if (_trayPopupBusy) {
    return true;
  }

  _trayPopupBusy = true;
  try {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return false;

    // Na Windows při okně skrytém do traye může mít overlay 0×0 — pak dříve padalo na nativní menu bez tématu.
    final overlayCtx = overlayState.context;
    final overlayRo = overlayCtx.findRenderObject();
    final Rect overlayRect;
    if (overlayRo is RenderBox && overlayRo.hasSize) {
      final topLeft = overlayRo.localToGlobal(Offset.zero);
      final oSize = overlayRo.size;
      overlayRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, oSize.width, oSize.height);
    } else {
      final sz = MediaQuery.sizeOf(context);
      overlayRect = Rect.fromLTWH(0, 0, sz.width, sz.height);
    }

    final AmbilightAppController c;
    try {
      c = context.read<AmbilightAppController>();
    } catch (_) {
      return false;
    }

    final reducedMotion = c.config.globalSettings.performanceMode ||
        !c.config.globalSettings.uiAnimationsEnabled;
    final menuTheme = AmbiLightTheme.themeForKey(
      normalizeAmbilightUiTheme(c.config.globalSettings.theme),
      reducedMotion: reducedMotion,
    );
    final scheme = menuTheme.colorScheme;

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

    _trayFlutterMenuVisible = true;
    try {
      await showMenu<void>(
        context: context,
        useRootNavigator: true,
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
          menuTheme,
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
    } finally {
      _trayFlutterMenuVisible = false;
    }
  } finally {
    _trayPopupBusy = false;
  }
}

List<PopupMenuEntry<void>> _trayEntries(
  BuildContext context,
  AmbilightAppController c,
  ThemeData menuTheme, {
  required Future<void> Function() onQuit,
  required Future<void> Function(AmbilightAppController c) onOpenSettings,
}) {
  final l10n = context.l10n;
  final scheme = menuTheme.colorScheme;
  final labelSmall = menuTheme.textTheme.labelSmall?.copyWith(
    color: scheme.primary,
    fontWeight: FontWeight.w600,
  );

  PopupMenuItem<void> hdr(String text) => PopupMenuItem<void>(
        enabled: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        height: 30,
        child: _trayMenuThemed(menuTheme, Text(text, style: labelSmall)),
      );

  void modeTap(String mode) {
    unawaited(c.setStartMode(mode));
  }

  return [
    PopupMenuItem<void>(
      onTap: () => c.toggleEnabled(),
      child: _trayMenuThemed(
        menuTheme,
        Text(c.enabled ? l10n.trayDisableOutput : l10n.trayEnableOutput),
      ),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<void>(
      onTap: () => modeTap('light'),
      child: _trayMenuThemed(
          menuTheme, Text(l10n.trayModeLine(l10n.modeLightTitle))),
    ),
    PopupMenuItem<void>(
      onTap: () => modeTap('screen'),
      child: _trayMenuThemed(
          menuTheme, Text(l10n.trayModeLine(l10n.modeScreenTitle))),
    ),
    PopupMenuItem<void>(
      onTap: () => modeTap('music'),
      child: _trayMenuThemed(
          menuTheme, Text(l10n.trayModeLine(l10n.modeMusicTitle))),
    ),
    PopupMenuItem<void>(
      onTap: () => modeTap('pchealth'),
      child: _trayMenuThemed(
          menuTheme, Text(l10n.trayModeLine(l10n.modePcHealthTitle))),
    ),
    const PopupMenuDivider(height: 1),
    hdr(l10n.trayScreenPresetsSection),
    for (final name in AmbilightPresets.screenNames)
      PopupMenuItem<void>(
        padding: const EdgeInsets.only(left: 28, right: 16),
        onTap: () => unawaited(c.applyQuickScreenPreset(name)),
        child: _trayMenuThemed(menuTheme, Text(name)),
      ),
    hdr(l10n.trayMusicPresetsSection),
    for (final name in AmbilightPresets.musicNames)
      PopupMenuItem<void>(
        padding: const EdgeInsets.only(left: 28, right: 16),
        onTap: () => unawaited(c.applyQuickMusicPreset(name)),
        child: _trayMenuThemed(menuTheme, Text(name)),
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
      child: _trayMenuThemed(menuTheme, Text(l10n.performanceModeTitle)),
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
      child: _trayMenuThemed(menuTheme, Text(l10n.autostartTitle)),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<void>(
      onTap: () => c.toggleMusicPaletteLock(),
      child: _trayMenuThemed(
        menuTheme,
        Text(
          c.musicPaletteLocked
              ? l10n.trayMusicUnlockColors
              : (c.musicPaletteLockCapturePending
                  ? l10n.trayMusicCancelLockPending
                  : l10n.trayMusicLockColorsShort),
        ),
      ),
    ),
    const PopupMenuDivider(height: 1),
    PopupMenuItem<void>(
      onTap: () => unawaited(onOpenSettings(c)),
      child: _trayMenuThemed(menuTheme, Text(l10n.traySettingsEllipsis)),
    ),
    PopupMenuItem<void>(
      onTap: () => unawaited(onQuit()),
      child: _trayMenuThemed(
        menuTheme,
        Text(l10n.trayQuit, style: TextStyle(color: scheme.error)),
      ),
    ),
  ];
}
