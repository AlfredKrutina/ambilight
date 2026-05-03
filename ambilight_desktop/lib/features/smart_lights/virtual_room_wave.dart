import 'dart:math' as math;

import '../../core/models/smart_lights_models.dart';

/// Modulace základní barvy podle vzdálenosti od TV a času — „vlna“ přes místnost.
abstract final class VirtualRoomWave {
  static (int r, int g, int b) apply({
    required VirtualRoomLayout room,
    required SmartFixture fixture,
    required (int r, int g, int b) base,
    required int animationTick,
  }) {
    if (!room.waveEnabled) return base;
    final dx = fixture.roomX - room.tvX;
    final dy = fixture.roomY - room.tvY;
    final dist = math.sqrt(dx * dx + dy * dy);
    final phase = animationTick * room.waveSpeed - dist * room.waveDistanceScale;
    final s = math.sin(phase);
    final m = 1.0 - room.waveStrength + room.waveStrength * (0.5 + 0.5 * s);
    return (
      (base.$1 * m).round().clamp(0, 255),
      (base.$2 * m).round().clamp(0, 255),
      (base.$3 * m).round().clamp(0, 255),
    );
  }
}
