import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../layout_breakpoints.dart';

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
                              child: Text('Zařízení ${i + 1}', style: Theme.of(context).textTheme.titleSmall),
                            ),
                            if (devices.length > 1)
                              IconButton(
                                tooltip: 'Odebrat',
                                onPressed: () {
                                  final next = List<DeviceSettings>.from(devices)..removeAt(i);
                                  onDevicesChanged(next);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                        TextFormField(
                          initialValue: d.name,
                          decoration: const InputDecoration(labelText: 'Název', border: OutlineInputBorder()),
                          onChanged: (v) {
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(name: v);
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: d.id,
                          decoration: const InputDecoration(
                            labelText: 'ID (skupina v configu)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(id: v.trim().isEmpty ? d.id : v.trim());
                            onDevicesChanged(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Typ', border: OutlineInputBorder()),
                          value: d.type == 'wifi' ? 'wifi' : 'serial',
                          items: const [
                            DropdownMenuItem(value: 'serial', child: Text('Serial (USB)')),
                            DropdownMenuItem(value: 'wifi', child: Text('Wi‑Fi (UDP)')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(type: v);
                            onDevicesChanged(next);
                          },
                        ),
                        if (d.type == 'serial') ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Port (nebo zadej ručně níže)',
                              border: OutlineInputBorder(),
                            ),
                            value: ports.contains(d.port) ? d.port : null,
                            hint: Text(d.port),
                            items: [
                              ...ports.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              final next = List<DeviceSettings>.from(devices);
                              next[i] = d.copyWith(port: v);
                              onDevicesChanged(next);
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: d.port,
                            decoration: const InputDecoration(
                              labelText: 'Port (text)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final next = List<DeviceSettings>.from(devices);
                              next[i] = d.copyWith(port: v);
                              onDevicesChanged(next);
                            },
                          ),
                        ],
                        if (d.type == 'wifi') ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: d.ipAddress,
                            decoration: const InputDecoration(
                              labelText: 'IP adresa',
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
                        SwitchListTile(
                          title: const Text('Ovládání přes Home Assistant (neposílat z PC)'),
                          value: d.controlViaHa,
                          onChanged: (v) {
                            final next = List<DeviceSettings>.from(devices);
                            next[i] = d.copyWith(controlViaHa: v);
                            onDevicesChanged(next);
                          },
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
