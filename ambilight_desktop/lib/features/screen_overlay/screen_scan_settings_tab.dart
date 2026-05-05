import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../screen_capture/screen_capture.dart';
import 'scan_overlay_controller.dart';
import 'scan_overlay_painter.dart';
import 'scan_region_geometry.dart';
import '../../ui/widgets/config_drag_slider.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';

/// Sekce scan overlay + mini schéma + náhled snímku (vložit do [ScreenSettingsTab]).
class ScreenScanOverlaySection extends StatefulWidget {
  const ScreenScanOverlaySection({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onScreenModeChanged,
    required this.advancedScanLayout,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<ScreenModeSettings> onScreenModeChanged;
  /// `scan_mode == advanced` — per‑hrana slidery; v simple jen schéma + monitor.
  final bool advancedScanLayout;

  @override
  State<ScreenScanOverlaySection> createState() => _ScreenScanOverlaySectionState();
}

class _ScreenScanOverlaySectionState extends State<ScreenScanOverlaySection> {
  List<MonitorInfo> _monitors = const [];
  ui.Image? _thumb;
  int? _lastThumbKey;
  AmbilightAppController? _ambi;
  bool _ambiListenerAttached = false;
  Timer? _thumbDebounce;
  bool _thumbDecodeInFlight = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonitors());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _ambi ?? context.read<AmbilightAppController>();
      if (c.config.globalSettings.startMode == 'screen') {
        unawaited(_decodeThumb(c));
      }
    });
  }

  static String _overlaySig(ScreenModeSettings sm) =>
      '${sm.monitorIndex}|${sm.scanDepthTop}|${sm.scanDepthBottom}|${sm.scanDepthLeft}|${sm.scanDepthRight}|'
      '${sm.paddingTop}|${sm.paddingBottom}|${sm.paddingLeft}|${sm.paddingRight}|'
      '${sm.scanDepthPercent}|${sm.paddingPercent}';

  @override
  void didUpdateWidget(covariant ScreenScanOverlaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlaySig(widget.draft.screenMode) != _overlaySig(oldWidget.draft.screenMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncOverlayIfVisible(context);
      });
    }
    final wasScreen = oldWidget.draft.globalSettings.startMode == 'screen';
    final isScreen = widget.draft.globalSettings.startMode == 'screen';
    if (isScreen && !wasScreen) {
      unawaited(_decodeThumb(_ambi ?? context.read<AmbilightAppController>()));
    }
    if (!isScreen && wasScreen) {
      _thumbDebounce?.cancel();
      if (_thumb != null) {
        setState(() {
          _thumb!.dispose();
          _thumb = null;
          _lastThumbKey = null;
        });
      }
    }
  }

  Future<void> _loadMonitors() async {
    final list = await ScreenCaptureSource.platform().listMonitors();
    if (!mounted) return;
    setState(() => _monitors = list);
  }

  void _syncOverlayIfVisible(BuildContext context) {
    final scan = context.read<ScanOverlayController>();
    if (scan.visualizeEnabled) {
      scan.syncFromDraft(widget.draft.screenMode, widget.draft.screenMode.monitorIndex);
    }
  }

  void _onScanSliderLive(BuildContext context, ScreenModeSettings nextSm) {
    unawaited(
      context.read<ScanOverlayController>().ensureShownForLivePreview(
            nextSm,
            nextSm.monitorIndex,
          ),
    );
  }

  void _onScanSliderRelease(BuildContext context) {
    context.read<ScanOverlayController>().scheduleAutoHideAfterSliderRelease();
  }

  void _onAmbiControllerChanged() {
    if (!mounted) return;
    final c = _ambi;
    if (c == null) return;
    if (c.config.globalSettings.startMode != 'screen') return;
    // Debounce: při tažení posuvníku přeneseme poslední snímek krátce po ustání updatů (řidší než každý tick engine).
    _thumbDebounce?.cancel();
    _thumbDebounce = Timer(const Duration(milliseconds: 100), () {
      _thumbDebounce = null;
      if (!mounted) return;
      unawaited(_decodeThumb(_ambi ?? context.read<AmbilightAppController>()));
    });
  }

  Future<void> _decodeThumb(AmbilightAppController c) async {
    final f = c.latestScreenFrame;
    if (f == null || !f.isValid) {
      if (_thumb != null && mounted) {
        setState(() {
          _thumb!.dispose();
          _thumb = null;
          _lastThumbKey = null;
        });
      } else if (_thumb != null) {
        _thumb!.dispose();
        _thumb = null;
        _lastThumbKey = null;
      }
      return;
    }
    final key = Object.hash(f.width, f.height, f.rgba.length);
    if (key == _lastThumbKey && _thumb != null) return;

    if (_thumbDecodeInFlight) return;
    _thumbDecodeInFlight = true;
    try {
      _lastThumbKey = key;
      final cpl = Completer<ui.Image?>();
      try {
        ui.decodeImageFromPixels(
          f.rgba,
          f.width,
          f.height,
          ui.PixelFormat.rgba8888,
          (img) {
            if (!cpl.isCompleted) cpl.complete(img);
          },
        );
      } catch (_) {
        if (!cpl.isCompleted) cpl.complete(null);
      }
      final img = await cpl.future.timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      if (!mounted) return;
      setState(() {
        _thumb?.dispose();
        _thumb = img;
      });
    } finally {
      _thumbDecodeInFlight = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ambiListenerAttached) {
      _ambiListenerAttached = true;
      _ambi = context.read<AmbilightAppController>();
      _ambi!.previewFrameNotifier.addListener(_onAmbiControllerChanged);
    }
  }

  @override
  void dispose() {
    _thumbDebounce?.cancel();
    _ambi?.previewFrameNotifier.removeListener(_onAmbiControllerChanged);
    _thumb?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hidePreviewAfterSec = ScanOverlayController.autoHideAfterSliderRelease.inSeconds;
    final sm = widget.draft.screenMode;
    final innerMax = (widget.maxWidth * 0.92).clamp(280.0, 720.0);
    final previewArmed = context.select<ScanOverlayController, bool>((s) => s.monitorPreviewArmed);
    final overlayVisible = context.select<ScanOverlayController, bool>((s) => s.visualizeEnabled);
    final startMode = widget.draft.globalSettings.startMode;

    double effTop() => sm.scanDepthTop > 0 ? sm.scanDepthTop.toDouble() : sm.scanDepthPercent.toDouble();
    double effBot() =>
        sm.scanDepthBottom > 0 ? sm.scanDepthBottom.toDouble() : sm.scanDepthPercent.toDouble();
    double effLeft() =>
        sm.scanDepthLeft > 0 ? sm.scanDepthLeft.toDouble() : sm.scanDepthPercent.toDouble();
    double effRight() =>
        sm.scanDepthRight > 0 ? sm.scanDepthRight.toDouble() : sm.scanDepthPercent.toDouble();
    double effPadT() => sm.paddingTop > 0 ? sm.paddingTop.toDouble() : sm.paddingPercent.toDouble();
    double effPadB() =>
        sm.paddingBottom > 0 ? sm.paddingBottom.toDouble() : sm.paddingPercent.toDouble();
    double effPadL() => sm.paddingLeft > 0 ? sm.paddingLeft.toDouble() : sm.paddingPercent.toDouble();
    double effPadR() =>
        sm.paddingRight > 0 ? sm.paddingRight.toDouble() : sm.paddingPercent.toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: innerMax),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 32),
          Text(l10n.scanOverlayTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l10n.scanOverlayIntro(hidePreviewAfterSec),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(l10n.scanPreviewMonitorTitle),
            subtitle: Text(
              !previewArmed
                  ? l10n.scanPreviewOff
                  : overlayVisible
                      ? l10n.scanPreviewVisible(hidePreviewAfterSec)
                      : l10n.scanPreviewOnDragging,
            ),
            value: previewArmed,
            onChanged: (v) async {
              await context.read<ScanOverlayController>().setMonitorPreviewArmed(v);
              if (context.mounted) setState(() {});
            },
          ),
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: l10n.fieldMonitorMssSameAsCapture,
              border: const OutlineInputBorder(),
            ),
            value: _validMonitorValue(sm.monitorIndex),
            items: _monitors.isEmpty
                ? [
                    DropdownMenuItem(
                      value: sm.monitorIndex,
                      child: Text(l10n.scanMonitorNoEnum(sm.monitorIndex)),
                    ),
                  ]
                : _monitors
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.mssStyleIndex,
                        child: Text(
                          '${m.mssStyleIndex}: ${m.width}×${m.height} @ (${m.left},${m.top})${m.isPrimary ? ' ★' : ''}',
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              if (v == null) return;
              widget.onScreenModeChanged(sm.copyWith(monitorIndex: v));
              _syncOverlayIfVisible(context);
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: !previewArmed
                ? null
                : () async {
                    final scan = context.read<ScanOverlayController>();
                    await scan.showPreviewNow(sm, sm.monitorIndex);
                    if (context.mounted) setState(() {});
                  },
            icon: const Icon(Icons.preview_outlined, size: 18),
            label: Text(l10n.scanPreviewNowButton),
          ),
          const SizedBox(height: 16),
          if (widget.advancedScanLayout) ...[
          Text(l10n.scanDepthPerEdge, style: Theme.of(context).textTheme.titleSmall),
          _pctSlider(
            context,
            l10n,
            l10n.scanEdgeTop,
            effTop(),
            (v) {
              final next = sm.copyWith(scanDepthTop: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          _pctSlider(
            context,
            l10n,
            l10n.scanEdgeBottom,
            effBot(),
            (v) {
              final next = sm.copyWith(scanDepthBottom: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          _pctSlider(
            context,
            l10n,
            l10n.scanEdgeLeft,
            effLeft(),
            (v) {
              final next = sm.copyWith(scanDepthLeft: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          _pctSlider(
            context,
            l10n,
            l10n.scanEdgeRight,
            effRight(),
            (v) {
              final next = sm.copyWith(scanDepthRight: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          const SizedBox(height: 8),
          Text(l10n.scanPaddingPerEdge, style: Theme.of(context).textTheme.titleSmall),
          _pctSlider(
            context,
            l10n,
            l10n.scanEdgeTop,
            effPadT(),
            (v) {
              final next = sm.copyWith(paddingTop: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          _pctSlider(
            context,
            l10n,
            l10n.scanEdgeBottom,
            effPadB(),
            (v) {
              final next = sm.copyWith(paddingBottom: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          _pctSlider(
            context,
            l10n,
            l10n.scanPadLeft,
            effPadL(),
            (v) {
              final next = sm.copyWith(paddingLeft: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          _pctSlider(
            context,
            l10n,
            l10n.scanPadRight,
            effPadR(),
            (v) {
              final next = sm.copyWith(paddingRight: v.round());
              widget.onScreenModeChanged(next);
              _onScanSliderLive(context, next);
            },
            onChangeEnd: () => _onScanSliderRelease(context),
          ),
          ] else ...[
            Text(
              l10n.scanSimpleModeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          Text(l10n.scanDiagramTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: AspectRatio(
              aspectRatio: _monitorAspectRatio(sm.monitorIndex),
              child: LayoutBuilder(
                builder: (context, c) {
                  final sz = Size(c.maxWidth, c.maxHeight);
                  final regions = ScanRegionGeometry.calculateRegions(
                    monitorWidth: sz.width,
                    monitorHeight: sz.height,
                    depthTopPct: effTop(),
                    depthBottomPct: effBot(),
                    depthLeftPct: effLeft(),
                    depthRightPct: effRight(),
                    padTopPct: effPadT(),
                    padBottomPct: effPadB(),
                    padLeftPct: effPadL(),
                    padRightPct: effPadR(),
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: ScanOverlayPainter(regions: regions),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.scanLastFrameTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          RepaintBoundary(
            child: SizedBox(
              height: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: _thumb == null
                      ? Center(
                          child: Text(
                            startMode != 'screen'
                                ? l10n.scanThumbNeedScreenMode
                                : l10n.scanThumbWaiting,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : RawImage(image: _thumb, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _validMonitorValue(int wanted) {
    if (_monitors.isEmpty) return wanted;
    final ids = _monitors.map((e) => e.mssStyleIndex).toSet();
    if (ids.contains(wanted)) return wanted;
    return _monitors.first.mssStyleIndex;
  }

  /// Poměr stran náhledu v nastavení — odpovídá vybranému monitoru, ne fixnímu 16∶9.
  double _monitorAspectRatio(int monitorIndex) {
    MonitorInfo? hit;
    for (final m in _monitors) {
      if (m.mssStyleIndex == monitorIndex) {
        hit = m;
        break;
      }
    }
    if (hit == null || hit.height <= 0) return 16 / 9;
    final a = hit.width / hit.height;
    if (a.isNaN || a <= 0) return 16 / 9;
    return a.clamp(0.35, 3.5);
  }

  Widget _pctSlider(
    BuildContext context,
    AppLocalizations l10n,
    String edgeLabel,
    double value,
    ValueChanged<double> onChanged, {
    VoidCallback? onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.scanPctLabel(edgeLabel, value.round()), style: Theme.of(context).textTheme.labelLarge),
        ConfigDragSlider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          label: '${value.round()}',
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
