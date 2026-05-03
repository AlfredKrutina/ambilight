import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/models/config_models.dart';
import 'scan_overlay_window_ops.dart';
import 'scan_region_geometry.dart';

/// Náhled zón skenu jako vrstva nad UI aplikace — okno se **nepřesouvá** na celý monitor.
///
/// [monitorPreviewArmed] = přepínač v Nastavení; náhled při tažení slideru
/// a po [Slider.onChangeEnd] skrytí po [autoHideAfterSliderRelease].
class ScanOverlayController extends ChangeNotifier {
  static const Duration autoHideAfterSliderRelease = Duration(seconds: 1);

  bool _visible = false;
  bool _monitorPreviewArmed = true;
  ScreenModeSettings _sm = const ScreenModeSettings();
  int _monitorMssIndex = 1;
  Size? _monitorLogicalSize;
  Timer? _autoHideTimer;
  Future<void>? _ongoingShow;

  bool get visualizeEnabled => _visible;

  bool get monitorPreviewArmed => _monitorPreviewArmed;

  ScreenModeSettings get screenMode => _sm;

  int get monitorMssIndex => _monitorMssIndex;

  bool _escapeHandler(KeyEvent event) {
    if (!_visible) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    cancelAutoHideTimer();
    unawaited(hide());
    return true;
  }

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void cancelAutoHideTimer() => _cancelAutoHideTimer();

  void scheduleAutoHideAfterSliderRelease() {
    if (!_monitorPreviewArmed || !_visible) return;
    _cancelAutoHideTimer();
    _autoHideTimer = Timer(autoHideAfterSliderRelease, () {
      _autoHideTimer = null;
      unawaited(hide());
    });
  }

  Future<void> ensureShownForLivePreview(ScreenModeSettings sm, int monitorMssIndex) async {
    if (!_monitorPreviewArmed) return;
    _sm = sm;
    _monitorMssIndex = monitorMssIndex;
    _cancelAutoHideTimer();
    if (_visible) {
      syncFromDraft(sm, monitorMssIndex);
      return;
    }
    while (_ongoingShow != null) {
      await _ongoingShow;
      if (_visible) {
        syncFromDraft(sm, monitorMssIndex);
        return;
      }
    }
    final f = show(sm, monitorMssIndex);
    _ongoingShow = f;
    try {
      await f;
    } finally {
      if (identical(_ongoingShow, f)) {
        _ongoingShow = null;
      }
    }
  }

  Future<void> setMonitorPreviewArmed(bool v) async {
    if (_monitorPreviewArmed == v) return;
    _monitorPreviewArmed = v;
    if (!v) {
      _cancelAutoHideTimer();
      await hide();
    }
    notifyListeners();
  }

  /// Stejný náhled jako při slideru (v okně aplikace, jen pruhy skenu) + odpočet skrytí.
  Future<void> showPreviewNow(ScreenModeSettings sm, int monitorMssIndex) async {
    if (!_monitorPreviewArmed) return;
    await show(sm, monitorMssIndex);
    scheduleAutoHideAfterSliderRelease();
  }

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
    final s = sx < sy ? sx : sy;
    final ox = (sz.width - mw * s) / 2.0;
    final oy = (sz.height - mh * s) / 2.0;
    if (s <= 0) return regions;
    if ((s - 1).abs() < 1e-5 && ox.abs() < 1e-3 && oy.abs() < 1e-3) return regions;
    return regions
        .map(
          (r) => Rect.fromLTWH(
            r.left * s + ox,
            r.top * s + oy,
            r.width * s,
            r.height * s,
          ),
        )
        .toList();
  }

  void syncFromDraft(ScreenModeSettings sm, int monitorMssIndex) {
    _sm = sm;
    _monitorMssIndex = monitorMssIndex;
    if (_visible) {
      notifyListeners();
    }
  }

  Future<void> show(ScreenModeSettings sm, int monitorMssIndex) async {
    _cancelAutoHideTimer();
    _sm = sm;
    _monitorMssIndex = monitorMssIndex;
    final frame = await scanOverlayDisplayRectForMonitor(_monitorMssIndex);
    _monitorLogicalSize = frame == null ? null : Size(frame.width, frame.height);
    await scanOverlayEnsureFlutterReceivesPointer();

    if (!_visible) {
      HardwareKeyboard.instance.addHandler(_escapeHandler);
    }
    _visible = true;
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
      unawaited(scanOverlayEnsureFlutterReceivesPointer());
    });
  }

  Future<void> hide() async {
    if (!_visible) return;
    _cancelAutoHideTimer();
    HardwareKeyboard.instance.removeHandler(_escapeHandler);
    try {
      await scanOverlayRestoreWindow();
    } finally {
      _visible = false;
      _monitorLogicalSize = null;
      notifyListeners();
      unawaited(scanOverlayEnsureFlutterReceivesPointer());
    }
  }

  @override
  void dispose() {
    _cancelAutoHideTimer();
    HardwareKeyboard.instance.removeHandler(_escapeHandler);
    if (_visible) {
      _visible = false;
    }
    _monitorLogicalSize = null;
    unawaited(scanOverlayRestoreWindow());
    super.dispose();
  }
}
