import 'package:ambilight_desktop/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// [MaterialApp] s delegáty AmbiLight l10n — bez toho [AmbiShell] / [SettingsPage] při testech spadnou na `AppLocalizations.of`.
Widget ambilightTestMaterialApp({
  required Widget home,
  Locale locale = const Locale('cs'),
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: home,
  );
}
