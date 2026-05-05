import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Sdílené widgety dashboard UI (glass, gradient, navigace).
abstract final class DashboardUi {
  static const double sidebarWidth = 264;
  static const double topChromeHeight = 56;
  static const double radiusLg = 20;
  static const double radiusMd = 14;

  /// Jemné pozadí hlavního obsahu.
  static BoxDecoration pageBackdrop(ColorScheme scheme) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.surface,
          Color.lerp(scheme.surface, scheme.primaryContainer, 0.08)!,
        ],
      ),
    );
  }
}

/// Rozmazaný panel (glassmorphism light).
class AmbiGlassPanel extends StatelessWidget {
  const AmbiGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = DashboardUi.radiusLg,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.42 : 0.75),
                scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.28 : 0.55),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Ikona „i“ — tooltip při najetí; volitelně delší text v dialogu po kliknutí.
class AmbiHelpIcon extends StatelessWidget {
  const AmbiHelpIcon({
    super.key,
    required this.message,
    this.details,
  });

  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant);
    final hasDetails = details != null && details!.trim().isNotEmpty;
    if (hasDetails) {
      return IconButton(
        icon: icon,
        tooltip: message,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          final l10n = AppLocalizations.of(context);
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.help),
              content: SingleChildScrollView(
                child: Text(details!, style: Theme.of(ctx).textTheme.bodyMedium),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
              ],
            ),
          );
        },
      );
    }
    return Tooltip(
      message: message,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 1),
        child: icon,
      ),
    );
  }
}

/// Jednotný nadpis stránky (Přehled, Zařízení, O aplikaci).
class AmbiPageHeader extends StatelessWidget {
  const AmbiPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.bottomSpacing = 16,
    this.helpTooltip,
    this.helpDetails,
  });

  final String title;
  final String? subtitle;
  final double bottomSpacing;
  final String? helpTooltip;
  final String? helpDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasHelp = helpTooltip != null && helpTooltip!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (hasHelp) AmbiHelpIcon(message: helpTooltip!, details: helpDetails),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

/// Nadpis sekce uvnitř stránky (Režim, Integrace, …).
class AmbiSectionHeader extends StatelessWidget {
  const AmbiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.bottomSpacing = 8,
    this.helpTooltip,
    this.helpDetails,
  });

  final String title;
  final String? subtitle;
  final double bottomSpacing;
  final String? helpTooltip;
  final String? helpDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasHelp = helpTooltip != null && helpTooltip!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (hasHelp) AmbiHelpIcon(message: helpTooltip!, details: helpDetails),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

/// Karta ve stylu „Shortcuts“ — silná výplň, ikona, titulek.
/// Výšku i šířku určí rodič (např. mřížka); [minHeight] je jen spodní hranice při volném layoutu.
class AmbiGradientTile extends StatelessWidget {
  const AmbiGradientTile({
    super.key,
    required this.gradient,
    required this.icon,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.showSelectionCheckIcon = true,
    required this.onTap,
    this.minHeight = 100,
    this.tooltip,
  });

  final Gradient gradient;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  /// U dlaždice s překryvným tlačítkem v [Stack] vypni, aby fajfka nebyla dvakrát (viz domovský Režim).
  final bool showSelectionCheckIcon;
  final VoidCallback onTap;
  final double minHeight;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = StringBuffer(title);
    if (subtitle != null && subtitle!.isNotEmpty) {
      semanticsLabel.write(', ${subtitle!}');
    }
    if (selected) semanticsLabel.write(AppLocalizations.of(context).semanticsSelected);
    Widget tile = Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel.toString(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DashboardUi.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DashboardUi.radiusLg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DashboardUi.radiusLg),
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.35 : 0.2),
                  blurRadius: selected ? 20 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: selected ? Colors.white.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final iconSz = (24 - (c.maxWidth - 220) * 0.012).clamp(20, 24).toDouble();
                    const designH = 96.0;
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth, maxHeight: designH),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: iconSz),
                                const Spacer(),
                                if (selected && showSelectionCheckIcon)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white.withValues(alpha: 0.95),
                                    size: iconSz * 0.78,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      height: 1.25,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tip = tooltip;
    if (tip != null && tip.trim().isNotEmpty) {
      tile = Tooltip(message: tip, child: tile);
    }
    return tile;
  }
}

/// Položka levého menu (sidebar).
class AmbiSidebarTile extends StatelessWidget {
  const AmbiSidebarTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                          letterSpacing: -0.1,
                        ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final tip = tooltip;
    if (tip != null && tip.trim().isNotEmpty) {
      row = Tooltip(message: tip, child: row);
    }
    return row;
  }
}

/// Nadpisek skupiny v sidebaru (nastavení).
class AmbiSidebarSectionLabel extends StatelessWidget {
  const AmbiSidebarSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
