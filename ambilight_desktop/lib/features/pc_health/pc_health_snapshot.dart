/// Normalizované hodnoty pro `PcHealthSettings.metrics` (klíče jako v Pythonu).
class PcHealthSnapshot {
  const PcHealthSnapshot({
    this.cpuUsage = 0,
    this.ramUsage = 0,
    this.netUsage = 0,
    this.cpuTemp = 0,
    this.gpuUsage = 0,
    this.gpuTemp = 0,
    this.diskUsage = 0,
  });

  final double cpuUsage;
  final double ramUsage;
  final double netUsage;
  final double cpuTemp;
  final double gpuUsage;
  final double gpuTemp;
  /// Využití systémového disku v % (0–100), kde je k dispozici (např. Windows první pevný disk).
  final double diskUsage;

  static const PcHealthSnapshot empty = PcHealthSnapshot();

  /// Nahradí NaN/nekonečno nulou, procenta 0–100, teploty 0–125 (bezpečný vstup do engine / UI).
  PcHealthSnapshot get finiteSanitized {
    double pct(double x) => (x.isFinite ? x : 0.0).clamp(0.0, 100.0);
    double temp(double x) => (x.isFinite ? x : 0.0).clamp(0.0, 125.0);
    return PcHealthSnapshot(
      cpuUsage: pct(cpuUsage),
      ramUsage: pct(ramUsage),
      netUsage: pct(netUsage),
      cpuTemp: temp(cpuTemp),
      gpuUsage: pct(gpuUsage),
      gpuTemp: temp(gpuTemp),
      diskUsage: pct(diskUsage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PcHealthSnapshot &&
          cpuUsage == other.cpuUsage &&
          ramUsage == other.ramUsage &&
          netUsage == other.netUsage &&
          cpuTemp == other.cpuTemp &&
          gpuUsage == other.gpuUsage &&
          gpuTemp == other.gpuTemp &&
          diskUsage == other.diskUsage;

  @override
  int get hashCode => Object.hash(
        cpuUsage,
        ramUsage,
        netUsage,
        cpuTemp,
        gpuUsage,
        gpuTemp,
        diskUsage,
      );

  double valueForMetric(String name) {
    switch (name) {
      case 'cpu_usage':
        return cpuUsage;
      case 'ram_usage':
        return ramUsage;
      case 'net_usage':
        return netUsage;
      case 'cpu_temp':
        return cpuTemp;
      case 'gpu_usage':
        return gpuUsage;
      case 'gpu_temp':
        return gpuTemp;
      case 'disk_usage':
        return diskUsage;
      default:
        return 0;
    }
  }
}

/// Přenos přes isolate port (jen primitiva).
Map<String, Object?> pcHealthSnapshotToPortableMap(PcHealthSnapshot s) {
  return <String, Object?>{
    'cu': s.cpuUsage,
    'ru': s.ramUsage,
    'nu': s.netUsage,
    'ct': s.cpuTemp,
    'gu': s.gpuUsage,
    'gt': s.gpuTemp,
    'du': s.diskUsage,
  };
}

PcHealthSnapshot pcHealthSnapshotFromPortableMap(Map<String, Object?> m) {
  double rd(String k) {
    final v = m[k];
    if (v is num) return v.toDouble();
    return 0;
  }

  return PcHealthSnapshot(
    cpuUsage: rd('cu'),
    ramUsage: rd('ru'),
    netUsage: rd('nu'),
    cpuTemp: rd('ct'),
    gpuUsage: rd('gu'),
    gpuTemp: rd('gt'),
    diskUsage: rd('du'),
  ).finiteSanitized;
}
