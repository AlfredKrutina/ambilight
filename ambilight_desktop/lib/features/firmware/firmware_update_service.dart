import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'firmware_manifest.dart';

/// Stažení manifestu a binárek do cache složky.
class FirmwareUpdateService {
  FirmwareUpdateService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<FirmwareManifest> fetchManifest(String manifestUrl) async {
    final uri = Uri.parse(manifestUrl.trim());
    final res = await _client.get(uri).timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('manifest HTTP ${res.statusCode}', uri: uri);
    }
    return FirmwareManifest.parseJsonString(utf8.decode(res.bodyBytes));
  }

  /// Stáhne všechny části z [manifest] do [cacheDir]/[manifest.version]/ a ověří SHA-256.
  Future<String> downloadAll({
    required FirmwareManifest manifest,
    required String cacheDir,
    void Function(String message)? onProgress,
  }) async {
    final root = p.join(cacheDir, manifest.version);
    await Directory(root).create(recursive: true);
    for (final part in manifest.parts) {
      if (part.url.isEmpty) continue;
      onProgress?.call('Stahuji ${part.file}…');
      final uri = Uri.parse(part.url);
      final res = await _client.get(uri).timeout(const Duration(minutes: 5));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('${part.file}: HTTP ${res.statusCode}', uri: uri);
      }
      final bytes = res.bodyBytes;
      final digest = sha256.convert(bytes).toString();
      if (digest.toLowerCase() != part.sha256.toLowerCase()) {
        throw StateError('SHA-256 nesedí u ${part.file} (očekáváno ${part.sha256}, je $digest)');
      }
      final out = File(p.join(root, part.file));
      await out.writeAsBytes(bytes, flush: true);
    }
    onProgress?.call('Hotovo → $root');
    return root;
  }

  void close() {
    _client.close();
  }
}
