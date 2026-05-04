import 'dart:math' as math;

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

  /// Horní hranice čitelného bloku (px). Na ultrawide zůstane obsah vycentrovaný, řádky se nepřetahují.
  static const double contentMaxReading = 1180;

  /// Dlaždice režimu na přehledu — max. šířka buňky (více sloupců místo dvou „nárazníků“).
  static const double homeModeTileMaxExtent = 276;

  /// Šířka / výška buňky mřížky režimů (šířší = nižší řádek).
  static const double homeModeTileAspectRatio = 2.35;

  /// Max. šířka horní „power“ karty na širokém layoutu (zbytek řádku zůstane vzdušný).
  static const double homeHeroPowerMaxWidth = 560;

  static double maxContentWidth(double width) {
    if (width <= contentMaxReading) return width;
    return contentMaxReading;
  }

  /// Vnitřní šířka záložek Nastavení. Nahrazuje nebezpečný vzor
  /// `maxContentWidth(w).clamp(280, w)` — při `w < 280` by [num.clamp] spadl (nesplní se min ≤ max).
  static double settingsContentInnerMax(double parentWidth) {
    var p = parentWidth;
    if (!p.isFinite || p < 0) p = 280.0;
    final capped = maxContentWidth(p);
    final lo = math.min(280.0, p);
    final hi = math.max(lo, p);
    return capped.clamp(lo, hi);
  }

  /// Šířka pro layout logiku na stránkách zabalených v [ResponsiveBody] (stejný strop jako obsah).
  static double layoutContentWidth(double parentWidth) => maxContentWidth(parentWidth);

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
