import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// Locale pro hlášky mimo widget strom (chyby před prvním snímkem MaterialApp).
final class AppLocaleBridge {
  AppLocaleBridge._();

  static Locale locale = const Locale('en');

  static AppLocalizations get strings => lookupAppLocalizations(locale);

  static void syncFromPlatform() {
    final loc = PlatformDispatcher.instance.locale;
    locale = loc.languageCode == 'cs' ? const Locale('cs') : const Locale('en');
  }

  static void syncFrom(BuildContext context) {
    locale = Localizations.localeOf(context);
  }
}
