import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../l10n/context_ext.dart';
import 'wizard_dialog_shell.dart';

/// D14 — uloží aktuální `screen_mode` jako uživatelský preset do `user_screen_presets`.
class ConfigProfileWizardDialog extends StatefulWidget {
  const ConfigProfileWizardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const ConfigProfileWizardDialog());
  }

  @override
  State<ConfigProfileWizardDialog> createState() => _ConfigProfileWizardDialogState();
}

class _ConfigProfileWizardDialogState extends State<ConfigProfileWizardDialog> {
  final _nameCtrl = TextEditingController();
  bool _draftNameApplied = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftNameApplied) return;
    _draftNameApplied = true;
    _nameCtrl.text = context.l10n.defaultPresetNameDraft;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<AmbilightAppController>();
    final existing = c.config.userScreenPresets.keys.toList()..sort();

    return WizardDialogShell(
      title: l10n.configProfileWizardTitle,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        FilledButton(
          onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final nextPresets = Map<String, Map<String, dynamic>>.from(c.config.userScreenPresets);
            nextPresets[name] = Map<String, dynamic>.from(c.config.screenMode.toJson());
            await c.applyConfigAndPersist(c.config.copyWith(userScreenPresets: nextPresets));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.configProfileSavedSnack(name))),
              );
            }
          },
          child: Text(l10n.save),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.configProfileIntro,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.configProfileNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (existing.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.configProfileExistingTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...existing.map((e) => ListTile(dense: true, title: Text(e))),
          ],
        ],
      ),
    );
  }
}
