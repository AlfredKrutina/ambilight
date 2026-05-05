import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Long-lived token Home Assistant mimo `default.json` (stejný adresář jako Spotify).
class HaTokenStore {
  HaTokenStore._();

  static const _fileName = 'ha_long_lived_token.txt';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(dir.path, 'ambilight_desktop'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File(p.join(appDir.path, _fileName));
  }

  /// `null` = soubor neexistuje / prázdný / chyba čtení.
  static Future<String?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final s = (await f.readAsString()).trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String token) async {
    final t = token.trim();
    if (t.isEmpty) {
      await clear();
      return;
    }
    final f = await _file();
    await f.writeAsString(t, flush: true);
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
