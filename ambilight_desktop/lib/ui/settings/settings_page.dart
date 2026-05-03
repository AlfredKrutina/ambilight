import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/app_error_safety.dart';
import '../../core/device_bindings_debug.dart';
import '../../core/models/config_models.dart';
import '../../core/models/smart_lights_models.dart';
import '../dashboard_ui.dart';
import '../layout_breakpoints.dart';
import '../responsive_body.dart';
import 'tabs/devices_tab.dart';
import 'tabs/global_settings_tab.dart';
import 'tabs/light_settings_tab.dart';
import 'tabs/music_settings_tab.dart';
import 'tabs/pc_health_settings_tab.dart';
import 'tabs/screen_settings_tab.dart';
import 'tabs/firmware_settings_tab.dart';
import 'tabs/smart_integration_tab.dart';
import 'tabs/spotify_settings_tab.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabCount = 9;

  @override
  void initState() {
    super.initState();
    final boot = context.read<AmbilightAppController>().takePendingSettingsTabIndex();
    final initialTab =
        (boot != null && boot >= 0 && boot < _tabCount) ? boot : 0;
    _tabController = TabController(
      length: _tabCount,
      initialIndex: initialTab,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _queue(AppConfig next) {
    context.read<AmbilightAppController>().queueConfigApply(next);
  }

  void _patchGlobal(GlobalSettings g) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(globalSettings: g));
  }

  void _patchLight(LightModeSettings l) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(lightMode: l));
  }

  /// Při změně COM/IP/typu zařízení okamžitý rebuild transportů; u názvu a počtu LED jen debounce
  /// ([queueConfigApply]) — opakované zavírání COM při psaní čísla na Windows ničí heap v driveru.
  void _patchDevices(List<DeviceSettings> devices) {
    final c = context.read<AmbilightAppController>();
    final prev = c.config.globalSettings.devices;
    final next = c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(devices: devices));
    traceDeviceBindings(
      'SettingsPage._patchDevices: nový seznam (${devices.length}) → ${formatDeviceBindingsList(devices)}',
    );
    traceConfigBindings('SettingsPage._patchDevices: snapshot před apply', c.config);
    final hot = AmbilightAppController.devicesChangeRequiresTransportRebuild(prev, devices);
    traceDeviceBindings('SettingsPage._patchDevices: transportRebuild=$hot');
    if (hot) {
      unawaited(() async {
        try {
          await c.applyConfigAndPersist(next);
          traceDeviceBindings('SettingsPage._patchDevices: applyConfigAndPersist OK');
        } catch (e, st) {
          traceDeviceBindingsSevere('SettingsPage._patchDevices: applyConfigAndPersist výjimka', e, st);
          reportAppFault('Uložení seznamu zařízení selhalo: ${e.toString().split('\n').first}');
        }
      }());
    } else {
      c.queueConfigApply(next);
    }
  }

  void _patchScreen(ScreenModeSettings s) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(screenMode: s));
  }

  void _patchMusic(MusicModeSettings m) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(musicMode: m));
  }

  void _patchPcHealth(PcHealthSettings p) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(pcHealth: p));
  }

  void _patchSpotify(SpotifySettings s) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(spotify: s));
  }

  void _patchSmartLights(SmartLightsSettings s) {
    final c = context.read<AmbilightAppController>();
    _queue(c.config.copyWith(smartLights: s));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AmbilightAppController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final useRail = AppBreakpoints.useSettingsSideRail(w);
        final contentW = useRail ? (w - 252 - 1) : w;

        Widget tabChild(int i) {
          switch (i) {
            case 0:
              return GlobalSettingsTab(
                draft: c.config,
                maxWidth: contentW,
                onChanged: _patchGlobal,
              );
            case 1:
              return DevicesTab(
                draft: c.config,
                maxWidth: contentW,
                onDevicesChanged: _patchDevices,
              );
            case 2:
              return LightSettingsTab(
                draft: c.config,
                maxWidth: contentW,
                onChanged: _patchLight,
              );
            case 3:
              return ScreenSettingsTab(
                draft: c.config,
                maxWidth: contentW,
                onChanged: _patchScreen,
              );
            case 4:
              return MusicSettingsTab(
                draft: c.config,
                maxWidth: contentW,
                onChanged: _patchMusic,
              );
            case 5:
              return PcHealthSettingsTab(
                controller: c,
                maxWidth: contentW,
                onChanged: _patchPcHealth,
              );
            case 6:
              return SpotifySettingsTab(
                draft: c.config,
                maxWidth: contentW,
                onSpotifyChanged: _patchSpotify,
                onSystemMediaAlbumChanged: (sm) {
                  final ctrl = context.read<AmbilightAppController>();
                  _queue(ctrl.config.copyWith(systemMediaAlbum: sm));
                },
              );
            case 7:
              return SmartIntegrationTab(
                draft: c.config,
                maxWidth: contentW,
                onSmartLightsChanged: _patchSmartLights,
              );
            case 8:
              return FirmwareSettingsTab(
                draft: c.config,
                maxWidth: contentW,
                onGlobalChanged: _patchGlobal,
              );
            default:
              return const SizedBox.shrink();
          }
        }

        final body = TabBarView(
          controller: _tabController,
          physics: useRail ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < _tabCount; i++)
              KeyedSubtree(
                // Stabilní klíč jen podle indexu záložky — [configPersistGeneration] by při
                // každém uložení konfigurace zničil strom a srazil scroll nahoru.
                key: ValueKey<int>(i),
                child: RepaintBoundary(child: tabChild(i)),
              ),
          ],
        );

        final scheme = Theme.of(context).colorScheme;
        final hint = DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            ),
            color: scheme.surfaceContainer.withValues(alpha: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.save_alt_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Engine a posuvníky reagují hned; na disk se zapíše krátce po poslední změně. Presety obrazovky a hudby se tím nemění.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );

        if (useRail) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSidebar(
                selectedIndex: _tabController.index,
                onSelect: (i) => setState(() => _tabController.index = i),
              ),
              VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nastavení', style: Theme.of(context).textTheme.headlineSmall),
                          Text(
                            'Vyber téma vlevo — tlačítko Použít nepotřebuješ.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    hint,
                    Expanded(
                      child: ResponsiveBody(
                        maxWidth: contentW,
                        child: body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('Nastavení', style: Theme.of(context).textTheme.headlineSmall),
            ),
            hint,
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Globální'),
                Tab(text: 'Zařízení'),
                Tab(text: 'Světlo'),
                Tab(text: 'Obrazovka'),
                Tab(text: 'Hudba'),
                Tab(text: 'PC Health'),
                Tab(text: 'Spotify'),
                Tab(text: 'Smart Home'),
                Tab(text: 'Firmware'),
              ],
            ),
            Expanded(
              child: ResponsiveBody(
                maxWidth: w,
                child: body,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 252,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.88),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            const AmbiSidebarSectionLabel('Základ'),
            AmbiSidebarTile(
              icon: Icons.tune_rounded,
              label: 'Globální',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            AmbiSidebarTile(
              icon: Icons.usb_rounded,
              label: 'Zařízení',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            const AmbiSidebarSectionLabel('Režimy'),
            AmbiSidebarTile(
              icon: Icons.palette_rounded,
              label: 'Světlo',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            AmbiSidebarTile(
              icon: Icons.desktop_windows_rounded,
              label: 'Obrazovka',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
            AmbiSidebarTile(
              icon: Icons.graphic_eq_rounded,
              label: 'Hudba',
              selected: selectedIndex == 4,
              onTap: () => onSelect(4),
            ),
            AmbiSidebarTile(
              icon: Icons.monitor_heart_rounded,
              label: 'PC Health',
              selected: selectedIndex == 5,
              onTap: () => onSelect(5),
            ),
            const AmbiSidebarSectionLabel('Integrace'),
            AmbiSidebarTile(
              icon: Icons.queue_music_rounded,
              label: 'Spotify',
              selected: selectedIndex == 6,
              onTap: () => onSelect(6),
            ),
            AmbiSidebarTile(
              icon: Icons.home_work_outlined,
              label: 'Smart Home',
              selected: selectedIndex == 7,
              onTap: () => onSelect(7),
            ),
            AmbiSidebarTile(
              icon: Icons.system_update_alt_rounded,
              label: 'Firmware',
              selected: selectedIndex == 8,
              onTap: () => onSelect(8),
            ),
          ],
        ),
      ),
    );
  }
}
