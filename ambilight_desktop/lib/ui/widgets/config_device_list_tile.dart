import 'package:flutter/material.dart';

import '../../core/models/config_models.dart';

/// Krátký popis typu a počtu LED — bez IP ani technických identifikátorů.
String deviceKindUserLabel(DeviceSettings d) => d.type == 'wifi' ? 'Wi‑Fi' : 'USB';

String deviceFriendlySubtitle(DeviceSettings d) {
  final kind = deviceKindUserLabel(d);
  final n = d.ledCount;
  return '$kind · $n LED';
}

/// Řádek zařízení: přehledné zobrazení + menu pro akce (technické údaje jen v dialogu).
class ConfigDeviceListTile extends StatelessWidget {
  const ConfigDeviceListTile({
    super.key,
    required this.device,
    required this.connected,
    required this.onEditStrip,
    this.onIdentify,
    this.onResetWifi,
    this.onRefreshFirmware,
  });

  final DeviceSettings device;
  final bool connected;
  final VoidCallback onEditStrip;
  final VoidCallback? onIdentify;
  final VoidCallback? onResetWifi;
  final VoidCallback? onRefreshFirmware;

  static void _showDetails(BuildContext context, DeviceSettings d) {
    final buf = StringBuffer()
      ..writeln('Interní ID: ${d.id}')
      ..writeln('Typ: ${d.type}')
      ..writeln('Počet LED: ${d.ledCount}');
    if (d.type == 'wifi') {
      buf.writeln('IP: ${d.ipAddress.isEmpty ? "—" : d.ipAddress}');
      buf.writeln('UDP port: ${d.udpPort}');
    } else {
      buf.writeln('Port: ${d.port}');
    }
    if (d.firmwareVersion.isNotEmpty) {
      buf.writeln('Firmware: ${d.firmwareVersion}');
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Technické údaje'),
        content: SelectableText(buf.toString().trimRight()),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zavřít'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = device;
    final isWifi = d.type == 'wifi';
    final scheme = Theme.of(context).colorScheme;
    final haNote = d.controlViaHa;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onEditStrip,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  isWifi ? Icons.wifi_rounded : Icons.usb_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          deviceFriendlySubtitle(d),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        Icon(
                          connected ? Icons.link_rounded : Icons.link_off_rounded,
                          size: 16,
                          color: connected ? scheme.primary : scheme.error,
                        ),
                        Text(
                          connected ? 'Spojení OK' : 'Nepřipojeno',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: connected ? scheme.primary : scheme.error,
                              ),
                        ),
                      ],
                    ),
                    if (haNote)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Ovládání přes Home Assistant — barvy z PC se na toto zařízení neposílají.',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.tertiary),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Další akce',
                onSelected: (value) {
                  switch (value) {
                    case 'details':
                      _showDetails(context, d);
                    case 'edit':
                      onEditStrip();
                    case 'identify':
                      onIdentify?.call();
                    case 'fw':
                      onRefreshFirmware?.call();
                    case 'reset_wifi':
                      onResetWifi?.call();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Upravit mapování LED')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'details', child: Text('Technické údaje…')),
                  if (isWifi && d.ipAddress.isNotEmpty && onIdentify != null)
                    const PopupMenuItem(value: 'identify', child: Text('Krátce identifikovat (bliknutí)')),
                  if (onRefreshFirmware != null)
                    const PopupMenuItem(value: 'fw', child: Text('Obnovit údaj o firmwaru')),
                  if (isWifi && d.ipAddress.isNotEmpty && onResetWifi != null)
                    const PopupMenuItem(
                      value: 'reset_wifi',
                      child: Text('Reset uložené Wi‑Fi na kontroléru'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
