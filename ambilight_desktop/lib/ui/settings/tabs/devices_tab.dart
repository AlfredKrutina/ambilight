import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/device_bindings_debug.dart';
import '../../../core/models/config_models.dart';
import '../../../data/udp_device_commands.dart';
import '../../../services/led_discovery_service.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/config_device_list_tile.dart';
import '../../wizards/led_strip_wizard_dialog.dart';
import '../../../l10n/context_ext.dart';
import '../../../l10n/generated/app_localizations.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onDevicesChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<List<DeviceSettings>> onDevicesChanged;

  static String _newDeviceId() => 'd${DateTime.now().millisecondsSinceEpoch}';

  static String _connectionTileSubtitle(DeviceSettings d, AppLocalizations l10n) {
    if (d.type == 'wifi') {
      if (d.ipAddress.trim().isEmpty) return l10n.devicesWifiIpMissing;
      return l10n.devicesWifiSaved;
    }
    if (d.port.trim().isEmpty) return l10n.devicesSerialPortMissing;
    return l10n.devicesPortSummary(d.port);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = draft.globalSettings.devices;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);
    final ports = AmbilightAppController.serialPorts();

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.devicesTabHeader,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.devicesTabIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (devices.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.devicesTabEmptyHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  final next = List<DeviceSettings>.from(devices)
                    ..add(
                      DeviceSettings(
                        id: _newDeviceId(),
                        name: l10n.devicesNewDeviceName,
                        type: 'serial',
                        port: ports.isNotEmpty ? ports.first : 'COM5',
                        ledCount: draft.globalSettings.ledCount,
                      ),
                    );
                  onDevicesChanged(next);
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.devicesAddDevice),
              ),
              const SizedBox(height: 16),
              ...devices.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                return Card(
                  key: ValueKey<String>('dev-tab-${d.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.name.isEmpty ? l10n.devicesUnnamedDevice(i + 1) : d.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.segmentsLabel,
                              onPressed: () => LedStripWizardDialog.show(context, deviceId: d.id),
                              icon: const Icon(Icons.border_outer),
                            ),
                            if (d.type == 'wifi' && d.ipAddress.trim().isNotEmpty)
                              PopupMenuButton<String>(
                                tooltip: l10n.discIdentifyTooltip,
                                icon: const Icon(Icons.more_vert),
                                onSelected: (v) async {
                                  final messenger = ScaffoldMessenger.maybeOf(context);
                                  final ctrl = context.read<AmbilightAppController>();
                                  if (v == 'id') {
                                    await UdpDeviceCommands.sendIdentify(d.ipAddress, d.udpPort);
                                    return;
                                  }
                                  if (v == 'wifi') {
                                    final go = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(ctx.l10n.resetWifiTitle),
                                        content: Text(ctx.l10n.resetWifiContent(d.name)),
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
                                    final ok = await UdpDeviceCommands.sendResetWifi(
                                      d.ipAddress,
                                      d.udpPort,
                                      logContext: d.name,
                                    );
                                    if (!context.mounted || messenger == null) return;
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(ok ? l10n.resetWifiSent : l10n.resetWifiFailed)),
                                    );
                                    return;
                                  }
                                  if (v == 'fw') {
                                    final pong = await LedDiscoveryService.queryPong(d.ipAddress, udpPort: d.udpPort);
                                    if (!context.mounted || messenger == null) return;
                                    if (pong == null) {
                                      messenger.showSnackBar(SnackBar(content: Text(l10n.pongMissing)));
                                      return;
                                    }
                                    final devList = ctrl.config.globalSettings.devices;
                                    final idx = devList.indexWhere((x) => x.id == d.id);
                                    if (idx < 0) return;
                                    final dev = devList[idx];
                                    final devs = [...devList];
                                    devs[idx] = dev.copyWith(
                                      firmwareVersion: pong.version,
                                      fwTemporalSmoothingMode:
                                          pong.fwTemporalSmoothingMode ?? dev.fwTemporalSmoothingMode,
                                    );
                                    traceDeviceBindings('DevicesTab: refresh fw ${dev.id} → ${pong.version}');
                                    await ctrl.applyConfigAndPersist(
                                      ctrl.config.copyWith(
                                        globalSettings: ctrl.config.globalSettings.copyWith(devices: devs),
                                      ),
                                    );
                                    if (context.mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(l10n.firmwareLabel(pong.version))),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(value: 'id', child: Text(l10n.menuIdentifyBlink)),
                                  PopupMenuItem(value: 'fw', child: Text(l10n.menuRefreshFirmwareInfo)),
                                  PopupMenuItem(value: 'wifi', child: Text(l10n.discResetWifiTooltip)),
                                ],
                              ),
                            IconButton(
                              tooltip: l10n.devicesRemoveTooltip,
                              onPressed: () async {
                                final name = d.name.trim().isEmpty ? l10n.devicesUnnamedDevice(i + 1) : d.name;
                                final ok = await showConfirmRemoveDeviceDialog(
                                  context,
                                  deviceName: name,
                                  isLast: devices.length <= 1,
                                );
                                if (ok && context.mounted) {
                                  final removed = devices[i];
                                  traceDeviceBindings(
                                    'DevicesTab: odebrat index=$i id=${removed.id} typ=${removed.type}',
                                  );
                                  onDevicesChanged(List<DeviceSettings>.from(devices)..removeAt(i));
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deviceFriendlySubtitle(d, l10n),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: d.name,
                          decoration: InputDecoration(
                            labelText: l10n.fieldDisplayName,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(name: v);
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: l10n.fieldConnectionType,
                            border: const OutlineInputBorder(),
                          ),
                          value: (d.type == 'wifi' || d.type == 'serial') ? d.type : 'serial',
                          items: [
                            DropdownMenuItem(value: 'serial', child: Text(l10n.devicesTypeUsb)),
                            DropdownMenuItem(value: 'wifi', child: Text(l10n.devicesTypeWifi)),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            traceDeviceBindings(
                              'DevicesTab: přepnutí typu id=${d.id} z ${d.type} na $v',
                            );
                            final next = List<DeviceSettings>.from(devices);
                            if (v == 'wifi') {
                              next[i] = d.copyWith(
                                type: 'wifi',
                                port: '',
                                ipAddress: d.ipAddress.trim(),
                                udpPort: d.udpPort <= 0 ? 4210 : d.udpPort,
                              );
                            } else {
                              next[i] = d.copyWith(
                                type: 'serial',
                                ipAddress: '',
                                port: d.port.trim().isEmpty
                                    ? (ports.isNotEmpty ? ports.first : 'COM5')
                                    : d.port,
                              );
                            }
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: '${d.ledCount}',
                          decoration: InputDecoration(
                            labelText: l10n.fieldLedCount,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (v) {
                            final n = int.tryParse(v) ?? d.ledCount;
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(ledCount: n.clamp(1, 2000));
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.devicesControlViaHa),
                          subtitle: Text(l10n.devicesControlViaHaSubtitle),
                          value: d.controlViaHa,
                          onChanged: (v) {
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(controlViaHa: v);
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l10n.deviceFwTemporalSectionTitle,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.deviceFwTemporalHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: [
                            ButtonSegment(value: 0, label: Text(l10n.deviceFwTemporalOff)),
                            ButtonSegment(value: 1, label: Text(l10n.deviceFwTemporalSmooth)),
                            ButtonSegment(value: 2, label: Text(l10n.deviceFwTemporalSnap)),
                          ],
                          selected: {d.fwTemporalSmoothingMode.clamp(0, 2)},
                          onSelectionChanged: (set) {
                            final v = set.first;
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(fwTemporalSmoothingMode: v);
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              final ctrl = context.read<AmbilightAppController>();
                              final ok = await ctrl.sendFirmwareTemporalModeForDevice(
                                d.id,
                                d.fwTemporalSmoothingMode,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok ? l10n.deviceFwTemporalSnackOk : l10n.deviceFwTemporalSnackFail,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.send_outlined),
                            label: Text(l10n.deviceFwTemporalApply),
                          ),
                        ),
                        ExpansionTile(
                          initiallyExpanded: d.type == 'serial' ||
                              (d.type == 'wifi' && d.ipAddress.trim().isEmpty),
                          title: Text(l10n.devicesConnectionSection),
                          subtitle: Text(_connectionTileSubtitle(d, l10n)),
                          children: [
                            if (d.type == 'serial') ...[
                              TextFormField(
                                key: ValueKey<String>('port-$i-${d.port}'),
                                initialValue: d.port,
                                decoration: InputDecoration(
                                  labelText: l10n.fieldComPort,
                                  hintText: ports.isNotEmpty ? l10n.devicesComHintExample(ports.first) : l10n.devicesComHintExample('COM3'),
                                  border: const OutlineInputBorder(),
                                  helperText: ports.isEmpty
                                      ? null
                                      : l10n.devicesComDetectedHelper(ports.join(', ')),
                                ),
                                onChanged: (v) {
                                  final next = List<DeviceSettings>.from(devices);
                                  next[i] = d.copyWith(port: v);
                                  onDevicesChanged(next);
                                },
                              ),
                              if (ports.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: ports
                                      .map(
                                        (p) => ActionChip(
                                          label: Text(p),
                                          onPressed: () {
                                            final next = List<DeviceSettings>.from(devices);
                                            next[i] = d.copyWith(port: p);
                                            onDevicesChanged(next);
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                            if (d.type == 'wifi') ...[
                              TextFormField(
                                key: ValueKey<String>('ip-$i-${d.ipAddress}'),
                                initialValue: d.ipAddress,
                                decoration: InputDecoration(
                                  labelText: l10n.fieldControllerIp,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.url,
                                onChanged: (v) {
                                  final next = List<DeviceSettings>.from(devices);
                                  next[i] = d.copyWith(ipAddress: v.trim());
                                  onDevicesChanged(next);
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: ValueKey<String>('udp-$i-${d.udpPort}'),
                                initialValue: '${d.udpPort}',
                                decoration: InputDecoration(
                                  labelText: l10n.fieldUdpPort,
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (v) {
                                  final p = int.tryParse(v) ?? d.udpPort;
                                  final next = List<DeviceSettings>.from(devices);
                                  next[i] = d.copyWith(udpPort: p.clamp(1, 65535));
                                  onDevicesChanged(next);
                                },
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextFormField(
                              key: ValueKey<String>('id-$i-${d.id}'),
                              initialValue: d.id,
                              decoration: InputDecoration(
                                labelText: l10n.fieldInternalId,
                                helperText: l10n.helperInternalId,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final next = List<DeviceSettings>.from(devices);
                                next[i] = d.copyWith(id: v.trim().isEmpty ? d.id : v.trim());
                                onDevicesChanged(next);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
