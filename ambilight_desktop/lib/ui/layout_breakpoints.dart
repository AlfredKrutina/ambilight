import 'package:flutter/material.dart';

/// G1 — jeden zdroj breakpointů (MASTER plán): compact < 600, medium 600–1200, expanded ≥ 1200.
abstract final class AppBreakpoints {
  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 1200;

  static bool isCompactWidth(double width) => width < compactMaxWidth;
  static bool isMediumWidth(double width) =>
      width >= compactMaxWidth && width < mediumMaxWidth;
  static bool isExpandedWidth(double width) => width >= mediumMaxWidth;

  /// Postranní rail pro nastavení / navigaci sekce od šířky „medium“ výš (tablet + desktop).
  static bool useSettingsSideRail(double width) => width >= compactMaxWidth;

  /// Hlavní obálka aplikace (D15 / G1): `NavigationRail` místo spodního baru od stejného prahu.
  static bool useShellSideRail(double width) => width >= compactMaxWidth;

  /// Horní hranice čitelného bloku (px). Na širším okně zůstane obsah vycentrovaný.
  static const double contentMaxReading = 1320;

  static double maxContentWidth(double width) {
    if (width <= contentMaxReading) return width;
    return contentMaxReading;
  }

  static int formColumnsForWidth(double width) => width >= compactMaxWidth ? 2 : 1;
}

/// Dvousloupec formuláře jen na širším layoutu; na úzkém jeden sloupec.
Widget settingsFormGrid({
  required double maxWidth,
  required List<Widget> children,
}) {
  final cols = AppBreakpoints.formColumnsForWidth(maxWidth);
  if (cols == 1) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList(),
    );
  }
  return Wrap(
    spacing: 16,
    runSpacing: 12,
    children: children
        .map(
          (w) => SizedBox(
            width: (maxWidth - 16) / 2,
            child: w,
          ),
        )
        .toList(),
  );
}
