import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import 'dashboard_ui.dart';
import 'responsive_body.dart';

typedef _HomeDev = ({String id, String name, String type, int ledCount, bool ok});

typedef _HomePick = ({
  bool enabled,
  String startMode,
  bool spotifyConnected,
  String? spotifyLastError,
  bool spotifyAlbumIntegration,
  String? spotifyClientId,
  List<_HomeDev> devices,
});

_HomePick _homePick(AmbilightAppController c) => (
      enabled: c.enabled,
      startMode: c.config.globalSettings.startMode,
      spotifyConnected: c.spotify.isConnected,
      spotifyLastError: c.spotify.lastError,
      spotifyAlbumIntegration: c.config.spotify.enabled,
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
        final wide = cw >= 760;
        final gridCols = cw >= 520 ? 2 : 1;

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
                      child: wide ? _heroRowWide(context, ctrl, scheme, v) : _heroColumn(context, ctrl, scheme, v),
                    ),
                  ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: AmbiSectionHeader(
              title: 'Režim',
              subtitle: 'Co se právě promítá na pásky. Jednotlivé předvolby upravíš v Nastavení podle režimu.',
            ),
          ),
        ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: gridCols == 2 ? 1.35 : 1.5,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final m = _modes[i];
                          return AmbiGradientTile(
                            gradient: m.gradient,
                            icon: m.icon,
                            title: m.title,
                            subtitle: m.subtitle,
                            selected: current == m.id,
                            onTap: () => ctrl.setStartMode(m.id),
                            minHeight: 108,
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
                        albumColorsEnabled: v.spotifyAlbumIntegration,
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
                          'Zatím nemáš žádné zařízení.\n\nV navigaci otevři „Zařízení“ a použij Discovery nebo průvodce přidáním pásku.',
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
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _PowerHeroCard(c: c, scheme: scheme, enabled: v.enabled),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: AmbiGlassPanel(
            padding: const EdgeInsets.all(18),
            child: _EngineStatus(scheme: scheme),
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
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  on ? Icons.play_circle_fill_rounded : Icons.pause_circle_outline_rounded,
                  size: 40,
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 4,
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
                    '(Snímků: ${context.watch<AmbilightAppController>().animationTick})',
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
    required this.albumColorsEnabled,
    required this.clientId,
  });

  final AmbilightAppController c;
  final ColorScheme scheme;
  final bool connected;
  final String? lastError;
  final bool albumColorsEnabled;
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
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Barvy alba v music módu'),
            value: albumColorsEnabled,
            onChanged: c.setSpotifyIntegrationEnabled,
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
