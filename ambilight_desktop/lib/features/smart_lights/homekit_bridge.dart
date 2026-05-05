import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apple HomeKit přes MethodChannel (implementováno jen v macOS Runner).
abstract final class HomeKitBridge {
  static const MethodChannel _ch = MethodChannel('ambilight/homekit');

  static bool get _mayUse => !kIsWeb && Platform.isMacOS;

  static Future<bool> isPlatformSupported() async {
    if (!_mayUse) return false;
    try {
      final v = await _ch.invokeMethod<bool>('isSupported');
      return v == true;
    } catch (_) {
      return false;
    }
  }

  /// `{ uuid, name }` pro světla s HomeKit Lightbulb službou.
  static Future<List<Map<String, String>>> listLights() async {
    if (!_mayUse) return const [];
    try {
      final raw = await _ch.invokeMethod<dynamic>('listLights');
      if (raw is! List) return const [];
      return raw
          .map((e) {
            if (e is! Map) return <String, String>{};
            final m = Map<String, dynamic>.from(e);
            return {
              'uuid': m['uuid']?.toString() ?? '',
              'name': m['name']?.toString() ?? '',
            };
          })
          .where((m) => m['uuid']!.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<(bool ok, String error)> setLightColor({
    required String accessoryUuid,
    required int r,
    required int g,
    required int b,
    required int brightnessPct,
  }) async {
    if (!_mayUse) {
      return (false, 'HomeKit is only available on macOS');
    }
    try {
      final ok = await _ch.invokeMethod<bool>('setLightColor', <String, Object?>{
        'uuid': accessoryUuid,
        'r': r.clamp(0, 255),
        'g': g.clamp(0, 255),
        'b': b.clamp(0, 255),
        'brightnessPct': brightnessPct.clamp(0, 100),
      });
      return (ok == true, ok == true ? '' : 'HomeKit refused');
    } catch (e) {
      return (false, e.toString());
    }
  }
}
