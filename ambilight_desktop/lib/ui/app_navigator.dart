import 'package:flutter/material.dart';

/// Globální navigátor pro tématický tray popup ([showMenu]) — musí sedět s [MaterialApp.navigatorKey].
final GlobalKey<NavigatorState> ambiNavigatorKey = GlobalKey<NavigatorState>();

/// Vrátí kontext pod [Navigator], vhodný pro `showDialog`/`showMenu`.
///
/// [fallbackContext] se použije pouze pokud už má dostupný root navigator.
BuildContext? ambiNavigatorModalContext([BuildContext? fallbackContext]) {
  final rootNav = fallbackContext == null ? null : Navigator.maybeOf(fallbackContext, rootNavigator: true);
  final rootCtx = rootNav?.context;
  if (rootCtx != null && rootCtx.mounted) return rootCtx;
  final keyCtx = ambiNavigatorKey.currentState?.overlay?.context ?? ambiNavigatorKey.currentContext;
  if (keyCtx != null && keyCtx.mounted) return keyCtx;
  if (fallbackContext != null && fallbackContext.mounted) return fallbackContext;
  return null;
}
