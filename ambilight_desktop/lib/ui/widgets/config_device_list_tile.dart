import 'package:flutter/material.dart';

import '../../core/models/config_models.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';

/// Krátký popis typu a počtu LED — bez IP ani technických identifikátorů.
String deviceFriendlySubtitle(DeviceSettings d, AppLocalizations l10n) =>
    d.type == 'wifi' ? l10n.deviceSubtitleWifiLed(d.ledCount) : l10n.deviceSubtitleUsbLed(d.ledCount);

/// Potvrzení odebrání zařízení z konfigurace ([isLast] = poslední v seznamu).
Future<bool> showConfirmRemoveDeviceDialog(
  BuildContext context, {
  required String deviceName,
  required bool isLast,
}) async {
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.removeDeviceDialogTitle),
      content: Text(
        isLast ? l10n.removeDeviceDialogLastBody : l10n.removeDeviceDialogNamedBody(deviceName),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return go == true;
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
    this.onRemove,
  });

  final DeviceSettings device;
  final bool connected;
  final VoidCallback onEditStrip;
  final VoidCallback? onIdentify;
  final VoidCallback? onResetWifi;
  final VoidCallback? onRefreshFirmware;
  final VoidCallback? onRemove;

  static void _showDetails(BuildContext context, DeviceSettings d) {
    final l10n = context.l10n;
    final buf = StringBuffer()
      ..writeln(l10n.detailLineInternalId(d.id))
      ..writeln(l10n.detailLineType(d.type))
      ..writeln(l10n.detailLineLedCount(d.ledCount));
    if (d.type == 'wifi') {
      buf.writeln(l10n.detailLineIp(d.ipAddress.isEmpty ? '—' : d.ipAddress));
      buf.writeln(l10n.detailLineUdpPort(d.udpPort));
    } else {
      buf.writeln(l10n.detailLineSerialPort(d.port));
    }
    if (d.firmwareVersion.isNotEmpty) {
      buf.writeln(l10n.detailLineFirmware(d.firmwareVersion));
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deviceDetailsTitle),
        content: SelectableText(buf.toString().trimRight()),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                          deviceFriendlySubtitle(d, l10n),
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
                          connected ? l10n.deviceConnectionOkLabel : l10n.deviceConnectionOfflineLabel,
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
                          l10n.deviceHaControlledNote,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.tertiary),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.menuMoreActions,
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
                    case 'remove':
                      onRemove?.call();
                  }
                },
                itemBuilder: (ctx) {
                  final loc = AppLocalizations.of(ctx);
                  final err = Theme.of(ctx).colorScheme.error;
                  return [
                    PopupMenuItem(value: 'edit', child: Text(loc.menuEditLedMapping)),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'details', child: Text(loc.menuTechnicalDetailsEllipsis)),
                    if (isWifi && d.ipAddress.isNotEmpty && onIdentify != null)
                      PopupMenuItem(value: 'identify', child: Text(loc.menuIdentifyBlink)),
                    if (onRefreshFirmware != null)
                      PopupMenuItem(value: 'fw', child: Text(loc.menuRefreshFirmwareInfo)),
                    if (isWifi && d.ipAddress.isNotEmpty && onResetWifi != null)
                      PopupMenuItem(
                        value: 'reset_wifi',
                        child: Text(loc.menuResetSavedWifi),
                      ),
                    if (onRemove != null) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'remove',
                        child:
                            Text(loc.menuRemoveDeviceEllipsis, style: TextStyle(color: err, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
