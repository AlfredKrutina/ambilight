import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../application/pipeline_diagnostics.dart';
import '../../core/models/config_models.dart';
import '../../core/protocol/serial_frame.dart';
import 'screen_frame.dart';

/// Throttle [processFrameToDevices] H1/H2 diagnostic prints (isolate / sync path).
int _processFrameDiagThrottle = 0;

typedef CaptureLedKey = (String?, int);

/// Segment vzorkuje jiný monitor než aktuální snímek ([ScreenModeSettings.monitorIndex]).
class SegmentCaptureWarning {
  const SegmentCaptureWarning({
    required this.segmentIndex,
    required this.edge,
    required this.segmentMonitorIdx,
    required this.captureMonitorIndex,
  });
  final int segmentIndex;
  final String edge;
  final int segmentMonitorIdx;
  final int captureMonitorIndex;
}

/// Geometrie jednoho segmentu ve souřadnicích snímku (šipka dovnitř od hrany).
class SegmentRoiRect {
  const SegmentRoiRect({required this.x, required this.y, required this.w, required this.h});
  final int x;
  final int y;
  final int w;
  final int h;
  bool get isEmpty => w <= 0 || h <= 0;
}

/// Čisté funkce + jedna mutable třída pro vyhlazení a pracovní buffery.
abstract final class ScreenColorPipeline {
  /// Součet LED napříč zařízeními (stejná logika jako [AmbilightEngine.combinedDeviceLedLength]).
  static int combinedDeviceLedCount(AppConfig config) {
    final ds = config.globalSettings.devices;
    if (ds.isEmpty) {
      return config.globalSettings.ledCount.clamp(1, SerialAmbilightProtocol.maxLedsPerDevice);
    }
    var s = 0;
    for (final d in ds) {
      s += d.ledCount;
    }
    return s.clamp(1, 4096);
  }

  /// Konfigurované segmenty, nebo výchozí mapování po obvodu monitoru (Python `default.json`).
  static List<LedSegment> effectiveScreenSegments(AppConfig config) {
    final s = config.screenMode.segments;
    if (s.isNotEmpty) return s;
    return implicitScreenSegments(config);
  }

  /// Rozdělí LED indexy 0…N−1 na levou / horní / pravou / spodní hranu (plný ROI, `ref_*` = 0).
  /// Nejvyšší LED index + 1 ze segmentů pro [deviceId] (`primary` → první zařízení).
  static int impliedLedCountFromSegments(AppConfig config, String deviceId) {
    final devices = config.globalSettings.devices;
    if (devices.isEmpty) return 0;
    final primaryId = devices.first.id;
    var hi = -1;
    for (final seg in effectiveScreenSegments(config)) {
      var tid = seg.deviceId;
      if (tid == null || tid.isEmpty || tid == 'primary') {
        tid = primaryId;
      }
      if (tid != deviceId) continue;
      hi = math.max(hi, math.max(seg.ledStart, seg.ledEnd));
    }
    return hi < 0 ? 0 : hi + 1;
  }

  /// Délka výstupního bufferu: nesklízí starý discovery počet (např. 512), když segmenty sahají jen do 99.
  static int effectiveDeviceLedCount(AppConfig config, DeviceSettings dev) {
    final cap = SerialAmbilightProtocol.maxLedsPerDevice;
    final stored = dev.ledCount.clamp(1, cap);
    final implied = impliedLedCountFromSegments(config, dev.id);
    if (implied <= 0) return stored;
    return math.min(stored, implied).clamp(1, cap);
  }

  /// Stejná logika jako [segmentMatchesCaptureFrame], ale jen podle čísla monitoru ze settings.
  static bool segmentMatchesMonitorIndex(LedSegment seg, int captureMonitorIndex) {
    final fm = captureMonitorIndex;
    final sm = seg.monitorIdx;
    if (sm == fm) return true;
    if (fm >= 1 && sm + 1 == fm) return true;
    return false;
  }

  static String? _cornerKeyForEdgePair(String e1, String e2) {
    final a = e1.toLowerCase();
    final b = e2.toLowerCase();
    final s = {a, b};
    if (s.containsAll({'left', 'top'})) return 'top_left';
    if (s.containsAll({'top', 'right'})) return 'top_right';
    if (s.containsAll({'right', 'bottom'})) return 'bottom_right';
    if (s.containsAll({'bottom', 'left'})) return 'bottom_left';
    return null;
  }

  static int _segLo(LedSegment s) => math.min(s.ledStart, s.ledEnd);

  static int _segHi(LedSegment s) => math.max(s.ledStart, s.ledEnd);

  /// Dva sousední LED indexy na pásku mezi segmenty [a] a [b] (vhůru podél indexů nebo wrap  N−1 ↔ 0).
  static List<int>? _junctionLedPair(LedSegment a, LedSegment b, int spanLo, int spanHi) {
    final aLo = _segLo(a);
    final aHi = _segHi(a);
    final bLo = _segLo(b);
    final bHi = _segHi(b);
    if (aHi + 1 == bLo) return [aHi, bLo];
    if (bHi + 1 == aLo) return [bHi, aLo];
    if (spanLo == 0 && aHi == spanHi && bLo == spanLo) return [aHi, bLo];
    if (spanLo == 0 && bHi == spanHi && aLo == spanLo) return [bHi, aLo];
    return null;
  }

  /// LED indexy pro rohové značky kalibrace podle [LedSegment] mapování (ne fixní PyQt konstanty).
  /// Roh = pár sousedních indexů na pásku mezi dvěma hranami (včetně wrap spodní → levá hrana).
  static List<int> cornerMarkerLedIndices({
    required AppConfig config,
    required String deviceId,
    required String corner,
  }) {
    final cap = SerialAmbilightProtocol.maxLedsPerDevice;
    final devices = config.globalSettings.devices;
    if (devices.isEmpty) return const [];
    DeviceSettings? dev;
    for (final d in devices) {
      if (d.id == deviceId) {
        dev = d;
        break;
      }
    }
    if (dev == null) return const [];

    final bufLen = math
        .max(dev.ledCount, impliedLedCountFromSegments(config, deviceId))
        .clamp(1, cap);

    String resolvedSegDev(LedSegment s) {
      var tid = s.deviceId;
      if (tid == null || tid.isEmpty || tid == 'primary') {
        tid = devices.first.id;
      }
      return tid;
    }

    final mi = config.screenMode.monitorIndex;
    final mine = effectiveScreenSegments(config)
        .where((s) => resolvedSegDev(s) == deviceId && segmentMatchesMonitorIndex(s, mi))
        .toList();

    LedSegment? pickEdge(String edge) {
      try {
        return mine.firstWhere((s) => s.edge.toLowerCase() == edge);
      } catch (_) {
        return null;
      }
    }

    final byEdge = <String, LedSegment>{};
    for (final e in const ['left', 'top', 'right', 'bottom']) {
      final s = pickEdge(e);
      if (s != null) byEdge[e] = s;
    }

    if (byEdge.length < 4) {
      return _fallbackCornerMarkerIndices(corner, bufLen);
    }

    var spanLo = 1 << 30;
    var spanHi = -1;
    for (final s in byEdge.values) {
      spanLo = math.min(spanLo, _segLo(s));
      spanHi = math.max(spanHi, _segHi(s));
    }

    final chain = byEdge.values.toList()..sort((a, b) => _segLo(a).compareTo(_segLo(b)));
    final junctions = <String, List<int>>{};
    for (var i = 0; i < chain.length; i++) {
      final cur = chain[i];
      final next = chain[(i + 1) % chain.length];
      final key = _cornerKeyForEdgePair(cur.edge, next.edge);
      if (key == null) continue;
      final pair = _junctionLedPair(cur, next, spanLo, spanHi);
      if (pair != null) {
        junctions[key] = pair;
      }
    }

    final hit = junctions[corner];
    if (hit != null && hit.length >= 2) {
      final a = hit[0].clamp(0, bufLen - 1);
      final b = hit[1].clamp(0, bufLen - 1);
      if (a == b) {
        final b2 = math.min(a + 1, bufLen - 1);
        return a == b2 ? <int>[a] : <int>[a, b2];
      }
      return a <= b ? <int>[a, b] : <int>[b, a];
    }

    return _fallbackCornerMarkerIndices(corner, bufLen);
  }

  static List<int> _fallbackCornerMarkerIndices(String corner, int bufLen) {
    if (bufLen <= 0) return const [];
    final maxIdx = bufLen - 1;
    List<int> pair(int a, int b) {
      final aa = a.clamp(0, maxIdx);
      final bb = b.clamp(0, maxIdx);
      if (aa == bb) {
        final bb2 = math.min(aa + 1, maxIdx);
        return aa == bb2 ? <int>[aa] : <int>[aa, bb2];
      }
      return aa <= bb ? <int>[aa, bb] : <int>[bb, aa];
    }

    switch (corner) {
      case 'top_left':
        return pair((maxIdx * 0.25).floor(), (maxIdx * 0.25).floor() + 1);
      case 'top_right':
        return pair((maxIdx * 0.5).floor(), (maxIdx * 0.5).floor() + 1);
      case 'bottom_right':
        return pair((maxIdx * 0.75).floor(), (maxIdx * 0.75).floor() + 1);
      case 'bottom_left':
        return pair(maxIdx, 0);
      default:
        return const [];
    }
  }

  static List<LedSegment> implicitScreenSegments(AppConfig config) {
    final n = combinedDeviceLedCount(config);
    final mi = config.screenMode.monitorIndex;
    if (n < 1) return const [];
    final counts = [n ~/ 4, n ~/ 4, n ~/ 4, n ~/ 4];
    for (var i = 0; i < n % 4; i++) {
      counts[i]++;
    }
    const edges = ['left', 'top', 'right', 'bottom'];
    const revs = [true, false, false, true];
    var led = 0;
    final out = <LedSegment>[];
    for (var e = 0; e < 4; e++) {
      final cnt = counts[e];
      if (cnt <= 0) continue;
      out.add(
        LedSegment(
          ledStart: led,
          ledEnd: led + cnt - 1,
          monitorIdx: mi,
          edge: edges[e],
          depth: 10,
          reverse: revs[e],
          pixelStart: 0,
          pixelEnd: 0,
          refWidth: 0,
          refHeight: 0,
        ),
      );
      led += cnt;
    }
    return out;
  }

  /// Python MSS: `target_mss_idx = segment.monitor_idx + 1` (`capture.py`), tedy legacy
  /// `monitor_idx == 0` znamená první fyzický monitor = MSS `[1]` = [ScreenFrame.monitorIndex] `1`.
  /// Flutter už posílá přímo MSS index (`0` virtuální plocha, `1`… první LCD…).
  /// Shoda: stejný index **nebo** legacy `frame.monitorIndex == segment.monitorIdx + 1` pro `frame >= 1`.
  static bool segmentMatchesCaptureFrame(LedSegment seg, ScreenFrame frame) {
    final fm = frame.monitorIndex;
    final sm = seg.monitorIdx;
    if (sm == fm) return true;
    if (fm >= 1 && sm + 1 == fm) return true;
    return false;
  }

  /// Segmenty, jejichž [LedSegment.monitorIdx] nesedí na aktuální snímek ([ScreenModeSettings.monitorIndex]).
  static List<SegmentCaptureWarning> screenSegmentCaptureWarnings(AppConfig config) {
    final cap = config.screenMode.monitorIndex;
    final rgba = Uint8List(4);
    final frame = ScreenFrame(monitorIndex: cap, width: 1, height: 1, rgba: rgba);
    final segs = effectiveScreenSegments(config);
    final out = <SegmentCaptureWarning>[];
    for (var i = 0; i < segs.length; i++) {
      if (!segmentMatchesCaptureFrame(segs[i], frame)) {
        out.add(
          SegmentCaptureWarning(
            segmentIndex: i,
            edge: segs[i].edge,
            segmentMonitorIdx: segs[i].monitorIdx,
            captureMonitorIndex: cap,
          ),
        );
      }
    }
    return out;
  }

  /// Diagnostika ([AMBI_PIPELINE_DIAGNOSTICS]): shoda segmentů s [frame] a ROI v pixelech snímku (např. po downscale).
  static void logSegmentDiagnosticsForFrame(AppConfig config, ScreenFrame frame) {
    if (!ambilightPipelineDiagnosticsEnabled) return;
    final sm = config.screenMode;
    pipelineDiagLog(
      'segment_cfg',
      'minBrightness=${sm.minBrightness} interpolationMs=${sm.interpolationMs} '
      'colorSampling=${sm.colorSampling}',
    );
    final segs = effectiveScreenSegments(config);
    var matched = 0;
    for (var i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final ok = segmentMatchesCaptureFrame(seg, frame);
      if (!ok) {
        pipelineDiagLog(
          'segment_skip',
          'i=$i edge=${seg.edge} monSeg=${seg.monitorIdx} monFrame=${frame.monitorIndex}',
        );
        continue;
      }
      matched++;
      final roi = segmentRoiInFrameBuffer(seg, sm, frame);
      pipelineDiagLog(
        'segment_roi',
        'i=$i edge=${seg.edge} led=${seg.ledStart}-${seg.ledEnd} px=${seg.pixelStart}-${seg.pixelEnd} '
        'ref=${seg.refWidth}x${seg.refHeight} roiBuf=${roi.x},${roi.y} ${roi.w}x${roi.h} empty=${roi.isEmpty}',
      );
    }
    pipelineDiagLog(
      'segment_summary',
      'segments=${segs.length} matched=$matched frame=${frame.width}x${frame.height} mon=${frame.monitorIndex}',
    );
  }

  static const int _kDefaultSegmentRefWidth = 1920;
  static const int _kDefaultSegmentRefHeight = 1080;

  /// ROI v [0 .. monW-1] × [0 .. monH-1], vždy aspoň 1×1 pokud je snímek neprázdný.
  static SegmentRoiRect _roiClampMin1(SegmentRoiRect r, int monW, int monH) {
    if (monW < 1 || monH < 1) {
      return const SegmentRoiRect(x: 0, y: 0, w: 0, h: 0);
    }
    final maxX = monW - 1;
    final maxY = monH - 1;
    var x0 = r.x.clamp(0, maxX);
    var y0 = r.y.clamp(0, maxY);
    var x1 = r.x + r.w - 1;
    var y1 = r.y + r.h - 1;
    x1 = x1.clamp(0, maxX);
    y1 = y1.clamp(0, maxY);
    var w = x1 - x0 + 1;
    var h = y1 - y0 + 1;
    if (w < 1) {
      w = 1;
      x0 = x0.clamp(0, maxX);
    }
    if (h < 1) {
      h = 1;
      y0 = y0.clamp(0, maxY);
    }
    if (x0 + w > monW) x0 = monW - w;
    if (y0 + h > monH) y0 = monH - h;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    return SegmentRoiRect(x: x0, y: y0, w: w, h: h);
  }

  /// ROI jako v Python `CaptureThread._recalc_geometry_cache` (per-edge scan depth + padding).
  static SegmentRoiRect segmentRoi(
    LedSegment seg,
    ScreenModeSettings sm,
    int monW,
    int monH,
  ) {
    final scanTop = sm.scanDepthTop > 0 ? sm.scanDepthTop : sm.scanDepthPercent;
    final scanBottom = sm.scanDepthBottom > 0 ? sm.scanDepthBottom : sm.scanDepthPercent;
    final scanLeft = sm.scanDepthLeft > 0 ? sm.scanDepthLeft : sm.scanDepthPercent;
    final scanRight = sm.scanDepthRight > 0 ? sm.scanDepthRight : sm.scanDepthPercent;

    final padTop = sm.paddingTop > 0 ? sm.paddingTop : sm.paddingPercent;
    final padBottom = sm.paddingBottom > 0 ? sm.paddingBottom : sm.paddingPercent;
    final padLeft = sm.paddingLeft > 0 ? sm.paddingLeft : sm.paddingPercent;
    final padRight = sm.paddingRight > 0 ? sm.paddingRight : sm.paddingPercent;

    final padTopPx = (monH * (padTop / 100.0)).floor();
    final padBottomPx = (monH * (padBottom / 100.0)).floor();
    final padLeftPx = (monW * (padLeft / 100.0)).floor();
    final padRightPx = (monW * (padRight / 100.0)).floor();

    var pS = seg.pixelStart;
    var pE = seg.pixelEnd;
    var skipRefScale = false;
    if (pS == 0 && pE == 0) {
      skipRefScale = true;
      if (seg.edge == 'top' || seg.edge == 'bottom') {
        pS = 0;
        pE = monW;
      } else {
        pS = 0;
        pE = monH;
      }
    }

    // pixelStart/End v referenčním rozlišení; při ref 0 fallback 1920×1080. Plný okraj (0,0) už je v pixelech snímku.
    if (!skipRefScale) {
      if (seg.edge == 'top' || seg.edge == 'bottom') {
        final refSpan = seg.refWidth > 0 ? seg.refWidth : _kDefaultSegmentRefWidth;
        final inv = 1.0 / refSpan;
        var f0 = pS * inv;
        var f1 = pE * inv;
        if (f0 > f1) {
          final t = f0;
          f0 = f1;
          f1 = t;
        }
        f0 = f0.clamp(0.0, 1.0);
        f1 = f1.clamp(0.0, 1.0);
        pS = (f0 * monW).floor();
        pE = (f1 * monW).ceil();
        if (pE <= pS) pE = math.min(monW, pS + 1);
      } else {
        final refSpan = seg.refHeight > 0
            ? seg.refHeight
            : (seg.refWidth > 0 ? seg.refWidth : _kDefaultSegmentRefHeight);
        final inv = 1.0 / refSpan;
        var f0 = pS * inv;
        var f1 = pE * inv;
        if (f0 > f1) {
          final t = f0;
          f0 = f1;
          f1 = t;
        }
        f0 = f0.clamp(0.0, 1.0);
        f1 = f1.clamp(0.0, 1.0);
        pS = (f0 * monH).floor();
        pE = (f1 * monH).ceil();
        if (pE <= pS) pE = math.min(monH, pS + 1);
      }
    }

    int iclamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

    switch (seg.edge) {
      case 'top':
        final depth = math.max(10, (monH * (scanTop / 100.0)).floor());
        int roiY0 = iclamp(padTopPx, 0, math.max(0, monH - 1));
        int roiY1 = iclamp(padTopPx + depth, 0, monH);
        roiY1 = math.max(roiY0 + 1, roiY1);
        if (roiY1 > monH) roiY1 = monH;
        int x0 = iclamp(pS, 0, math.max(0, monW - 1));
        int x1 = iclamp(pE, 0, monW);
        x1 = math.max(x0 + 1, x1);
        if (x1 > monW) x1 = monW;
        return _roiClampMin1(
          SegmentRoiRect(x: x0, y: roiY0, w: x1 - x0, h: roiY1 - roiY0),
          monW,
          monH,
        );
      case 'bottom':
        final depth = math.max(10, (monH * (scanBottom / 100.0)).floor());
        int roiY1 = iclamp(monH - padBottomPx, 0, monH);
        int roiY0 = iclamp(monH - padBottomPx - depth, 0, math.max(0, monH - 1));
        roiY1 = math.max(roiY0 + 1, roiY1);
        if (roiY1 > monH) roiY1 = monH;
        int x0 = iclamp(pS, 0, math.max(0, monW - 1));
        int x1 = iclamp(pE, 0, monW);
        x1 = math.max(x0 + 1, x1);
        if (x1 > monW) x1 = monW;
        return _roiClampMin1(
          SegmentRoiRect(x: x0, y: roiY0, w: x1 - x0, h: roiY1 - roiY0),
          monW,
          monH,
        );
      case 'left':
        final depth = math.max(10, (monW * (scanLeft / 100.0)).floor());
        int roiX0 = iclamp(padLeftPx, 0, math.max(0, monW - 1));
        int roiX1 = iclamp(padLeftPx + depth, 0, monW);
        roiX1 = math.max(roiX0 + 1, roiX1);
        if (roiX1 > monW) roiX1 = monW;
        int y0 = iclamp(pS, 0, math.max(0, monH - 1));
        int y1 = iclamp(pE, 0, monH);
        y1 = math.max(y0 + 1, y1);
        if (y1 > monH) y1 = monH;
        return _roiClampMin1(
          SegmentRoiRect(x: roiX0, y: y0, w: roiX1 - roiX0, h: y1 - y0),
          monW,
          monH,
        );
      case 'right':
      default:
        final depth = math.max(10, (monW * (scanRight / 100.0)).floor());
        int roiX1 = iclamp(monW - padRightPx, 0, monW);
        int roiX0 = iclamp(monW - padRightPx - depth, 0, math.max(0, monW - 1));
        roiX1 = math.max(roiX0 + 1, roiX1);
        if (roiX1 > monW) roiX1 = monW;
        int y0 = iclamp(pS, 0, math.max(0, monH - 1));
        int y1 = iclamp(pE, 0, monH);
        y1 = math.max(y0 + 1, y1);
        if (y1 > monH) y1 = monH;
        return _roiClampMin1(
          SegmentRoiRect(x: roiX0, y: y0, w: roiX1 - roiX0, h: y1 - y0),
          monW,
          monH,
        );
    }
  }

  static SegmentRoiRect _intersectRoiRects(SegmentRoiRect a, SegmentRoiRect b) {
    final x0 = math.max(a.x, b.x);
    final y0 = math.max(a.y, b.y);
    final x1 = math.min(a.x + a.w, b.x + b.w);
    final y1 = math.min(a.y + a.h, b.y + b.h);
    final w = x1 - x0;
    final h = y1 - y0;
    if (w <= 0 || h <= 0) {
      return const SegmentRoiRect(x: 0, y: 0, w: 0, h: 0);
    }
    return SegmentRoiRect(x: x0, y: y0, w: w, h: h);
  }

  /// ROI ve souřadnicích [frame.rgba] (výřez + layout meta z nativního capture).
  static SegmentRoiRect segmentRoiInFrameBuffer(
    LedSegment seg,
    ScreenModeSettings sm,
    ScreenFrame frame,
  ) {
    if (!frame.hasBufferLayoutMeta) {
      return segmentRoi(seg, sm, frame.width, frame.height);
    }
    final lw = frame.layoutW;
    final lh = frame.layoutH;
    final roiLayout = segmentRoi(seg, sm, lw, lh);
    final ox = frame.bufferOriginX;
    final oy = frame.bufferOriginY;
    final nw = frame.nativeBufferWidth!;
    final nh = frame.nativeBufferHeight!;
    final buf = SegmentRoiRect(x: ox, y: oy, w: nw, h: nh);
    final inter = _intersectRoiRects(roiLayout, buf);
    if (inter.isEmpty) {
      return inter;
    }
    final sx = frame.width / nw;
    final sy = frame.height / nh;
    int clampFloor(num v, int lo, int hi) => v.floor().clamp(lo, hi).toInt();
    int clampCeil(num v, int lo, int hi) => v.ceil().clamp(lo, hi).toInt();
    final x0 = clampFloor((inter.x - ox) * sx, 0, math.max(0, frame.width - 1));
    final y0 = clampFloor((inter.y - oy) * sy, 0, math.max(0, frame.height - 1));
    final x1 = clampCeil((inter.x + inter.w - ox) * sx, 0, frame.width);
    final y1 = clampCeil((inter.y + inter.h - oy) * sy, 0, frame.height);
    final rw = math.max(1, x1 - x0);
    final rh = math.max(1, y1 - y0);
    return _roiClampMin1(SegmentRoiRect(x: x0, y: y0, w: rw, h: rh), frame.width, frame.height);
  }

  /// Agregace ROI → [ledCount] RGB (0–255).
  ///
  /// Každá LED dostane podobně jako PyQt `capture.py`: podél hrany se ROI rozdělí na `ledCount`
  /// obdélníků (šířka u top/bottom, výška u left/right); uvnitř obdélníku je **průměr** (`average`)
  /// nebo **medián po kanálech R/G/B** (`median`) ze všech pixelů — žádná závislost na rozlišení
  /// snímku kromě mapování ROI do bufferu.
  static void sampleRoiColors(
    ScreenFrame frame,
    SegmentRoiRect roi,
    String edge,
    int ledCount,
    Uint8List outRgb, {
    String colorSampling = 'median',
  }) {
    final need = ledCount * 3;
    if (outRgb.length < need) {
      throw ArgumentError(
        'outRgb.length (${outRgb.length}) < ledCount*3 ($need)',
      );
    }
    if (!frame.isValid || roi.isEmpty || ledCount <= 0) {
      outRgb.fillRange(0, need, 0);
      return;
    }

    final fw = frame.width;
    final fh = frame.height;
    final rgba = frame.rgba;
    final x0 = roi.x.clamp(0, fw - 1);
    final y0 = roi.y.clamp(0, fh - 1);
    final x1 = math.min(fw, roi.x + roi.w);
    final y1 = math.min(fh, roi.y + roi.h);
    final rw = math.max(0, x1 - x0);
    final rh = math.max(0, y1 - y0);
    if (rw <= 0 || rh <= 0) {
      outRgb.fillRange(0, need, 0);
      return;
    }

    final useMean = _useMeanColorSampling(colorSampling);
    if (edge == 'top' || edge == 'bottom') {
      if (useMean) {
        _averageColumnsThenResample(rgba, fw, fh, x0, y0, rw, rh, ledCount, outRgb);
      } else {
        _perLedRectMedianTopBottom(rgba, fw, fh, x0, y0, rw, rh, ledCount, outRgb);
      }
    } else {
      if (useMean) {
        _averageRowsThenResample(rgba, fw, fh, x0, y0, rw, rh, ledCount, outRgb);
      } else {
        _perLedRectMedianLeftRight(rgba, fw, fh, x0, y0, rw, rh, ledCount, outRgb);
      }
    }
  }

  static bool _useMeanColorSampling(String mode) {
    final t = mode.trim().toLowerCase();
    return t == 'average' || t == 'mean' || t == 'avg';
  }

  static void _clearHist3(Int32List r, Int32List g, Int32List b) {
    for (var i = 0; i < 256; i++) {
      r[i] = 0;
      g[i] = 0;
      b[i] = 0;
    }
  }

  static int _kthSmallestFromHist(Int32List h, int k) {
    final need = k + 1;
    var c = 0;
    for (var v = 0; v < 256; v++) {
      c += h[v];
      if (c >= need) return v;
    }
    return 255;
  }

  /// Medián jednoho kanálu (0–255); sudý počet = průměr dvou středních hodnot (jako NumPy).
  static int _medianByteFromHist(Int32List h, int n) {
    if (n <= 0) return 0;
    final lo = _kthSmallestFromHist(h, (n - 1) ~/ 2);
    final hi = _kthSmallestFromHist(h, n ~/ 2);
    return ((lo + hi + 1) ~/ 2).clamp(0, 255);
  }

  /// Rozdělení délky `axisLen` px na `ledCount` intervalů — shodné s [_resampleStrip1D].
  static (int, int) _ledBinAlongAxis(int axisLen, int ledCount, int ledIndex) {
    final u0 = (ledIndex * axisLen / ledCount).floor();
    var u1 = math.max(u0 + 1, ((ledIndex + 1) * axisLen / ledCount).ceil());
    if (u1 > axisLen) u1 = axisLen;
    return (u0, u1);
  }

  static void _perLedRectMedianTopBottom(
    Uint8List rgba,
    int fw,
    int fh,
    int x0,
    int y0,
    int rw,
    int rh,
    int ledCount,
    Uint8List outRgb,
  ) {
    final hr = Int32List(256);
    final hg = Int32List(256);
    final hb = Int32List(256);
    for (var i = 0; i < ledCount; i++) {
      final bin = _ledBinAlongAxis(rw, ledCount, i);
      final u0 = bin.$1;
      final u1 = bin.$2;
      _clearHist3(hr, hg, hb);
      var n = 0;
      for (var yy = 0; yy < rh; yy++) {
        final ys = y0 + yy;
        if (ys < 0 || ys >= fh) continue;
        for (var u = u0; u < u1; u++) {
          final xs = x0 + u;
          if (xs < 0 || xs >= fw) continue;
          final o = (ys * fw + xs) * 4;
          hr[rgba[o]]++;
          hg[rgba[o + 1]]++;
          hb[rgba[o + 2]]++;
          n++;
        }
      }
      if (n <= 0) {
        outRgb[i * 3] = 0;
        outRgb[i * 3 + 1] = 0;
        outRgb[i * 3 + 2] = 0;
      } else {
        outRgb[i * 3] = _medianByteFromHist(hr, n);
        outRgb[i * 3 + 1] = _medianByteFromHist(hg, n);
        outRgb[i * 3 + 2] = _medianByteFromHist(hb, n);
      }
    }
  }

  static void _perLedRectMedianLeftRight(
    Uint8List rgba,
    int fw,
    int fh,
    int x0,
    int y0,
    int rw,
    int rh,
    int ledCount,
    Uint8List outRgb,
  ) {
    final hr = Int32List(256);
    final hg = Int32List(256);
    final hb = Int32List(256);
    for (var i = 0; i < ledCount; i++) {
      final bin = _ledBinAlongAxis(rh, ledCount, i);
      final v0 = bin.$1;
      final v1 = bin.$2;
      _clearHist3(hr, hg, hb);
      var n = 0;
      for (var xx = 0; xx < rw; xx++) {
        final xs = x0 + xx;
        if (xs < 0 || xs >= fw) continue;
        for (var v = v0; v < v1; v++) {
          final ys = y0 + v;
          if (ys < 0 || ys >= fh) continue;
          final o = (ys * fw + xs) * 4;
          hr[rgba[o]]++;
          hg[rgba[o + 1]]++;
          hb[rgba[o + 2]]++;
          n++;
        }
      }
      if (n <= 0) {
        outRgb[i * 3] = 0;
        outRgb[i * 3 + 1] = 0;
        outRgb[i * 3 + 2] = 0;
      } else {
        outRgb[i * 3] = _medianByteFromHist(hr, n);
        outRgb[i * 3 + 1] = _medianByteFromHist(hg, n);
        outRgb[i * 3 + 2] = _medianByteFromHist(hb, n);
      }
    }
  }

  static void _averageColumnsThenResample(
    Uint8List rgba,
    int fw,
    int fh,
    int x0,
    int y0,
    int rw,
    int rh,
    int ledCount,
    Uint8List outRgb,
  ) {
    final colR = Float64List(rw);
    final colG = Float64List(rw);
    final colB = Float64List(rw);
    final invRh = 1.0 / rh;
    for (var x = 0; x < rw; x++) {
      var sr = 0.0;
      var sg = 0.0;
      var sb = 0.0;
      final xs = x0 + x;
      for (var y = 0; y < rh; y++) {
        final ys = y0 + y;
        final o = (ys * fw + xs) * 4;
        sr += rgba[o];
        sg += rgba[o + 1];
        sb += rgba[o + 2];
      }
      colR[x] = sr * invRh;
      colG[x] = sg * invRh;
      colB[x] = sb * invRh;
    }
    _resampleStrip1D(colR, colG, colB, rw, ledCount, outRgb);
  }

  static void _averageRowsThenResample(
    Uint8List rgba,
    int fw,
    int fh,
    int x0,
    int y0,
    int rw,
    int rh,
    int ledCount,
    Uint8List outRgb,
  ) {
    final rowR = Float64List(rh);
    final rowG = Float64List(rh);
    final rowB = Float64List(rh);
    final invRw = 1.0 / rw;
    for (var y = 0; y < rh; y++) {
      var sr = 0.0;
      var sg = 0.0;
      var sb = 0.0;
      final ys = y0 + y;
      for (var x = 0; x < rw; x++) {
        final xs = x0 + x;
        final o = (ys * fw + xs) * 4;
        sr += rgba[o];
        sg += rgba[o + 1];
        sb += rgba[o + 2];
      }
      rowR[y] = sr * invRw;
      rowG[y] = sg * invRw;
      rowB[y] = sb * invRw;
    }
    _resampleStrip1D(rowR, rowG, rowB, rh, ledCount, outRgb);
  }

  /// Area-like box převod délky `srcLen` → `dstLen`.
  static void _resampleStrip1D(
    Float64List r,
    Float64List g,
    Float64List b,
    int srcLen,
    int dstLen,
    Uint8List outRgb,
  ) {
    if (srcLen <= 0 || dstLen <= 0) return;
    for (var i = 0; i < dstLen; i++) {
      final t0 = (i * srcLen / dstLen).floor();
      final t1 = math.max(t0 + 1, ((i + 1) * srcLen / dstLen).ceil());
      var sr = 0.0;
      var sg = 0.0;
      var sb = 0.0;
      final n = (t1 - t0).clamp(1, srcLen);
      for (var t = t0; t < t1 && t < srcLen; t++) {
        sr += r[t];
        sg += g[t];
        sb += b[t];
      }
      final inv = 1.0 / n;
      outRgb[i * 3] = (sr * inv).round().clamp(0, 255);
      outRgb[i * 3 + 1] = (sg * inv).round().clamp(0, 255);
      outRgb[i * 3 + 2] = (sb * inv).round().clamp(0, 255);
    }
  }

  /// Saturační boost, gamma, ultra sat, kalibrace, min jas (pořadí odpovídá Python `capture.py` + rozšíření min_brightness).
  static (int, int, int) applyTransforms(
    int r,
    int g,
    int b,
    ScreenModeSettings sm,
  ) {
    var rn = r / 255.0;
    var gn = g / 255.0;
    var bn = b / 255.0;

    var (h, s, v) = _rgbToHsv(rn, gn, bn);
    s = (s * sm.saturationBoost).clamp(0.0, 1.0);
    (rn, gn, bn) = _hsvToRgb(h, s, v);

    final gLin = sm.gamma <= 0 ? 2.2 : sm.gamma;
    rn = rn > 0 ? math.pow(rn, 1.0 / gLin).toDouble() : 0.0;
    gn = gn > 0 ? math.pow(gn, 1.0 / gLin).toDouble() : 0.0;
    bn = bn > 0 ? math.pow(bn, 1.0 / gLin).toDouble() : 0.0;

    r = (rn * 255).round().clamp(0, 255);
    g = (gn * 255).round().clamp(0, 255);
    b = (bn * 255).round().clamp(0, 255);

    if (sm.ultraSaturation) {
      final boost = sm.ultraSaturationAmount;
      rn = r / 255.0;
      gn = g / 255.0;
      bn = b / 255.0;
      (h, s, v) = _rgbToHsv(rn, gn, bn);
      s = (s * boost).clamp(0.0, 1.0);
      (rn, gn, bn) = _hsvToRgb(h, s, v);
      var ch0 = rn;
      var ch1 = gn;
      var ch2 = bn;
      final maxC = math.max(ch0, math.max(ch1, ch2));
      if (maxC > 0.1) {
        final contrastFactor = math.min(boost / 10.0, 0.8);
        double enh(double ch) {
          if ((ch - maxC).abs() < 1e-9) {
            return (ch + (1.0 - ch) * contrastFactor * 0.5).clamp(0.0, 1.0);
          }
          return (ch * (1.0 - contrastFactor)).clamp(0.0, 1.0);
        }

        ch0 = enh(ch0);
        ch1 = enh(ch1);
        ch2 = enh(ch2);
        rn = ch0;
        gn = ch1;
        bn = ch2;
      }
      r = (rn * 255).round().clamp(0, 255);
      g = (gn * 255).round().clamp(0, 255);
      b = (bn * 255).round().clamp(0, 255);
    }

    final cal = _activeCalibration(sm);
    if (cal != null) {
      (r, g, b) = applyCalibration(r, g, b, cal);
    }

    (r, g, b) = _applyMinBrightness(r, g, b, sm.minBrightness);
    return (r, g, b);
  }

  static Map<String, dynamic>? _activeCalibration(ScreenModeSettings sm) {
    Map<String, dynamic>? cal;
    if (sm.calibrationProfiles.isNotEmpty) {
      cal = sm.calibrationProfiles[sm.activeCalibrationProfile];
    }
    cal ??= sm.colorCalibration;
    if (cal == null) return null;
    if (cal['enabled'] != true) return null;
    return cal;
  }

  /// Stejné jako Python `apply_color_correction`.
  static (int, int, int) applyCalibration(int r, int g, int b, Map<String, dynamic> cal) {
    final gain = _tripleDouble(cal['gain'], 1.0);
    final gamma = _tripleDouble(cal['gamma'], 1.0);
    final offset = _tripleInt(cal['offset'], 0);
    var rn = _calibCh(r / 255.0, gain[0], gamma[0], offset[0]);
    var gn = _calibCh(g / 255.0, gain[1], gamma[1], offset[1]);
    var bn = _calibCh(b / 255.0, gain[2], gamma[2], offset[2]);
    return (
      (rn * 255).round().clamp(0, 255),
      (gn * 255).round().clamp(0, 255),
      (bn * 255).round().clamp(0, 255),
    );
  }

  static double _calibCh(double normalized, double gain, double gamma, int offset) {
    var v = normalized;
    if (gamma > 0) {
      v = math.pow(v, 1.0 / gamma).toDouble();
    }
    v = v * gain + offset / 255.0;
    return v.clamp(0.0, 1.0);
  }

  static List<double> _tripleDouble(dynamic v, double def) {
    if (v is List && v.length >= 3) {
      return [
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
      ];
    }
    return [def, def, def];
  }

  static List<int> _tripleInt(dynamic v, int def) {
    if (v is List && v.length >= 3) {
      return [
        (v[0] as num).round(),
        (v[1] as num).round(),
        (v[2] as num).round(),
      ];
    }
    return [def, def, def];
  }

  static (int, int, int) _applyMinBrightness(int r, int g, int b, int minB) {
    if (minB <= 0) return (r, g, b);
    final lum = 0.299 * r + 0.587 * g + 0.114 * b;
    final minL = minB.clamp(0, 255).toDouble();
    if (lum >= minL) return (r, g, b);
    if (lum <= 0.001) {
      return (minB.clamp(0, 255), minB.clamp(0, 255), minB.clamp(0, 255));
    }
    final f = minL / lum;
    return (
      (r * f).round().clamp(0, 255),
      (g * f).round().clamp(0, 255),
      (b * f).round().clamp(0, 255),
    );
  }

  static (double, double, double) _rgbToHsv(double r, double g, double b) {
    final maxc = math.max(r, math.max(g, b));
    final minc = math.min(r, math.min(g, b));
    final d = maxc - minc;
    double h;
    if (d < 1e-10) {
      h = 0;
    } else if (maxc == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (maxc == g) {
      h = 60 * (((b - r) / d) + 2);
    } else {
      h = 60 * (((r - g) / d) + 4);
    }
    if (h < 0) h += 360;
    h /= 360.0;
    final s = maxc <= 0 ? 0.0 : d / maxc;
    final v = maxc;
    return (h, s, v);
  }

  static (double, double, double) _hsvToRgb(double h, double s, double v) {
    final hh = (h % 1.0) * 6.0;
    final sector = hh.floor();
    final f = hh - sector;
    final p = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));
    switch (sector) {
      case 0:
        return (v, t, p);
      case 1:
        return (q, v, p);
      case 2:
        return (p, v, t);
      case 3:
        return (p, q, v);
      case 4:
        return (t, p, v);
      default:
        return (v, p, q);
    }
  }

  /// Klíč shodný s Python `(device_id, led_idx)` včetně `primary`.
  static CaptureLedKey captureKey(String? deviceId, int ledIdx) => (deviceId, ledIdx);

  static Map<CaptureLedKey, (int, int, int)> extractCaptureMap({
    required ScreenFrame frame,
    required ScreenModeSettings sm,
    required List<LedSegment> segments,
    Uint8List? reusableRgbStrip,
  }) {
    final out = <CaptureLedKey, (int, int, int)>{};
    if (!frame.isValid || segments.isEmpty) return out;

    var maxLeds = 1;
    for (final seg in segments) {
      final len = (seg.ledEnd - seg.ledStart).abs() + 1;
      if (len > maxLeds) maxLeds = len;
    }
    final strip = reusableRgbStrip ?? Uint8List(maxLeds * 3);
    if (strip.length < maxLeds * 3) {
      throw ArgumentError('reusableRgbStrip too short');
    }

    for (final seg in segments) {
      if (!segmentMatchesCaptureFrame(seg, frame)) continue;
      final roi = segmentRoiInFrameBuffer(seg, sm, frame);
      final cnt = (seg.ledEnd - seg.ledStart).abs() + 1;
      if (cnt <= 0 || roi.isEmpty) continue;

      sampleRoiColors(frame, roi, seg.edge, cnt, strip, colorSampling: sm.colorSampling);

      for (var i = 0; i < cnt; i++) {
        var r = strip[i * 3];
        var g = strip[i * 3 + 1];
        var b = strip[i * 3 + 2];
        final rgb = applyTransforms(r, g, b, sm);
        r = rgb.$1;
        g = rgb.$2;
        b = rgb.$3;
        final ledIdx = seg.reverse ? (seg.ledEnd - i) : (seg.ledStart + i);
        out[captureKey(seg.deviceId, ledIdx)] = (r, g, b);
      }
    }
    return out;
  }

  /// Živý náhled pro UI: RGB podél hrany ve stejném pořadí jako [sampleRoiColors]
  /// (po [applyTransforms]). Index `0` je **začátek hrany v ROI** — u horní/spodní hrany
  /// zleva doprava, u levé/pravé shora dolů. Prázdné, pokud snímek nebo monitor segmentu nesedí.
  static List<(int, int, int)> segmentSpatialRgbPreview({
    required LedSegment seg,
    required ScreenModeSettings sm,
    required ScreenFrame frame,
  }) {
    if (!frame.isValid || !segmentMatchesCaptureFrame(seg, frame)) {
      return const [];
    }
    final roi = segmentRoiInFrameBuffer(seg, sm, frame);
    final cnt = (seg.ledEnd - seg.ledStart).abs() + 1;
    if (cnt <= 0 || roi.isEmpty) {
      return const [];
    }
    final strip = Uint8List(cnt * 3);
    sampleRoiColors(frame, roi, seg.edge, cnt, strip, colorSampling: sm.colorSampling);
    final out = <(int, int, int)>[];
    for (var i = 0; i < cnt; i++) {
      var r = strip[i * 3];
      var g = strip[i * 3 + 1];
      var b = strip[i * 3 + 2];
      final rgb = applyTransforms(r, g, b, sm);
      out.add((rgb.$1, rgb.$2, rgb.$3));
    }
    return out;
  }

  /// Jako Python `_process_screen_mode`: mapa capture → buffery podle `device_id` v segmentu.
  static Map<String, List<(int, int, int)>> mergeCaptureToDeviceBuffers(
    AppConfig config,
    Map<CaptureLedKey, (int, int, int)> captured,
  ) {
    final devices = config.globalSettings.devices;
    final out = <String, List<(int, int, int)>>{};
    for (final dev in devices) {
      final n = effectiveDeviceLedCount(config, dev);
      out[dev.id] = List<(int, int, int)>.filled(n, (0, 0, 0), growable: false);
    }
    if (devices.isEmpty) return out;

    for (final seg in effectiveScreenSegments(config)) {
      final rawDev = seg.deviceId;
      var targetDev = rawDev;
      if (targetDev == null || targetDev.isEmpty || targetDev == 'primary') {
        targetDev = devices.first.id;
      }
      if (!out.containsKey(targetDev)) continue;

      final buf = out[targetDev]!;
      final length = (seg.ledEnd - seg.ledStart).abs() + 1;
      for (var i = 0; i < length; i++) {
        final ledIdx = seg.reverse ? (seg.ledEnd - i) : (seg.ledStart + i);
        if (ledIdx < 0 || ledIdx >= buf.length) continue;
        final c = captured[captureKey(rawDev, ledIdx)] ?? (0, 0, 0);
        buf[ledIdx] = c;
      }
    }
    return out;
  }

  /// Celý krok: snímek → per-device RGB (bez časového vyhlazení).
  static Map<String, List<(int, int, int)>> processFrameToDevices(
    AppConfig config,
    ScreenFrame frame,
    ScreenPipelineRuntime runtime,
  ) {
    final devices = config.globalSettings.devices;
    final segs = effectiveScreenSegments(config);
    final maxLeds = segs.isEmpty
        ? 1
        : segs.map((s) => (s.ledEnd - s.ledStart).abs() + 1).reduce(math.max);
    runtime.ensureRgbStripCapacity(maxLeds);
    final captured = extractCaptureMap(
      frame: frame,
      sm: config.screenMode,
      segments: segs,
      reusableRgbStrip: runtime.rgbStripWork,
    );

    if (ambilightPipelineDiagnosticsEnabled) {
      var segMatchMon = 0;
      var segMissMon = 0;
      for (final seg in segs) {
        if (segmentMatchesCaptureFrame(seg, frame)) {
          segMatchMon++;
        } else {
          segMissMon++;
        }
      }
      final shouldLog = devices.isEmpty ||
          (captured.isEmpty && devices.isNotEmpty && segs.isNotEmpty);
      if (shouldLog && (++_processFrameDiagThrottle % 30 == 1)) {
        pipelineDiagIsolatePrint(
          'process_frame '
          '${devices.isEmpty ? 'H1_devices_empty' : 'H2_captured_empty_or_no_samples'} '
          'devices=${devices.length} segs=${segs.length} segMatchMon=$segMatchMon '
          'segMissMon=$segMissMon capturedKeys=${captured.length} '
          'frameMon=${frame.monitorIndex} ${frame.width}x${frame.height}',
        );
      }
    }

    return mergeCaptureToDeviceBuffers(config, captured);
  }
}

/// Mutable stav: EMA jako Python `AppState.interpolate_colors` + pracovní buffer pro segment.
final class ScreenPipelineRuntime {
  ScreenPipelineRuntime();

  static const int _maxStrip = 4096;
  Uint8List rgbStripWork = Uint8List(_maxStrip * 3);
  final Map<String, Float64List> _smooth = {};
  DateTime? _lastSmooth;
  bool _smoothPrimed = false;

  void ensureRgbStripCapacity(int maxLeds) {
    final need = math.max(maxLeds, 1) * 3;
    if (rgbStripWork.length < need) {
      rgbStripWork = Uint8List(need);
    }
  }

  void resetSmoothing() {
    _smooth.clear();
    _lastSmooth = null;
    _smoothPrimed = false;
  }

  /// `smoothMs` z `ScreenModeSettings.interpolation_ms` (EMA jako Python `AppState.interpolate_colors`).
  Map<String, List<(int, int, int)>> applyTemporalSmoothing({
    required Map<String, List<(int, int, int)>> targets,
    required int smoothMs,
  }) {
    if (smoothMs <= 0) {
      _syncSmoothFromTargets(targets);
      return targets;
    }

    final dtMs = consumeDtMs();
    var alpha = (dtMs / smoothMs).clamp(0.0, 1.0);
    if (alpha <= 0) alpha = 1.0;

    if (!_smoothPrimed) {
      _smoothPrimed = true;
      _syncSmoothFromTargets(targets);
      return _quantizeSmooth(targets.keys.toList());
    }

    for (final e in targets.entries) {
      final id = e.key;
      final tgt = e.value;
      var state = _smooth[id];
      final n3 = tgt.length * 3;
      if (state == null || state.length != n3) {
        state = Float64List(n3);
        _smooth[id] = state;
        for (var i = 0; i < tgt.length; i++) {
          state[i * 3] = tgt[i].$1.toDouble();
          state[i * 3 + 1] = tgt[i].$2.toDouble();
          state[i * 3 + 2] = tgt[i].$3.toDouble();
        }
      } else {
        for (var i = 0; i < tgt.length; i++) {
          final tr = tgt[i].$1.toDouble();
          final tg = tgt[i].$2.toDouble();
          final tb = tgt[i].$3.toDouble();
          final o = i * 3;
          state[o] += (tr - state[o]) * alpha;
          state[o + 1] += (tg - state[o + 1]) * alpha;
          state[o + 2] += (tb - state[o + 2]) * alpha;
        }
      }
    }

    return _quantizeSmooth(targets.keys.toList());
  }

  void _syncSmoothFromTargets(Map<String, List<(int, int, int)>> targets) {
    for (final e in targets.entries) {
      final tgt = e.value;
      final state = Float64List(tgt.length * 3);
      for (var i = 0; i < tgt.length; i++) {
        state[i * 3] = tgt[i].$1.toDouble();
        state[i * 3 + 1] = tgt[i].$2.toDouble();
        state[i * 3 + 2] = tgt[i].$3.toDouble();
      }
      _smooth[e.key] = state;
    }
  }

  Map<String, List<(int, int, int)>> _quantizeSmooth(List<String> keys) {
    final out = <String, List<(int, int, int)>>{};
    for (final id in keys) {
      final state = _smooth[id];
      if (state == null) continue;
      final n = state.length ~/ 3;
      final list = List<(int, int, int)>.generate(
        n,
        (i) => (
          state[i * 3].round().clamp(0, 255),
          state[i * 3 + 1].round().clamp(0, 255),
          state[i * 3 + 2].round().clamp(0, 255),
        ),
        growable: false,
      );
      out[id] = list;
    }
    return out;
  }

  double consumeDtMs() {
    final now = DateTime.now();
    if (_lastSmooth == null) {
      _lastSmooth = now;
      return 33.0;
    }
    final dt = now.difference(_lastSmooth!).inMicroseconds / 1000.0;
    _lastSmooth = now;
    if (dt <= 0.5 || dt > 500) return 33.0;
    return dt;
  }
}
