import 'package:flutter/material.dart';

import '../core/models/config_models.dart';
import '../l10n/context_ext.dart';

class AmbilightUiThemeOption {
  const AmbilightUiThemeOption({
    required this.key,
    required this.icon,
  });

  final String key;
  final IconData icon;
}

/// Sdílený katalog UI témat pro onboarding i Settings.
abstract final class AmbilightUiThemeCatalog {
  static const List<AmbilightUiThemeOption> options = [
    AmbilightUiThemeOption(key: 'snowrunner', icon: Icons.ac_unit_rounded),
    AmbilightUiThemeOption(key: 'dark_blue', icon: Icons.nights_stay_rounded),
    AmbilightUiThemeOption(key: 'light', icon: Icons.light_mode_rounded),
    AmbilightUiThemeOption(key: 'coffee', icon: Icons.coffee_rounded),
  ];

  static String title(BuildContext context, String canonicalKey) {
    final l10n = context.l10n;
    return switch (canonicalKey) {
      'snowrunner' => l10n.themeSnowrunner,
      'dark_blue' => l10n.themeDarkBlue,
      'light' => l10n.themeLight,
      'coffee' => l10n.themeCoffee,
      _ => l10n.themeDarkBlue,
    };
  }

  static String onboardingSubtitle(BuildContext context, String canonicalKey) {
    final l10n = context.l10n;
    return switch (canonicalKey) {
      'light' || 'coffee' => l10n.onboardWizardThemeLightSubtitle,
      _ => l10n.onboardWizardThemeDarkSubtitle,
    };
  }

  static bool contains(String canonicalKey) {
    return options.any((o) => o.key == normalizeAmbilightUiTheme(canonicalKey));
  }
}
