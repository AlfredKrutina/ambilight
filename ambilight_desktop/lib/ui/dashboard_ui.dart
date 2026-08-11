import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Sdílené tokeny a widgety dashboard UI (NVIDIA-like matte chrome).
abstract final class DashboardUi {
  static const double sidebarWidth = 220;
  static const double settingsRailWidth = 220;
  @Deprecated('Top chrome removed; kept for callers')
  static const double topChromeHeight = 0;
  static const double railWidth = 220;
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;

  /// Flat canvas — no soft gradients.
  static BoxDecoration pageBackdrop(ColorScheme scheme) {
    return BoxDecoration(color: scheme.surface);
  }

  static BoxDecoration railBackdrop(ColorScheme scheme) {
    return BoxDecoration(
      color: scheme.surfaceContainerLow,
      border: Border(
        right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
    );
  }
}

/// Matný panel (NVIDIA-style surface card).
class AmbiSurfacePanel extends StatelessWidget {
  const AmbiSurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = DashboardUi.radiusMd,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Zpětná kompatibilita — glass → matný surface.
class AmbiGlassPanel extends StatelessWidget {
  const AmbiGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = DashboardUi.radiusMd,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return AmbiSurfacePanel(
      padding: padding,
      borderRadius: borderRadius,
      child: child,
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

/// Jednotný nadpis stránky (NVIDIA content header).
class AmbiPageHeader extends StatelessWidget {
  const AmbiPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.bottomSpacing = 20,
    this.helpTooltip,
    this.helpDetails,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final double bottomSpacing;
  final String? helpTooltip;
  final String? helpDetails;
  final Widget? trailing;

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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
            if (hasHelp) AmbiHelpIcon(message: helpTooltip!, details: helpDetails),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

/// Nadpis sekce uvnitř stránky.
class AmbiSectionHeader extends StatelessWidget {
  const AmbiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.bottomSpacing = 10,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
              ),
            ),
            if (hasHelp) AmbiHelpIcon(message: helpTooltip!, details: helpDetails),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

/// Theme-aware feature card (replaces rainbow gradient tiles).
class AmbiFeatureCard extends StatelessWidget {
  const AmbiFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.selected = false,
    this.showSelectionCheckIcon = true,
    required this.onTap,
    this.onSecondaryTap,
    this.secondaryTooltip,
    this.minHeight = 100,
    this.tooltip,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool showSelectionCheckIcon;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final String? secondaryTooltip;
  final double minHeight;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
          focusColor: scheme.primary.withValues(alpha: 0.16),
          hoverColor: scheme.primary.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
              color: selected
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerHigh,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: selected ? scheme.primary : scheme.outlineVariant,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 22,
                                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                                ),
                                const Spacer(),
                                if (onSecondaryTap != null)
                                  IconButton(
                                    tooltip: secondaryTooltip,
                                    onPressed: onSecondaryTap,
                                    icon: Icon(Icons.tune_rounded, size: 18, color: scheme.onSurfaceVariant),
                                    visualDensity: VisualDensity.compact,
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(32, 32),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                if (selected && showSelectionCheckIcon)
                                  Icon(Icons.check_circle, color: scheme.primary, size: 18),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            if (subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.25,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

/// Legacy API — maps to [AmbiFeatureCard] (gradient ignored).
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
  final bool showSelectionCheckIcon;
  final VoidCallback onTap;
  final double minHeight;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return AmbiFeatureCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      selected: selected,
      showSelectionCheckIcon: showSelectionCheckIcon,
      onTap: onTap,
      minHeight: minHeight,
      tooltip: tooltip,
    );
  }
}

/// Položka levého menu (NVIDIA rail).
class AmbiSidebarTile extends StatelessWidget {
  const AmbiSidebarTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row = Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
          onTap: onTap,
          focusColor: scheme.primary.withValues(alpha: 0.18),
          hoverColor: scheme.onSurface.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
              color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12,
                        vertical: compact ? 10 : 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: selected ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                                    letterSpacing: -0.1,
                                    fontSize: compact ? 13 : 14,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
      ),
    );
  }
}
