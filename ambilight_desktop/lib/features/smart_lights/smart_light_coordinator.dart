import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/models/config_models.dart';
import '../../core/models/smart_lights_models.dart';
import '../../engine/screen/screen_frame.dart';
import 'fixture_color_resolver.dart';
import 'ha_api_client.dart';
import 'homekit_bridge.dart';
import 'virtual_room_wave.dart';

final _log = Logger('SmartLights');

/// Odesílání barev na Home Assistant a Apple HomeKit s throttlingem.
class SmartLightCoordinator {
  HaApiClient? _ha;
  String _haSig = '';
  final Map<String, DateTime> _lastSent = {};
  int _inFlight = 0;
  static const int _maxInFlight = 6;

  void dispose() {
    _ha?.close();
    _ha = null;
    _haSig = '';
    _lastSent.clear();
  }

  void _syncHaClient(SmartLightsSettings sl) {
    final sig =
        '${sl.haBaseUrl.trim()}|${sl.haLongLivedToken.trim().hashCode}|${sl.haAllowInsecureCert}|${sl.haTimeoutSeconds}';
    if (sig == _haSig && _ha != null) return;
    _ha?.close();
    _ha = null;
    _haSig = '';
    if (sl.haBaseUrl.trim().isEmpty || sl.haLongLivedToken.trim().isEmpty) {
      return;
    }
    _ha = HaApiClient(
      baseUrl: sl.haBaseUrl,
      token: sl.haLongLivedToken,
      allowInsecureCert: sl.haAllowInsecureCert,
      timeout: Duration(seconds: sl.haTimeoutSeconds.clamp(3, 120)),
    );
    _haSig = sig;
  }

  /// Volat z hlavní tick smyčky po výpočtu [perDevice] (např. na konci [_distribute]).
  void onFrame({
    required AppConfig config,
    required Map<String, List<(int, int, int)>> perDevice,
    required int engineBrightness,
    required ScreenFrame? frame,
    required bool appEnabled,
    required int animationTick,
  }) {
    final sl = config.smartLights;
    if (!sl.enabled || sl.fixtures.isEmpty) {
      return;
    }
    _syncHaClient(sl);
    final minGapMs = (1000 / sl.maxUpdateHzPerFixture.clamp(1, 30)).round();
    final gap = Duration(milliseconds: minGapMs.clamp(16, 1000));
    final now = DateTime.now();

    for (final fx in sl.fixtures) {
      if (!fx.enabled || fx.mode != SmartFixtureMode.ambient) continue;
      if (fx.backend == SmartLightBackend.homeAssistant) {
        if (fx.haEntityId.isEmpty || _ha == null) continue;
      } else if (fx.backend == SmartLightBackend.appleHomeKit) {
        if (fx.homeKitAccessoryUuid.isEmpty) continue;
      }

      final last = _lastSent[fx.id];
      if (last != null && now.difference(last) < gap) continue;

      if (_inFlight >= _maxInFlight) {
        continue;
      }

      final rgbBase = appEnabled
          ? FixtureColorResolver.resolve(
              fixture: fx,
              config: config,
              perDevice: perDevice,
              frame: frame,
            )
          : (0, 0, 0);
      final rgb = VirtualRoomWave.apply(
        room: sl.virtualRoom,
        fixture: fx,
        base: rgbBase,
        animationTick: animationTick,
      );
      final briPct = appEnabled
          ? _brightnessPct(engineBrightness, sl.globalBrightnessCapPct, fx.brightnessPctCap)
          : 0;

      _lastSent[fx.id] = now;

      if (fx.backend == SmartLightBackend.homeAssistant) {
        final client = _ha;
        if (client == null) continue;
        _inFlight++;
        unawaited(() async {
          try {
            final res = await client.lightTurnOnRgb(
              entityId: fx.haEntityId,
              r: rgb.$1,
              g: rgb.$2,
              b: rgb.$3,
              brightnessPct: briPct,
            );
            if (!res.$1 && kDebugMode) {
              _log.fine('HA ${fx.haEntityId}: ${res.$2}');
            }
          } catch (e, st) {
            _log.fine('HA send ${fx.id}: $e', e, st);
          } finally {
            _inFlight--;
          }
        }());
      } else if (fx.backend == SmartLightBackend.appleHomeKit) {
        _inFlight++;
        unawaited(() async {
          try {
            final res = await HomeKitBridge.setLightColor(
              accessoryUuid: fx.homeKitAccessoryUuid,
              r: rgb.$1,
              g: rgb.$2,
              b: rgb.$3,
              brightnessPct: briPct,
            );
            if (!res.$1 && kDebugMode) {
              _log.fine('HomeKit ${fx.id}: ${res.$2}');
            }
          } catch (e, st) {
            _log.fine('HomeKit send ${fx.id}: $e', e, st);
          } finally {
            _inFlight--;
          }
        }());
      }
    }
  }

  static int _brightnessPct(int engineScalar, int globalCap, int fixtureCap) {
    final g = globalCap.clamp(1, 100);
    final f = fixtureCap.clamp(1, 100);
    final base = (engineScalar.clamp(0, 255) * 100 / 255).round();
    return (base * g / 100 * f / 100).round().clamp(0, 100);
  }
}
