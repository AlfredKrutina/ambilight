import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';

/// Export / import JSON konfigurace (parita PyQt + `importConfigFromJsonString`).
class ConfigBackupSection extends StatelessWidget {
  const ConfigBackupSection({super.key, this.onImported});

  /// Po úspěšném importu — např. obnovit draft v [SettingsPage].
  final VoidCallback? onImported;

  Future<void> _export(BuildContext context) async {
    final c = context.read<AmbilightAppController>();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export konfigurace AmbiLight',
      fileName: 'ambilight_config.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    final out = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    try {
      await File(out).writeAsString(c.exportConfigJsonString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uloženo: $out')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export selhal: $e')));
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final c = context.read<AmbilightAppController>();
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (r == null || r.files.isEmpty) return;
    final p = r.files.single.path;
    if (p == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Soubor nelze přečíst (chybí cesta).')),
        );
      }
      return;
    }
    try {
      final text = await File(p).readAsString();
      await c.importConfigFromJsonString(text);
      onImported?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfigurace načtena a uložena.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import selhal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Záloha konfigurace', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'JSON stejný jako u Python verze (`config/default.json`). Import přepíše běžící nastavení a uloží ho.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _export(context),
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: const Text('Exportovat JSON…'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                  label: const Text('Importovat JSON…'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
