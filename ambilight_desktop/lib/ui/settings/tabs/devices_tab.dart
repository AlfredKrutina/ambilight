import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/config_device_list_tile.dart';

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

  static String _connectionTileSubtitle(DeviceSettings d) {
    if (d.type == 'wifi') {
      if (d.ipAddress.trim().isEmpty) return 'Doplň IP adresu kontroléru';
      return 'Síťové údaje uloženy (uprav v rozbalení)';
    }
    if (d.port.trim().isEmpty) return 'Zadej COM port nebo vyber z detekovaných';
    return 'Port ${d.port}';
  }

  @override
  Widget build(BuildContext context) {
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
                'Zařízení',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Název a počet LED jsou důležité pro ovládání. IP a port jsou v sekci Připojení.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  final next = List<DeviceSettings>.from(devices)
                    ..add(
                      DeviceSettings(
                        id: _newDeviceId(),
                        name: 'Nové zařízení',
                        type: 'serial',
                        port: ports.isNotEmpty ? ports.first : 'COM5',
                        ledCount: draft.globalSettings.ledCount,
                      ),
                    );
                  onDevicesChanged(next);
                },
                icon: const Icon(Icons.add),
                label: const Text('Přidat zařízení'),
              ),
              const SizedBox(height: 16),
              ...devices.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                return Card(
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
                                d.name.isEmpty ? 'Zařízení ${i + 1}' : d.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (devices.length > 1)
                              IconButton(
                                tooltip: 'Odebrat zařízení',
                                onPressed: () {
                                  final next = List<DeviceSettings>.from(devices)..removeAt(i);
                                  onDevicesChanged(next);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deviceFriendlySubtitle(d),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: d.name,
                          decoration: const InputDecoration(
                            labelText: 'Zobrazovaný název',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(name: v);
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Typ připojení', border: OutlineInputBorder()),
                          value: d.type == 'wifi' ? 'wifi' : 'serial',
                          items: const [
                            DropdownMenuItem(value: 'serial', child: Text('USB (sériový port)')),
                            DropdownMenuItem(value: 'wifi', child: Text('Wi‑Fi (UDP)')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(type: v);
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: '${d.ledCount}',
                          decoration: const InputDecoration(
                            labelText: 'Počet LED',
                            border: OutlineInputBorder(),
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
                          title: const Text('Ovládat přes Home Assistant'),
                          subtitle: const Text('PC nebude na toto zařízení posílat barvy.'),
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
                          title: const Text('Připojení a interní údaje'),
                          subtitle: Text(_connectionTileSubtitle(d)),
                          children: [
                            if (d.type == 'serial') ...[
                              TextFormField(
                                key: ValueKey<String>('port-$i-${d.port}'),
                                initialValue: d.port,
                                decoration: InputDecoration(
                                  labelText: 'COM port',
                                  hintText: ports.isNotEmpty ? 'např. ${ports.first}' : 'COM3',
                                  border: const OutlineInputBorder(),
                                  helperText: ports.isEmpty
                                      ? null
                                      : 'Detekované: ${ports.join(", ")} — klepnutím níže rychle vyplníš',
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
                                decoration: const InputDecoration(
                                  labelText: 'IP adresa kontroléru',
                                  border: OutlineInputBorder(),
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
                                decoration: const InputDecoration(
                                  labelText: 'UDP port',
                                  border: OutlineInputBorder(),
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
                              decoration: const InputDecoration(
                                labelText: 'Interní ID (odkazy v konfiguraci)',
                                helperText: 'Měň jen pokud víš, že segmenty v JSON na to odkazují.',
                                border: OutlineInputBorder(),
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
