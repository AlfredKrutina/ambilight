import 'package:ambilight_desktop/core/models/smart_lights_models.dart';
import 'package:ambilight_desktop/features/smart_lights/smart_lights_music_timing.dart';
import 'package:ambilight_desktop/features/smart_lights/virtual_room_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('none passes through rgb and brightness 1', () {
    const room = VirtualRoomLayout(roomEffect: SmartRoomEffectKind.none);
    const fx = SmartFixture(id: 'a', displayName: 'L', roomX: 0.2, roomY: 0.3);
    final out = VirtualRoomEffects.apply(
      room: room,
      fixture: fx,
      base: (100, 90, 80),
      animationTick: 99,
    );
    expect(out.r, 100);
    expect(out.g, 90);
    expect(out.b, 80);
    expect(out.brightnessMul, 1.0);
  });

  test('breath ignores fixture position', () {
    const room = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.breath,
      waveSpeed: 0.1,
      waveStrength: 1.0,
    );
    const a = SmartFixture(id: 'a', displayName: 'A', roomX: 0.1, roomY: 0.9);
    const b = SmartFixture(id: 'b', displayName: 'B', roomX: 0.9, roomY: 0.1);
    final oa = VirtualRoomEffects.apply(room: room, fixture: a, base: (200, 200, 200), animationTick: 42);
    final ob = VirtualRoomEffects.apply(room: room, fixture: b, base: (200, 200, 200), animationTick: 42);
    expect(oa.r, ob.r);
    expect(oa.brightnessMul, ob.brightnessMul);
  });

  test('alongUserView differs from radial for symmetric lamps', () {
    const tvX = 0.5, tvY = 0.5, userX = 0.5, userY = 0.72;
    const base = (200, 200, 200);
    const tick = 17;
    const left = SmartFixture(id: 'L', displayName: 'L', roomX: 0.4, roomY: 0.5);
    const right = SmartFixture(id: 'R', displayName: 'R', roomX: 0.6, roomY: 0.5);

    const radial = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.wave,
      waveGeometry: SmartRoomWaveGeometry.radialFromTv,
      tvX: tvX,
      tvY: tvY,
      userX: userX,
      userY: userY,
      userFacingDeg: 0,
      waveSpeed: 0.2,
      waveStrength: 1.0,
      waveDistanceScale: 4.0,
    );
    final radialL = VirtualRoomEffects.apply(room: radial, fixture: left, base: base, animationTick: tick);
    final radialR = VirtualRoomEffects.apply(room: radial, fixture: right, base: base, animationTick: tick);
    expect(radialL.r, radialR.r, reason: 'same distance from TV');

    const along = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.wave,
      waveGeometry: SmartRoomWaveGeometry.alongUserView,
      tvX: tvX,
      tvY: tvY,
      userX: userX,
      userY: userY,
      userFacingDeg: 0,
      waveSpeed: 0.2,
      waveStrength: 1.0,
      waveDistanceScale: 4.0,
    );
    final alongL = VirtualRoomEffects.apply(room: along, fixture: left, base: base, animationTick: tick);
    final alongR = VirtualRoomEffects.apply(room: along, fixture: right, base: base, animationTick: tick);
    expect(alongL.r, isNot(equals(alongR.r)), reason: 'left vs right along perpendicular to gaze');
  });

  test('chase ranks order by projection then id', () {
    const room = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.chase,
      waveGeometry: SmartRoomWaveGeometry.horizontalRoom,
      tvX: 0.5,
      tvY: 0.5,
    );
    final fixtures = [
      const SmartFixture(id: 'z', displayName: 'Z', roomX: 0.8, roomY: 0.5),
      const SmartFixture(id: 'a', displayName: 'A', roomX: 0.2, roomY: 0.5),
    ];
    final ranks = VirtualRoomEffects.chaseRanks(room: room, fixtures: fixtures);
    expect(ranks['a'], 0);
    expect(ranks['z'], 1);
  });

  test('breath phase responds to music timing', () {
    const room = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.breath,
      waveSpeed: 0.1,
      waveStrength: 1.0,
    );
    const fx = SmartFixture(id: 'x', displayName: 'X');
    const base = (180, 180, 180);
    const tick = 40;
    final silent = VirtualRoomEffects.apply(room: room, fixture: fx, base: base, animationTick: tick);
    final withBeat = VirtualRoomEffects.apply(
      room: room,
      fixture: fx,
      base: base,
      animationTick: tick,
      musicTiming: const SmartLightsMusicTiming(active: true, beatEnvelope: 0.9, beatEdge: false),
    );
    expect(withBeat.r, isNot(equals(silent.r)));
  });

  test('brightnessOnly leaves rgb unchanged', () {
    const room = VirtualRoomLayout(
      roomEffect: SmartRoomEffectKind.breath,
      waveStrength: 1.0,
      brightnessModulation: SmartRoomBrightnessModulate.brightnessOnly,
    );
    const fx = SmartFixture(id: 'x', displayName: 'X');
    final out = VirtualRoomEffects.apply(
      room: room,
      fixture: fx,
      base: (200, 100, 50),
      animationTick: 5,
    );
    expect(out.r, 200);
    expect(out.g, 100);
    expect(out.b, 50);
    expect(out.brightnessMul, lessThan(1.0));
  });
}
