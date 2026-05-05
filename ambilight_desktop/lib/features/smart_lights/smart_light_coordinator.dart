import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/models/config_models.dart';
import '../../core/models/smart_lights_models.dart';
import '../../engine/screen/screen_frame.dart';
import '../../services/music/music_types.dart';
import 'fixture_color_resolver.dart';
import 'ha_api_client.dart';
import 'homekit_bridge.dart';
import 'smart_lights_music_timing.dart';
import 'virtual_room_effects.dart';

final _log = Logger('SmartLights');

/// Stav HA světla před začátkem ambient mirroringu z PC (pro návrat při ukončení aplikace).
class _HaMirroringBaseline {
  const _HaMirroringBaseline({
    required this.wasOn,
    required this.r,
    required this.g,
    required this.b,
    required this.brightnessPct,
  });

  final bool wasOn;
  final int r;
  final int g;
  final int b;
  final int brightnessPct;

  static _HaMirroringBaseline? tryParse(Map<String, dynamic> state) {
    try {
      final on = state['state'] == 'on';
      final attrs = state['attributes'];
      if (attrs is! Map) {
        return _HaMirroringBaseline(wasOn: on, r: 255, g: 255, b: 255, brightnessPct: on ? 100 : 0);
      }
      final map = Map<String, dynamic>.from(attrs);
      var r = 255;
      var g = 255;
      var b = 255;
      final rgb = map['rgb_color'];
      if (rgb is List && rgb.length >= 3) {
        r = (rgb[0] as num).round().clamp(0, 255);
        g = (rgb[1] as num).round().clamp(0, 255);
        b = (rgb[2] as num).round().clamp(0, 255);
      }
      var pct = 100;
      final bp = map['brightness_pct'];
      if (bp is num) {
        pct = bp.round().clamp(0, 100);
      } else {
        final bri = map['brightness'];
        if (bri is num) {
          pct = (bri / 255 * 100).round().clamp(0, 100);
        }
      }
      if (!on) {
        pct = 0;
      }
      return _HaMirroringBaseline(wasOn: on, r: r, g: g, b: b, brightnessPct: pct);
    } catch (e, st) {
      if (kDebugMode) {
        _log.fine('HA baseline parse: $e', e, st);
      }
      return null;
    }
  }
}

/// Odesílání barev na Home Assistant a Apple HomeKit s throttlingem.
class SmartLightCoordinator {
  HaApiClient? _ha;
  String _haSig = '';
  final Map<String, DateTime> _lastSent = {};
  final Map<String, _HaMirroringBaseline> _haMirroringBaselineByFixtureId = {};
  int _captureGeneration = 0;
  bool _haMirroringBaselineReady = false;
  Future<void>? _haBaselineCaptureFuture;
  int _inFlight = 0;
  static const int _maxInFlight = 6;

  bool _musicBeatLatchPrev = false;
  double _musicBeatEnvelope = 0;

  void dispose() {
    _ha?.close();
    _ha = null;
    _haSig = '';
    _lastSent.clear();
    _haMirroringBaselineByFixtureId.clear();
    _haMirroringBaselineReady = false;
    _haBaselineCaptureFuture = null;
    _musicBeatLatchPrev = false;
    _musicBeatEnvelope = 0;
  }

  SmartLightsMusicTiming _musicTiming(AppConfig config, MusicAnalysisSnapshot? snap) {
    final mode = config.globalSettings.startMode;
    final mm = config.musicMode;
    if (mode != 'music' || snap == null || !mm.beatDetectionEnabled) {
      _musicBeatLatchPrev = false;
      _musicBeatEnvelope *= 0.89;
      if (_musicBeatEnvelope < 0.02) {
        _musicBeatEnvelope = 0;
      }
      return SmartLightsMusicTiming.inactive;
    }
    final hit = smartLightsMusicBeatComposite(snap);
    final edge = hit && !_musicBeatLatchPrev;
    _musicBeatLatchPrev = hit;
    if (hit) {
      _musicBeatEnvelope = math.min(1.0, _musicBeatEnvelope + 0.52);
    } else {
      _musicBeatEnvelope *= 0.87;
    }
    return SmartLightsMusicTiming(
      active: true,
      beatEnvelope: _musicBeatEnvelope.clamp(0.0, 1.0),
      beatEdge: edge,
    );
  }

  /// Před dalším ambient streamingem z PC — při zapnutí výstupu znovu načti aktuální stav z HA.
  void invalidateHaMirroringBaselines() {
    _captureGeneration++;
    _haMirroringBaselineByFixtureId.clear();
    _haMirroringBaselineReady = false;
    _haBaselineCaptureFuture = null;
  }

  /// Zachytí stav HA světel před prvním přepsáním z PC (musí doběhnout před mirroringem).
  Future<void> ensureHaMirroringBaselines(AppConfig config) async {
    if (_haMirroringBaselineReady) return;
    _haBaselineCaptureFuture ??= _captureHaMirroringBaselines(config);
    await _haBaselineCaptureFuture;
  }

  Future<void> _captureHaMirroringBaselines(AppConfig config) async {
    final gen = ++_captureGeneration;
    try {
      final sl = config.smartLights;
      if (!sl.enabled || sl.fixtures.isEmpty) {
        if (gen == _captureGeneration) {
          _haMirroringBaselineReady = true;
        }
        return;
      }
      final targets = sl.fixtures
          .where(
            (f) =>
                f.enabled &&
                f.mode == SmartFixtureMode.ambient &&
                f.backend == SmartLightBackend.homeAssistant &&
                f.haEntityId.isNotEmpty,
          )
          .toList();
      if (targets.isEmpty) {
        if (gen == _captureGeneration) {
          _haMirroringBaselineReady = true;
        }
        return;
      }
      _syncHaClient(sl);
      final client = _ha;
      if (client == null) {
        if (gen == _captureGeneration) {
          _haMirroringBaselineReady = true;
        }
        return;
      }
      final got = await client.getStates();
      if (!got.$1 || gen != _captureGeneration) {
        if (gen == _captureGeneration) {
          _haMirroringBaselineReady = true;
        }
        return;
      }
      final states = got.$2;
      for (final t in targets) {
        Map<String, dynamic>? raw;
        for (final s in states) {
          if (s['entity_id']?.toString() == t.haEntityId) {
            raw = s;
            break;
          }
        }
        if (raw == null) continue;
        final base = _HaMirroringBaseline.tryParse(raw);
        if (base != null) {
          _haMirroringBaselineByFixtureId[t.id] = base;
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        _log.fine('ensureHaMirroringBaselines: $e', e, st);
      }
    } finally {
      _haBaselineCaptureFuture = null;
      if (gen == _captureGeneration) {
        _haMirroringBaselineReady = true;
      }
    }
  }

  /// Před [`sendPcReleaseHandoff`] — vrátit HA fixture do stavu před mirroringem (pokud byl snapshot).
  Future<void> restoreHaMirroringBaselines(AppConfig config) async {
    final sl = config.smartLights;
    if (!sl.enabled || _haMirroringBaselineByFixtureId.isEmpty) return;
    _syncHaClient(sl);
    final client = _ha;
    if (client == null) return;
    for (final fx in sl.fixtures) {
      if (fx.backend != SmartLightBackend.homeAssistant || fx.haEntityId.isEmpty) continue;
      final base = _haMirroringBaselineByFixtureId[fx.id];
      if (base == null) continue;
      try {
        if (!base.wasOn) {
          final off = await client.lightTurnOff(entityId: fx.haEntityId);
          if (!off.$1 && kDebugMode) {
            _log.fine('HA restore off ${fx.haEntityId}: ${off.$2}');
          }
        } else {
          final on = await client.lightTurnOnRgb(
            entityId: fx.haEntityId,
            r: base.r,
            g: base.g,
            b: base.b,
            brightnessPct: base.brightnessPct,
            transitionSeconds: 0.35,
            haPreferHsColor: false,
          );
          if (!on.$1 && kDebugMode) {
            _log.fine('HA restore on ${fx.haEntityId}: ${on.$2}');
          }
        }
      } catch (e, st) {
        if (kDebugMode) {
          _log.fine('HA restore ${fx.id}: $e', e, st);
        }
      }
    }
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
    MusicAnalysisSnapshot? musicSnapshot,
  }) {
    // Výstup vypnutý z UI — nerušit HA/HomeKit (žádný „blackout“ přes integraci).
    if (!appEnabled) {
      return;
    }
    final sl = config.smartLights;
    if (!sl.enabled || sl.fixtures.isEmpty) {
      return;
    }
    if (!_haMirroringBaselineReady) {
      unawaited(ensureHaMirroringBaselines(config));
      return;
    }
    _syncHaClient(sl);
    final baseGapMs = (1000 / sl.maxUpdateHzPerFixture.clamp(1, 30)).round().clamp(16, 1000);
    final musicTiming = _musicTiming(config, musicSnapshot);
    // Režim hudba + beat: častější push na HA/HomeKit i bez vlnového efektu (barvy z FFT mění rychle).
    final musicBeatSyncedUpdates =
        musicTiming.active && config.globalSettings.startMode == 'music';
    var effGapMs = baseGapMs;
    if (musicBeatSyncedUpdates) {
      if (musicTiming.beatEdge) {
        effGapMs = math.max(8, (baseGapMs * 0.28).round());
      } else if (musicTiming.beatEnvelope > 0.18) {
        effGapMs = math.max(11, (baseGapMs * 0.52).round());
      } else if (musicTiming.beatEnvelope > 0.06) {
        effGapMs = math.max(13, (baseGapMs * 0.72).round());
      }
    }
    final gap = Duration(milliseconds: effGapMs.clamp(8, 1000));
    final now = DateTime.now();
    final chaseRanks = sl.virtualRoom.roomEffect == SmartRoomEffectKind.chase
        ? VirtualRoomEffects.chaseRanks(room: sl.virtualRoom, fixtures: sl.fixtures)
        : null;

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

      final rgbBase = FixtureColorResolver.resolve(
        fixture: fx,
        config: config,
        perDevice: perDevice,
        frame: frame,
        musicSnapshot: musicSnapshot,
      );
      final effectOut = VirtualRoomEffects.apply(
        room: sl.virtualRoom,
        fixture: fx,
        base: rgbBase,
        animationTick: animationTick,
        chaseRanks: chaseRanks,
        musicTiming: musicTiming,
      );
      final rgb = (effectOut.r, effectOut.g, effectOut.b);
      final baseBri = _brightnessPct(engineBrightness, sl.globalBrightnessCapPct, fx.brightnessPctCap);
      final briPct = (baseBri * effectOut.brightnessMul).round().clamp(0, 100);

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
              haPreferHsColor: sl.haColorUseHsPath,
              haSaturationGain: sl.haSaturationGain,
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
