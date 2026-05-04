import 'package:flutter/widgets.dart';

import '../core/models/config_models.dart';

Locale? ambilightLocaleOverride(String uiLanguageSetting) {
  switch (normalizeAmbilightUiLanguage(uiLanguageSetting)) {
    case 'en':
      return const Locale('en');
    case 'cs':
      return const Locale('cs');
    default:
      return null;
  }
}

/// Mapuje systémové locale na podporované [cs] / [en].
Locale ambilightResolvePlatformLocale(List<Locale>? preferred) {
  if (preferred != null) {
    for (final loc in preferred) {
      if (loc.languageCode == 'cs') return const Locale('cs');
      if (loc.languageCode == 'en') return const Locale('en');
    }
  }
  return const Locale('en');
}
