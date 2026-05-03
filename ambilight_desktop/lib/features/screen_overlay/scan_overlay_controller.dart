import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../core/models/config_models.dart';
import 'scan_overlay_window_ops.dart';
import 'scan_region_geometry.dart';

/// Řídí fullscreen náhled oblasti snímání (D-detail) + live parametry z draftu.
class ScanOverlayController extends ChangeNotifier {
  bool _visible = false;
  ScreenModeSettings _sm = const ScreenModeSettings();
  int _monitorMssIndex = 1;
  /// Rozměry monitoru z OS (logické px), pro výpočet oblastí 1:1 s reálným displejem.
  Size? _monitorLogicalSize;

  bool get visualizeEnabled => _visible;

  ScreenModeSettings get screenMode => _sm;

  int get monitorMssIndex => _monitorMssIndex;

  List<Rect> regionsForLayoutSize(Size sz) {
    final sm = _sm;
    final top = sm.scanDepthTop > 0 ? sm.scanDepthTop.toDouble() : sm.scanDepthPercent.toDouble();
    final bottom =
        sm.scanDepthBottom > 0 ? sm.scanDepthBottom.toDouble() : sm.scanDepthPercent.toDouble();
    final left =
        sm.scanDepthLeft > 0 ? sm.scanDepthLeft.toDouble() : sm.scanDepthPercent.toDouble();
    final right =
        sm.scanDepthRight > 0 ? sm.scanDepthRight.toDouble() : sm.scanDepthPercent.toDouble();
    final pt = sm.paddingTop > 0 ? sm.paddingTop.toDouble() : sm.paddingPercent.toDouble();
    final pb = sm.paddingBottom > 0 ? sm.paddingBottom.toDouble() : sm.paddingPercent.toDouble();
    final pl = sm.paddingLeft > 0 ? sm.paddingLeft.toDouble() : sm.paddingPercent.toDouble();
    final pr = sm.paddingRight > 0 ? sm.paddingRight.toDouble() : sm.paddingPercent.toDouble();

    final mw = _monitorLogicalSize?.width ?? sz.width;
    final mh = _monitorLogicalSize?.height ?? sz.height;
    final regions = ScanRegionGeometry.calculateRegions(
      monitorWidth: mw,
      monitorHeight: mh,
      depthTopPct: top,
      depthBottomPct: bottom,
      depthLeftPct: left,
      depthRightPct: right,
      padTopPct: pt,
      padBottomPct: pb,
      padLeftPct: pl,
      padRightPct: pr,
    );
    if (_monitorLogicalSize == null || mw <= 0 || mh <= 0) return regions;
    final sx = sz.width / mw;
    final sy = sz.height / mh;
    if ((sx - 1).abs() < 0.0001 && (sy - 1).abs() < 0.0001) return regions;
    return regions
        .map((r) => Rect.fromLTWH(r.left * sx, r.top * sy, r.width * sx, r.height * sy))
        .toList();
  }

  /// Live z náhledu / sliderů (bez zavírání overlay).
  void syncFromDraft(ScreenModeSettings sm, int monitorMssIndex) {
    _sm = sm;
    _monitorMssIndex = monitorMssIndex;
    if (_visible) {
      notifyListeners();
    }
  }

  Future<void> show(ScreenModeSettings sm, int monitorMssIndex) async {
    _sm = sm;
    _monitorMssIndex = monitorMssIndex;
    final frame = await scanOverlayDisplayRectForMonitor(_monitorMssIndex);
    _monitorLogicalSize = frame == null ? null : Size(frame.width, frame.height);
    if (frame != null) {
      await scanOverlayEnterFullscreenRegion(frame);
    }
    _visible = true;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> hide() async {
    if (!_visible) return;
    _visible = false;
    _monitorLogicalSize = null;
    notifyListeners();
    await scanOverlayRestoreWindow();
  }

  @override
  void dispose() {
    if (_visible) {
      _visible = false;
    }
    _monitorLogicalSize = null;
    unawaited(scanOverlayRestoreWindow());
    super.dispose();
  }
}
