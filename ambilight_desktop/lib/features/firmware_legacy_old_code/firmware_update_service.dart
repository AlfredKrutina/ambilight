import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'firmware_manifest.dart';

/// Stažení manifestu a binárek do cache složky.
/// Částečné soubory `._partial` — pokud stahování spadne, lze pokračovat do [kResumePartialMaxAge]
/// (výchozí 24 h); poté se částečný soubor smaže a začne znovu od začátku.
class FirmwareUpdateService {
  FirmwareUpdateService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Max. stáří nedokončeného `*. _partial` souboru pro pokračování (Range).
  static const Duration kResumePartialMaxAge = Duration(hours: 24);

  Future<FirmwareManifest> fetchManifest(String manifestUrl) async {
    final uri = Uri.parse(manifestUrl.trim());
    final res = await _client.get(uri).timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('manifest HTTP ${res.statusCode}', uri: uri);
    }
    return FirmwareManifest.parseJsonString(utf8.decode(res.bodyBytes));
  }

  static bool _digestEq(String a, String b) => a.toLowerCase() == b.toLowerCase();

  static Future<String> _sha256HexFile(File f) async {
    final d = await sha256.bind(f.openRead()).first;
    return d.toString();
  }

  static Future<DateTime?> _fileModifiedUtc(File f) async {
    try {
      final s = await f.stat();
      return s.modified.toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadOnePart({
    required FirmwareSerialPart part,
    required String root,
    void Function(String message)? onProgress,
  }) async {
    if (part.url.isEmpty) return;
    final out = File(p.join(root, part.file));
    if (await out.exists()) {
      final h = await _sha256HexFile(out);
      if (_digestEq(h, part.sha256)) {
        onProgress?.call('Přeskakuji ${part.file} (kompletní, SHA-256 sedí).');
        return;
      }
      await out.delete();
    }

    final partial = File('${out.path}._partial');
    var startByte = 0;
    if (await partial.exists()) {
      final m = await _fileModifiedUtc(partial);
      if (m != null && DateTime.now().toUtc().difference(m) > kResumePartialMaxAge) {
        onProgress?.call('Mažu starý dílčí soubor ${part.file} (>${kResumePartialMaxAge.inHours} h).');
        await partial.delete();
      } else {
        startByte = await partial.length();
      }
    }

    final uri = Uri.parse(part.url);
    if (startByte > 0) {
      onProgress?.call('Pokračuji ve stahování ${part.file} od bajtu $startByte…');
    } else {
      onProgress?.call('Stahuji ${part.file}…');
    }

    Future<void> writeFullBodyToPartial(http.StreamedResponse res) async {
      final sink = partial.openWrite();
      try {
        await sink.addStream(res.stream);
      } finally {
        await sink.close();
      }
    }

    if (startByte == 0) {
      final req = http.Request('GET', uri);
      final res = await _client.send(req).timeout(const Duration(minutes: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        try {
          await partial.delete();
        } catch (_) {}
        throw HttpException('${part.file}: HTTP ${res.statusCode}', uri: uri);
      }
      await writeFullBodyToPartial(res);
    } else {
      var rangeFrom = startByte;
      while (true) {
        final req = http.Request('GET', uri);
        req.headers['Range'] = 'bytes=$rangeFrom-';
        final res = await _client.send(req).timeout(const Duration(minutes: 15));
        if (res.statusCode == 206) {
          final sink = partial.openWrite(mode: FileMode.writeOnlyAppend);
          try {
            await sink.addStream(res.stream);
          } finally {
            await sink.close();
          }
          break;
        }
        if (res.statusCode == 200) {
          onProgress?.call('Server nepodporuje Range — stahuji ${part.file} znovu celé.');
          try {
            await partial.delete();
          } catch (_) {}
          await writeFullBodyToPartial(res);
          break;
        }
        if (res.statusCode == 416) {
          if (rangeFrom == 0) {
            try {
              await partial.delete();
            } catch (_) {}
            throw HttpException('${part.file}: HTTP 416 (Range)', uri: uri);
          }
          onProgress?.call('Range neplatný — mažu dílčí ${part.file} a stahuji znovu od začátku.');
          try {
            await partial.delete();
          } catch (_) {}
          rangeFrom = 0;
          continue;
        }
        try {
          await partial.delete();
        } catch (_) {}
        throw HttpException('${part.file}: HTTP ${res.statusCode} (Range od $rangeFrom)', uri: uri);
      }
    }

    if (!await partial.exists()) {
      throw StateError('${part.file}: po stažení chybí dílčí soubor');
    }
    final got = await _sha256HexFile(partial);
    if (!_digestEq(got, part.sha256)) {
      try {
        await partial.delete();
      } catch (_) {}
      throw StateError('SHA-256 nesedí u ${part.file} (očekáváno ${part.sha256}, je $got)');
    }
    await partial.rename(out.path);
  }

  /// Stáhne všechny části z [manifest] do [cacheDir]/[manifest.version]/ a ověří SHA-256.
  /// Obnoví nedokončené `._partial` do [kResumePartialMaxAge].
  Future<String> downloadAll({
    required FirmwareManifest manifest,
    required String cacheDir,
    void Function(String message)? onProgress,
  }) async {
    final root = p.join(cacheDir, manifest.version);
    await Directory(root).create(recursive: true);
    for (final part in manifest.parts) {
      await _downloadOnePart(part: part, root: root, onProgress: onProgress);
    }
    onProgress?.call('Hotovo → $root');
    return root;
  }

  void close() {
    _client.close();
  }
}
