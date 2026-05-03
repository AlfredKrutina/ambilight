import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
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
  final _nameCtrl = TextEditingController(text: 'Můj preset');

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AmbilightAppController>();
    final existing = c.config.userScreenPresets.keys.toList()..sort();

    return WizardDialogShell(
      title: 'Uložit screen preset (D14)',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zavřít')),
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
                SnackBar(content: Text('Preset „$name“ uložen do user_screen_presets.')),
              );
            }
          },
          child: const Text('Uložit'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Soubor profilu (`default.json` / jiný) řeší ConfigRepository; zde jen snapshot aktuálního screen módu do JSON pole user_screen_presets.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Název presetu',
              border: OutlineInputBorder(),
            ),
          ),
          if (existing.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Existující presety:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...existing.map((e) => ListTile(dense: true, title: Text(e))),
          ],
        ],
      ),
    );
  }
}
