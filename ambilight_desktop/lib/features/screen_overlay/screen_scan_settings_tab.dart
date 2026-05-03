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

/// Sekce scan overlay + mini schéma + náhled snímku (vložit do [ScreenSettingsTab]).
class ScreenScanOverlaySection extends StatefulWidget {
  const ScreenScanOverlaySection({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onScreenModeChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<ScreenModeSettings> onScreenModeChanged;

  @override
  State<ScreenScanOverlaySection> createState() => _ScreenScanOverlaySectionState();
}

class _ScreenScanOverlaySectionState extends State<ScreenScanOverlaySection> {
  List<MonitorInfo> _monitors = const [];
  ui.Image? _thumb;
  int? _lastThumbKey;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonitors());
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

  Future<void> _decodeThumb(AmbilightAppController c) async {
    final f = c.latestScreenFrame;
    if (f == null || !f.isValid) {
      if (_thumb != null) {
        _thumb!.dispose();
        _thumb = null;
        _lastThumbKey = null;
      }
      return;
    }
    final key = Object.hash(f.width, f.height, f.rgba.length);
    if (key == _lastThumbKey && _thumb != null) return;
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
  }

  @override
  void dispose() {
    _thumb?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sm = widget.draft.screenMode;
    final innerMax = (widget.maxWidth * 0.92).clamp(280.0, 720.0);
    final scan = context.watch<ScanOverlayController>();
    final ctrl = context.watch<AmbilightAppController>();

    if (ctrl.config.globalSettings.startMode == 'screen') {
      unawaited(_decodeThumb(ctrl));
    }

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
          Text('Scan overlay (D-detail)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Zapni přepínač — aplikační okno se přesune na zvolený monitor v přesných '
            'rozměrech displeje (window_manager). Oblast snímání se počítá z reálné velikosti monitoru, '
            'ne z malého okna nastavení.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Zobrazit oblast snímání na monitoru'),
            subtitle: Text(scan.visualizeEnabled ? 'Aktivní — zavři „X“ nahoře v náhledu' : 'Vypnuto'),
            value: scan.visualizeEnabled,
            onChanged: (v) async {
              if (v) {
                await scan.show(sm, sm.monitorIndex);
              } else {
                await scan.hide();
              }
              if (context.mounted) setState(() {});
            },
          ),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: 'Monitor (MSS index, shodně s capture)',
              border: OutlineInputBorder(),
            ),
            value: _validMonitorValue(sm.monitorIndex),
            items: _monitors.isEmpty
                ? [
                    DropdownMenuItem(
                      value: sm.monitorIndex,
                      child: Text('Monitor ${sm.monitorIndex} (bez enumerace OS)'),
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
          const SizedBox(height: 16),
          Text('Hloubka snímání % (per-edge)', style: Theme.of(context).textTheme.titleSmall),
          _pctSlider(context, 'Horní', effTop(), (v) {
            widget.onScreenModeChanged(sm.copyWith(scanDepthTop: v.round()));
            _syncOverlayIfVisible(context);
          }),
          _pctSlider(context, 'Spodní', effBot(), (v) {
            widget.onScreenModeChanged(sm.copyWith(scanDepthBottom: v.round()));
            _syncOverlayIfVisible(context);
          }),
          _pctSlider(context, 'Levá', effLeft(), (v) {
            widget.onScreenModeChanged(sm.copyWith(scanDepthLeft: v.round()));
            _syncOverlayIfVisible(context);
          }),
          _pctSlider(context, 'Pravá', effRight(), (v) {
            widget.onScreenModeChanged(sm.copyWith(scanDepthRight: v.round()));
            _syncOverlayIfVisible(context);
          }),
          const SizedBox(height: 8),
          Text('Odsazení % (per-edge)', style: Theme.of(context).textTheme.titleSmall),
          _pctSlider(context, 'Horní', effPadT(), (v) {
            widget.onScreenModeChanged(sm.copyWith(paddingTop: v.round()));
            _syncOverlayIfVisible(context);
          }),
          _pctSlider(context, 'Spodní', effPadB(), (v) {
            widget.onScreenModeChanged(sm.copyWith(paddingBottom: v.round()));
            _syncOverlayIfVisible(context);
          }),
          _pctSlider(context, 'Levé', effPadL(), (v) {
            widget.onScreenModeChanged(sm.copyWith(paddingLeft: v.round()));
            _syncOverlayIfVisible(context);
          }),
          _pctSlider(context, 'Pravé', effPadR(), (v) {
            widget.onScreenModeChanged(sm.copyWith(paddingRight: v.round()));
            _syncOverlayIfVisible(context);
          }),
          const SizedBox(height: 16),
          Text('Schéma oblasti (poměr zvoleného monitoru)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AspectRatio(
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
          const SizedBox(height: 16),
          Text('Poslední snímek (screen režim)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: _thumb == null
                    ? Center(
                        child: Text(
                          ctrl.config.globalSettings.startMode != 'screen'
                              ? 'Zapni režim screen pro živý náhled.'
                              : 'Čekám na snímek…',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RawImage(image: _thumb, fit: BoxFit.contain),
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

  Widget _pctSlider(BuildContext context, String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${value.round()} %', style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: value.clamp(0, 100),
          max: 100,
          divisions: 100,
          label: '${value.round()}',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
