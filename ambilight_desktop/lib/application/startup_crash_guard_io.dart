import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../core/models/config_models.dart';
import '../data/config_repository.dart';
import '../features/smart_lights/ha_token_store.dart';
import '../features/spotify/spotify_token_store.dart';
import 'app_crash_log.dart';
import 'build_environment.dart';

final _log = Logger('StartupCrashGuard');

/// Po několika po sobě jdoucích startech bez „čistého“ běhu uloží kopii konfigurace a provede tovární reset na disku.
abstract final class StartupCrashGuard {
  static const _countFileName = 'unclean_session_count.txt';
  static const _defaultThreshold = 3;
  static const _warmupClearDelay = Duration(seconds: 4);

  static bool get _skipGuard =>
      Platform.environment['FLUTTER_TEST'] == 'true' ||
      ambilightStartupCrashRecoveryDisabled;

  static Future<File> _countFile() async {
    final dir = await AppCrashLog.resolveAmbilightSupportDirPath();
    await Directory(dir).create(recursive: true);
    return File(p.join(dir, _countFileName));
  }

  static Future<int> _readCount(File f) async {
    try {
      if (!await f.exists()) return 0;
      final n = int.tryParse((await f.readAsString()).trim(), radix: 10);
      if (n == null || n < 0) return 0;
      return n;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _writeCount(int n) async {
    final f = await _countFile();
    await f.writeAsString('$n', flush: true);
  }

  static Future<void> _copyIfExists(File src, String destPath) async {
    try {
      if (!await src.exists()) return;
      await src.copy(destPath);
    } catch (e, st) {
      _log.fine('recovery backup skip ${src.path}: $e', e, st);
    }
  }

  /// Záloha profilu a tokenů před automatickým resetem (podsložka `recovery_backup_<UTC ISO>`).
  static Future<void> _backupConfigSnapshot() async {
    final support = await AppCrashLog.resolveAmbilightSupportDirPath();
    await Directory(support).create(recursive: true);
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final destDir = Directory(p.join(support, 'recovery_backup_$ts'));
    await destDir.create(recursive: true);

    final cfg = await ConfigRepository.resolveConfigFile(ConfigRepository.defaultProfile);
    await _copyIfExists(cfg, p.join(destDir.path, ConfigRepository.defaultProfile));
    await _copyIfExists(File('${cfg.path}.bak'), p.join(destDir.path, '${ConfigRepository.defaultProfile}.bak'));

    await _copyIfExists(
      File(p.join(support, 'spotify_tokens.json')),
      p.join(destDir.path, 'spotify_tokens.json'),
    );
    await _copyIfExists(
      File(p.join(support, 'ha_long_lived_token.txt')),
      p.join(destDir.path, 'ha_long_lived_token.txt'),
    );

    if (ambilightVerboseLogsEnabled) {
      _log.info('Crash recovery: backed up config snapshot → ${destDir.path}');
    }
  }

  /// Totéž co základní část [AmbilightAppController.factoryResetAndPersist] bez běžícího controlleru.
  static Future<void> _diskFactoryReset() async {
    await HaTokenStore.clear();
    await SpotifyTokenStore.clear();
    await ConfigRepository.save(AppConfig.defaults());
  }

  /// Volat hned po [WidgetsFlutterBinding.ensureInitialized], před [AmbilightAppController.load].
  static Future<void> runPreBootstrapRecovery() async {
    if (_skipGuard) return;
    try {
      final cf = await _countFile();
      var n = await _readCount(cf);
      if (n >= _defaultThreshold) {
        await AppCrashLog.append(
          'Startup crash recovery: $n unclean sessions reached threshold ($_defaultThreshold); backing up and factory-resetting disk config.',
        );
        await _backupConfigSnapshot();
        await _diskFactoryReset();
        n = 0;
        if (ambilightVerboseLogsEnabled) {
          _log.info('Crash recovery: factory reset complete; starting fresh session counter');
        }
      }
      await _writeCount(n + 1);
    } catch (e, st) {
      _log.warning('runPreBootstrapRecovery: $e', e, st);
      unawaited(AppCrashLog.append('Startup crash guard failed (non-fatal)', error: e, stack: st));
    }
  }

  /// Normální ukončení ([desktop_chrome] „Ukončit“) nebo úspěšný warmup — session se nepočítá jako pády.
  static Future<void> markSessionClean() async {
    if (_skipGuard) return;
    try {
      await _writeCount(0);
    } catch (e, st) {
      _log.fine('markSessionClean: $e', e, st);
    }
  }

  /// Po prvním vykresleném snímku počká [_warmupClearDelay] a vymaže čítač (aplikace pravděpodobně žije).
  static void scheduleWarmupCompletion() {
    if (_skipGuard) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(_warmupClearDelay, () => unawaited(markSessionClean()));
    });
  }
}
