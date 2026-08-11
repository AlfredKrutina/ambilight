import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../../l10n/context_ext.dart';
import '../dashboard_ui.dart';
import '../responsive_body.dart';
import '../widgets/about_desktop_update_card.dart';
import 'device_firmware_panel.dart';

/// Top-level stránka: aktualizace desktop aplikace + firmware zařízení.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key});

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  String? _flashDeviceId;
  AmbilightAppController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<AmbilightAppController>();
    if (!identical(_controller, next)) {
      _controller?.removeListener(_pullPendingDevice);
      _controller = next..addListener(_pullPendingDevice);
      _pullPendingDevice();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_pullPendingDevice);
    super.dispose();
  }

  void _pullPendingDevice() {
    final id = _controller?.takePendingFlashDeviceId();
    if (id != null && mounted) {
      setState(() => _flashDeviceId = id);
    }
  }

  void _patchGlobal(GlobalSettings g) {
    final c = context.read<AmbilightAppController>();
    c.queueConfigApply(c.config.copyWith(globalSettings: g));
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AmbilightAppController, AppConfig>(
      selector: (_, c) => c.config,
      builder: (context, draft, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return ResponsiveBody(
              maxWidth: constraints.maxWidth,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                children: [
                  AmbiPageHeader(
                    title: context.l10n.updatesPageTitle,
                    subtitle: context.l10n.updatesPageSubtitle,
                    bottomSpacing: 20,
                  ),
                  AmbiSectionHeader(
                    title: context.l10n.updatesSectionAppTitle,
                    subtitle: context.l10n.updatesSectionAppHint,
                  ),
                  const AmbiSurfacePanel(
                    padding: EdgeInsets.all(18),
                    child: AboutDesktopUpdateCard(),
                  ),
                  const SizedBox(height: 28),
                  AmbiSectionHeader(
                    title: context.l10n.updatesSectionDeviceTitle,
                    subtitle: context.l10n.updatesSectionDeviceHint,
                  ),
                  DeviceFirmwarePanel(
                    key: ValueKey<String>('fw-${_flashDeviceId ?? 'none'}'),
                    draft: draft,
                    onGlobalChanged: _patchGlobal,
                    initialDeviceId: _flashDeviceId,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
