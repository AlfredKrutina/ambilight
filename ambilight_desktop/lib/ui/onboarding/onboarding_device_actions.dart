import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/app_error_safety.dart';
import '../../core/device_bindings_debug.dart';
import '../../core/models/config_models.dart';
import '../../core/protocol/serial_frame.dart';
import '../../l10n/app_locale_bridge.dart';
import '../../l10n/context_ext.dart';
import '../../services/serial_ambilight_port_discovery.dart';
import '../wizards/discovery_wizard_dialog.dart';

/// Wi‑Fi / UDP discovery — stejný dialog jako na stránce Zařízení.
Future<void> onboardingOpenWifiDiscovery(BuildContext context) {
  return DiscoveryWizardDialog.show(context);
}

/// COM scan se handshake — stejná logika jako [DevicesPage]._findAmbilightCom.
Future<void> onboardingSetupSerialUsb(BuildContext context) async {
  final c = context.read<AmbilightAppController>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(SnackBar(content: Text(context.l10n.comScanHandshake)));
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
  if (!context.mounted) return;
  if (port == null) {
    messenger?.showSnackBar(SnackBar(content: Text(context.l10n.comScanNoReply)));
    return;
  }
  final existing = c.config.globalSettings.devices;
  final hadSerialRow = existing.any((d) => d.type == 'serial');
  final wifiDevices = existing.where((d) => d.type == 'wifi');
  final ledHint = wifiDevices.isEmpty
      ? c.config.globalSettings.ledCount
      : wifiDevices.first.ledCount;
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
    'onboardingSetupSerialUsb: COM=$port hadSerialRow=$hadSerialRow',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (!context.mounted) return;
  try {
    await c.applyConfigAndPersist(next);
  } catch (e, st) {
    traceDeviceBindingsSevere('onboardingSetupSerialUsb apply výjimka', e, st);
    reportAppFault(AppLocaleBridge.strings.settingsDevicesSaveFailed(e.toString().split('\n').first));
    return;
  }
  if (context.mounted) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          hadSerialRow ? context.l10n.serialPortSet(port) : context.l10n.comScanUsbDeviceAdded(port),
        ),
      ),
    );
  }
}
