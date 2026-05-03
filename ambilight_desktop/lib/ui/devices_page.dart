import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../application/app_error_safety.dart';
import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../data/udp_device_commands.dart';
import '../services/led_discovery_service.dart';
import '../services/serial_ambilight_port_discovery.dart';
import 'wizards/calibration_wizard_dialog.dart';
import 'wizards/config_profile_wizard_dialog.dart';
import 'wizards/discovery_wizard_dialog.dart';
import 'wizards/led_strip_wizard_dialog.dart';
import 'dashboard_ui.dart';
import 'responsive_body.dart';
import 'wizards/zone_editor_wizard_dialog.dart';
import 'widgets/config_device_list_tile.dart';

bool _isValidIp(String raw) {
  final s = raw.replaceAll(',', '.').trim();
  if (s.isEmpty) return false;
  return InternetAddress.tryParse(s) != null;
}

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  bool _findingCom = false;

  Future<void> _findAmbilightCom() async {
    final c = context.read<AmbilightAppController>();
    setState(() => _findingCom = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Hledám COM s handshake 0xAA / 0xBB…')));
    final port = await SerialAmbilightPortDiscovery.findAmbilightPort(
      baudRate: c.config.globalSettings.baudRate,
    );
    if (!mounted) return;
    setState(() => _findingCom = false);
    if (port == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Žádný port neodpověděl (Ambilight handshake).')),
      );
      return;
    }
    final devs = c.config.globalSettings.devices
        .map((d) => d.type == 'serial' ? d.copyWith(port: port) : d)
        .toList();
    final next = c.config.copyWith(
      globalSettings: c.config.globalSettings.copyWith(
        devices: devs,
        serialPort: port,
      ),
    );
    traceDeviceBindings('DevicesPage._findAmbilightCom: nastavuji COM $port na všech serial řádcích');
    traceConfigBindings('DevicesPage._findAmbilightCom před apply', c.config);
    await c.applyConfigAndPersist(next);
    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text('Nastaven sériový port: $port')));
    }
  }

  Future<void> _discover() async {
    await DiscoveryWizardDialog.show(context);
  }

  Future<void> _openSaveDeviceSheet(BuildContext context, {DiscoveredLedController? preset}) async {
    final c = context.read<AmbilightAppController>();
    final nameCtrl = TextEditingController(text: preset?.name ?? 'Wi‑Fi controller');
    final ipCtrl = TextEditingController(text: preset?.ip ?? '');
    final portCtrl = TextEditingController(text: '4210');
    final ledCtrl = TextEditingController(text: '${preset?.ledCount ?? 66}');
    final fw = preset?.version ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Uložit zařízení', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Název')),
              TextField(
                controller: ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP adresa',
                  hintText: '192.168.1.42',
                ),
                keyboardType: TextInputType.url,
              ),
              TextField(
                controller: portCtrl,
                decoration: const InputDecoration(labelText: 'UDP port'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: ledCtrl,
                decoration: const InputDecoration(labelText: 'Počet LED'),
                keyboardType: TextInputType.number,
              ),
              if (fw.isNotEmpty) Text('Firmware (z PONG): $fw', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final ip = ipCtrl.text.trim();
                      if (!_isValidIp(ip)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Neplatná IP adresa.')),
                        );
                        return;
                      }
                      final port = int.tryParse(portCtrl.text.trim()) ?? 4210;
                      final pong = await LedDiscoveryService.queryPong(ip, udpPort: port);
                      if (!ctx.mounted) return;
                      if (pong == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PONG nepřišel (timeout).')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PONG: FW ${pong.version}, LED ${pong.ledCount}')),
                        );
                      }
                    },
                    child: const Text('Ověřit PONG'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final ip = ipCtrl.text.trim();
                      if (!_isValidIp(ip)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zadej platnou IPv4 adresu.')),
                        );
                        return;
                      }
                      final port = int.tryParse(portCtrl.text.trim()) ?? 4210;
                      final leds = int.tryParse(ledCtrl.text.trim()) ?? 66;
                      var firmware = fw;
                      if (firmware.isEmpty) {
                        final pong = await LedDiscoveryService.queryPong(ip, udpPort: port);
                        firmware = pong?.version ?? '';
                      }
                      if (!ctx.mounted) return;
                      final devs = [...c.config.globalSettings.devices];
                      devs.add(
                        DeviceSettings(
                          id: 'd${DateTime.now().millisecondsSinceEpoch % 100000000}',
                          name: nameCtrl.text.trim().isEmpty ? 'Wi‑Fi' : nameCtrl.text.trim(),
                          type: 'wifi',
                          ipAddress: ip.replaceAll(',', '.'),
                          udpPort: port,
                          ledCount: leds.clamp(1, 512),
                          firmwareVersion: firmware,
                        ),
                      );
                      final next = c.config.copyWith(
                        globalSettings: c.config.globalSettings.copyWith(devices: devs),
                      );
                      traceDeviceBindings(
                        'DevicesPage: ruční Wi‑Fi přidání ip=$ip udp=$port leds=$leds',
                      );
                      traceConfigBindings('DevicesPage: před apply (ruční Wi‑Fi)', c.config);
                      await c.applyConfigAndPersist(next);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Zařízení uloženo.')),
                      );
                    },
                    child: const Text('Uložit'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    nameCtrl.dispose();
    ipCtrl.dispose();
    portCtrl.dispose();
    ledCtrl.dispose();
  }

  Future<void> _confirmResetWifi(BuildContext context, DeviceSettings dev) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Wi‑Fi?'),
        content: Text(
          'Zařízení „${dev.name}“ smaže uložené Wi‑Fi přihlašovací údaje na kontroléru '
          'a restartuje se. Budete ho muset znovu připojit k síti.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušit')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odeslat RESET_WIFI'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final ok = await UdpDeviceCommands.sendResetWifi(dev.ipAddress, dev.udpPort, logContext: dev.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'RESET_WIFI odeslán.' : 'Odeslání se nezdařilo.')),
    );
  }

  Future<void> _removeDeviceAt(BuildContext context, AmbilightAppController c, int index) async {
    final list = c.config.globalSettings.devices;
    if (index < 0 || index >= list.length) return;
    final dev = list[index];
    final name = dev.name.trim().isEmpty ? 'Zařízení' : dev.name;
    final ok = await showConfirmRemoveDeviceDialog(
      context,
      deviceName: name,
      isLast: list.length <= 1,
    );
    if (!ok || !context.mounted) return;
    final next = [...list]..removeAt(index);
    traceDeviceBindings(
      'DevicesPage._removeDeviceAt: mažu index=$index id=${dev.id} typ=${dev.type} → zbývá ${next.length}',
    );
    traceConfigBindings('DevicesPage._removeDeviceAt PŘED apply', c.config);
    try {
      await c.applyConfigAndPersist(
        c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(devices: next)),
      );
    } catch (e, st) {
      traceDeviceBindingsSevere('DevicesPage._removeDeviceAt: apply selhal', e, st);
      reportAppFault('Odebrání zařízení selhalo: ${e.toString().split('\n').first}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Odebrání se nepodařilo: $e')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Zařízení „$name“ bylo odebráno.')),
    );
  }

  Future<void> _refreshFirmware(BuildContext context, AmbilightAppController c, int index) async {
    final dev = c.config.globalSettings.devices[index];
    if (dev.type != 'wifi' || dev.ipAddress.isEmpty) return;
    final pong = await LedDiscoveryService.queryPong(dev.ipAddress, udpPort: dev.udpPort);
    if (!context.mounted) return;
    if (pong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PONG nepřišel.')),
      );
      return;
    }
    final devs = [...c.config.globalSettings.devices];
    devs[index] = dev.copyWith(firmwareVersion: pong.version);
    traceDeviceBindings('DevicesPage._refreshFirmware: ${dev.id} → fw ${pong.version}');
    await c.applyConfigAndPersist(
      c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(devices: devs)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firmware: ${pong.version}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AmbilightAppController>();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ResponsiveBody(
          maxWidth: constraints.maxWidth,
          child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        AmbiPageHeader(
          title: 'Zařízení',
          subtitle:
              'Vyhledání v síti, úprava segmentů a kalibrace. Klepnutím na řádek zařízení otevřeš mapování LED.',
          bottomSpacing: 20,
        ),
        AmbiGlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Akce', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _discover,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Discovery — průvodce'),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
          builder: (context, bc) {
            final narrow = bc.maxWidth < 520;
            final children = [
              OutlinedButton.icon(
                onPressed: () => ZoneEditorWizardDialog.show(context),
                icon: const Icon(Icons.border_outer),
                label: const Text('Segmenty'),
              ),
              OutlinedButton.icon(
                onPressed: () => CalibrationWizardDialog.show(context),
                icon: const Icon(Icons.tune),
                label: const Text('Kalibrace'),
              ),
              OutlinedButton.icon(
                onPressed: () => ConfigProfileWizardDialog.show(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Screen preset'),
              ),
            ];
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in children) ...[w, const SizedBox(height: 6)],
                ],
              );
            }
            return Wrap(spacing: 8, runSpacing: 8, children: children);
          },
        ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openSaveDeviceSheet(context, preset: null),
                icon: const Icon(Icons.add),
                label: const Text('Přidat Wi‑Fi ručně'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _findingCom ? null : _findAmbilightCom,
                icon: _findingCom
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.usb),
                label: Text(_findingCom ? 'Hledám COM…' : 'Najít Ambilight (COM)'),
              ),
            ],
          ),
        ),
        const Divider(height: 32),
        Text(
          'Nakonfigurovaná zařízení',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (c.config.globalSettings.devices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AmbiGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Zatím žádné — můžeš nejdřív nastavit režimy a presety. Pro ovládání pásku přidej USB nebo Wi‑Fi výše.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ...c.config.globalSettings.devices.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final isWifi = d.type == 'wifi';
          final ok = c.connectionSnapshot[d.id] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ConfigDeviceListTile(
              device: d,
              connected: ok,
              onEditStrip: () => LedStripWizardDialog.show(context, deviceId: d.id),
              onIdentify: isWifi && d.ipAddress.isNotEmpty
                  ? () => UdpDeviceCommands.sendIdentify(d.ipAddress, d.udpPort)
                  : null,
              onResetWifi: isWifi && d.ipAddress.isNotEmpty ? () => _confirmResetWifi(context, d) : null,
              onRefreshFirmware: isWifi && d.ipAddress.isNotEmpty ? () => _refreshFirmware(context, c, i) : null,
              onRemove: () => _removeDeviceAt(context, c, i),
            ),
          );
        }),
        Theme(
          data: Theme.of(context),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              'Diagnostika (COM porty)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            children: [
              SelectableText(
                AmbilightAppController.serialPorts().join(', ').isEmpty
                    ? 'Žádné porty nejsou detekované.'
                    : AmbilightAppController.serialPorts().join(', '),
                style: Theme.of(context).textTheme.bodySmall,
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
