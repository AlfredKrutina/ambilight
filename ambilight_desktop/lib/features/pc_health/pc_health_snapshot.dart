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
