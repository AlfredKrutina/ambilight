import 'dart:math' as math;

import '../../core/models/smart_lights_models.dart';
import 'smart_lights_music_timing.dart';

/// Výstup modulace pro jedno světlo (barva + násobič jasu pro HA / HomeKit).
class SmartEffectOutput {
  const SmartEffectOutput({
    required this.r,
    required this.g,
    required this.b,
    required this.brightnessMul,
  });

  final int r;
  final int g;
  final int b;
  /// 0–1, vynásobit `brightness_pct` před odesláním.
  final double brightnessMul;
}

abstract final class VirtualRoomEffects {
  /// Deterministické pořadí pro [SmartRoomEffectKind.chase]: nižší projekce → nižší rank.
  static Map<String, int> chaseRanks({
    required VirtualRoomLayout room,
    required List<SmartFixture> fixtures,
  }) {
    final entries = <({String id, double key})>[];
    for (final f in fixtures) {
      final k = _spatialScalar(room: room, fixture: f, forChase: true);
      entries.add((id: f.id, key: k));
    }
    entries.sort((a, b) {
      final c = a.key.compareTo(b.key);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    final map = <String, int>{};
    for (var i = 0; i < entries.length; i++) {
      map[entries[i].id] = i;
    }
    return map;
  }

  static SmartEffectOutput apply({
    required VirtualRoomLayout room,
    required SmartFixture fixture,
    required (int r, int g, int b) base,
    required int animationTick,
    Map<String, int>? chaseRanks,
    SmartLightsMusicTiming? musicTiming,
  }) {
    if (room.roomEffect == SmartRoomEffectKind.none) {
      final mt = musicTiming;
      if (mt != null && mt.active) {
        final env = mt.beatEnvelope;
        final edge = mt.beatEdge;
        final mul = (1.0 + env * 0.30 + (edge ? 0.14 : 0.0)).clamp(0.66, 1.44);
        return SmartEffectOutput(
          r: base.$1,
          g: base.$2,
          b: base.$3,
          brightnessMul: mul,
        );
      }
      return SmartEffectOutput(
        r: base.$1,
        g: base.$2,
        b: base.$3,
        brightnessMul: 1.0,
      );
    }

    final phase = _phaseForEffect(
      room: room,
      fixture: fixture,
      animationTick: animationTick,
      chaseRanks: chaseRanks,
      musicTiming: musicTiming,
    );
    final s = math.sin(phase);
    final m = 1.0 - room.waveStrength + room.waveStrength * (0.5 + 0.5 * s);
    return _applyModulation(room: room, base: base, m: m.clamp(0.0, 1.0));
  }

  static double _phaseForEffect({
    required VirtualRoomLayout room,
    required SmartFixture fixture,
    required int animationTick,
    Map<String, int>? chaseRanks,
    SmartLightsMusicTiming? musicTiming,
  }) {
    final t = animationTick.toDouble();
    final sp = room.waveSpeed.clamp(0.01, 0.5);
    final sc = room.waveDistanceScale.clamp(0.5, 20.0);
    final mt = musicTiming;
    final musicOn = mt != null && mt.active;
    final env = musicOn ? mt.beatEnvelope : 0.0;
    final edge = musicOn && mt.beatEdge;

    switch (room.roomEffect) {
      case SmartRoomEffectKind.none:
        return 0;
      case SmartRoomEffectKind.wave:
        final spatial = _spatialScalar(room: room, fixture: fixture, forChase: false);
        var ph = t * sp - spatial * sc;
        if (musicOn) {
          ph += env * 0.95;
          if (edge) ph += 0.55;
        }
        return ph;
      case SmartRoomEffectKind.breath:
        var ph = t * sp * 1.15;
        if (musicOn) {
          // Beat posouvá fázi — pulz „sedí“ na muziku; pomalý tah engine ticku zůstává jako základ.
          ph += env * math.pi * 2.15;
          if (edge) ph += math.pi * 0.42;
        }
        return ph;
      case SmartRoomEffectKind.chase:
        final rank = chaseRanks?[fixture.id] ?? 0;
        final n = math.max(chaseRanks?.length ?? 1, 1);
        final step = (2 * math.pi / n) * sc * 0.18;
        var ph = t * sp - rank * step;
        if (musicOn) {
          ph += env * math.pi * 1.05;
          if (edge) ph += math.pi * 0.55 / n;
        }
        return ph;
      case SmartRoomEffectKind.sparkle:
        final h = _hash01(fixture.id);
        final spatial = _spatialScalar(room: room, fixture: fixture, forChase: false);
        var ph = t * sp * 2.4 + h * 12.566370614359172 + spatial * sc * 0.35;
        if (musicOn) {
          ph += env * 3.1;
          if (edge) ph += 1.15;
        }
        return ph;
    }
  }

  static double _spatialScalar({
    required VirtualRoomLayout room,
    required SmartFixture fixture,
    required bool forChase,
  }) {
    final fx = fixture.roomX;
    final fy = fixture.roomY;
    final tx = room.tvX;
    final ty = room.tvY;
    final ux = room.userX;
    final uy = room.userY;

    switch (room.waveGeometry) {
      case SmartRoomWaveGeometry.radialFromTv:
        final dx = fx - tx;
        final dy = fy - ty;
        return math.sqrt(dx * dx + dy * dy);
      case SmartRoomWaveGeometry.alongUserView:
        final base = math.atan2(ty - uy, tx - ux);
        final dir = base + room.userFacingDeg * math.pi / 180;
        final px = -math.sin(dir);
        final py = math.cos(dir);
        return (fx - ux) * px + (fy - uy) * py;
      case SmartRoomWaveGeometry.horizontalRoom:
        return fx - tx;
      case SmartRoomWaveGeometry.verticalRoom:
        return fy - ty;
      case SmartRoomWaveGeometry.customAngle:
        final rad = room.waveExtraAngleDeg * math.pi / 180;
        final px = math.cos(rad);
        final py = math.sin(rad);
        return (fx - tx) * px + (fy - ty) * py;
    }
  }

  static SmartEffectOutput _applyModulation({
    required VirtualRoomLayout room,
    required (int r, int g, int b) base,
    required double m,
  }) {
    switch (room.brightnessModulation) {
      case SmartRoomBrightnessModulate.rgbOnly:
        return SmartEffectOutput(
          r: (base.$1 * m).round().clamp(0, 255),
          g: (base.$2 * m).round().clamp(0, 255),
          b: (base.$3 * m).round().clamp(0, 255),
          brightnessMul: 1.0,
        );
      case SmartRoomBrightnessModulate.brightnessOnly:
        return SmartEffectOutput(
          r: base.$1,
          g: base.$2,
          b: base.$3,
          brightnessMul: m,
        );
      case SmartRoomBrightnessModulate.both:
        return SmartEffectOutput(
          r: (base.$1 * m).round().clamp(0, 255),
          g: (base.$2 * m).round().clamp(0, 255),
          b: (base.$3 * m).round().clamp(0, 255),
          brightnessMul: m,
        );
    }
  }

  static double _hash01(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = 0x1fffffff & (h + c);
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= h >> 6;
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= h >> 11;
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    h ^= h >> 10;
    return (h & 0xffff) / 65535.0;
  }
}
