import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/device_bindings_debug.dart';
import '../../../core/models/config_models.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/config_device_list_tile.dart';
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
