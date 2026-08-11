import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../core/models/config_models.dart';
import '../features/spotify/spotify_service.dart';
import '../l10n/context_ext.dart';
import 'dashboard_ui.dart';
import 'guides/music_spotify_integration_guide.dart';
import 'layout_breakpoints.dart';
import 'responsive_body.dart';

typedef _HomeDev = ({String id, String name, String type, int ledCount});

typedef _HomePick = ({
  bool enabled,
  String startMode,
  bool spotifyConnected,
  String? spotifyLastError,
  bool spotifyIntegrationEnabled,
  bool spotifyUseAlbumColors,
  String? spotifyClientId,
  bool smartLightsEnabled,
  bool haLooksConfigured,
  int smartFixtureCount,
  String firmwareManifestDisplay,
  List<_HomeDev> devices,
});

_HomePick _homePick(AmbilightAppController c, SpotifyService sp) => (
      enabled: c.enabled,
      startMode: c.config.globalSettings.startMode,
      spotifyConnected: sp.isConnected,
      spotifyLastError: sp.lastError,
      spotifyIntegrationEnabled: c.config.spotify.enabled,
      spotifyUseAlbumColors: c.config.spotify.useAlbumColors,
      spotifyClientId: c.config.spotify.clientId,
      smartLightsEnabled: c.config.smartLights.enabled,
      haLooksConfigured: c.config.smartLights.haBaseUrl.trim().isNotEmpty &&
          c.config.smartLights.haLongLivedToken.trim().isNotEmpty,
      smartFixtureCount: c.config.smartLights.fixtures.length,
      firmwareManifestDisplay: effectiveFirmwareManifestUrl(c.config.globalSettings.firmwareManifestUrl),
      devices: [
        for (final d in c.config.globalSettings.devices)
          (id: d.id, name: d.name, type: d.type, ledCount: d.ledCount),
      ],
    );

String _deviceStripSubtitle(BuildContext context, String type, int ledCount) {
  final l10n = context.l10n;
  final kind = type == 'wifi' ? l10n.kindWifi : l10n.kindUsb;
  return l10n.deviceLedSubtitle(kind, ledCount);
}

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  List<
      ({
        String id,
        String title,
        String subtitle,
        IconData icon,
      })> _modes(BuildContext context) {
    final l = context.l10n;
    return [
      (
        id: 'light',
        title: l.modeLightTitle,
        subtitle: l.modeLightSubtitle,
        icon: Icons.light_mode_rounded,
      ),
      (
        id: 'screen',
        title: l.modeScreenTitle,
        subtitle: l.modeScreenSubtitle,
        icon: Icons.desktop_windows_rounded,
      ),
      (
        id: 'music',
        title: l.modeMusicTitle,
        subtitle: l.modeMusicSubtitle,
        icon: Icons.graphic_eq_rounded,
      ),
      (
        id: 'pchealth',
        title: l.modePcHealthTitle,
        subtitle: l.modePcHealthSubtitle,
        icon: Icons.monitor_heart_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final layoutW = AppBreakpoints.layoutContentWidth(cw);
        final useWideHero = layoutW >= 760;

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
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 4),
                    sliver: SliverToBoxAdapter(
                      child: AmbiPageHeader(
                        title: context.l10n.homeOverviewTitle,
                        subtitle: context.l10n.homeOverviewSubtitle,
                        bottomSpacing: 12,
                        trailing: useWideHero
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => ctrl.requestOpenDevices(),
                                    icon: const Icon(Icons.hub_outlined, size: 18),
                                    label: Text(context.l10n.navDevices),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => ctrl.requestOpenUpdates(),
                                    icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                                    label: Text(context.l10n.navUpdates),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    sliver: SliverToBoxAdapter(
                      child: useWideHero
                          ? _heroRowWide(context, ctrl, scheme, v, layoutW)
                          : _heroColumn(context, ctrl, scheme, v),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
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
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
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
                            minHeight: 96,
                            tooltip: _modeTileTooltip(context, m.id),
                          );
                        },
                        childCount: modes.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: AmbiSectionHeader(
                        title: context.l10n.homeIntegrationsTitle,
                        subtitle: context.l10n.homeIntegrationsSubtitle,
                        helpTooltip: context.l10n.homeSectionIntegrationsHelpTooltip,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                    sliver: SliverToBoxAdapter(
                      child: _IntegrationsDashboardRow(
                        layoutW: layoutW,
                        ctrl: ctrl,
                        scheme: scheme,
                        v: v,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                    sliver: SliverToBoxAdapter(
                      child: AmbiSectionHeader(
                        title: context.l10n.homeDevicesTitle,
                        subtitle: context.l10n.homeDevicesSubtitle,
                        helpTooltip: context.l10n.homeSectionDevicesHelpTooltip,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<Map<String, bool>>(
                      valueListenable: ctrl.connectionSnapshotNotifier,
                      builder: (context, snap, _) {
                        return SizedBox(
                          height: 132,
                          child: v.devices.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  child: AmbiSurfacePanel(
                                    padding: const EdgeInsets.all(20),
                                    child: Center(
                                      child: Text(
                                        context.l10n.homeDevicesEmpty,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  itemCount: v.devices.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, i) {
                                    final d = v.devices[i];
                                    return _DeviceStripCard(
                                      name: d.name,
                                      type: d.type,
                                      ledCount: d.ledCount,
                                      connected: snap[d.id] == true,
                                    );
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 36)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _heroRowWide(
    BuildContext context,
    AmbilightAppController c,
    ColorScheme scheme,
    _HomePick v,
    double layoutW,
  ) {
    final powerMax =
        (layoutW * 0.52).clamp(360.0, AppBreakpoints.homeHeroPowerMaxWidth).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: powerMax),
              child: _PowerHeroCard(c: c, scheme: scheme, enabled: v.enabled),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: (layoutW * 0.46).clamp(280.0, 420.0).toDouble()),
              child: AmbiSurfacePanel(
                padding: const EdgeInsets.all(18),
                child: _EngineStatus(scheme: scheme),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroColumn(
    BuildContext context,
    AmbilightAppController c,
    ColorScheme scheme,
    _HomePick v,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PowerHeroCard(c: c, scheme: scheme, enabled: v.enabled),
        const SizedBox(height: 14),
        AmbiSurfacePanel(
          padding: const EdgeInsets.all(18),
          child: _EngineStatus(scheme: scheme),
        ),
      ],
    );
  }
}

class _PowerHeroCard extends StatelessWidget {
  const _PowerHeroCard({required this.c, required this.scheme, required this.enabled});

  final AmbilightAppController c;
  final ColorScheme scheme;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final on = enabled;
    return LayoutBuilder(
      builder: (context, bx) {
        final iconSize = (38 - (bx.maxWidth - 400) * 0.02).clamp(28, 36).toDouble();
        final titleStyle = bx.maxWidth > 520
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.titleMedium;
        return AmbiSurfacePanel(
          padding: EdgeInsets.all(bx.maxWidth > 520 ? 22 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    on ? Icons.play_circle_fill_rounded : Icons.pause_circle_outline_rounded,
                    size: iconSize,
                    color: on ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: on,
                    onChanged: c.setEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.homeLedOutputTitle,
                style: titleStyle?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                on ? context.l10n.homeLedOutputOnBody : context.l10n.homeLedOutputOffBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (on) ...[
                const SizedBox(height: 14),
                Container(
                  height: 3,
                  width: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EngineStatus extends StatelessWidget {
  const _EngineStatus({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.homeServiceTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
                  color: scheme.primary.withValues(alpha: 0.14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(Icons.blur_on_rounded, color: scheme.primary, size: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.homeBackgroundTitle, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    context.l10n.homeBackgroundBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntegrationsDashboardRow extends StatelessWidget {
  const _IntegrationsDashboardRow({
    required this.layoutW,
    required this.ctrl,
    required this.scheme,
    required this.v,
  });

  final double layoutW;
  final AmbilightAppController ctrl;
  final ColorScheme scheme;
  final _HomePick v;

  @override
  Widget build(BuildContext context) {
    final wide = layoutW >= 720;
    final music = _IntegrationMusicCard(c: ctrl, scheme: scheme, v: v);
    final ha = _IntegrationHaCard(ctrl: ctrl, scheme: scheme, v: v);
    final fw = _IntegrationFirmwareCard(ctrl: ctrl, scheme: scheme, v: v);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: music),
          const SizedBox(width: 12),
          Expanded(child: ha),
          const SizedBox(width: 12),
          Expanded(child: fw),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        music,
        const SizedBox(height: 12),
        ha,
        const SizedBox(height: 12),
        fw,
      ],
    );
  }
}

class _IntegrationCardHeader extends StatelessWidget {
  const _IntegrationCardHeader({
    required this.title,
    required this.icon,
    required this.scheme,
    required this.onOpenSettings,
  });

  final String title;
  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: onOpenSettings,
          child: Text(context.l10n.integrationSettingsButton),
        ),
      ],
    );
  }
}

class _IntegrationMusicCard extends StatelessWidget {
  const _IntegrationMusicCard({required this.c, required this.scheme, required this.v});

  final AmbilightAppController c;
  final ColorScheme scheme;
  final _HomePick v;

  @override
  Widget build(BuildContext context) {
    final connected = v.spotifyConnected;
    final clientId = v.spotifyClientId;
    return Tooltip(
      message: context.l10n.integrationMusicCardTooltip,
      child: AmbiSurfacePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IntegrationCardHeader(
            title: context.l10n.musicCardTitle,
            icon: Icons.graphic_eq_rounded,
            scheme: scheme,
            onOpenSettings: () => c.requestOpenSettingsTabIndex(AmbilightAppController.settingsTabSpotify),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                connected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                size: 22,
                color: connected ? scheme.secondary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  connected ? context.l10n.spotifyConnected : context.l10n.spotifyDisconnected,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            v.spotifyLastError ??
                ((clientId == null || clientId.isEmpty)
                    ? context.l10n.spotifyHintNeedClientId
                    : context.l10n.spotifyHintLogin),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => MusicSpotifyIntegrationGuide.show(context),
              icon: const Icon(Icons.menu_book_outlined, size: 20),
              label: Text(context.l10n.help),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.spotifyOAuthTitle),
            subtitle: Text(context.l10n.spotifyOAuthSubtitle),
            value: v.spotifyIntegrationEnabled,
            onChanged: c.setSpotifyIntegrationEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.spotifyAlbumColorsTitle),
            subtitle: Text(context.l10n.spotifyAlbumColorsSubtitle),
            value: v.spotifyUseAlbumColors,
            onChanged: v.spotifyIntegrationEnabled ? c.setSpotifyUseAlbumColors : null,
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonal(onPressed: () => c.spotifyConnect(), child: Text(context.l10n.signIn)),
              OutlinedButton(onPressed: () => c.spotifyDisconnect(), child: Text(context.l10n.signOut)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _IntegrationHaCard extends StatelessWidget {
  const _IntegrationHaCard({required this.ctrl, required this.scheme, required this.v});

  final AmbilightAppController ctrl;
  final ColorScheme scheme;
  final _HomePick v;

  @override
  Widget build(BuildContext context) {
    final on = v.smartLightsEnabled;
    final ok = v.haLooksConfigured;
    final statusLine = !on
        ? context.l10n.haStatusOff
        : ok
            ? context.l10n.haStatusOnOk(v.smartFixtureCount)
            : context.l10n.haStatusOnNeedUrl;
    final detail = ok ? context.l10n.haDetailOk : context.l10n.haDetailNeedUrl;

    return Tooltip(
      message: context.l10n.integrationHaCardTooltip,
      child: AmbiSurfacePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IntegrationCardHeader(
            title: context.l10n.haCardTitle,
            icon: Icons.home_work_outlined,
            scheme: scheme,
            onOpenSettings: () => ctrl.requestOpenSettingsTabIndex(AmbilightAppController.settingsTabSmartIntegration),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                on && ok ? Icons.check_circle_rounded : Icons.tune_rounded,
                size: 22,
                color: on && ok ? scheme.secondary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusLine,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }
}

class _IntegrationFirmwareCard extends StatelessWidget {
  const _IntegrationFirmwareCard({required this.ctrl, required this.scheme, required this.v});

  final AmbilightAppController ctrl;
  final ColorScheme scheme;
  final _HomePick v;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.integrationFirmwareCardTooltip,
      child: AmbiSurfacePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IntegrationCardHeader(
            title: context.l10n.fwCardTitle,
            icon: Icons.system_update_alt_rounded,
            scheme: scheme,
            onOpenSettings: () => ctrl.requestOpenUpdates(),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.fwManifestLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            v.firmwareManifestDisplay,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.fwManifestHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }
}

class _DeviceStripCard extends StatelessWidget {
  const _DeviceStripCard({
    required this.name,
    required this.type,
    required this.ledCount,
    required this.connected,
  });

  final String name;
  final String type;
  final int ledCount;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: AmbiSurfacePanel(
        padding: const EdgeInsets.all(14),
        borderRadius: DashboardUi.radiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connected ? Icons.link_rounded : Icons.link_off_rounded,
                  size: 20,
                  color: connected ? scheme.primary : scheme.error,
                ),
                const Spacer(),
                Text(
                  type == 'wifi' ? context.l10n.kindWifi : context.l10n.kindUsb,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              context.l10n.deviceStripStateLine(
                _deviceStripSubtitle(context, type, ledCount),
                connected ? context.l10n.deviceConnected : context.l10n.deviceDisconnected,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
