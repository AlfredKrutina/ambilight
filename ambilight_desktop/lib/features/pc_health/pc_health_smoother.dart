import 'pc_health_snapshot.dart';

/// EMA nad metrikami — omezuje skoky při pomalém sběru / šumu (C8 stabilita).
final class PcHealthSmoother {
  PcHealthSmoother({this.alpha = 0.35});

  final double alpha;
  PcHealthSnapshot? _prev;

  void reset() {
    _prev = null;
  }

  PcHealthSnapshot apply(PcHealthSnapshot raw) {
    final p = _prev;
    if (p == null) {
      _prev = raw;
      return raw;
    }
    final a = alpha.clamp(0.01, 1.0);
    double lerp(double x, double y) => x + (y - x) * a;
    final blended = PcHealthSnapshot(
      cpuUsage: lerp(p.cpuUsage, raw.cpuUsage),
      ramUsage: lerp(p.ramUsage, raw.ramUsage),
      netUsage: lerp(p.netUsage, raw.netUsage),
      cpuTemp: lerp(p.cpuTemp, raw.cpuTemp),
      gpuUsage: lerp(p.gpuUsage, raw.gpuUsage),
      gpuTemp: lerp(p.gpuTemp, raw.gpuTemp),
      diskUsage: lerp(p.diskUsage, raw.diskUsage),
    );
    _prev = blended;
    return blended;
  }
}
