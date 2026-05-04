import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../l10n/context_ext.dart';
import 'wizard_dialog_shell.dart';

/// D12 — výběr aktivního kalibračního profilu z `calibration_profiles`.
class CalibrationWizardDialog extends StatefulWidget {
  const CalibrationWizardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const CalibrationWizardDialog());
  }

  @override
  State<CalibrationWizardDialog> createState() => _CalibrationWizardDialogState();
}

class _CalibrationWizardDialogState extends State<CalibrationWizardDialog> {
  bool _ready = false;
  String? _selected;
  List<String> _names = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final c = context.read<AmbilightAppController>();
    final sm = c.config.screenMode;
    _names = sm.calibrationProfiles.keys.toList()..sort();
    _selected = sm.activeCalibrationProfile;
    if (_names.isNotEmpty && !_names.contains(_selected)) {
      _selected = _names.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<AmbilightAppController>();
    final sm = c.config.screenMode;

    return WizardDialogShell(
      title: l10n.calibWizardTitle,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        FilledButton(
          onPressed: _names.isEmpty || _selected == null
              ? null
              : () async {
                  await c.applyConfigAndPersist(
                    c.config.copyWith(
                      screenMode: sm.copyWith(activeCalibrationProfile: _selected),
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.calibActiveProfileSnack(_selected!))),
                    );
                  }
                },
          child: Text(l10n.calibSaveChoice),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.calibWizardIntro,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          if (_names.isEmpty)
            Text(
              l10n.calibNoProfiles,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            DropdownButtonFormField<String>(
              value: _names.contains(_selected) ? _selected : _names.first,
              decoration: InputDecoration(
                labelText: l10n.calibActiveProfileLabel,
                border: const OutlineInputBorder(),
              ),
              items: _names.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
        ],
      ),
    );
  }
}
