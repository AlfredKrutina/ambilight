import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../../data/udp_device_commands.dart';
import '../../services/led_discovery_service.dart';
import 'wizard_dialog_shell.dart';

/// D9 — průvodce discovery: sken, seznam, identify, uložení (polish oproti jednoduchému AlertDialog).
class DiscoveryWizardDialog extends StatefulWidget {
  const DiscoveryWizardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const DiscoveryWizardDialog(),
    );
  }

  @override
  State<DiscoveryWizardDialog> createState() => _DiscoveryWizardDialogState();
}

class _DiscoveryWizardDialogState extends State<DiscoveryWizardDialog> {
  bool _scanning = false;
  List<DiscoveredLedController> _found = [];

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found = [];
    });
    final list = await LedDiscoveryService.scan();
    if (!mounted) return;
    setState(() {
      _found = list;
      _scanning = false;
    });
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žádné zařízení neodpovědělo (UDP 4210).')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _savePreset(BuildContext context, DiscoveredLedController d) async {
    final c = context.read<AmbilightAppController>();
    final devs = [
      ...c.config.globalSettings.devices,
      DeviceSettings(
        id: 'd${DateTime.now().millisecondsSinceEpoch % 100000000}',
        name: d.name,
        type: 'wifi',
        ipAddress: d.ip,
        udpPort: 4210,
        ledCount: d.ledCount.clamp(1, 512),
        firmwareVersion: d.version,
      ),
    ];
    await c.applyConfigAndPersist(
      c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(devices: devs)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Přidáno: ${d.name}')));
    }
  }

  Future<void> _confirmResetWifi(BuildContext context, DiscoveredLedController d) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Wi‑Fi?'),
        content: Text(
          'Zařízení „${d.name}“ (${d.ip}) smaže uložené Wi‑Fi přihlašovací údaje '
          'a restartuje se. Budete ho muset znovu nakonfigurovat.',
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
    final ok = await UdpDeviceCommands.sendResetWifi(d.ip, 4210, logContext: d.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'RESET_WIFI odeslán.' : 'Odeslání se nezdařilo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WizardDialogShell(
      title: 'Discovery (D9)',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hotovo')),
        FilledButton.tonal(
          onPressed: _scanning ? null : _scan,
          child: Text(_scanning ? 'Skenuji…' : 'Znovu skenovat'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Broadcast DISCOVER_ESP32 na port 4210. Identify pošle krátké zvýraznění na strip.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (_scanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_found.isEmpty)
            Text(
              'Žádná zařízení. Zkontroluj síť a FW.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            ..._found.map(
              (d) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(d.name),
                  subtitle: Text('${d.ip} · LED ${d.ledCount} · FW ${d.version}'),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Reset Wi‑Fi (smaže uložené přihlašovací údaje)',
                        icon: const Icon(Icons.wifi_off_outlined),
                        onPressed: () => _confirmResetWifi(context, d),
                      ),
                      IconButton(
                        tooltip: 'Identify',
                        icon: const Icon(Icons.highlight),
                        onPressed: () => UdpDeviceCommands.sendIdentify(d.ip, 4210),
                      ),
                      FilledButton(
                        onPressed: () => _savePreset(context, d),
                        child: const Text('Přidat'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
