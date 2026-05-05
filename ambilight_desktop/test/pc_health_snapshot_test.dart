import 'package:ambilight_desktop/features/pc_health/pc_health_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PcHealthSnapshot equality ignores identity when values match', () {
    const a = PcHealthSnapshot(cpuUsage: 12.5, gpuTemp: 44);
    const b = PcHealthSnapshot(cpuUsage: 12.5, gpuTemp: 44);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('PcHealthSnapshot inequality when any field differs', () {
    const a = PcHealthSnapshot(cpuUsage: 1);
    const b = PcHealthSnapshot(cpuUsage: 2);
    expect(a, isNot(equals(b)));
  });

  test('finiteSanitized clamps and clears non-finite', () {
    const raw = PcHealthSnapshot(
      cpuUsage: double.nan,
      ramUsage: double.infinity,
      netUsage: -5,
      cpuTemp: 999,
      gpuUsage: 50,
      gpuTemp: double.nan,
      diskUsage: 101,
    );
    final s = raw.finiteSanitized;
    expect(s.cpuUsage, 0);
    expect(s.ramUsage, 0);
    expect(s.netUsage, 0);
    expect(s.cpuTemp, 125);
    expect(s.gpuUsage, 50);
    expect(s.gpuTemp, 0);
    expect(s.diskUsage, 100);
  });

  test('portable map roundtrip', () {
    const orig = PcHealthSnapshot(cpuUsage: 12, gpuTemp: 42);
    final back = pcHealthSnapshotFromPortableMap(pcHealthSnapshotToPortableMap(orig));
    expect(back, equals(orig));
  });
}
