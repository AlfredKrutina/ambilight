import 'package:flutter/material.dart';

/// Dashboard paleta (tmavý SaaS + světlý „mint“).
abstract final class AmbiLightTheme {
  static const Color _cyan = Color(0xFF22D3EE);
  static const Color _violet = Color(0xFFA78BFA);
  static const Color _coral = Color(0xFFF472B6);

  static ThemeData light() {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D9488),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0F766E),
      onPrimary: Colors.white,
      secondary: const Color(0xFF6366F1),
      tertiary: const Color(0xFFEA580C),
      surface: const Color(0xFFF8FAFC),
      surfaceContainerLow: const Color(0xFFEEF2FF),
      surfaceContainerHigh: const Color(0xFFE2E8F0),
      surfaceContainerHighest: const Color(0xFFCBD5E1),
    );
    return _build(colors);
  }

  static ThemeData dark() {
    const surface = Color(0xFF0B0F14);
    final colors = ColorScheme.fromSeed(
      seedColor: _cyan,
      brightness: Brightness.dark,
      primary: _cyan,
      secondary: _violet,
      tertiary: _coral,
      surface: surface,
    ).copyWith(
      onPrimary: const Color(0xFF042F2E),
      primaryContainer: const Color(0xFF134E4A),
      onPrimaryContainer: const Color(0xFFCCFBF1),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF4C1D95),
      onSecondaryContainer: const Color(0xFFEDE9FE),
      onTertiary: const Color(0xFF1E1B4B),
      tertiaryContainer: const Color(0xFF831843),
      onTertiaryContainer: const Color(0xFFFCE7F3),
      onSurface: const Color(0xFFF1F5F9),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: const Color(0xFF334155),
      outlineVariant: const Color(0xFF1E293B),
      surfaceContainerHighest: const Color(0xFF1E293B),
      surfaceContainerHigh: const Color(0xFF162032),
      surfaceContainer: const Color(0xFF121826),
      surfaceContainerLow: const Color(0xFF0F141C),
    );
    return _build(colors);
  }

  static ThemeData _build(ColorScheme colors) {
    final isDark = colors.brightness == Brightness.dark;
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: colors.surfaceContainer.withValues(alpha: 0.4),
        foregroundColor: colors.onSurface,
        surfaceTintColor: colors.primary.withValues(alpha: 0.12),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerHighest.withValues(alpha: isDark ? 0.55 : 0.92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colors.surfaceContainer.withValues(alpha: 0.95),
        indicatorColor: colors.primary.withValues(alpha: 0.28),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? colors.primary : colors.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh.withValues(alpha: 0.65),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
    );
  }
}
