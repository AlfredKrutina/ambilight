import '../../core/models/smart_lights_models.dart';
import 'virtual_room_effects.dart';

/// Zpětná kompatibilita — deleguje na [VirtualRoomEffects].
abstract final class VirtualRoomWave {
  static (int r, int g, int b) apply({
    required VirtualRoomLayout room,
    required SmartFixture fixture,
    required (int r, int g, int b) base,
    required int animationTick,
  }) {
    final out = VirtualRoomEffects.apply(
      room: room,
      fixture: fixture,
      base: base,
      animationTick: animationTick,
    );
    return (out.r, out.g, out.b);
  }
}
