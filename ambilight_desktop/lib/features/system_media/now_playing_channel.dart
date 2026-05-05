import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Nativní kanál `ambilight/now_playing` (Windows GSMTC).
class NowPlayingChannel {
  NowPlayingChannel._();

  static const MethodChannel _ch = MethodChannel('ambilight/now_playing');

  /// Vrací mapu s klíči `thumbnail` ([Uint8List]?), `title`, `artist`, `sourceAppUserModelId`.
  /// Na ne-Windows nebo při chybě kanálu vrací `null`.
  static Future<Map<String, dynamic>?> getThumbnail() async {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      final raw = await _ch.invokeMethod<dynamic>('getThumbnail');
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
