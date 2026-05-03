import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/models/config_models.dart';

final _log = Logger('ConfigRepository');

/// Persists [AppConfig] next to the Python app (`config/default.json`) or under app support.
class ConfigRepository {
  ConfigRepository._();

  static const String defaultProfile = 'default.json';

  /// Prefer existing `config/default.json` in CWD (dev), else application support.
  static Future<File> resolveConfigFile(String profile) async {
    final name = profile.endsWith('.json') ? profile : '$profile.json';
    final cwdConfig = File(p.join('config', name));
    if (await cwdConfig.exists()) {
      _log.fine('Using config: ${cwdConfig.absolute.path}');
      return cwdConfig;
    }
    final dir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(dir.path, 'ambilight_desktop'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    final f = File(p.join(appDir.path, name));
    _log.fine('Using config: ${f.absolute.path}');
    return f;
  }

  static Future<AppConfig> load([String profile = defaultProfile]) async {
    try {
      final file = await resolveConfigFile(profile);
      if (!await file.exists()) {
        return AppConfig.defaults();
      }
      final text = await file.readAsString();
      return AppConfig.parse(text);
    } catch (e, st) {
      _log.warning('Config load failed: $e', e, st);
      return AppConfig.defaults();
    }
  }

  /// Zapíše JSON přes `.tmp` a přejmenování — při pádu během zápisu zůstane buď starý [file], nebo obnovitelný `.bak`.
  static Future<void> save(AppConfig config, [String profile = defaultProfile]) async {
    final file = await resolveConfigFile(profile);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final json = config.sanitizedForPersistence().toJsonString();
    final tmp = File('${file.path}.tmp');
    final bak = File('${file.path}.bak');
    if (await tmp.exists()) {
      try {
        await tmp.delete();
      } catch (e, st) {
        _log.fine('remove stale tmp: $e', e, st);
      }
    }
    await tmp.writeAsString(json, flush: true);
    if (await file.exists()) {
      if (await bak.exists()) {
        await bak.delete();
      }
      await file.rename(bak.path);
    }
    await tmp.rename(file.path);
    try {
      if (await bak.exists()) {
        await bak.delete();
      }
    } catch (e, st) {
      _log.fine('remove config backup: $e', e, st);
    }
    _log.info('Saved ${file.path}');
  }
}
