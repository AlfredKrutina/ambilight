import 'dart:io';

import 'package:path/path.dart' as p;

import 'firmware_manifest.dart';

/// Spuštění `esptool` / `python -m esptool` pro zápis flash podle manifestu.
abstract final class EsptoolFlashRunner {
  static Future<(List<String> prefix, String? err)> _resolvePrefix() async {
    const tries = <List<String>>[
      ['esptool'],
      ['python', '-m', 'esptool'],
      ['py', '-3', '-m', 'esptool'],
      ['py', '-m', 'esptool'],
    ];
    for (final prefix in tries) {
      try {
        final r = await Process.run(
          prefix.first,
          [...prefix.skip(1), '--version'],
          runInShell: Platform.isWindows,
        );
        if (r.exitCode == 0) {
          return (prefix, null);
        }
      } on ProcessException {
        continue;
      }
    }
    return (
      <String>[],
      'Nenalezen esptool. Nainstaluj např. pip install esptool a ověř příkaz esptool v PATH.',
    );
  }

  /// Zapíše všechny [manifest.parts] z adresáře [downloadedDir] (soubory podle názvu).
  static Future<(bool ok, String log)> flashSerial({
    required FirmwareManifest manifest,
    required String downloadedDir,
    required String comPort,
    int baud = 460800,
  }) async {
    final (prefix, err) = await _resolvePrefix();
    if (prefix.isEmpty) {
      return (false, err ?? 'esptool');
    }
    final exe = prefix.first;
    final head = prefix.skip(1).toList();
    final args = <String>[
      ...head,
      '--chip',
      manifest.chip,
      '--port',
      comPort,
      '--baud',
      '$baud',
      'write_flash',
      '--flash_mode',
      manifest.flashMode,
      '--flash_freq',
      manifest.flashFreq,
      '--flash_size',
      manifest.flashSize,
    ];
    final root = p.normalize(downloadedDir);
    int offHex(String o) {
      final s = o.toLowerCase().replaceFirst('0x', '');
      return int.tryParse(s, radix: 16) ?? 0;
    }

    final ordered = [...manifest.parts]..sort((a, b) => offHex(a.offset).compareTo(offHex(b.offset)));
    for (final part in ordered) {
      if (part.offset.isEmpty || part.file.isEmpty) continue;
      final fp = p.normalize(p.join(root, part.file));
      if (!File(fp).existsSync()) {
        return (false, 'Chybí soubor: $fp');
      }
      args.add(part.offset);
      args.add(fp);
    }

    final r = await Process.run(
      exe,
      args,
      runInShell: Platform.isWindows,
      environment: {...Platform.environment},
    );
    final out = '${r.stdout}\n${r.stderr}'.trim();
    return (r.exitCode == 0, out.isEmpty ? '(žádný výstup)' : out);
  }
}
