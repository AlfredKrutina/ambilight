import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Spotify tokeny mimo `default.json`.
///
/// Desktop: soubor v application support (`…/ambilight_desktop/spotify_tokens.json`).
/// Slabší než OS credential store, ale **bez nativního C++ pluginu** (žádné `atlstr.h` / ATL).
class SpotifyTokenStore {
  SpotifyTokenStore._();

  static const _fileName = 'spotify_tokens.json';

  static Future<File> _tokenFile() async {
    final dir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(dir.path, 'ambilight_desktop'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File(p.join(appDir.path, _fileName));
  }

  static Future<void> write({required String accessToken, required String refreshToken}) async {
    final f = await _tokenFile();
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'access': accessToken,
        'refresh': refreshToken,
      }),
    );
  }

  static Future<(String?, String?)> read() async {
    try {
      final f = await _tokenFile();
      if (!await f.exists()) return (null, null);
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>?;
      if (map == null) return (null, null);
      return (map['access']?.toString(), map['refresh']?.toString());
    } catch (_) {
      return (null, null);
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _tokenFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
