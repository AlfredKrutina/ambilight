import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import 'dashboard_ui.dart';
import 'guides/music_spotify_integration_guide.dart';
import 'layout_breakpoints.dart';
import 'responsive_body.dart';

typedef _HomeDev = ({String id, String name, String type, int ledCount, bool ok});

typedef _HomePick = ({
  bool enabled,
  String startMode,
  bool spotifyConnected,
  String? spotifyLastError,
  bool spotifyIntegrationEnabled,
  bool spotifyUseAlbumColors,
  String? spotifyClientId,
  List<_HomeDev> devices,
});

_HomePick _homePick(AmbilightAppController c) => (
      enabled: c.enabled,
      startMode: c.config.globalSettings.startMode,
      spotifyConnected: c.spotify.isConnected,
      spotifyLastError: c.spotify.lastError,
      spotifyIntegrationEnabled: c.config.spotify.enabled,
      spotifyUseAlbumColors: c.config.spotify.useAlbumColors,
      spotifyClientId: c.config.spotify.clientId,
      devices: [
        for (final d in c.config.globalSettings.devices)
          (id: d.id, name: d.name, type: d.type, ledCount: d.ledCount, ok: c.connectionSnapshot[d.id] ?? false),
      ],
    );

String _deviceStripSubtitle(String type, int ledCount) {
  final kind = type == 'wifi' ? 'Wi‑Fi' : 'USB';
  return '$kind · $ledCount LED';
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final _modes = <({
    String id,
    String title,
    String subtitle,
    IconData icon,
    Gradient gradient,
  })>[
    (
      id: 'light',
      title: 'Světlo',
      subtitle: 'Statické efekty, zóny, dýchání',
      icon: Icons.light_mode_rounded,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFB923C), Color(0xFFF472B6)],
      ),
    ),
    (
      id: 'screen',
      title: 'Obrazovka',
      subtitle: 'Ambilight ze snímku monitoru',
      icon: Icons.desktop_windows_rounded,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
      ),
    ),
    (
      id: 'music',
      title: 'Hudba',
      subtitle: 'FFT, melodie, barvy',
      icon: Icons.graphic_eq_rounded,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
      ),
    ),
    (
      id: 'pchealth',
      title: 'PC Health',
      subtitle: 'Teploty, zátěž, vizualizace',
      icon: Icons.monitor_heart_rounded,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D9488), Color(0xFF22C55E)],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final layoutW = AppBreakpoints.layoutContentWidth(cw);
        final useWideHero = layoutW >= 760;

        return Selector<AmbilightAppController, _HomePick>(
          selector: (_, c) => _homePick(c),
          builder: (context, v, _) {
            final ctrl = context.read<AmbilightAppController>();
            final current = v.startMode;
            return ResponsiveBody(
              maxWidth: cw,
              child: CustomScrollView(
                slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          sliver: SliverToBoxAdapter(
            child: AmbiPageHeader(
              title: 'Přehled',
              subtitle:
                  'Zapni výstup, vyber režim a zkontroluj připojení. Podrobná konfigurace je v záložkách Zařízení a Nastavení.',
              bottomSpacing: 8,
            ),
          ),
        ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: useWideHero
                          ? _heroRowWide(context, ctrl, scheme, v, layoutW)
                          : _heroColumn(context, ctrl, scheme, v),
                    ),
                  ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AmbiSectionHeader(
              title: 'Režim',
              subtitle:
                  'Klepnutím na dlaždici změníš aktivní režim. Ikona tužky v rohu otevře Nastavení přímo pro daný režim.',
            ),
          ),
        ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: AppBreakpoints.homeModeTileMaxExtent,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: AppBreakpoints.homeModeTileAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final m = _modes[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(DashboardUi.radiusLg),
                            child: Stack(
                              fit: StackFit.passthrough,
                              children: [
                                AmbiGradientTile(
                                  gradient: m.gradient,
                                  icon: m.icon,
                                  title: m.title,
                                  subtitle: m.subtitle,
                                  selected: current == m.id,
                                  showSelectionCheckIcon: false,
                                  onTap: () => ctrl.setStartMode(m.id),
                                  minHeight: 96,
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: IconButton.filledTonal(
                                          tooltip: 'Nastavení režimu „${m.title}“',
                                          style: IconButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            backgroundColor: Colors.black.withValues(alpha: 0.28),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(34, 34),
                                            maximumSize: const Size(34, 34),
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () => ctrl.requestOpenSettingsForStartMode(m.id),
                                          icon: const Icon(Icons.tune_rounded, size: 18),
                                        ),
                                      ),
                                      if (current == m.id) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white.withValues(alpha: 0.95),
                                          size: 24,
                                          shadows: const [
                                            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _modes.length,
                      ),
                    ),
                  ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AmbiSectionHeader(
              title: 'Spotify',
              subtitle:
                  'Barvy z alba: Spotify (OAuth) nebo na Windows z aktuálního OS přehrávače (Apple Music, často YouTube v prohlížeči). Tokeny a Client ID: Nastavení → Spotify.',
            ),
          ),
        ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: _SpotifyCard(
                        c: ctrl,
                        scheme: scheme,
                        connected: v.spotifyConnected,
                        lastError: v.spotifyLastError,
                        integrationEnabled: v.spotifyIntegrationEnabled,
                        useAlbumColors: v.spotifyUseAlbumColors,
                        clientId: v.spotifyClientId,
                      ),
                    ),
                  ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AmbiSectionHeader(
              title: 'Zařízení',
              subtitle:
                  'Rychlý náhled stavu. Úpravy pásku, discovery a sítě jsou v hlavní sekci „Zařízení“ v navigaci.',
            ),
          ),
        ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 132,
                      child: v.devices.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: AmbiGlassPanel(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                        child: Text(
                          'Žádné výstupní zařízení — běžný stav, dokud nepřipojíš pásek.\n\n'
                          'Můžeš nastavovat režimy, presety a zálohu. Pro odesílání barev přidej zařízení v „Zařízení“ (Discovery nebo ručně).',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: v.devices.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final d = v.devices[i];
                                return _DeviceStripCard(
                                  name: d.name,
                                  type: d.type,
                                  ledCount: d.ledCount,
                                  connected: d.ok,
                                );
                              },
                            ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
              child: AmbiGlassPanel(
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
        AmbiGlassPanel(
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
        return Material(
          borderRadius: BorderRadius.circular(DashboardUi.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: on
                    ? [const Color(0xFF6366F1), const Color(0xFFEC4899)]
                    : [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh],
              ),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            ),
            padding: EdgeInsets.all(bx.maxWidth > 520 ? 22 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      on ? Icons.play_circle_fill_rounded : Icons.pause_circle_outline_rounded,
                      size: iconSize,
                      color: on ? Colors.white : scheme.onSurfaceVariant,
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: on,
                      onChanged: c.setEnabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Výstup na LED',
                  style: titleStyle?.copyWith(
                        color: on ? Colors.white : scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  on ? 'Barvy se posílají na všechna aktivní zařízení.' : 'Vypnuto — pásky dostanou černou.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: on ? Colors.white.withValues(alpha: 0.92) : scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
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
        Text('Služba', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.35),
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Běží na pozadí', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'Aplikace průběžně připravuje barvy pro pásky. '
                    'Stav se mění při přepnutí režimu nebo zařízení. '
                    '(Snímků: ${context.select<AmbilightAppController, int>((c) => c.animationTick)})',
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

class _SpotifyCard extends StatelessWidget {
  const _SpotifyCard({
    required this.c,
    required this.scheme,
    required this.connected,
    required this.lastError,
    required this.integrationEnabled,
    required this.useAlbumColors,
    required this.clientId,
  });

  final AmbilightAppController c;
  final ColorScheme scheme;
  final bool connected;
  final String? lastError;
  final bool integrationEnabled;
  final bool useAlbumColors;
  final String? clientId;

  @override
  Widget build(BuildContext context) {
    return AmbiGlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                size: 22,
                color: connected ? scheme.secondary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                connected ? 'Připojeno' : 'Nepřipojeno',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lastError ??
                ((clientId == null || clientId!.isEmpty)
                    ? 'Pro přihlášení k účtu Spotify doplníš Client ID v Nastavení → Spotify.'
                    : 'Po „Přihlásit“ potvrdíš přístup v prohlížeči; návrat proběhne automaticky na tento počítač.'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => MusicSpotifyIntegrationGuide.show(context),
              icon: const Icon(Icons.menu_book_outlined, size: 20),
              label: const Text('Nápověda: hudba a obaly'),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Spotify integrace (OAuth + API)'),
            subtitle: const Text('Zapne dotazování účtu; vypnutím se zastaví polling.'),
            value: integrationEnabled,
            onChanged: c.setSpotifyIntegrationEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Barvy z alba přes Spotify'),
            subtitle: const Text('V music módu má přednost před FFT, pokud API vrátí obal.'),
            value: useAlbumColors,
            onChanged: integrationEnabled ? c.setSpotifyUseAlbumColors : null,
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonal(onPressed: () => c.spotifyConnect(), child: const Text('Přihlásit')),
              OutlinedButton(onPressed: () => c.spotifyDisconnect(), child: const Text('Odpojit')),
            ],
          ),
        ],
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
      child: AmbiGlassPanel(
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
                  type == 'wifi' ? 'Wi‑Fi' : 'USB',
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
              '${_deviceStripSubtitle(type, ledCount)} · ${connected ? "připojeno" : "nepřipojeno"}',
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
