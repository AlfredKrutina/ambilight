import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import 'dashboard_ui.dart';
import 'devices_page.dart';
import 'home_page.dart';
import 'layout_breakpoints.dart';
import 'responsive_body.dart';
import 'settings_page.dart';

const _navSpecs = <({IconData icon, String label, String tooltip})>[
  (icon: Icons.grid_view_rounded, label: 'Přehled', tooltip: 'Domů — režimy, zkratky a náhled zařízení'),
  (icon: Icons.hub_outlined, label: 'Zařízení', tooltip: 'Discovery, pásky a kalibrace'),
  (icon: Icons.tune_rounded, label: 'Nastavení', tooltip: 'Režimy, integrace a záloha konfigurace'),
  (icon: Icons.info_outline_rounded, label: 'O aplikaci', tooltip: 'Verze a základní informace'),
];

class AmbiShell extends StatefulWidget {
  const AmbiShell({super.key});

  @override
  State<AmbiShell> createState() => _AmbiShellState();
}

class _AmbiShellState extends State<AmbiShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomePage(),
    DevicesPage(),
    SettingsPage(),
    _AboutPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final useSidebar = AppBreakpoints.useShellSideRail(w);

        final topChrome = const _TopChrome();
        final instant = MediaQuery.disableAnimationsOf(context);

        final content = DecoratedBox(
          decoration: DashboardUi.pageBackdrop(scheme),
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: instant ? Duration.zero : const Duration(milliseconds: 280),
              switchInCurve: instant ? Curves.linear : Curves.easeOutQuart,
              switchOutCurve: instant ? Curves.linear : Curves.easeInQuart,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, anim) {
                if (instant) return child;
                final slide = Tween<Offset>(
                  begin: const Offset(0.014, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                return FadeTransition(
                  opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutQuad),
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: _pages[_index],
              ),
            ),
          ),
        );

        Widget boundedContent(BoxConstraints c) {
          return ResponsiveBody(
            maxWidth: c.maxWidth,
            child: content,
          );
        }

        if (useSidebar) {
          return Scaffold(
            backgroundColor: scheme.surface,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topChrome,
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MainSidebar(
                        key: const Key('ambi-main-sidebar'),
                        selectedIndex: _index,
                        onSelect: (i) => setState(() => _index = i),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => boundedContent(c),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: scheme.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topChrome,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => boundedContent(c),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            height: 72,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final s in _navSpecs)
                NavigationDestination(
                  icon: Icon(s.icon),
                  label: s.label,
                  tooltip: s.tooltip,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: Container(
        height: DashboardUi.topChromeHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(scheme.secondary, scheme.surface, 0.15)!,
              Color.lerp(scheme.tertiary, scheme.surface, 0.2)!,
              scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.blur_circular, color: scheme.onSurface, size: 26),
            const SizedBox(width: 10),
            Text(
              'AmbiLight',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
            ),
            const Spacer(),
            Selector<AmbilightAppController, bool>(
              selector: (_, c) => c.enabled,
              builder: (context, on, _) {
                final ctrl = context.read<AmbilightAppController>();
                return Tooltip(
                  message: on ? 'Vypnout posílání barev na pásky' : 'Zapnout posílání barev na pásky',
                  child: FilledButton.tonalIcon(
                    onPressed: () => ctrl.setEnabled(!on),
                    icon: Icon(on ? Icons.bolt : Icons.bolt_outlined, size: 20),
                    label: Text(on ? 'Výstup zapnutý' : 'Výstup vypnutý'),
                    style: FilledButton.styleFrom(
                      foregroundColor: on ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                      backgroundColor: on
                          ? scheme.tertiaryContainer.withValues(alpha: 0.85)
                          : scheme.surface.withValues(alpha: 0.55),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MainSidebar extends StatelessWidget {
  const _MainSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: DashboardUi.sidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
          border: Border(
            right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
              child: Text(
                'Navigace',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (var i = 0; i < _navSpecs.length; i++)
                    AmbiSidebarTile(
                      icon: _navSpecs[i].icon,
                      label: _navSpecs[i].label,
                      selected: selectedIndex == i,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Desktop · LED / Wi‑Fi',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ResponsiveBody(
          maxWidth: constraints.maxWidth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              AmbiPageHeader(
                title: 'O aplikaci',
                subtitle: 'AmbiLight Desktop — ovládání LED pásků z Windows (USB i Wi‑Fi).',
                bottomSpacing: 12,
              ),
              AmbiGlassPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AmbiLight Desktop', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(
                      'Desktopový klient ve Flutteru, sladěný s firmware pro ESP32. '
                      'Průvodce v aplikaci tě provedou páskem, segmenty obrazovky a kalibrací.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Ladění',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      children: [
                        Selector<AmbilightAppController, int>(
                          selector: (_, c) => c.animationTick,
                          builder: (context, tick, _) => SelectableText(
                            'Čítač snímků engine: $tick',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
