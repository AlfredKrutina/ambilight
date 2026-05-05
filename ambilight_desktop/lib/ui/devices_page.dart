import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/ambilight_app_controller.dart';
import '../application/app_error_safety.dart';
import '../l10n/app_locale_bridge.dart';
import '../l10n/context_ext.dart';
import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../core/protocol/serial_frame.dart';
import '../services/led_discovery_service.dart';
import '../services/serial_ambilight_port_discovery.dart';
import 'wizards/calibration_wizard_dialog.dart';
import 'wizards/config_profile_wizard_dialog.dart';
import 'wizards/discovery_wizard_dialog.dart';
import 'dashboard_ui.dart';
import 'responsive_body.dart';
import 'settings/tabs/devices_tab.dart';
import 'wizards/segment_geometry_wizard_dialog.dart';
import 'wizards/zone_editor_wizard_dialog.dart';

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
  int _comScanIndex = 0;
  int _comScanTotal = 0;

  Future<void> _findAmbilightCom() async {
    final c = context.read<AmbilightAppController>();
    setState(() {
      _findingCom = true;
      _comScanIndex = 0;
      _comScanTotal = 0;
    });
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
    final port = await c.runWithLoopPaused(
      () => SerialAmbilightPortDiscovery.findAmbilightPort(
        baudRate: c.config.globalSettings.baudRate,
        skipPortNames: skipOpenCom,
        onPortProgress: (idx, tot) {
          if (!mounted) return;
          setState(() {
            _comScanIndex = idx;
            _comScanTotal = tot;
          });
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _findingCom = false;
      _comScanTotal = 0;
    });
    if (port == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.comScanNoReply)),
      );
      return;
    }
    final existing = c.config.globalSettings.devices;
    final hadSerialRow = existing.any((d) => d.type == 'serial');
    final ledHint = existing.isEmpty
        ? c.config.globalSettings.ledCount
        : existing.map((d) => d.ledCount).fold<int>(c.config.globalSettings.ledCount, math.max);
    final devs = hadSerialRow
        ? existing.map((d) => d.type == 'serial' ? d.copyWith(port: port) : d).toList()
        : [
            ...existing,
            DeviceSettings(
              id: 'd${DateTime.now().millisecondsSinceEpoch % 100000000}',
              name: context.l10n.comScanUsbDeviceDefaultName(port),
              type: 'serial',
              port: port,
              ledCount: ledHint.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice),
            ),
          ];
    final next = c.config.copyWith(
      globalSettings: c.config.globalSettings.copyWith(
        devices: devs,
        serialPort: port,
      ),
    );
    traceDeviceBindings(
      'DevicesPage._findAmbilightCom: COM=$port hadSerialRow=$hadSerialRow → '
      '${hadSerialRow ? "update serial ports" : "append USB device row"}',
    );
    traceConfigBindings('DevicesPage._findAmbilightCom před apply', c.config);
    // Krátká prodleva po zavření portu ve discovery — stabilnější první connect bez hard resetu ESP.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    await c.applyConfigAndPersist(next);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            hadSerialRow ? context.l10n.serialPortSet(port) : context.l10n.comScanUsbDeviceAdded(port),
          ),
        ),
      );
    }
  }

  Future<void> _discover() async {
    await DiscoveryWizardDialog.show(context);
  }

  /// Stejná logika jako dříve v Nastavení — změna COM/IP/typu okamžitě přestaví transporty.
  void _patchDevices(List<DeviceSettings> devices) {
    final c = context.read<AmbilightAppController>();
    final prev = c.config.globalSettings.devices;
    final next = c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(devices: devices));
    traceDeviceBindings(
      'DevicesPage._patchDevices: nový seznam (${devices.length}) → ${formatDeviceBindingsList(devices)}',
    );
    traceConfigBindings('DevicesPage._patchDevices: snapshot před apply', c.config);
    final hot = AmbilightAppController.devicesChangeRequiresTransportRebuild(prev, devices);
    traceDeviceBindings('DevicesPage._patchDevices: transportRebuild=$hot');
    if (hot) {
      unawaited(() async {
        try {
          await c.applyConfigAndPersist(next);
          traceDeviceBindings('DevicesPage._patchDevices: applyConfigAndPersist OK');
        } catch (e, st) {
          traceDeviceBindingsSevere('DevicesPage._patchDevices: applyConfigAndPersist výjimka', e, st);
          reportAppFault(AppLocaleBridge.strings.settingsDevicesSaveFailed(e.toString().split('\n').first));
        }
      }());
    } else {
      c.queueConfigApply(next);
    }
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
                      var fwTemporal = 0;
                      final pong = await LedDiscoveryService.queryPong(ip.replaceAll(',', '.'), udpPort: port);
                      if (pong != null) {
                        firmware = firmware.isEmpty ? pong.version : firmware;
                        fwTemporal = pong.fwTemporalSmoothingMode ?? 0;
                      } else if (firmware.isEmpty) {
                        firmware = '';
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
                          ledCount: leds.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice),
                          firmwareVersion: firmware,
                          fwTemporalSmoothingMode: fwTemporal,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              RepaintBoundary(
                child: AmbiGlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.devicesActionsTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Tooltip(
                        message: context.l10n.devicesActionDiscoverTooltip,
                        child: FilledButton.icon(
                          onPressed: _discover,
                          icon: const Icon(Icons.wifi_tethering),
                          label: Text(context.l10n.discoveryWizardLabel),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, bc) {
                          final narrow = bc.maxWidth < 520;
                          final l10n = context.l10n;
                          final children = [
                            Tooltip(
                              message: l10n.devicesActionZonesTooltip,
                              child: OutlinedButton.icon(
                                onPressed: () => ZoneEditorWizardDialog.show(context),
                                icon: const Icon(Icons.border_outer),
                                label: Text(l10n.segmentsLabel),
                              ),
                            ),
                            Tooltip(
                              message: l10n.devicesActionSegGeomTooltip,
                              child: OutlinedButton.icon(
                                onPressed: () => SegmentGeometryWizardDialog.show(context),
                                icon: const Icon(Icons.screen_rotation_alt_outlined),
                                label: Text(l10n.segGeomWizardLaunchButton),
                              ),
                            ),
                            Tooltip(
                              message: l10n.devicesActionCalibrationTooltip,
                              child: OutlinedButton.icon(
                                onPressed: () => CalibrationWizardDialog.show(context),
                                icon: const Icon(Icons.tune),
                                label: Text(l10n.calibrationLabel),
                              ),
                            ),
                            Tooltip(
                              message: l10n.devicesActionPresetTooltip,
                              child: OutlinedButton.icon(
                                onPressed: () => ConfigProfileWizardDialog.show(context),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                label: Text(l10n.screenPresetLabel),
                              ),
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
                      Tooltip(
                        message: context.l10n.devicesActionAddWifiTooltip,
                        child: OutlinedButton.icon(
                          onPressed: () => _openSaveDeviceSheet(context, preset: null),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.addWifiManual),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: context.l10n.devicesActionFindComTooltip,
                        child: OutlinedButton.icon(
                          onPressed: _findingCom ? null : _findAmbilightCom,
                          icon: _findingCom
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.usb),
                          label: Text(_findingCom ? context.l10n.findingCom : context.l10n.findAmbilightCom),
                        ),
                      ),
                      if (_findingCom && _comScanTotal > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_comScanIndex + 1} / $_comScanTotal',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              Selector<AmbilightAppController, AppConfig>(
                selector: (_, ctrl) => ctrl.config,
                builder: (context, draft, _) {
                  return RepaintBoundary(
                    child: DevicesTab(
                      draft: draft,
                      maxWidth: constraints.maxWidth,
                      onDevicesChanged: _patchDevices,
                    ),
                  );
                },
              ),
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
  }
}
