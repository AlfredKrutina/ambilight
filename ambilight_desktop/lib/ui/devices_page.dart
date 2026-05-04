import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../application/app_error_safety.dart';
import '../l10n/app_locale_bridge.dart';
import '../l10n/context_ext.dart';
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
    messenger.showSnackBar(SnackBar(content: Text(context.l10n.comScanHandshake)));
    final snap = c.connectionSnapshot;
    final skipOpenCom = <String>{
      for (final d in c.config.globalSettings.devices)
        if (d.type == 'serial' &&
            d.port.trim().isNotEmpty &&
            (snap[d.id] ?? false))
          d.port.trim(),
    };
    final port = await SerialAmbilightPortDiscovery.findAmbilightPort(
      baudRate: c.config.globalSettings.baudRate,
      skipPortNames: skipOpenCom,
    );
    if (!mounted) return;
    setState(() => _findingCom = false);
    if (port == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.comScanNoReply)),
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
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.serialPortSet(port))));
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
              Text(ctx.l10n.saveDeviceTitle, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: ctx.l10n.fieldDeviceName)),
              TextField(
                controller: ipCtrl,
                decoration: InputDecoration(
                  labelText: ctx.l10n.fieldIpAddress,
                  hintText: '192.168.1.42',
                ),
                keyboardType: TextInputType.url,
              ),
              TextField(
                controller: portCtrl,
                decoration: InputDecoration(labelText: ctx.l10n.fieldUdpPort),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: ledCtrl,
                decoration: InputDecoration(labelText: ctx.l10n.fieldLedCount),
                keyboardType: TextInputType.number,
              ),
              if (fw.isNotEmpty) Text(ctx.l10n.firmwareFromPong(fw), style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final ip = ipCtrl.text.trim();
                      if (!_isValidIp(ip)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.invalidIp)),
                        );
                        return;
                      }
                      final port = int.tryParse(portCtrl.text.trim()) ?? 4210;
                      final pong = await LedDiscoveryService.queryPong(ip, udpPort: port);
                      if (!ctx.mounted) return;
                      if (pong == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.pongTimeout)),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.pongResult(pong.version, pong.ledCount))),
                        );
                      }
                    },
                    child: Text(ctx.l10n.verifyPong),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final ip = ipCtrl.text.trim();
                      if (!_isValidIp(ip)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.enterValidIpv4)),
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
                        SnackBar(content: Text(context.l10n.deviceSaved)),
                      );
                    },
                    child: Text(ctx.l10n.save),
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
        title: Text(ctx.l10n.resetWifiTitle),
        content: Text(ctx.l10n.resetWifiContent(dev.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.sendResetWifi),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final ok = await UdpDeviceCommands.sendResetWifi(dev.ipAddress, dev.udpPort, logContext: dev.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? context.l10n.resetWifiSent : context.l10n.resetWifiFailed)),
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
      reportAppFault(AppLocaleBridge.strings.removeDeviceFailed(e.toString().split('\n').first));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.removeFailed(e.toString()))),
        );
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.deviceRemoved(name))),
    );
  }

  Future<void> _refreshFirmware(BuildContext context, AmbilightAppController c, int index) async {
    final dev = c.config.globalSettings.devices[index];
    if (dev.type != 'wifi' || dev.ipAddress.isEmpty) return;
    final pong = await LedDiscoveryService.queryPong(dev.ipAddress, udpPort: dev.udpPort);
    if (!context.mounted) return;
    if (pong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pongMissing)),
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
        SnackBar(content: Text(context.l10n.firmwareLabel(pong.version))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<AmbilightAppController>();
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([c, c.previewFrameNotifier, c.connectionSnapshotNotifier]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return ResponsiveBody(
              maxWidth: constraints.maxWidth,
              child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        AmbiPageHeader(
          title: context.l10n.devicesPageTitle,
          subtitle: context.l10n.devicesPageSubtitle,
          bottomSpacing: 20,
        ),
        AmbiGlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.devicesActionsTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _discover,
                icon: const Icon(Icons.wifi_tethering),
                label: Text(context.l10n.discoveryWizardLabel),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
          builder: (context, bc) {
            final narrow = bc.maxWidth < 520;
            final children = [
              OutlinedButton.icon(
                onPressed: () => ZoneEditorWizardDialog.show(context),
                icon: const Icon(Icons.border_outer),
                label: Text(context.l10n.segmentsLabel),
              ),
              OutlinedButton.icon(
                onPressed: () => CalibrationWizardDialog.show(context),
                icon: const Icon(Icons.tune),
                label: Text(context.l10n.calibrationLabel),
              ),
              OutlinedButton.icon(
                onPressed: () => ConfigProfileWizardDialog.show(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(context.l10n.screenPresetLabel),
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
                label: Text(context.l10n.addWifiManual),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _findingCom ? null : _findAmbilightCom,
                icon: _findingCom
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.usb),
                label: Text(_findingCom ? context.l10n.findingCom : context.l10n.findAmbilightCom),
              ),
            ],
          ),
        ),
        const Divider(height: 32),
        Text(
          context.l10n.devicesConfiguredTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (c.config.globalSettings.devices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AmbiGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.devicesEmptyStateBody,
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
              context.l10n.diagnosticsComPorts,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            children: [
              SelectableText(
                AmbilightAppController.serialPorts().join(', ').isEmpty
                    ? context.l10n.noSerialPortsDetected
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
      },
    );
  }
}
