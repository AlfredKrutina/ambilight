import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../core/models/config_models.dart';
import 'dashboard_ui.dart';
import 'responsive_body.dart';

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
    final c = context.watch<AmbilightAppController>();
    final scheme = Theme.of(context).colorScheme;
    final current = c.config.globalSettings.startMode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final wide = cw >= 760;
        final gridCols = cw >= 520 ? 2 : 1;

        return ResponsiveBody(
          maxWidth: cw,
          child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Přehled',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nejpoužívanější ovládání nahoře; detaily v Zařízení a Nastavení.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: wide ? _heroRowWide(context, c, scheme) : _heroColumn(context, c, scheme),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Režim',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  onTap: () => c.setStartMode(m.id),
                  minHeight: 108,
                );
              },
              childCount: _modes.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Spotify',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          sliver: SliverToBoxAdapter(child: _SpotifyCard(c: c, scheme: scheme)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Zařízení — zkratka (plná správa vlevo v menu)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 132,
            child: c.config.globalSettings.devices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AmbiGlassPanel(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Žádné zařízení — otevři sekci Zařízení a přidej strip nebo discovery.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: c.config.globalSettings.devices.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final d = c.config.globalSettings.devices[i];
                      final ok = c.connectionSnapshot[d.id] ?? false;
                      return _DeviceStripCard(device: d, connected: ok);
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
  }

  Widget _heroRowWide(BuildContext context, AmbilightAppController c, ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _PowerHeroCard(c: c, scheme: scheme),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: AmbiGlassPanel(
            padding: const EdgeInsets.all(18),
            child: _EngineStatus(c: c, scheme: scheme),
          ),
        ),
      ],
    );
  }

  Widget _heroColumn(BuildContext context, AmbilightAppController c, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PowerHeroCard(c: c, scheme: scheme),
        const SizedBox(height: 14),
        AmbiGlassPanel(
          padding: const EdgeInsets.all(18),
          child: _EngineStatus(c: c, scheme: scheme),
        ),
      ],
    );
  }
}

class _PowerHeroCard extends StatelessWidget {
  const _PowerHeroCard({required this.c, required this.scheme});

  final AmbilightAppController c;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final on = c.enabled;
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
  const _EngineStatus({required this.c, required this.scheme});

  final AmbilightAppController c;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Engine', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
                  Text('Tick ${c.animationTick}', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    'Směna snímků běží na pozadí.',
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
  const _SpotifyCard({required this.c, required this.scheme});

  final AmbilightAppController c;
  final ColorScheme scheme;

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
                c.spotify.isConnected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                color: c.spotify.isConnected ? scheme.secondary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                c.spotify.isConnected ? 'Připojeno' : 'Nepřipojeno',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c.spotify.lastError ??
                ((c.config.spotify.clientId == null || c.config.spotify.clientId!.isEmpty)
                    ? 'Client ID doplníš v Nastavení → Spotify.'
                    : 'OAuth redirect: http://127.0.0.1:8767/callback'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Barvy alba v music módu'),
            value: c.config.spotify.enabled,
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
  const _DeviceStripCard({required this.device, required this.connected});

  final DeviceSettings device;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = device;
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
                  d.type == 'wifi' ? 'Wi‑Fi' : 'USB',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const Spacer(),
            Text(
              d.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              d.type == 'wifi' ? d.ipAddress : d.port,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
