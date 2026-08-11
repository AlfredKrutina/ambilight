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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  AmbiPageHeader(
                    title: context.l10n.updatesPageTitle,
                    subtitle: context.l10n.updatesPageSubtitle,
                    bottomSpacing: 16,
                  ),
                  Text(
                    context.l10n.updatesSectionAppTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.updatesSectionAppHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const AmbiGlassPanel(
                    padding: EdgeInsets.all(18),
                    child: AboutDesktopUpdateCard(),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.l10n.updatesSectionDeviceTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.updatesSectionDeviceHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
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
