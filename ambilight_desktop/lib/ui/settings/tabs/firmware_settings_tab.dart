import 'package:flutter/material.dart';

import '../../../core/models/config_models.dart';
import '../../updates/device_firmware_panel.dart';

/// Dříve záložka Nastavení → Firmware. Flash UI je na stránce Aktualizace;
/// tento wrapper zůstává pro případné staré importy.
@Deprecated('Use UpdatesPage / DeviceFirmwarePanel')
class FirmwareSettingsTab extends StatelessWidget {
  const FirmwareSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onGlobalChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<GlobalSettings> onGlobalChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth.clamp(280, 920)),
          child: DeviceFirmwarePanel(
            draft: draft,
            onGlobalChanged: onGlobalChanged,
          ),
        ),
      ),
    );
  }
}
