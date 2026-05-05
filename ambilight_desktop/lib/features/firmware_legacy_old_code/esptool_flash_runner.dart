import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'firmware_manifest.dart';

/// Spuštění `esptool` / `python -m esptool` pro zápis flash podle manifestu.
///
/// Po úspěšném zápisu každého oddílu se uloží checkpoint do [downloadedDir]/.flash_checkpoint.json.
/// Při přerušení (pád procesu, zavření app) lze znovu spustit stejný flash do [kResumeSessionMaxAge]
/// od začátku relace — dokončí se jen zbývající oddíly. Po úplném dokončení se checkpoint smaže.
abstract final class EsptoolFlashRunner {
  static const String checkpointFileName = '.flash_checkpoint.json';
  static const Duration kResumeSessionMaxAge = Duration(hours: 24);

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

  static int _offHex(String o) {
    final s = o.toLowerCase().replaceFirst('0x', '');
    return int.tryParse(s, radix: 16) ?? 0;
  }

  static String _partsFingerprint(FirmwareManifest manifest) {
    final ordered = [...manifest.parts]..sort((a, b) => _offHex(a.offset).compareTo(_offHex(b.offset)));
    final canonical = ordered.map((e) => '${e.offset}|${e.file}|${e.sha256}').join('\n');
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static File _checkpointFile(String downloadedDir) => File(p.join(p.normalize(downloadedDir), checkpointFileName));

  static bool _comEq(String a, String b) {
    final ta = a.trim();
    final tb = b.trim();
    if (Platform.isWindows) {
      return ta.toUpperCase() == tb.toUpperCase();
    }
    return ta == tb;
  }

  /// Načte offsety už úspěšně zapsané v rámci platné relace (do [maxSessionAge] od [session_started_at]).
  static Future<({Set<String> completed, DateTime? sessionStarted})> _loadCheckpoint({
    required FirmwareManifest manifest,
    required String downloadedDir,
    required String comPort,
    required int baud,
    required Duration maxSessionAge,
  }) async {
    final f = _checkpointFile(downloadedDir);
    if (!await f.exists()) {
      return (completed: <String>{}, sessionStarted: null);
    }
    try {
      final j = jsonDecode(await f.readAsString());
      if (j is! Map<String, dynamic>) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      final fp = j['parts_fingerprint']?.toString() ?? '';
      if (fp != _partsFingerprint(manifest)) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      if ((j['manifest_version']?.toString() ?? '') != manifest.version) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      if ((j['chip']?.toString() ?? '') != manifest.chip) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      if (!_comEq(j['com_port']?.toString() ?? '', comPort)) {
        return (completed: <String>{}, sessionStarted: null);
      }
      if ((j['baud'] as num?)?.toInt() != baud) {
        return (completed: <String>{}, sessionStarted: null);
      }
      if ((j['flash_mode']?.toString() ?? '') != manifest.flashMode) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      if ((j['flash_freq']?.toString() ?? '') != manifest.flashFreq) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      if ((j['flash_size']?.toString() ?? '') != manifest.flashSize) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      final started = DateTime.tryParse(j['session_started_at']?.toString() ?? '')?.toUtc();
      if (started == null) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      if (DateTime.now().toUtc().isAfter(started.add(maxSessionAge))) {
        await f.delete();
        return (completed: <String>{}, sessionStarted: null);
      }
      final raw = j['completed_offsets'];
      final completed = <String>{};
      if (raw is List) {
        for (final e in raw) {
          completed.add(e.toString());
        }
      }
      return (completed: completed, sessionStarted: started);
    } catch (_) {
      try {
        await f.delete();
      } catch (_) {}
      return (completed: <String>{}, sessionStarted: null);
    }
  }

  static Future<void> _saveCheckpoint({
    required FirmwareManifest manifest,
    required String downloadedDir,
    required String comPort,
    required int baud,
    required Set<String> completed,
    required DateTime sessionStartedUtc,
  }) async {
    final f = _checkpointFile(downloadedDir);
    final payload = <String, dynamic>{
      'schema': 1,
      'parts_fingerprint': _partsFingerprint(manifest),
      'manifest_version': manifest.version,
      'chip': manifest.chip,
      'com_port': comPort.trim(),
      'baud': baud,
      'flash_mode': manifest.flashMode,
      'flash_freq': manifest.flashFreq,
      'flash_size': manifest.flashSize,
      'completed_offsets': completed.toList()..sort(),
      'session_started_at': sessionStartedUtc.toIso8601String(),
      'last_updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  static Future<void> _deleteCheckpoint(String downloadedDir) async {
    try {
      await _checkpointFile(downloadedDir).delete();
    } catch (_) {}
  }

  /// Zapíše všechny [manifest.parts] z adresáře [downloadedDir] (soubory podle názvu).
  ///
  /// Při přerušení uloží průběh; stejný manifest + COM + baud + cache složka — znovu spusť do 24 h
  /// od prvního spuštění relace, dokončí se zbývající oddíly.
  static Future<(bool ok, String log)> flashSerial({
    required FirmwareManifest manifest,
    required String downloadedDir,
    required String comPort,
    int baud = 460800,
    Duration resumeSessionMaxAge = kResumeSessionMaxAge,
  }) async {
    final (prefix, err) = await _resolvePrefix();
    if (prefix.isEmpty) {
      return (false, err ?? 'esptool');
    }
    final exe = prefix.first;
    final head = prefix.skip(1).toList();
    final root = p.normalize(downloadedDir);

    final loaded = await _loadCheckpoint(
      manifest: manifest,
      downloadedDir: root,
      comPort: comPort,
      baud: baud,
      maxSessionAge: resumeSessionMaxAge,
    );
    var completed = loaded.completed;
    var sessionStarted = loaded.sessionStarted;

    sessionStarted ??= DateTime.now().toUtc();

    final ordered = [...manifest.parts]..sort((a, b) => _offHex(a.offset).compareTo(_offHex(b.offset)));
    final logBuf = StringBuffer();
    if (completed.isNotEmpty) {
      logBuf.writeln('Pokračování flash: přeskakuji ${completed.length} už zapsaných oddílů (relace do '
          '${sessionStarted.add(resumeSessionMaxAge).toIso8601String()} UTC).');
    }

    for (final part in ordered) {
      if (part.offset.isEmpty || part.file.isEmpty) continue;
      final offKey = part.offset.trim();
      if (completed.contains(offKey)) {
        logBuf.writeln('Přeskakuji $offKey ${part.file} (už v checkpointu).');
        continue;
      }
      final fp = p.normalize(p.join(root, part.file));
      if (!File(fp).existsSync()) {
        return (false, '${logBuf}Chybí soubor: $fp');
      }

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
        part.offset,
        fp,
      ];

      logBuf.writeln('→ esptool … write_flash ${part.offset} ${part.file}');
      final r = await Process.run(
        exe,
        args,
        runInShell: Platform.isWindows,
        environment: {...Platform.environment},
      );
      final chunkOut = '${r.stdout}\n${r.stderr}'.trim();
      if (chunkOut.isNotEmpty) {
        logBuf.writeln(chunkOut);
      }
      if (r.exitCode != 0) {
        return (false, logBuf.toString());
      }
      completed = {...completed, offKey};
      await _saveCheckpoint(
        manifest: manifest,
        downloadedDir: root,
        comPort: comPort,
        baud: baud,
        completed: completed,
        sessionStartedUtc: sessionStarted,
      );
    }

    await _deleteCheckpoint(root);
    final out = logBuf.toString().trim();
    return (true, out.isEmpty ? '(hotovo, žádný výstup esptool)' : out);
  }
}
