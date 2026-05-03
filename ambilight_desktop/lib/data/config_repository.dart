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

  static Future<void> save(AppConfig config, [String profile = defaultProfile]) async {
    final file = await resolveConfigFile(profile);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(config.sanitizedForPersistence().toJsonString());
    _log.info('Saved ${file.path}');
  }
}
