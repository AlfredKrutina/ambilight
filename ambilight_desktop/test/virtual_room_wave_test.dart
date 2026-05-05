import 'package:ambilight_desktop/core/models/smart_lights_models.dart';
import 'package:ambilight_desktop/features/smart_lights/virtual_room_wave.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VirtualRoomWave disabled passes base', () {
    const room = VirtualRoomLayout(roomEffect: SmartRoomEffectKind.none);
    const fx = SmartFixture(id: 'a', displayName: 'L', roomX: 0.2, roomY: 0.3);
    final out = VirtualRoomWave.apply(
      room: room,
      fixture: fx,
      base: (100, 80, 60),
      animationTick: 10,
    );
    expect(out, (100, 80, 60));
  });

  test('VirtualRoomWave modulates by tick and distance', () {
    const room = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.wave,
      waveSpeed: 0.1,
      waveStrength: 1.0,
      waveDistanceScale: 1.0,
      tvX: 0.5,
      tvY: 0.5,
    );
    const fx = SmartFixture(id: 'a', displayName: 'L', roomX: 0.5, roomY: 0.5);
    final a = VirtualRoomWave.apply(room: room, fixture: fx, base: (200, 200, 200), animationTick: 0);
    final b = VirtualRoomWave.apply(room: room, fixture: fx, base: (200, 200, 200), animationTick: 50);
    expect(a.$1, isNot(equals(b.$1)));
  });
}
