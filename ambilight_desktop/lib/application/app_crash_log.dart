import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _log = Logger('AppCrashLog');

/// Append-only soubor v Application Support (`…/ambilight_desktop/crash_log.txt`).
/// Při překročení [_maxFileBytes] se soubor zkrátí na [_trimKeepBytes] (rotace v rámci jednoho souboru).
/// Nepoužívá [reportAppFault] — žádný cyklický import s [app_error_safety].
abstract final class AppCrashLog {
  static const crashLogFileName = 'crash_log.txt';
  static const supportSubfolder = 'ambilight_desktop';

  static const _maxFileBytes = 512 * 1024;
  static const _trimKeepBytes = 256 * 1024;
  static const _dedupeWindow = Duration(seconds: 20);
  static File? _file;
  static String? _lastDedupeKey;
  static DateTime? _lastDedupeAt;

  /// `…/Application Support/ambilight_desktop` (macOS) / ekvivalent na Win/Linux.
  static Future<String> resolveAmbilightSupportDirPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, supportSubfolder);
  }

  /// Absolutní cesta k `crash_log.txt` (soubor nemusí existovat).
  static Future<String> resolveCrashLogFilePath() async {
    return p.join(await resolveAmbilightSupportDirPath(), crashLogFileName);
  }

  static String _dedupeKey(String headline, Object? error) {
    final h = headline.trim();
    final head = h.length > 280 ? h.substring(0, 280) : h;
    final err = error == null ? '' : error.toString();
    final e = err.length > 160 ? err.substring(0, 160) : err;
    return '$head|$e';
  }

  /// Best-effort zápis; výjimky polykáme — aplikace nesmí padat na logu.
  static Future<void> append(
    String headline, {
    Object? error,
    StackTrace? stack,
  }) async {
    try {
      final now = DateTime.now();
      final key = _dedupeKey(headline, error);
      if (_lastDedupeKey == key && _lastDedupeAt != null && now.difference(_lastDedupeAt!) < _dedupeWindow) {
        return;
      }
      _lastDedupeKey = key;
      _lastDedupeAt = now;

      final dirPath = await resolveAmbilightSupportDirPath();
      await Directory(dirPath).create(recursive: true);
      _file ??= File(p.join(dirPath, crashLogFileName));
      final f = _file!;
      if (await f.exists()) {
        final len = await f.length();
        if (len > _maxFileBytes) {
          final raw = await f.readAsString();
          final cut = raw.length > _trimKeepBytes ? raw.substring(raw.length - _trimKeepBytes) : raw;
          await f.writeAsString(
            '--- trimmed ${DateTime.now().toUtc().toIso8601String()} ---\n$cut',
            flush: true,
          );
        }
      }
      final ts = DateTime.now().toUtc().toIso8601String();
      final sb = StringBuffer()
        ..writeln('--- $ts ---')
        ..writeln(headline.trim());
      if (error != null) sb.writeln('error: $error');
      if (stack != null) sb.writeln('$stack');
      sb.writeln();
      await f.writeAsString(sb.toString(), mode: FileMode.append, flush: true);
    } catch (e, st) {
      assert(() {
        debugPrint('AppCrashLog.append failed: $e\n$st');
        return true;
      }());
      _log.fine('append failed: $e', e, st);
    }
  }
}
