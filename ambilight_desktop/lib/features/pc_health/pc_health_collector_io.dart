import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'pc_health_snapshot.dart';
import 'pc_health_types.dart';

final _log = Logger('PcHealthCollector');

PcHealthCollector createPcHealthCollector() => _IoCollector();

class _IoCollector implements PcHealthCollector {
  int? _linuxIdle;
  int? _linuxTotal;
  int? _lastNetBytes;
  DateTime? _lastNetTime;

  @override
  Future<PcHealthSnapshot> collect() async {
    try {
      if (Platform.isWindows) {
        return await _collectWindows();
      }
      if (Platform.isLinux) {
        return await _collectLinux();
      }
      if (Platform.isMacOS) {
        return await _collectMac();
      }
    } catch (e, st) {
      _log.fine('collect fallback: $e', e, st);
    }
    return PcHealthSnapshot.empty;
  }

  Future<PcHealthSnapshot> _collectWindows() async {
    final cpuRam = await _powershellCpuRam();
    final disk = await _windowsDiskUsedPercent();
    final gpu = await _nvidiaSmi();
    final net = await _windowsNetPercent();

    double cpuTemp = 0;
    try {
      final t = await _run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r"(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty CurrentTemperature)",
        ],
        const Duration(seconds: 2),
      );
      if (t != null && t.trim().isNotEmpty) {
        final kelvinTenth = double.tryParse(t.trim());
        if (kelvinTenth != null) {
          cpuTemp = (kelvinTenth / 10.0) - 273.15;
        }
      }
    } catch (_) {}

    return PcHealthSnapshot(
      cpuUsage: cpuRam.$1,
      ramUsage: cpuRam.$2,
      netUsage: net,
      cpuTemp: cpuTemp.clamp(0, 120),
      gpuUsage: gpu.$1,
      gpuTemp: gpu.$2,
      diskUsage: disk.clamp(0, 100),
    );
  }

  Future<double> _windowsDiskUsedPercent() async {
    const script = r'''
$d = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -First 1 -Property FreeSpace,Size
if ($null -eq $d -or $d.Size -le 0) { Write-Output "0" } else { Write-Output ([math]::Round((1.0 - $d.FreeSpace / $d.Size) * 100.0, 1)) }
''';
    final out = await _run('powershell', ['-NoProfile', '-Command', script], const Duration(seconds: 3));
    if (out == null) return 0;
    return double.tryParse(out.trim()) ?? 0;
  }

  Future<(double, double)> _powershellCpuRam() async {
    const script = r'''
$c = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
$os = Get-CimInstance Win32_OperatingSystem
$r = if ($os.TotalVisibleMemorySize -gt 0) { [math]::Round((1.0 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100.0, 1) } else { 0 }
Write-Output ("{0:0.###}|{1:0.###}" -f $c, $r)
''';
    final out = await _run('powershell', ['-NoProfile', '-Command', script], const Duration(seconds: 4));
    if (out == null) return (0.0, 0.0);
    final parts = out.trim().split('|');
    if (parts.length != 2) return (0.0, 0.0);
    return (double.tryParse(parts[0]) ?? 0, double.tryParse(parts[1]) ?? 0);
  }

  Future<(double, double)> _nvidiaSmi() async {
    final out = await _run(
      'nvidia-smi',
      ['--query-gpu=utilization.gpu,temperature.gpu', '--format=csv,noheader,nounits'],
      const Duration(seconds: 3),
    );
    if (out == null) return (0.0, 0.0);
    final line = out.trim().split('\n').first.trim();
    final parts = line.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) return (0.0, 0.0);
    return (double.tryParse(parts[0]) ?? 0, double.tryParse(parts[1]) ?? 0);
  }

  Future<double> _windowsNetPercent() async {
    final out = await _run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'$s = Get-NetAdapter | Where-Object Status -eq "Up" | Get-NetAdapterStatistics | Measure-Object -Sum ReceivedBytes; $s.Sum',
      ],
      const Duration(seconds: 3),
    );
    if (out == null) return 0;
    final bytes = int.tryParse(out.trim());
    if (bytes == null) return 0;
    final now = DateTime.now();
    final prevB = _lastNetBytes;
    final prevT = _lastNetTime;
    _lastNetBytes = bytes;
    _lastNetTime = now;
    if (prevB == null || prevT == null) return 0;
    final dt = now.difference(prevT).inMilliseconds / 1000.0;
    if (dt <= 0) return 0;
    final mbps = (bytes - prevB) / dt / (1024 * 1024);
    return (mbps / 10.0 * 100).clamp(0, 100);
  }

  Future<PcHealthSnapshot> _collectLinux() async {
    final cpu = await _linuxCpuPercent();
    final ram = await _linuxRamPercent();
    final net = await _linuxNetPercent();
    final cpuTemp = await _linuxThermal();
    final gpu = await _nvidiaSmi();

    return PcHealthSnapshot(
      cpuUsage: cpu,
      ramUsage: ram,
      netUsage: net,
      cpuTemp: cpuTemp,
      gpuUsage: gpu.$1,
      gpuTemp: gpu.$2,
      diskUsage: 0,
    );
  }

  Future<double> _linuxCpuPercent() async {
    final line = await File('/proc/stat').readAsLines().then((l) => l.firstWhere((e) => e.startsWith('cpu '), orElse: () => ''));
    if (line.isEmpty) return 0;
    final parts = line.split(RegExp(r'\s+')).skip(1).map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length < 4) return 0;
    final idle = parts[3] + (parts.length > 4 ? parts[4] : 0);
    var total = 0;
    for (final v in parts) {
      total += v;
    }
    final prevIdle = _linuxIdle;
    final prevTotal = _linuxTotal;
    _linuxIdle = idle;
    _linuxTotal = total;
    if (prevIdle == null || prevTotal == null) return 0;
    final didle = idle - prevIdle;
    final dtotal = total - prevTotal;
    if (dtotal <= 0) return 0;
    return (100 * (1 - didle / dtotal)).clamp(0, 100);
  }

  Future<double> _linuxRamPercent() async {
    final text = await File('/proc/meminfo').readAsString();
    int? avail, total;
    for (final l in const LineSplitter().convert(text)) {
      if (l.startsWith('MemAvailable:')) {
        avail = int.tryParse(l.split(RegExp(r'\s+'))[1]);
      } else if (l.startsWith('MemTotal:')) {
        total = int.tryParse(l.split(RegExp(r'\s+'))[1]);
      }
    }
    if (avail == null || total == null || total == 0) return 0;
    return (100 * (1 - avail / total)).clamp(0, 100);
  }

  Future<double> _linuxNetPercent() async {
    final text = await File('/proc/net/dev').readAsString();
    var recv = 0;
    for (final line in const LineSplitter().convert(text).skip(2)) {
      final idx = line.indexOf(':');
      if (idx < 0) continue;
      final name = line.substring(0, idx).trim();
      if (name == 'lo') continue;
      final nums = line.substring(idx + 1).trim().split(RegExp(r'\s+'));
      if (nums.isNotEmpty) {
        recv += int.tryParse(nums[0]) ?? 0;
      }
    }
    final now = DateTime.now();
    final prev = _lastNetBytes;
    final prevT = _lastNetTime;
    _lastNetBytes = recv;
    _lastNetTime = now;
    if (prev == null || prevT == null) return 0;
    final dt = now.difference(prevT).inMilliseconds / 1000.0;
    if (dt <= 0) return 0;
    final mbps = (recv - prev) / dt / (1024 * 1024);
    return (mbps / 10.0 * 100).clamp(0, 100);
  }

  Future<double> _linuxThermal() async {
    try {
      final f = File('/sys/class/thermal/thermal_zone0/temp');
      if (await f.exists()) {
        final mk = int.tryParse((await f.readAsString()).trim());
        if (mk != null) return (mk / 1000.0).clamp(0, 120);
      }
    } catch (_) {}
    return 0;
  }

  Future<PcHealthSnapshot> _collectMac() async {
    final ram = await _macRamPercent();
    final cpu = await _macCpuFromLoadavg();
    final disk = await _macDiskUsedPercent();
    final net = await _macNetUsageScaled();
    final gpu = await _nvidiaSmi();
    return PcHealthSnapshot(
      cpuUsage: cpu,
      ramUsage: ram,
      netUsage: net,
      cpuTemp: 0,
      gpuUsage: gpu.$1,
      gpuTemp: gpu.$2,
      diskUsage: disk.clamp(0, 100),
    );
  }

  /// Součet přijatých bajtů ze všech rozhraní kromě `lo*` — robustní vůči pořadí sloupců v `netstat`.
  static const _kMacNetstatSumScript = r'''
netstat -ibn 2>/dev/null | awk '
NR==1 { for (i = 1; i <= NF; i++) if ($i == "Ibytes") ib = i }
NR > 1 && $1 !~ /^lo/ && ib > 0 && NF >= ib { s += $ib }
END { print s+0 }
'
''';

  Future<double> _macRamPercent() async {
    final pageSize = await _run('sysctl', ['-n', 'hw.pagesize'], const Duration(seconds: 2));
    final ps = int.tryParse(pageSize?.trim() ?? '4096') ?? 4096;
    final vm = await _run('/usr/bin/vm_stat', [], const Duration(seconds: 2));
    if (vm == null) return 0;
    int pages(String prefix) {
      for (final line in const LineSplitter().convert(vm)) {
        final t = line.trim();
        if (t.startsWith(prefix)) {
          final m = RegExp(r'(\d+)').firstMatch(t);
          return int.tryParse(m?.group(1) ?? '0') ?? 0;
        }
      }
      return 0;
    }

    final free = pages('Pages free');
    final inactive = pages('Pages inactive');
    final purgeable = pages('Pages purgeable');
    final memSize = await _run('sysctl', ['-n', 'hw.memsize'], const Duration(seconds: 2));
    final totalBytes = int.tryParse(memSize?.trim() ?? '') ?? 0;
    if (totalBytes <= 0) return 0;
    final readilyAvail = (free + inactive + purgeable) * ps;
    return (100 * (1 - readilyAvail / totalBytes)).clamp(0, 100);
  }

  Future<double> _macCpuFromLoadavg() async {
    final loadStr = await _run('sysctl', ['-n', 'vm.loadavg'], const Duration(seconds: 2));
    if (loadStr == null) return 0;
    final inner = RegExp(r'\{\s*([^}]+)\s*\}').firstMatch(loadStr)?.group(1);
    if (inner == null) return 0;
    final parts = inner.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 0;
    final load1 = double.tryParse(parts.first) ?? 0;
    var ncpu = int.tryParse((await _run('sysctl', ['-n', 'hw.logicalcpu'], const Duration(seconds: 2)))?.trim() ?? '') ?? 0;
    if (ncpu <= 0) {
      ncpu = int.tryParse((await _run('sysctl', ['-n', 'hw.ncpu'], const Duration(seconds: 2)))?.trim() ?? '') ?? 1;
    }
    if (ncpu <= 0) ncpu = 1;
    return (load1 / ncpu * 100).clamp(0, 100);
  }

  Future<double> _macDiskUsedPercent() async {
    final cap = await _run(
      '/bin/sh',
      ['-c', r"df -k / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%'"],
      const Duration(seconds: 4),
    );
    final v = double.tryParse(cap?.trim() ?? '');
    if (v != null && v >= 0 && v <= 100) return v;
    final out = await _run('/sbin/df', ['-k', '/'], const Duration(seconds: 4));
    if (out == null) return 0;
    final lines = const LineSplitter().convert(out).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 0;
    final last = lines.last;
    final m = RegExp(r'(\d+)%').firstMatch(last);
    if (m != null) return double.tryParse(m.group(1)!) ?? 0;
    return 0;
  }

  Future<double> _macNetUsageScaled() async {
    final out = await _run('/bin/sh', ['-c', _kMacNetstatSumScript], const Duration(seconds: 4));
    final bytes = int.tryParse(out?.trim() ?? '') ?? 0;
    final now = DateTime.now();
    final prevB = _lastNetBytes;
    final prevT = _lastNetTime;
    _lastNetBytes = bytes;
    _lastNetTime = now;
    if (prevB == null || prevT == null) return 0;
    final dt = now.difference(prevT).inMilliseconds / 1000.0;
    if (dt <= 0) return 0;
    final mbps = (bytes - prevB) / dt / (1024 * 1024);
    return (mbps / 10.0 * 100).clamp(0, 100);
  }

  Future<String?> _run(String executable, List<String> args, Duration timeout) async {
    try {
      final r = await Process.run(executable, args, runInShell: false).timeout(timeout);
      if (r.exitCode != 0) {
        if (kDebugMode) {
          _log.fine('$executable ${args.take(2)} exit ${r.exitCode} stderr=${r.stderr}');
        }
        return r.stdout?.toString();
      }
      return r.stdout?.toString();
    } catch (e) {
      if (kDebugMode) _log.fine('$executable failed: $e');
      return null;
    }
  }
}
