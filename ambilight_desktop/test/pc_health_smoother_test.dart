import 'package:ambilight_desktop/features/pc_health/pc_health_smoother.dart';
import 'package:ambilight_desktop/features/pc_health/pc_health_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PcHealthSmoother blends toward new sample', () {
    final s = PcHealthSmoother(alpha: 0.5);
    final a = s.apply(const PcHealthSnapshot(cpuUsage: 0));
    expect(a.cpuUsage, 0);
    final b = s.apply(const PcHealthSnapshot(cpuUsage: 100));
    expect(b.cpuUsage, 50);
    final c = s.apply(const PcHealthSnapshot(cpuUsage: 100));
    expect(c.cpuUsage, 75);
  });

  test('reset clears state', () {
    final s = PcHealthSmoother();
    s.apply(const PcHealthSnapshot(cpuUsage: 80));
    s.reset();
    final x = s.apply(const PcHealthSnapshot(cpuUsage: 0));
    expect(x.cpuUsage, 0);
  });
}
