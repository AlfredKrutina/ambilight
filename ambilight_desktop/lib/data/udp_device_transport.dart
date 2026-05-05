import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../application/debug_trace.dart';
import '../application/pipeline_diagnostics.dart';
import '../core/device_bindings_debug.dart';
import '../core/models/config_models.dart';
import '../core/protocol/udp_frame.dart';
import 'device_transport.dart';
import 'udp_device_commands.dart';
import 'udp_socket_bind.dart';

final _log = Logger('UdpTransport');

/// I při stejném hash pošli znovu, aby LED nestárly (plynulý pohyb při pomalé změně průměru).
const int _kUdpDedupeMaxSkipAgeMs = 50;

int _udpRgbFrameHash(List<(int r, int g, int b)> colors, int bri) {
  var h = bri ^ (colors.length * 0x9E3779B9);
  for (var i = 0; i < colors.length; i++) {
    final c = colors[i];
    h = 0x7fffffff & (h * 31 + c.$1);
    h = 0x7fffffff & (h * 31 + c.$2);
    h = 0x7fffffff & (h * 31 + c.$3);
  }
  return h;
}

class UdpDeviceTransport extends DeviceTransport {
  UdpDeviceTransport(super.device);

  RawDatagramSocket? _socket;
  InternetAddress? _addr;
  bool _ready = false;
  bool _loggedUdpOversize = false;
  bool _connecting = false;

  /// Po [disconnect]/[dispose] se zvýší — [connect] po `await` nesmí pokračovat se starým socketem.
  int _lifecycleGen = 0;

  DateTime? _lastPartialSendLog;

  /// Nejnovější rámec z [sendColors]; starší se zahazují (max 1 slot). Worker běží na pozadí.
  ({List<(int r, int g, int b)> colors, int bri})? _rgbLatestJob;

  /// Právě probíhá async odesílání ([_emitFramePaced]).
  bool _rgbWorkerBusy = false;

  /// Poslední úspěšně odeslaný rámec — [null] po [disconnect] / před prvním TX; viz [_emitFramePaced].
  int? _lastSentRgbFrameHash;

  /// Čas posledního úspěšného UDP emitu ([DateTime.now().millisecondsSinceEpoch]); 0 = ještě nebylo.
  int _lastSuccessfulEmitWallMs = 0;

  @override
  bool get isConnected => _ready && _socket != null && _addr != null;

  static Future<InternetAddress?> _resolveTarget(String raw) async {
    final host = raw.replaceAll(',', '.').trim();
    if (host.isEmpty) return null;
    final direct = InternetAddress.tryParse(host);
    if (direct != null) return direct;
    try {
      final list = await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      if (list.isEmpty) return null;
      for (final a in list) {
        if (a.type == InternetAddressType.IPv4) return a;
      }
      return list.first;
    } catch (e) {
      _log.fine('UDP lookup $host: $e');
      return null;
    }
  }

  int get _udpPort => device.udpPort.clamp(1, 65535);

  /// Trvalý socket: při neúplném `send` max. 5 pokusů s prodlevou 2 ms, pak zahodit datagram.
  Future<bool> _sendDatagramPersistent(
    RawDatagramSocket sock,
    Uint8List pkt,
    InternetAddress addr,
    int port,
  ) async {
    if (pkt.isEmpty) return true;
    var failCount = 0;
    var last = 0;
    while (true) {
      last = sock.send(pkt, addr, port);
      if (last == pkt.length) return true;
      failCount++;
      if (failCount >= 5) {
        _logUdpSendFailureIfNeeded(last, pkt.length, addr, port);
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  void _logUdpSendFailureIfNeeded(int n, int expected, InternetAddress addr, int port) {
    if (n == expected) return;
    final now = DateTime.now();
    if (_lastPartialSendLog == null ||
        now.difference(_lastPartialSendLog!) > const Duration(seconds: 5)) {
      _lastPartialSendLog = now;
      ambilightDebugTrace(
        'UdpTransport send vrátilo $n/$expected B → ${device.name} ${addr.address}:$port',
      );
      _log.warning(
        'UDP send selhal ($n/$expected B) → ${device.name} ${addr.address}:$port '
        '(firewall / síť; rámce jsou << MTU a pod limitem lampy)',
      );
    }
  }

  Future<void> _waitRgbTransportIdle() async {
    while (_rgbWorkerBusy || _rgbLatestJob != null) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (!_ready) {
        return;
      }
    }
  }

  Future<void> _runRgbWorkerIfNeeded() async {
    if (_rgbWorkerBusy) {
      return;
    }
    _rgbWorkerBusy = true;
    try {
      while (_ready && _rgbLatestJob != null) {
        final job = _rgbLatestJob!;
        _rgbLatestJob = null;
        await _emitFramePaced(job.colors, job.bri);
      }
    } finally {
      _rgbWorkerBusy = false;
      if (_rgbLatestJob != null && _ready) {
        unawaited(_runRgbWorkerIfNeeded());
      }
    }
  }

  /// Jeden kompletní snímek — chunky 0x06 + flush 0x08; jen persistentní socket.
  /// Mezi datagramy záměrně není `Future.delayed(1 ms)` — na Windows se mapuje na ~15,6 ms tick.
  Future<void> _emitFramePaced(List<(int r, int g, int b)> colors, int brightnessScalar) async {
    final genEnter = _lifecycleGen;
    final sock = _socket;
    final addr = _addr;
    final emitSw = ambilightPipelineDiagnosticsEnabled ? (Stopwatch()..start()) : null;
    var diagPath = 'abort';
    if (!_ready || sock == null || addr == null || colors.isEmpty) {
      emitSw?.stop();
      return;
    }
    final bri = brightnessScalar.clamp(0, 255);
    final frameHash = _udpRgbFrameHash(colors, bri);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rawEmitAgeMs =
        _lastSuccessfulEmitWallMs == 0 ? _kUdpDedupeMaxSkipAgeMs + 1 : nowMs - _lastSuccessfulEmitWallMs;
    // Záporný rozdíl (úprava systémového času) → chovej se jako „staré“, ať se rámec nezasekne ve skip.
    final emitAgeMs = rawEmitAgeMs < 0 ? _kUdpDedupeMaxSkipAgeMs + 1 : rawEmitAgeMs;
    final dedupeSkip =
        _lastSentRgbFrameHash != null && frameHash == _lastSentRgbFrameHash && emitAgeMs <= _kUdpDedupeMaxSkipAgeMs;
    if (dedupeSkip) {
      emitSw?.stop();
      if (ambilightPipelineDiagnosticsEnabled) {
        final sinceCap = PipelineDiagCaptureTimeline.elapsedSinceCaptureMicros();
        final sinceMs = sinceCap == null ? '-' : (sinceCap / 1000).toStringAsFixed(1);
        pipelineDiagLog(
          'udp_emit_skip',
          'dev=${device.name} leds=${colors.length} hash=$frameHash sinceCaptureMs=$sinceMs emitAgeMs=$emitAgeMs',
        );
      }
      return;
    }
    final port = _udpPort;
    final cap = UdpAmbilightProtocol.maxRgbPixelsPerUdpDatagram;
    try {
      if (colors.length <= cap) {
        diagPath = '0x02_bulk';
        if (genEnter != _lifecycleGen) {
          return;
        }
        final pkt = UdpAmbilightProtocol.buildRgbFrame(colors, brightness: bri);
        if (!await _sendDatagramPersistent(sock, pkt, addr, port)) {
          diagPath = 'abort_tx_blocked';
          return;
        }
        _lastSentRgbFrameHash = frameHash;
        _lastSuccessfulEmitWallMs = DateTime.now().millisecondsSinceEpoch;
        return;
      }
      if (!_loggedUdpOversize) {
        _loggedUdpOversize = true;
        _log.info(
          'UDP ${colors.length} LED > $cap — chunky 0x06 + jeden flush 0x08 (${device.name}). '
          'Vyžaduje aktuální lamp FW; kalibrace jedním pixelem stále 0x03.',
        );
      }
      final chunkMax = UdpAmbilightProtocol.maxRgbPixelsPerUdpOpcode06Chunk;
      diagPath = '0x06_chunked';
      var offset = 0;
      while (offset < colors.length) {
        if (genEnter != _lifecycleGen) {
          return;
        }
        final take = colors.length - offset > chunkMax ? chunkMax : colors.length - offset;
        final sub = colors.sublist(offset, offset + take);
        final pkt = UdpAmbilightProtocol.buildRgbChunkOpcode06(offset, sub);
        if (!await _sendDatagramPersistent(sock, pkt, addr, port)) {
          diagPath = 'abort_tx_blocked';
          return;
        }
        offset += take;
      }
      if (genEnter != _lifecycleGen) {
        return;
      }
      if (!await _sendDatagramPersistent(
        sock,
        UdpAmbilightProtocol.buildFlushOpcode08(bri, colors.length),
        addr,
        port,
      )) {
        diagPath = 'abort_tx_blocked';
        return;
      }
      _lastSentRgbFrameHash = frameHash;
      _lastSuccessfulEmitWallMs = DateTime.now().millisecondsSinceEpoch;
    } catch (e, st) {
      _log.fine('sendColors: $e', e, st);
    } finally {
      emitSw?.stop();
      if (ambilightPipelineDiagnosticsEnabled && emitSw != null) {
        PipelineUdpDiagStats.emitCompleted++;
        if (diagPath == '0x02_bulk') {
          PipelineUdpDiagStats.path0x02Bulk++;
        } else if (diagPath == '0x06_chunked') {
          PipelineUdpDiagStats.path0x06Chunked++;
        }
        PipelineUdpDiagStats.recordEmitMs(emitSw.elapsedMilliseconds);
        final sinceCap = PipelineDiagCaptureTimeline.elapsedSinceCaptureMicros();
        final sinceMs = sinceCap == null ? '-' : (sinceCap / 1000).toStringAsFixed(1);
        pipelineDiagLog(
          'udp_emit_done',
          'dev=${device.name} ms=${emitSw.elapsedMilliseconds} leds=${colors.length} path=$diagPath gen=$genEnter '
          'sinceCaptureMs=$sinceMs',
        );
      }
    }
  }

  @override
  Future<void> connect() async {
    if (_connecting || isConnected) return;
    _connecting = true;
    _loggedUdpOversize = false;
    try {
      disconnect();
      final gen = _lifecycleGen;
      final raw = device.ipAddress;
      _addr = await _resolveTarget(raw);
      if (gen != _lifecycleGen) {
        _addr = null;
        return;
      }
      if (_addr == null) {
        _log.warning('UDP: neplatná adresa nebo DNS selhalo: $raw');
        return;
      }
      final bindAddr =
          await udpBindAddressForOutgoingTo(_addr!, probeDestinationPort: _udpPort);
      final sock = await RawDatagramSocket.bind(bindAddr, 0, reuseAddress: true);
      if (gen != _lifecycleGen) {
        try {
          sock.close();
        } catch (_) {}
        _addr = null;
        return;
      }
      _socket = sock;
      _socket!.broadcastEnabled = false;
      _ready = true;
      traceDeviceBindings('UdpTransport.connect OK: ${device.id} → ${_addr!.address}:$_udpPort');
      ambilightDebugTrace(
        'UdpTransport socket dev=${device.id} local=${bindAddr.address} remote=${_addr!.address}:$_udpPort '
        'broadcast=${_socket!.broadcastEnabled}',
      );
      _log.info('UDP ready local=${bindAddr.address} → remote=${_addr!.address}:$_udpPort');
    } catch (e, st) {
      traceDeviceBindingsWarning(
        'UdpTransport.connect FAIL ${device.id} ${device.ipAddress}',
        e,
        st,
      );
      _log.warning('UDP connect failed: $e', e, st);
      disconnect();
    } finally {
      _connecting = false;
    }
  }

  @override
  void disconnect() {
    _lifecycleGen++;
    _lastSentRgbFrameHash = null;
    _lastSuccessfulEmitWallMs = 0;
    _rgbLatestJob = null;
    _ready = false;
    _socket?.close();
    _socket = null;
    _addr = null;
  }

  @override
  Future<void> sendColorsNow(List<(int r, int g, int b)> colors, int brightnessPercent) async {
    if (!_ready || _socket == null || _addr == null || colors.isEmpty) {
      return;
    }
    _lastSentRgbFrameHash = null;
    _lastSuccessfulEmitWallMs = 0;
    _rgbLatestJob = null;
    while (_rgbWorkerBusy) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (!_ready) {
        return;
      }
    }
    _rgbWorkerBusy = true;
    try {
      await _emitFramePaced(
        List<(int, int, int)>.from(colors, growable: false),
        brightnessPercent.clamp(0, 255),
      );
    } finally {
      _rgbWorkerBusy = false;
      if (_rgbLatestJob != null && _ready) {
        unawaited(_runRgbWorkerIfNeeded());
      }
    }
  }

  @override
  void sendColors(List<(int r, int g, int b)> colors, int brightnessScalar) {
    if (!_ready || _socket == null || _addr == null || colors.isEmpty) return;
    if (ambilightPipelineDiagnosticsEnabled) {
      PipelineUdpDiagStats.sendColorsCalls++;
      final hadQueued = _rgbLatestJob != null;
      if (hadQueued) {
        PipelineUdpDiagStats.jobSupersededWhileQueued++;
        pipelineDiagLog(
          'udp_sendColors_supersede',
          'dev=${device.name} leds=${colors.length} workerBusy=$_rgbWorkerBusy',
        );
      }
    }
    _rgbLatestJob = (
      colors: List<(int, int, int)>.from(colors, growable: false),
      bri: brightnessScalar.clamp(0, 255),
    );
    unawaited(_runRgbWorkerIfNeeded());
  }

  @override
  void sendPixel(int index, int r, int g, int b) {
    final sock = _socket;
    final addr = _addr;
    if (!_ready || sock == null || addr == null) return;
    try {
      final pkt = Uint8List.fromList(UdpAmbilightProtocol.buildSinglePixel(index, r, g, b));
      final port = _udpPort;
      unawaited(() async {
        await _waitRgbTransportIdle();
        if (!_ready || _socket == null || _addr == null) {
          return;
        }
        await _sendDatagramPersistent(_socket!, pkt, _addr!, port);
      }());
    } catch (e, st) {
      _log.fine('pixel send: $e', e, st);
    }
  }

  @override
  void syncDeviceSnapshot(DeviceSettings next) {
    device = next;
  }

  @override
  void dispose() => disconnect();

  Future<bool> sendIdentify() async {
    final ip = device.ipAddress;
    final port = _udpPort;
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendIdentify(ip, port, logContext: device.name);
  }

  Future<bool> sendResetWifi() async {
    final ip = device.ipAddress;
    final port = _udpPort;
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendResetWifi(ip, port, logContext: device.name);
  }
}
