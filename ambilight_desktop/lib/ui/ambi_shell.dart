import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../application/app_crash_log.dart';
import '../application/build_environment.dart';
import '../application/desktop_chrome_stub.dart'
    if (dart.library.io) '../application/desktop_chrome_io.dart' as desktop_chrome;
import '../core/models/config_models.dart';
import '../l10n/context_ext.dart';
import '../l10n/generated/app_localizations.dart';
import 'dashboard_ui.dart';
import 'devices_page.dart';
import 'home_page.dart';
import 'layout_breakpoints.dart';
import 'responsive_body.dart';
import 'settings_page.dart';
import 'updates/updates_page.dart';

/// Stručný popis nakonfigurovaných výstupů (odpovídá `devices`, ignoruje HA-only).
String _configuredOutputKindsFooter(AppConfig c, AppLocalizations l10n) {
  final ds = c.globalSettings.devices.where((d) => !d.controlViaHa).toList();
  if (ds.isEmpty) return l10n.footerNoOutputs;
  var usb = 0;
  var wifi = 0;
  for (final d in ds) {
    if (d.type == 'wifi') {
      wifi++;
    } else {
      usb++;
    }
  }
  final parts = <String>[];
  if (usb > 0) parts.add(usb == 1 ? l10n.footerUsbOne : l10n.footerUsbMany(usb));
  if (wifi > 0) parts.add(wifi == 1 ? l10n.footerWifiOne : l10n.footerWifiMany(wifi));
  return parts.join(' · ');
}

List<({IconData icon, String label, String tooltip})> _navSpecs(AppLocalizations l) => [
      (icon: Icons.home_outlined, label: l.navOverview, tooltip: l.navOverviewTooltip),
      (icon: Icons.hub_outlined, label: l.navDevices, tooltip: l.navDevicesTooltip),
      (icon: Icons.system_update_alt_rounded, label: l.navUpdates, tooltip: l.navUpdatesTooltip),
      (icon: Icons.tune_rounded, label: l.navSettings, tooltip: l.navSettingsTooltip),
      (icon: Icons.info_outline_rounded, label: l.navAbout, tooltip: l.navAboutTooltip),
    ];

class AmbiShell extends StatefulWidget {
  const AmbiShell({super.key});

  @override
  State<AmbiShell> createState() => _AmbiShellState();
}

({List<String> ids, int total}) _deviceOnlineMeta(AmbilightAppController c) {
  final devs = c.config.globalSettings.devices.where((d) => !d.controlViaHa).toList();
  return (
    ids: [for (final d in devs) d.id],
    total: devs.length,
  );
}

class _AmbiShellState extends State<AmbiShell> with WidgetsBindingObserver {
  int _index = 0;
  AmbilightAppController? _controller;

  static const _pages = <Widget>[
    HomePage(),
    DevicesPage(),
    UpdatesPage(),
    SettingsPage(),
    _AboutPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(desktop_chrome.onDesktopAppResumed());
      final c = _controller;
      if (c != null) {
        unawaited(c.refreshCaptureSessionInfo());
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<AmbilightAppController>();
    if (!identical(_controller, next)) {
      _controller?.removeListener(_onControllerNavigation);
      _controller = next..addListener(_onControllerNavigation);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerNavigation);
    super.dispose();
  }

  void _onControllerNavigation() {
    if (!mounted) return;
    final idx = _controller?.takePendingShellIndex();
    if (idx != null) {
      if (kDebugMode || ambilightReleaseChannel == 'staging') {
        debugPrint('[AmbiShell] navigate index → $idx');
      }
      setState(() => _index = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final useSidebar = AppBreakpoints.useShellSideRail(w);
        final navSpecs = _navSpecs(context.l10n);
        final instant = MediaQuery.disableAnimationsOf(context);

        final content = DecoratedBox(
          decoration: DashboardUi.pageBackdrop(scheme),
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: instant ? Duration.zero : const Duration(milliseconds: 220),
              switchInCurve: instant ? Curves.linear : Curves.easeOutCubic,
              switchOutCurve: instant ? Curves.linear : Curves.easeInCubic,
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
                return FadeTransition(
                  opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutQuad),
                  child: child,
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
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AmbiAppRail(
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
          );
        }

        return Scaffold(
          backgroundColor: scheme.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CompactPowerBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => boundedContent(c),
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            height: 64,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final s in navSpecs)
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

/// Full-height NVIDIA-style rail: brand, nav, power/status footer.
class _AmbiAppRail extends StatelessWidget {
  const _AmbiAppRail({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final navSpecs = _navSpecs(context.l10n);
    // Primary destinations in rail body; About stays in list (index 4) like NVIDIA secondary.
    return SizedBox(
      width: DashboardUi.railWidth,
      child: DecoratedBox(
        decoration: DashboardUi.railBackdrop(scheme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 16, 20),
              child: Row(
                children: [
                  Icon(Icons.blur_circular, color: scheme.primary, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (var i = 0; i < navSpecs.length; i++)
                    AmbiSidebarTile(
                      icon: navSpecs[i].icon,
                      label: navSpecs[i].label,
                      tooltip: navSpecs[i].tooltip,
                      selected: selectedIndex == i,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Selector<AmbilightAppController, ({List<String> ids, int total})>(
                selector: (_, c) => _deviceOnlineMeta(c),
                builder: (context, meta, _) {
                  if (meta.total <= 0) {
                    return Text(
                      _configuredOutputKindsFooter(
                        context.read<AmbilightAppController>().config,
                        context.l10n,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                    );
                  }
                  final ctrl = context.read<AmbilightAppController>();
                  return ValueListenableBuilder<Map<String, bool>>(
                    valueListenable: ctrl.connectionSnapshotNotifier,
                    builder: (context, snap, _) {
                      var online = 0;
                      for (final id in meta.ids) {
                        if (snap[id] == true) online++;
                      }
                      final ok = online >= meta.total;
                      return Row(
                        children: [
                          Icon(
                            ok ? Icons.link_rounded : Icons.link_off_rounded,
                            size: 18,
                            color: ok ? scheme.primary : scheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ok
                                  ? context.l10n.allOutputsOnline(online, meta.total)
                                  : context.l10n.someOutputsOffline(online, meta.total),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Selector<AmbilightAppController, bool>(
                selector: (_, c) => c.enabled,
                builder: (context, on, _) {
                  final ctrl = context.read<AmbilightAppController>();
                  return Tooltip(
                    message: on ? context.l10n.tooltipColorsOn : context.l10n.tooltipColorsOff,
                    child: Material(
                      color: on
                          ? scheme.primary.withValues(alpha: 0.18)
                          : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(DashboardUi.radiusSm),
                        onTap: () => ctrl.setEnabled(!on),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                on ? Icons.bolt : Icons.bolt_outlined,
                                size: 20,
                                color: on ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  on ? context.l10n.outputOn : context.l10n.outputOff,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: on ? scheme.onSurface : scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              Switch.adaptive(
                                value: on,
                                onChanged: ctrl.setEnabled,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Power + link status when the full rail is hidden (narrow window).
class _CompactPowerBar extends StatelessWidget {
  const _CompactPowerBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7))),
        ),
        child: Row(
          children: [
            Icon(Icons.blur_circular, color: scheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Selector<AmbilightAppController, ({List<String> ids, int total})>(
              selector: (_, c) => _deviceOnlineMeta(c),
              builder: (context, meta, _) {
                if (meta.total <= 0) return const SizedBox.shrink();
                final ctrl = context.read<AmbilightAppController>();
                return ValueListenableBuilder<Map<String, bool>>(
                  valueListenable: ctrl.connectionSnapshotNotifier,
                  builder: (context, snap, _) {
                    var online = 0;
                    for (final id in meta.ids) {
                      if (snap[id] == true) online++;
                    }
                    final ok = online >= meta.total;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        ok ? Icons.link_rounded : Icons.link_off_rounded,
                        size: 20,
                        color: ok ? scheme.primary : scheme.error,
                      ),
                    );
                  },
                );
              },
            ),
            Selector<AmbilightAppController, bool>(
              selector: (_, c) => c.enabled,
              builder: (context, on, _) {
                final ctrl = context.read<AmbilightAppController>();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      on ? context.l10n.outputOn : context.l10n.outputOff,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: on ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                    ),
                    Switch.adaptive(
                      value: on,
                      onChanged: ctrl.setEnabled,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutPage extends StatefulWidget {
  const _AboutPage();

  @override
  State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  late final Future<({PackageInfo info, String crashLogPath})> _diagFuture = () async {
    final info = await PackageInfo.fromPlatform();
    final crashLogPath = await AppCrashLog.resolveCrashLogFilePath();
    return (info: info, crashLogPath: crashLogPath);
  }();

  Future<void> _copyPath(BuildContext context, String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final copied = context.l10n.pathCopiedSnackbar;
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ResponsiveBody(
          maxWidth: constraints.maxWidth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            children: [
              AmbiPageHeader(
                title: context.l10n.aboutTitle,
                subtitle: context.l10n.aboutSubtitle,
                bottomSpacing: 16,
              ),
              AmbiSurfacePanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.aboutAppName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.aboutBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder(
                      future: _diagFuture,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            context.l10n.versionLoadError(snap.error.toString()),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          );
                        }
                        if (!snap.hasData) {
                          return const LinearProgressIndicator(minHeight: 3);
                        }
                        final d = snap.data!;
                        final sha = ambilightGitSha.trim();
                        final shaShort = sha.length > 10 ? sha.substring(0, 10) : sha;
                        final mode = kReleaseMode ? 'release' : 'debug';
                        final buf = StringBuffer()
                          ..writeln(context.l10n.versionLine(d.info.version, d.info.buildNumber))
                          ..writeln(context.l10n.buildLine(mode, ambilightReleaseChannel));
                        if (shaShort.isNotEmpty) {
                          buf.writeln(context.l10n.gitLine(shaShort));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(buf.toString(), style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 14),
                            Text(
                              context.l10n.updatesOpenAppUpdatesHint,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  context.read<AmbilightAppController>().requestOpenUpdates(),
                              icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                              label: Text(context.l10n.updatesOpenAppUpdatesCta),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final ctrl = context.read<AmbilightAppController>();
                                await ctrl.applyConfigAndPersist(
                                  ctrl.config.copyWith(
                                    globalSettings: ctrl.config.globalSettings.copyWith(onboardingCompleted: false),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.auto_stories_outlined, size: 18),
                              label: Text(context.l10n.showOnboardingAgain),
                            ),
                            const SizedBox(height: 12),
                            Text(context.l10n.crashLogFileLabel, style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 6),
                            SelectableText(
                              d.crashLogPath,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _copyPath(context, d.crashLogPath),
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: Text(context.l10n.copyLogPath),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        context.l10n.debugSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      children: [
                        Selector<AmbilightAppController, ({int tick, Locale locale})>(
                          selector: (_, c) => (tick: c.animationTick, locale: Localizations.localeOf(context)),
                          builder: (context, s, _) => SelectableText(
                            context.l10n.engineTickDebug(s.tick),
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
