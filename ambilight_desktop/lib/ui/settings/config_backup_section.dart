import 'dart:convert' show utf8;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../l10n/context_ext.dart';

/// macOS: vlastní NSOpenPanel — file_picker + sandbox bez entitlementů často neukáže Finder.
const MethodChannel _kMacConfigBackupChannel =
    MethodChannel('ambilight/config_backup');

/// Export / import JSON konfigurace (parita PyQt + `importConfigFromJsonString`).
class ConfigBackupSection extends StatelessWidget {
  const ConfigBackupSection({super.key, this.onImported});

  /// Po úspěšném importu — např. obnovit draft v [SettingsPage].
  final VoidCallback? onImported;

  Future<void> _export(BuildContext context, {required bool includeSecrets}) async {
    final l10n = context.l10n;
    final c = context.read<AmbilightAppController>();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: includeSecrets ? l10n.backupSecretsSaveDialogTitle : l10n.exportDialogTitle,
      fileName: includeSecrets ? 'ambilight_config_with_secrets.json' : 'ambilight_config.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    final out = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    try {
      final json =
          includeSecrets ? await c.exportConfigJsonForBackup(includeSecrets: true) : c.exportConfigJsonString();
      await File(out).writeAsString(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportSavedTo(out))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.exportFailed(e.toString()))));
      }
    }
  }

  Future<void> _exportWithSecrets(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupSecretsExportTitle),
        content: SingleChildScrollView(child: Text(l10n.backupSecretsExportBody)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.backupExportWithSecretsConfirm)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _export(context, includeSecrets: true);
    }
  }

  Future<void> _import(BuildContext context) async {
    final c = context.read<AmbilightAppController>();
    final initialDirectory = Platform.environment['HOME'];

    Future<String?> textFromFilePickerResult(FilePickerResult? r) async {
      if (r == null || r.files.isEmpty) return null;
      final picked = r.files.single;
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        return utf8.decode(picked.bytes!);
      }
      final p = picked.path;
      if (p != null) {
        return File(p).readAsString();
      }
      return null;
    }

    Future<String?> pickViaFilePicker() async {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        initialDirectory: initialDirectory,
      );
      if (r == null || r.files.isEmpty) return null;
      final s = await textFromFilePickerResult(r);
      if (s == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importReadError)),
        );
      }
      return s;
    }

    late final String text;
    if (Platform.isMacOS) {
      try {
        final path =
            await _kMacConfigBackupChannel.invokeMethod<String>('pickImportJsonPath');
        if (path == null || path.isEmpty) return;
        try {
          text = await File(path).readAsString();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.importFailed(e.toString()))),
            );
          }
          return;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[ConfigBackup] mac native picker fallback: $e\n$st');
        }
        final fallback = await pickViaFilePicker();
        if (fallback == null) return;
        text = fallback;
      }
    } else {
      final s = await pickViaFilePicker();
      if (s == null) return;
      text = s;
    }

    try {
      await c.importConfigFromJsonString(text);
      onImported?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importLoaded)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.importFailed(e.toString()))));
      }
    }
  }

  Future<void> _factoryReset(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.factoryResetDialogTitle),
        content: SingleChildScrollView(child: Text(l10n.factoryResetDialogBody)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onError, backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.factoryResetConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final c = context.read<AmbilightAppController>();
    try {
      await c.factoryResetAndPersist();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.factoryResetDone)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.factoryResetFailed(e.toString()))));
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
            Text(context.l10n.backupTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              context.l10n.backupIntroBody,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.backupImportRestoresTokensHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _export(context, includeSecrets: false),
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: Text(context.l10n.backupExport),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportWithSecrets(context),
                  icon: const Icon(Icons.key_outlined, size: 20),
                  label: Text(context.l10n.backupExportWithSecrets),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                  label: Text(context.l10n.backupImport),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(context.l10n.factoryResetTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _factoryReset(context),
              icon: const Icon(Icons.restart_alt_outlined, size: 20),
              label: Text(context.l10n.factoryResetButton),
            ),
          ],
        ),
      ),
    );
  }
}
