import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models/config_models.dart';
import '../../engine/screen/screen_color_pipeline.dart';
import '../../engine/screen/screen_frame.dart';
import 'screen_capture_source.dart';

/// Virtuální obdélník výřezu pro nativní stream (desktop souřadnice).
class ScreenCaptureStreamCrop {
  const ScreenCaptureStreamCrop({
    required this.cropLeft,
    required this.cropTop,
    required this.cropWidth,
    required this.cropHeight,
    required this.layoutWidth,
    required this.layoutHeight,
  });

  final int cropLeft;
  final int cropTop;
  final int cropWidth;
  final int cropHeight;
  final int layoutWidth;
  final int layoutHeight;

  Map<String, Object?> toStreamArguments() => <String, Object?>{
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropWidth': cropWidth,
        'cropHeight': cropHeight,
        'layoutWidth': layoutWidth,
        'layoutHeight': layoutHeight,
      };
}

/// Spojení ROI všech segmentů na zvoleném monitoru → menší BitBlt/DXGI copy.
///
/// Pro [monitorIndex] <= 0 nebo chybějící [MonitorInfo] vrací `null` (plný snímek).
ScreenCaptureStreamCrop? computeStreamCropUnion(
  AppConfig config,
  List<MonitorInfo> monitors,
) {
  final monIdx = config.screenMode.monitorIndex;
  if (monIdx <= 0) {
    return null;
  }
  MonitorInfo? mon;
  for (final m in monitors) {
    if (m.mssStyleIndex == monIdx) {
      mon = m;
      break;
    }
  }
  if (mon == null) {
    return null;
  }
  final mw = mon.width;
  final mh = mon.height;
  if (mw < 1 || mh < 1) {
    return null;
  }
  final sm = config.screenMode;
  final segs = ScreenColorPipeline.effectiveScreenSegments(config);
  final pseudo = ScreenFrame(
    monitorIndex: monIdx,
    width: mw,
    height: mh,
    rgba: Uint8List(0),
  );
  int? minX;
  int? minY;
  int? maxX;
  int? maxY;
  for (final seg in segs) {
    if (!ScreenColorPipeline.segmentMatchesCaptureFrame(seg, pseudo)) {
      continue;
    }
    final roi = ScreenColorPipeline.segmentRoi(seg, sm, mw, mh);
    if (roi.isEmpty) {
      continue;
    }
    if (minX == null) {
      minX = roi.x;
    } else {
      minX = math.min(minX, roi.x);
    }
    if (minY == null) {
      minY = roi.y;
    } else {
      minY = math.min(minY, roi.y);
    }
    if (maxX == null) {
      maxX = roi.x + roi.w;
    } else {
      maxX = math.max(maxX, roi.x + roi.w);
    }
    if (maxY == null) {
      maxY = roi.y + roi.h;
    } else {
      maxY = math.max(maxY, roi.y + roi.h);
    }
  }
  if (minX == null || minY == null || maxX == null || maxY == null) {
    return null;
  }
  final ax = minX;
  final ay = minY;
  final bx = maxX;
  final by = maxY;
  const margin = 2;
  var x0 = (ax - margin).clamp(0, mw - 1);
  var y0 = (ay - margin).clamp(0, mh - 1);
  var x1 = (bx + margin).clamp(0, mw);
  var y1 = (by + margin).clamp(0, mh);
  if (x1 <= x0) {
    x1 = math.min(mw, x0 + 1);
  }
  if (y1 <= y0) {
    y1 = math.min(mh, y0 + 1);
  }
  final cw = x1 - x0;
  final ch = y1 - y0;
  if (cw < 1 || ch < 1) {
    return null;
  }
  return ScreenCaptureStreamCrop(
    cropLeft: mon.left + x0,
    cropTop: mon.top + y0,
    cropWidth: cw,
    cropHeight: ch,
    layoutWidth: mw,
    layoutHeight: mh,
  );
}
