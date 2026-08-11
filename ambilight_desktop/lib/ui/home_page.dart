import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../features/spotify/spotify_service.dart';
import '../l10n/context_ext.dart';
import 'dashboard_ui.dart';
import 'layout_breakpoints.dart';
import 'responsive_body.dart';

typedef _HomeDev = ({String id, String name, String type, int ledCount});

typedef _HomePick = ({
  bool enabled,
  String startMode,
  bool spotifyConnected,
  bool spotifyIntegrationEnabled,
  bool smartLightsEnabled,
  bool haLooksConfigured,
  int smartFixtureCount,
  List<_HomeDev> devices,
});

_HomePick _homePick(AmbilightAppController c, SpotifyService sp) => (
      enabled: c.enabled,
      startMode: c.config.globalSettings.startMode,
      spotifyConnected: sp.isConnected,
      spotifyIntegrationEnabled: c.config.spotify.enabled,
      smartLightsEnabled: c.config.smartLights.enabled,
      haLooksConfigured: c.config.smartLights.haBaseUrl.trim().isNotEmpty &&
          c.config.smartLights.haLongLivedToken.trim().isNotEmpty,
      smartFixtureCount: c.config.smartLights.fixtures.length,
      devices: [
        for (final d in c.config.globalSettings.devices)
          (id: d.id, name: d.name, type: d.type, ledCount: d.ledCount),
      ],
    );

String _modeTileTooltip(BuildContext context, String id) {
  final l = context.l10n;
  switch (id) {
    case 'light':
      return l.modeLightTooltip;
    case 'screen':
      return l.modeScreenTooltip;
    case 'music':
      return l.modeMusicTooltip;
    case 'pchealth':
      return l.modePcHealthTooltip;
    default:
      return '';
  }
}

String _modeTitle(BuildContext context, String id) {
  final l = context.l10n;
  switch (id) {
    case 'light':
      return l.modeLightTitle;
    case 'screen':
      return l.modeScreenTitle;
    case 'music':
      return l.modeMusicTitle;
    case 'pchealth':
      return l.modePcHealthTitle;
    default:
      return id;
  }
}

/// Přehled: status (bez duplicitního power) → režimy → zařízení → zkratky.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  List<({String id, String title, String subtitle, IconData icon})> _modes(BuildContext context) {
    final l = context.l10n;
    return [
      (id: 'light', title: l.modeLightTitle, subtitle: l.modeLightSubtitle, icon: Icons.light_mode_rounded),
      (id: 'screen', title: l.modeScreenTitle, subtitle: l.modeScreenSubtitle, icon: Icons.desktop_windows_rounded),
      (id: 'music', title: l.modeMusicTitle, subtitle: l.modeMusicSubtitle, icon: Icons.graphic_eq_rounded),
      (id: 'pchealth', title: l.modePcHealthTitle, subtitle: l.modePcHealthSubtitle, icon: Icons.monitor_heart_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final layoutW = AppBreakpoints.layoutContentWidth(cw);

        return Selector2<AmbilightAppController, SpotifyService, _HomePick>(
          selector: (_, c, sp) => _homePick(c, sp),
          builder: (context, v, _) {
            final ctrl = context.read<AmbilightAppController>();
            final current = v.startMode;
            final modes = _modes(context);

            return ResponsiveBody(
              maxWidth: cw,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                    sliver: SliverToBoxAdapter(
                      child: AmbiPageHeader(
                        title: context.l10n.homeOverviewTitle,
                        subtitle: context.l10n.homeOverviewSubtitle,
                        bottomSpacing: 8,
                      ),
                    ),
                  ),

                  // Compact live status — power lives in the rail, not here.
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    sliver: SliverToBoxAdapter(
                      child: _StatusStrip(v: v, ctrl: ctrl, scheme: scheme),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: AmbiSectionHeader(
                        title: context.l10n.homeModeTitle,
                        subtitle: context.l10n.homeModeSubtitle,
                        helpTooltip: context.l10n.homeSectionModeHelpTooltip,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: AppBreakpoints.homeModeTileMaxExtent,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: AppBreakpoints.homeModeTileAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final m = modes[i];
                          return AmbiFeatureCard(
                            icon: m.icon,
                            title: m.title,
                            subtitle: m.subtitle,
                            selected: current == m.id,
                            showSelectionCheckIcon: true,
                            onTap: () => ctrl.setStartMode(m.id),
                            onSecondaryTap: () => ctrl.requestOpenSettingsForStartMode(m.id),
                            secondaryTooltip: context.l10n.modeSettingsTooltip(m.title),
                            minHeight: 88,
                            tooltip: _modeTileTooltip(context, m.id),
                          );
                        },
                        childCount: modes.length,
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: AmbiSectionHeader(
                              title: context.l10n.homeDevicesTitle,
                              subtitle: context.l10n.homeDevicesSubtitle,
                              helpTooltip: context.l10n.homeSectionDevicesHelpTooltip,
                              bottomSpacing: 0,
                            ),
                          ),
                          TextButton(
                            onPressed: () => ctrl.requestOpenDevices(),
                            child: Text(context.l10n.navDevices),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<Map<String, bool>>(
                      valueListenable: ctrl.connectionSnapshotNotifier,
                      builder: (context, snap, _) {
                        if (v.devices.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: AmbiSurfacePanel(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.hub_outlined, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      context.l10n.homeDevicesEmpty,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () => ctrl.requestOpenDevices(),
                                    child: Text(context.l10n.navDevices),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            itemCount: v.devices.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final d = v.devices[i];
                              return _DeviceChip(
                                name: d.name,
                                type: d.type,
                                ledCount: d.ledCount,
                                connected: snap[d.id] == true,
                                onTap: () => ctrl.requestOpenDevices(),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: AmbiSectionHeader(
                        title: context.l10n.homeIntegrationsTitle,
                        subtitle: context.l10n.homeIntegrationsSubtitle,
                        helpTooltip: context.l10n.homeSectionIntegrationsHelpTooltip,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                    sliver: SliverToBoxAdapter(
                      child: _QuickLinks(
                        layoutW: layoutW,
                        ctrl: ctrl,
                        v: v,
                        scheme: scheme,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Read-only status: output on/off + mode + device health. Power toggle is in the rail.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.v, required this.ctrl, required this.scheme});

  final _HomePick v;
  final AmbilightAppController ctrl;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final on = v.enabled;
    return AmbiSurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: ValueListenableBuilder<Map<String, bool>>(
        valueListenable: ctrl.connectionSnapshotNotifier,
        builder: (context, snap, _) {
          final ids = [for (final d in v.devices) d.id];
          var online = 0;
          for (final id in ids) {
            if (snap[id] == true) online++;
          }
          final total = ids.length;
          final linkOk = total == 0 || online >= total;

          return Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                icon: on ? Icons.bolt : Icons.bolt_outlined,
                label: on ? context.l10n.outputOn : context.l10n.outputOff,
                emphasized: on,
                scheme: scheme,
              ),
              _StatusPill(
                icon: Icons.tune_rounded,
                label: _modeTitle(context, v.startMode),
                emphasized: false,
                scheme: scheme,
                onTap: () => ctrl.requestOpenSettingsForStartMode(v.startMode),
              ),
              _StatusPill(
                icon: linkOk ? Icons.link_rounded : Icons.link_off_rounded,
                label: total == 0
                    ? context.l10n.footerNoOutputs
                    : (linkOk
                        ? context.l10n.allOutputsOnline(online, total)
                        : context.l10n.someOutputsOffline(online, total)),
                emphasized: !linkOk,
                danger: !linkOk && total > 0,
                scheme: scheme,
                onTap: () => ctrl.requestOpenDevices(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.emphasized,
    required this.scheme,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool emphasized;
  final bool danger;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? scheme.error
        : (emphasized ? scheme.primary : scheme.onSurfaceVariant);
    final bg = danger
        ? scheme.error.withValues(alpha: 0.12)
        : (emphasized ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHighest);

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: emphasized || danger ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
        child: child,
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({
    required this.name,
    required this.type,
    required this.ledCount,
    required this.connected,
    required this.onTap,
  });

  final String name;
  final String type;
  final int ledCount;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kind = type == 'wifi' ? context.l10n.kindWifi : context.l10n.kindUsb;
    return SizedBox(
      width: 200,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
          child: AmbiSurfacePanel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connected ? Icons.link_rounded : Icons.link_off_rounded,
                      size: 18,
                      color: connected ? scheme.primary : scheme.error,
                    ),
                    const Spacer(),
                    Text(kind, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  context.l10n.deviceLedSubtitle(kind, ledCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact integration shortcuts — open settings instead of embedding full forms.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({
    required this.layoutW,
    required this.ctrl,
    required this.v,
    required this.scheme,
  });

  final double layoutW;
  final AmbilightAppController ctrl;
  final _HomePick v;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final spotifyOk = v.spotifyConnected && v.spotifyIntegrationEnabled;
    final haOk = v.smartLightsEnabled && v.haLooksConfigured;
    final items = <_QuickItem>[
      _QuickItem(
        icon: Icons.graphic_eq_rounded,
        title: context.l10n.musicCardTitle,
        subtitle: spotifyOk ? context.l10n.spotifyConnected : context.l10n.spotifyDisconnected,
        ok: spotifyOk,
        onTap: () => ctrl.requestOpenSettingsTabIndex(AmbilightAppController.settingsTabSpotify),
      ),
      _QuickItem(
        icon: Icons.home_work_outlined,
        title: context.l10n.haCardTitle,
        subtitle: !v.smartLightsEnabled
            ? context.l10n.haStatusOff
            : (haOk ? context.l10n.haStatusOnOk(v.smartFixtureCount) : context.l10n.haStatusOnNeedUrl),
        ok: haOk,
        onTap: () => ctrl.requestOpenSettingsTabIndex(AmbilightAppController.settingsTabSmartIntegration),
      ),
      _QuickItem(
        icon: Icons.system_update_alt_rounded,
        title: context.l10n.fwCardTitle,
        subtitle: context.l10n.navUpdates,
        ok: true,
        onTap: () => ctrl.requestOpenUpdates(),
      ),
    ];

    final wide = layoutW >= 720;
    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _QuickLinkTile(item: items[i], scheme: scheme)),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _QuickLinkTile(item: items[i], scheme: scheme),
        ],
      ],
    );
  }
}

class _QuickItem {
  const _QuickItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final VoidCallback onTap;
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.item, required this.scheme});

  final _QuickItem item;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(DashboardUi.radiusMd),
        child: AmbiSurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(item.icon, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: item.ok ? scheme.onSurfaceVariant : scheme.error,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
