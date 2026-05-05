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

String _pipelineDiagMsOrDash(int? micros) =>
    micros == null ? '-' : (micros / 1000).toStringAsFixed(1);

int _udpRgbBytesHash(Uint8List rgb, int bri) {
  var h = bri ^ (rgb.length * 0x9E3779B9);
  for (var i = 0; i < rgb.length; i++) {
    h = 0x7fffffff & (h * 31 + rgb[i]);
  }
  return h;
}

Uint8List _rgbTuplesToBytes(List<(int r, int g, int b)> colors) {
  final n = colors.length;
  final rgb = Uint8List(n * 3);
  for (var i = 0; i < n; i++) {
    final c = colors[i];
    final o = i * 3;
    rgb[o] = c.$1.clamp(0, 255);
    rgb[o + 1] = c.$2.clamp(0, 255);
    rgb[o + 2] = c.$3.clamp(0, 255);
  }
  return rgb;
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

  /// Nejnovější rámec z [sendColors] / [sendPackedRgbBytes]; starší se zahazují (max 1 slot).
  ({Uint8List rgb, int bri})? _rgbLatestJob;

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

  /// Trvalý socket: při neúplném `send` (Windows často vrací 0 při plném TX bufferu) opakování
  /// s levnými yieldy — nejdřív [Duration.zero], pak 1 ms, pak 2 ms (dříve jen 5× 2 ms ≈ strop latence).
  static const int _kSendDatagramMaxAttempts = 12;

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
      if (failCount >= _kSendDatagramMaxAttempts) {
        _logUdpSendFailureIfNeeded(last, pkt.length, addr, port);
        return false;
      }
      if (failCount <= 4) {
        await Future<void>.delayed(Duration.zero);
      } else if (failCount <= 8) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
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

  /// Max. ~10 s — při odpojené síti nekonečné čekání neblokuje kalibraci / pixel navždy.
  static const int _kWaitRgbTransportIdleMaxIterations = 5000;

  Future<void> _waitRgbTransportIdle() async {
    var n = 0;
    while (_rgbWorkerBusy || _rgbLatestJob != null) {
      n++;
      if (n > _kWaitRgbTransportIdleMaxIterations) {
        _log.warning(
          'UDP $_kWaitRgbTransportIdleMaxIterations×2 ms: worker stále busy nebo fronta neprázdná — '
          'přerušuji čekání (${device.name})',
        );
        return;
      }
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
        await _emitFramePacedRgb(job.rgb, job.bri);
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
  Future<void> _emitFramePacedRgb(Uint8List rgb, int brightnessScalar) async {
    final genEnter = _lifecycleGen;
    final sock = _socket;
    final addr = _addr;
    final emitSw = ambilightPipelineDiagnosticsEnabled ? (Stopwatch()..start()) : null;
    var diagPath = 'abort';
    if (!_ready || sock == null || addr == null || rgb.isEmpty || rgb.length % 3 != 0) {
      emitSw?.stop();
      return;
    }
    final pixelCount = rgb.length ~/ 3;
    final bri = brightnessScalar.clamp(0, 255);
    final frameHash = _udpRgbBytesHash(rgb, bri);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rawEmitAgeMs =
        _lastSuccessfulEmitWallMs == 0 ? _kUdpDedupeMaxSkipAgeMs + 1 : nowMs - _lastSuccessfulEmitWallMs;
    // Záporný rozdíl (úprava systémového času) → chovej se jako „staré“, ať se rámec nezasekne ve skip.
    final emitAgeMs = rawEmitAgeMs < 0 ? _kUdpDedupeMaxSkipAgeMs + 1 : rawEmitAgeMs;
    // Rainbow test: fáze je vázaná na [seq] → mezi snímky se hash mění; mezi tiky bez nového výstupu
    // izolátu zůstává stejný rámec — dedupe zabrání opakovanému celému 0x06+0x08 každých ~16 ms.
    final dedupeSkip = _lastSentRgbFrameHash != null &&
        frameHash == _lastSentRgbFrameHash &&
        emitAgeMs <= _kUdpDedupeMaxSkipAgeMs;
    if (dedupeSkip) {
      emitSw?.stop();
      if (ambilightPipelineDiagnosticsEnabled) {
        final sinceCap = PipelineDiagCaptureTimeline.elapsedSinceCaptureMicros();
        final sinceSub = PipelineDiagCaptureTimeline.elapsedSinceSubmitWallMicros();
        final sinceMs = _pipelineDiagMsOrDash(sinceCap);
        final subMs = _pipelineDiagMsOrDash(sinceSub);
        final staleCap = sinceCap != null && sinceCap > 500000;
        pipelineDiagLog(
          'udp_emit_skip',
          'dev=${device.name} leds=$pixelCount hash=$frameHash '
          'sinceCaptureMs=$sinceMs sinceSubmitMs=$subMs emitAgeMs=$emitAgeMs '
          'dedupe=1${staleCap ? ' longGapSinceCapture=1' : ''}',
        );
      }
      return;
    }
    final port = _udpPort;
    final cap = UdpAmbilightProtocol.maxRgbPixelsPerUdpDatagram;
    try {
      if (pixelCount <= cap) {
        diagPath = '0x02_bulk';
        if (genEnter != _lifecycleGen) {
          return;
        }
        final pkt = UdpAmbilightProtocol.buildRgbFrameFromRgbBytes(rgb, brightness: bri);
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
          'UDP $pixelCount LED > $cap — chunky 0x06 + jeden flush 0x08 (${device.name}). '
          'Vyžaduje aktuální lamp FW; kalibrace jedním pixelem stále 0x03.',
        );
      }
      final chunkMax = UdpAmbilightProtocol.udpOpcode06EmitChunkPixels;
      diagPath = '0x06_chunked';
      var offsetPx = 0;
      while (offsetPx < pixelCount) {
        if (genEnter != _lifecycleGen) {
          return;
        }
        final takePx = pixelCount - offsetPx > chunkMax ? chunkMax : pixelCount - offsetPx;
        final byteOffset = offsetPx * 3;
        final byteLen = takePx * 3;
        final sub = Uint8List.sublistView(rgb, byteOffset, byteOffset + byteLen);
        final pkt = UdpAmbilightProtocol.buildRgbChunkOpcode06FromRgbBytes(offsetPx, sub);
        if (!await _sendDatagramPersistent(sock, pkt, addr, port)) {
          diagPath = 'abort_tx_blocked';
          return;
        }
        offsetPx += takePx;
      }
      if (genEnter != _lifecycleGen) {
        return;
      }
      if (!await _sendDatagramPersistent(
        sock,
        UdpAmbilightProtocol.buildFlushOpcode08(bri, pixelCount),
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
        final sinceSub = PipelineDiagCaptureTimeline.elapsedSinceSubmitWallMicros();
        final sinceMs = _pipelineDiagMsOrDash(sinceCap);
        final subMs = _pipelineDiagMsOrDash(sinceSub);
        pipelineDiagLog(
          'udp_emit_done',
          'dev=${device.name} ms=${emitSw.elapsedMilliseconds} leds=$pixelCount path=$diagPath gen=$genEnter '
          'sinceCaptureMs=$sinceMs sinceSubmitMs=$subMs',
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
    var spin = 0;
    while (_rgbWorkerBusy) {
      spin++;
      if (spin > _kWaitRgbTransportIdleMaxIterations) {
        _log.warning(
          'sendColorsNow: čekání na idle worker překročilo limit — přerušuji (${device.name})',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (!_ready) {
        return;
      }
    }
    _rgbWorkerBusy = true;
    try {
      await _emitFramePacedRgb(
        _rgbTuplesToBytes(List<(int, int, int)>.from(colors, growable: false)),
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
    final bri = brightnessScalar.clamp(0, 255);
    final rgb = _rgbTuplesToBytes(colors);
    final incomingHash = _udpRgbBytesHash(rgb, bri);

    // Jen duplicita už zařazeného jobu — ne „stejný hash jako poslední emit“: to řeší
    // [_emitFramePacedRgb] (dedupe + emitAge). Předčasný return u volného workeru by mohl
    // bránit zařazení práce a kolidovat s keepalive / rychlým eager výstupem.
    final queued = _rgbLatestJob;
    if (queued != null && incomingHash == _udpRgbBytesHash(queued.rgb, queued.bri)) {
      return;
    }

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
    _rgbLatestJob = (rgb: rgb, bri: bri);
    unawaited(_runRgbWorkerIfNeeded());
  }

  /// Rychlá cesta ze screen izolátu: už hotový `[r,g,b,…]` (délka `3 × LED`), bez převodu z tuple listu.
  /// Vlastnictví bufferu přejde na frontu — volající ho už nesmí měnit ([packDeviceRgbMap] vždy nový buffer).
  void sendPackedRgbBytes(Uint8List rgb, int brightnessScalar) {
    if (!_ready || _socket == null || _addr == null || rgb.isEmpty || rgb.length % 3 != 0) {
      return;
    }
    final bri = brightnessScalar.clamp(0, 255);
    final incomingHash = _udpRgbBytesHash(rgb, bri);
    final queued = _rgbLatestJob;
    if (queued != null && incomingHash == _udpRgbBytesHash(queued.rgb, queued.bri)) {
      return;
    }
    if (ambilightPipelineDiagnosticsEnabled) {
      PipelineUdpDiagStats.sendColorsCalls++;
      final hadQueued = _rgbLatestJob != null;
      if (hadQueued) {
        PipelineUdpDiagStats.jobSupersededWhileQueued++;
        pipelineDiagLog(
          'udp_sendPacked_supersede',
          'dev=${device.name} leds=${rgb.length ~/ 3} workerBusy=$_rgbWorkerBusy',
        );
      }
    }
    _rgbLatestJob = (rgb: rgb, bri: bri);
    unawaited(_runRgbWorkerIfNeeded());
  }

  @override
  void sendPcReleaseHandoff() {
    final sock = _socket;
    final addr = _addr;
    if (!_ready || sock == null || addr == null) return;
    final pkt = Uint8List.fromList([UdpAmbilightProtocol.pcReleaseHandoff]);
    try {
      for (var i = 0; i < 8; i++) {
        if (sock.send(pkt, addr, _udpPort) == pkt.length) {
          return;
        }
      }
    } catch (e, st) {
      _log.fine('sendPcReleaseHandoff: $e', e, st);
    }
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

  @override
  Future<bool> sendFirmwareTemporalMode(int mode) async {
    final ip = device.ipAddress.trim();
    if (ip.isEmpty) return false;
    return UdpDeviceCommands.sendTemporalModeWithAck(
      ip,
      _udpPort,
      mode,
      logContext: device.name,
    );
  }
}
