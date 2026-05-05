import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/device_bindings_debug.dart';
import '../../core/models/config_models.dart';
import '../../core/protocol/serial_frame.dart';
import '../../l10n/context_ext.dart';
import '../../services/serial_ambilight_port_discovery.dart';
import '../app_navigator.dart';
import '../wizards/discovery_wizard_dialog.dart';

/// Wi‑Fi / UDP discovery — stejný dialog jako na stránce Zařízení.
Future<void> onboardingOpenWifiDiscovery(BuildContext context) {
  final dialogContext = ambiNavigatorModalContext(context) ?? context;
  return DiscoveryWizardDialog.show(dialogContext);
}

Future<void> _persistUsbPortAfterHandshake(
  BuildContext context,
  AmbilightAppController c,
  String port,
  ScaffoldMessengerState? messenger,
) async {
  final l10n = context.l10n;
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
            name: l10n.comScanUsbDeviceDefaultName(port),
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
  traceDeviceBindings('onboarding USB persist: COM=$port hadSerialRow=$hadSerialRow');
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (!context.mounted) return;
  try {
    await c.applyConfigAndPersist(next);
  } catch (e, st) {
    traceDeviceBindingsSevere('onboarding USB persist apply výjimka', e, st);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.settingsDevicesSaveFailed(e.toString().split('\n').first))),
    );
    return;
  }
  if (context.mounted) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          hadSerialRow ? l10n.serialPortSet(port) : l10n.comScanUsbDeviceAdded(port),
        ),
      ),
    );
  }
}

/// COM scan se handshake — stejná logika jako [DevicesPage]._findAmbilightCom.
Future<void> onboardingSetupSerialUsb(BuildContext context) async {
  final c = context.read<AmbilightAppController>();
  final uiContext = ambiNavigatorModalContext(context) ?? context;
  final messenger = ScaffoldMessenger.maybeOf(uiContext) ?? ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(SnackBar(content: Text(context.l10n.comScanHandshake)));
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
    ),
  );
  if (!context.mounted) return;
  if (port == null) {
    messenger?.showSnackBar(SnackBar(content: Text(context.l10n.comScanNoReply)));
    return;
  }
  await _persistUsbPortAfterHandshake(context, c, port, messenger);
}

/// Ruční výběr COM: handshake s DTR/RTS politikou ([SerialDeviceTransport.applyAmbilightPortPolicyAfterOpen]), pak uložení.
Future<void> onboardingConnectComPort(BuildContext context, String portName) async {
  final c = context.read<AmbilightAppController>();
  final uiContext = ambiNavigatorModalContext(context) ?? context;
  final messenger = ScaffoldMessenger.maybeOf(uiContext) ?? ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(SnackBar(content: Text(context.l10n.comScanHandshake)));
  final ok = await c.runWithLoopPaused(
    () => SerialAmbilightPortDiscovery.tryHandshakeOnPort(
      portName,
      baudRate: c.config.globalSettings.baudRate,
    ),
  );
  if (!context.mounted) return;
  if (!ok) {
    messenger?.showSnackBar(SnackBar(content: Text(context.l10n.comScanNoReply)));
    return;
  }
  await _persistUsbPortAfterHandshake(context, c, portName, messenger);
}
