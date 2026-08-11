import 'package:flutter/material.dart';

/// Palety rozhraní — výběr v Globální nastavení (`GlobalSettings.theme` + [normalizeAmbilightUiTheme]).
abstract final class AmbiLightTheme {
  static const Color _cyan = Color(0xFF22D3EE);
  static const Color _violet = Color(0xFFA78BFA);
  static const Color _coral = Color(0xFFF472B6);
  // Keep in sync with [DashboardUi] radii (NVIDIA-like flat chrome).
  static const double _rSm = 4;
  static const double _rMd = 8;
  static const double _rLg = 12;

  static ThemeData light({bool reducedMotion = false}) {
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
    return _build(colors, reducedMotion: reducedMotion);
  }

  /// Dřívější výchozí „tmavý“ vzhled — cyan / fialové akcenty na modré ploše.
  static ThemeData darkBlue({bool reducedMotion = false}) {
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
    return _build(colors, reducedMotion: reducedMotion);
  }

  /// Neutrální tmavý (orientačně „SnowRunner“) — šedé plochy, rezavý akcent bez neonové cyan.
  static ThemeData snowrunner({bool reducedMotion = false}) {
    const surface = Color(0xFF171718);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFFC2410C),
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: const Color(0xFFEA580C),
      onPrimary: const Color(0xFF1C0A00),
      primaryContainer: const Color(0xFF431407),
      onPrimaryContainer: const Color(0xFFFFEDD5),
      secondary: const Color(0xFFA8A29E),
      onSecondary: const Color(0xFF1C1917),
      secondaryContainer: const Color(0xFF44403C),
      onSecondaryContainer: const Color(0xFFE7E5E4),
      tertiary: const Color(0xFF78716C),
      onTertiary: Colors.white,
      onSurface: const Color(0xFFE7E5E4),
      onSurfaceVariant: const Color(0xFFA8A29E),
      outline: const Color(0xFF525252),
      outlineVariant: const Color(0xFF3F3F46),
      surfaceContainerHighest: const Color(0xFF27272A),
      surfaceContainerHigh: const Color(0xFF1F1F23),
      surfaceContainer: const Color(0xFF1A1A1D),
      surfaceContainerLow: const Color(0xFF141416),
    );
    return _build(colors, reducedMotion: reducedMotion);
  }

  /// NVIDIA-inspired — near-black surfaces, brand green `#76B900`.
  static ThemeData green({bool reducedMotion = false}) {
    const surface = Color(0xFF0D0D0D);
    final colors = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF76B900),
      onPrimary: const Color(0xFF0A0A0A),
      primaryContainer: const Color(0xFF3D5C00),
      onPrimaryContainer: const Color(0xFFD4F5A0),
      secondary: const Color(0xFFB0B0B0),
      onSecondary: const Color(0xFF121212),
      secondaryContainer: const Color(0xFF2A2A2A),
      onSecondaryContainer: const Color(0xFFE8E8E8),
      tertiary: const Color(0xFF8BC34A),
      onTertiary: const Color(0xFF0A0A0A),
      tertiaryContainer: const Color(0xFF2E3D14),
      onTertiaryContainer: const Color(0xFFE8F5C8),
      error: const Color(0xFFCF6679),
      onError: const Color(0xFF1A0004),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: surface,
      onSurface: const Color(0xFFE8E8E8),
      surfaceContainerHighest: const Color(0xFF2A2A2A),
      surfaceContainerHigh: const Color(0xFF1F1F1F),
      surfaceContainer: const Color(0xFF1A1A1A),
      surfaceContainerLow: const Color(0xFF121212),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      surfaceBright: const Color(0xFF2A2A2A),
      surfaceDim: const Color(0xFF0D0D0D),
      onSurfaceVariant: const Color(0xFFA0A0A0),
      outline: const Color(0xFF4A4A4A),
      outlineVariant: const Color(0xFF2E2E2E),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE8E8E8),
      onInverseSurface: const Color(0xFF1A1A1A),
      inversePrimary: const Color(0xFF3D5C00),
    );
    return _build(colors, reducedMotion: reducedMotion);
  }

  /// Coffee / kavárna — krémově-hnědé pozadí, tlumený „tmavší light“ (ne čistě bílý).
  static ThemeData coffee({bool reducedMotion = false}) {
    const surface = Color(0xFFDDD2C6);
    const onSurface = Color(0xFF2A211C);
    final colors = ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xFF5C4033),
      onPrimary: const Color(0xFFFFF4EC),
      primaryContainer: const Color(0xFFC4A882),
      onPrimaryContainer: const Color(0xFF2C1810),
      secondary: const Color(0xFF6D5B4D),
      onSecondary: const Color(0xFFFFF4EC),
      secondaryContainer: const Color(0xFFB5A08E),
      onSecondaryContainer: const Color(0xFF221A14),
      tertiary: const Color(0xFF8B7355),
      onTertiary: const Color(0xFFFFF4EC),
      tertiaryContainer: const Color(0xFFD4BC9E),
      onTertiaryContainer: const Color(0xFF2A1F14),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFF9DEDC),
      onErrorContainer: const Color(0xFF410E0B),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: const Color(0xFFC9B8A8),
      surfaceContainerHigh: const Color(0xFFD2C3B4),
      surfaceContainer: const Color(0xFFD8CABB),
      surfaceContainerLow: const Color(0xFFE3D6CA),
      surfaceContainerLowest: const Color(0xFFECE2D8),
      surfaceBright: const Color(0xFFE8DED4),
      surfaceDim: const Color(0xFFD0C4B6),
      onSurfaceVariant: const Color(0xFF52443C),
      outline: const Color(0xFF85756A),
      outlineVariant: const Color(0xFFB0A090),
      shadow: const Color(0xFF1A1410),
      scrim: const Color(0xFF1A1410),
      inverseSurface: const Color(0xFF38302A),
      onInverseSurface: const Color(0xFFF5EBE3),
      inversePrimary: const Color(0xFFD4BC9E),
    );
    return _build(colors, reducedMotion: reducedMotion);
  }

  static ThemeData themeForKey(String canonicalKey, {bool reducedMotion = false}) {
    switch (canonicalKey) {
      case 'light':
        return light(reducedMotion: reducedMotion);
      case 'coffee':
        return coffee(reducedMotion: reducedMotion);
      case 'snowrunner':
        return snowrunner(reducedMotion: reducedMotion);
      case 'green':
        return green(reducedMotion: reducedMotion);
      case 'dark_blue':
      default:
        return darkBlue(reducedMotion: reducedMotion);
    }
  }

  static ThemeData _build(ColorScheme colors, {required bool reducedMotion}) {
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: reducedMotion ? NoSplash.splashFactory : InkRipple.splashFactory,
      splashColor: reducedMotion ? Colors.transparent : null,
      highlightColor: reducedMotion ? Colors.transparent : null,
      hoverColor: reducedMotion ? Colors.transparent : null,
      focusColor: reducedMotion ? Colors.transparent : null,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: reducedMotion
              ? const _NoMotionPageTransitionsBuilder()
              : const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: reducedMotion
              ? const _NoMotionPageTransitionsBuilder()
              : const FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: reducedMotion
              ? const _NoMotionPageTransitionsBuilder()
              : const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rMd),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.85)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? colors.primary : colors.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_rSm)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_rSm),
          borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_rSm),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rLg)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        showDuration: const Duration(seconds: 5),
        decoration: BoxDecoration(
          color: colors.inverseSurface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(_rSm),
        ),
        textStyle: TextStyle(color: colors.onInverseSurface, fontSize: 12.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: colors.onSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
      ),
    );
  }
}

class _NoMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoMotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
