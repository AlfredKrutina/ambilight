import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../../engine/screen/screen_color_pipeline.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/config_drag_slider.dart';
import 'led_strip_wizard_dialog.dart';
import 'wizard_dialog_shell.dart';

String _edgeLabel(AppLocalizations l10n, String edge) {
  switch (edge) {
    case 'top':
      return l10n.zoneEdgeTop;
    case 'bottom':
      return l10n.zoneEdgeBottom;
    case 'left':
      return l10n.zoneEdgeLeft;
    case 'right':
      return l10n.zoneEdgeRight;
    default:
      return edge;
  }
}

/// Průvodce úpravou geometrie segmentů vůči monitoru (hrana, pásmo podél hrany, reverse).
class SegmentGeometryWizardDialog extends StatefulWidget {
  const SegmentGeometryWizardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const SegmentGeometryWizardDialog());
  }

  @override
  State<SegmentGeometryWizardDialog> createState() => _SegmentGeometryWizardDialogState();
}

class _SegmentGeometryWizardDialogState extends State<SegmentGeometryWizardDialog> {
  static const _edgeCycle = ['top', 'right', 'bottom', 'left'];

  List<LedSegment> _segments = const [];
  int _selectedIndex = 0;
  bool _loaded = false;
  AmbilightAppController? _ambiForDispose;
  bool _acquiredHighFidelityPreview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ambiForDispose ??= context.read<AmbilightAppController>();
    if (!_acquiredHighFidelityPreview) {
      _acquiredHighFidelityPreview = true;
      _ambiForDispose!.acquireHighFidelityPreviewUi();
    }
    if (_loaded) return;
    _loaded = true;
    final ctrl = _ambiForDispose!;
    _segments = List<LedSegment>.from(ctrl.config.screenMode.segments);
    _selectedIndex = _segments.isEmpty ? 0 : _segments.length - 1;
  }

  @override
  void dispose() {
    _ambiForDispose?.releaseHighFidelityPreviewUi();
    super.dispose();
  }

  static bool _wholeEdge(LedSegment s) => s.pixelStart == 0 && s.pixelEnd == 0;

  static int _edgeSpanRef(LedSegment s) {
    switch (s.edge) {
      case 'top':
      case 'bottom':
        return math.max(1, s.refWidth > 0 ? s.refWidth : 1920);
      case 'left':
      case 'right':
      default:
        final rh = s.refHeight > 0 ? s.refHeight : 0;
        final rw = s.refWidth > 0 ? s.refWidth : 0;
        return math.max(1, rh > 0 ? rh : (rw > 0 ? rw : 1080));
    }
  }

  (int monW, int monH, bool liveLayout) _previewLayoutDims(AmbilightAppController ctrl, LedSegment s) {
    final fr = ctrl.latestScreenFrame;
    if (fr != null && fr.isValid && ScreenColorPipeline.segmentMatchesCaptureFrame(s, fr)) {
      return (fr.layoutW, fr.layoutH, true);
    }
    final rw = s.refWidth > 0 ? s.refWidth : 1920;
    final rh = s.refHeight > 0 ? s.refHeight : 1080;
    return (rw, rh, false);
  }

  void _applyRefFromCapture(int i) {
    final ctrl = context.read<AmbilightAppController>();
    final fr = ctrl.latestScreenFrame;
    if (fr == null || !fr.isValid) return;
    setState(() {
      _segments[i] = _segments[i].copyWith(
        refWidth: fr.layoutW,
        refHeight: fr.layoutH,
        monitorIdx: fr.monitorIndex,
      );
    });
  }

  void _rotateEdge(int i, int delta) {
    final s = _segments[i];
    final k = _edgeCycle.indexOf(s.edge);
    final idx = k < 0 ? 0 : k;
    final newEdge = _edgeCycle[(idx + delta) % 4];
    setState(() {
      _segments[i] = s.copyWith(edge: newEdge, pixelStart: 0, pixelEnd: 0);
    });
  }

  void _presetBand(int i, {required int start, required int end}) {
    final s = _segments[i];
    final span = _edgeSpanRef(s);
    var ps = start.clamp(0, span);
    var pe = end.clamp(0, span);
    if (pe <= ps) pe = math.min(span, ps + 1);
    setState(() => _segments[i] = s.copyWith(pixelStart: ps, pixelEnd: pe));
  }

  void _normalizeBandOrder(int i) {
    final s = _segments[i];
    if (_wholeEdge(s)) return;
    final span = _edgeSpanRef(s);
    var ps = s.pixelStart.clamp(0, span);
    var pe = s.pixelEnd.clamp(0, span);
    if (pe <= ps) pe = math.min(span, ps + 1);
    setState(() => _segments[i] = s.copyWith(pixelStart: ps, pixelEnd: pe));
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AmbilightAppController, AppConfig>(
      selector: (_, c) => c.config,
      builder: (context, _, __) {
        final ctrl = context.read<AmbilightAppController>();
        return ListenableBuilder(
          listenable: ctrl.previewFrameNotifier,
          builder: (context, _) {
            final l10n = context.l10n;
            final scheme = Theme.of(context).colorScheme;

            return WizardDialogShell(
          title: l10n.segGeomWizardTitle,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                await ctrl.applyConfigAndPersist(
                  ctrl.config.copyWith(screenMode: ctrl.config.screenMode.copyWith(segments: _segments)),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.segGeomWizardSaved)));
                }
              },
              child: Text(l10n.save),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.segGeomWizardIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (_segments.isEmpty) ...[
                Text(l10n.segGeomWizardEmpty, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    await LedStripWizardDialog.show(context);
                    if (!context.mounted) return;
                    final c = context.read<AmbilightAppController>();
                    setState(() {
                      _segments = List<LedSegment>.from(c.config.screenMode.segments);
                      _selectedIndex = _segments.isEmpty ? 0 : _segments.length - 1;
                    });
                  },
                  child: Text(l10n.segGeomWizardOpenMapping),
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    final draftCfg = ctrl.config.copyWith(
                      screenMode: ctrl.config.screenMode.copyWith(segments: _segments),
                    );
                    final warn = ScreenColorPipeline.screenSegmentCaptureWarnings(draftCfg);
                    if (warn.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: scheme.errorContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
                          title: Text(
                            l10n.screenSegmentMonitorMismatchBanner(warn.first.captureMonitorIndex),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                DropdownButtonFormField<int>(
                  value: _selectedIndex.clamp(0, _segments.length - 1),
                  decoration: InputDecoration(
                    labelText: l10n.segGeomWizardSegmentPicker,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (var i = 0; i < _segments.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${l10n.segGeomWizardSegmentLabel(i)} · ${_edgeLabel(l10n, _segments[i].edge)} · '
                          '${l10n.segGeomWizardLedRange(_segments[i].ledStart, _segments[i].ledEnd)}',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedIndex = v);
                  },
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final i = _selectedIndex.clamp(0, _segments.length - 1);
                    final s = _segments[i];
                    final span = _edgeSpanRef(s);
                    final (monW, monH, live) = _previewLayoutDims(ctrl, s);
                    final sm = ctrl.config.screenMode;
                    final roi = ScreenColorPipeline.segmentRoi(s, sm, monW, monH);
                    final fr = ctrl.latestScreenFrame;
                    final spatialRgb = (fr != null && fr.isValid)
                        ? ScreenColorPipeline.segmentSpatialRgbPreview(seg: s, sm: sm, frame: fr)
                        : const <(int, int, int)>[];
                    final gradientColors = spatialRgb.isEmpty
                        ? null
                        : spatialRgb
                            .map((t) => Color.fromARGB(255, t.$1, t.$2, t.$3))
                            .toList(growable: false);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          live ? l10n.segGeomWizardPreviewLive : l10n.segGeomWizardPreviewRef,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.segGeomWizardPreviewCaption,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.segGeomWizardGradientSubtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        RepaintBoundary(
                          child: _SegmentMonitorPreview(
                            roi: roi,
                            monW: monW,
                            monH: monH,
                            edge: s.edge,
                            edgeLabel: _edgeLabel(l10n, s.edge),
                            spatialGradient: gradientColors,
                            colorScheme: scheme,
                            noGradientHint: spatialRgb.isEmpty ? l10n.segGeomWizardGradientUnavailable : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: IconButton.filledTonal(
                                tooltip: l10n.segGeomWizardRotateCcwTooltip,
                                onPressed: () => _rotateEdge(i, -1),
                                icon: const Icon(Icons.rotate_left),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(label: Text(_edgeLabel(l10n, s.edge))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: IconButton.filledTonal(
                                tooltip: l10n.segGeomWizardRotateCwTooltip,
                                onPressed: () => _rotateEdge(i, 1),
                                icon: const Icon(Icons.rotate_right),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.segGeomWizardReverse),
                          value: s.reverse,
                          onChanged: (v) => setState(() => _segments[i] = s.copyWith(reverse: v)),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.segGeomWizardWholeEdge),
                          subtitle: Text(
                            l10n.segGeomWizardWholeEdgeSubtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          value: _wholeEdge(s),
                          onChanged: (v) {
                            setState(() {
                              if (v) {
                                _segments[i] = s.copyWith(pixelStart: 0, pixelEnd: 0);
                              } else {
                                _segments[i] = s.copyWith(pixelStart: 0, pixelEnd: span);
                              }
                            });
                          },
                        ),
                        if (!_wholeEdge(s)) ...[
                          Text(
                            l10n.segGeomWizardBandTitle,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _segments[i] = s.copyWith(pixelStart: 0, pixelEnd: 0)),
                                child: Text(l10n.segGeomWizardPresetFull),
                              ),
                              TextButton(
                                onPressed: () => _presetBand(i, start: 0, end: span ~/ 2),
                                child: Text(l10n.segGeomWizardPresetStartHalf),
                              ),
                              TextButton(
                                onPressed: () => _presetBand(i, start: span ~/ 2, end: span),
                                child: Text(l10n.segGeomWizardPresetEndHalf),
                              ),
                              TextButton(
                                onPressed: () {
                                  final a = span ~/ 3;
                                  final b = (2 * span) ~/ 3;
                                  _presetBand(i, start: a, end: b);
                                },
                                child: Text(l10n.segGeomWizardPresetCenterThird),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.zoneFieldPixelStart(s.pixelStart), style: Theme.of(context).textTheme.labelLarge),
                          ConfigDragSlider(
                            value: s.pixelStart.clamp(0, span).toDouble(),
                            min: 0,
                            max: span.toDouble(),
                            divisions: math.min(200, math.max(1, span)),
                            label: '${s.pixelStart}',
                            onChanged: (v) {
                              setState(() => _segments[i] = s.copyWith(pixelStart: v.round()));
                              _normalizeBandOrder(i);
                            },
                          ),
                          Text(l10n.zoneFieldPixelEnd(s.pixelEnd), style: Theme.of(context).textTheme.labelLarge),
                          ConfigDragSlider(
                            value: s.pixelEnd.clamp(0, span).toDouble(),
                            min: 0,
                            max: span.toDouble(),
                            divisions: math.min(200, math.max(1, span)),
                            label: '${s.pixelEnd}',
                            onChanged: (v) {
                              setState(() => _segments[i] = s.copyWith(pixelEnd: v.round()));
                              _normalizeBandOrder(i);
                            },
                          ),
                        ],
                        Text(l10n.segGeomWizardMonitorTitle, style: Theme.of(context).textTheme.labelLarge),
                        ConfigDragSlider(
                          value: s.monitorIdx.clamp(0, 32).toDouble(),
                          min: 0,
                          max: 32,
                          divisions: 32,
                          label: '${s.monitorIdx}',
                          onChanged: (v) => setState(() => _segments[i] = s.copyWith(monitorIdx: v.round())),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: (ctrl.latestScreenFrame?.isValid ?? false)
                              ? () => _applyRefFromCapture(i)
                              : null,
                          icon: const Icon(Icons.photo_size_select_large_outlined),
                          label: Text(l10n.segGeomWizardRefFromCapture),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.zoneFieldRefWidth(s.refWidth),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        ConfigDragSlider(
                          value: s.refWidth.clamp(0, 8192).toDouble(),
                          min: 0,
                          max: 8192,
                          divisions: 64,
                          label: '${s.refWidth}',
                          onChanged: (v) => setState(() => _segments[i] = s.copyWith(refWidth: v.round())),
                        ),
                        Text(
                          l10n.zoneFieldRefHeight(s.refHeight),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        ConfigDragSlider(
                          value: s.refHeight.clamp(0, 8192).toDouble(),
                          min: 0,
                          max: 8192,
                          divisions: 64,
                          label: '${s.refHeight}',
                          onChanged: (v) => setState(() => _segments[i] = s.copyWith(refHeight: v.round())),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
          },
        );
      },
    );
  }
}

class _SegmentMonitorPreview extends StatelessWidget {
  const _SegmentMonitorPreview({
    required this.roi,
    required this.monW,
    required this.monH,
    required this.edge,
    required this.edgeLabel,
    required this.spatialGradient,
    required this.colorScheme,
    this.noGradientHint,
  });

  final SegmentRoiRect roi;
  final int monW;
  final int monH;
  final String edge;
  final String edgeLabel;
  final List<Color>? spatialGradient;
  final ColorScheme colorScheme;
  final String? noGradientHint;

  (Alignment, Alignment) _gradientAlignments() {
    switch (edge) {
      case 'left':
      case 'right':
        return (Alignment.topCenter, Alignment.bottomCenter);
      case 'top':
      case 'bottom':
      default:
        return (Alignment.centerLeft, Alignment.centerRight);
    }
  }

  BoxDecoration _roiFillDecoration() {
    final g = spatialGradient;
    if (g != null && g.length >= 2) {
      final al = _gradientAlignments();
      return BoxDecoration(
        gradient: LinearGradient(begin: al.$1, end: al.$2, colors: g),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.85), width: 2),
        borderRadius: BorderRadius.circular(4),
      );
    }
    if (g != null && g.length == 1) {
      return BoxDecoration(
        color: g.single,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.9), width: 2),
        borderRadius: BorderRadius.circular(4),
      );
    }
    return BoxDecoration(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.55), width: 2),
      borderRadius: BorderRadius.circular(4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aspect = monW / math.max(1, monH);
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          if (monW < 1 || monH < 1 || roi.isEmpty) {
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '—',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            );
          }
          final nx = roi.x / monW;
          final ny = roi.y / monH;
          final nw = roi.w / monW;
          final nh = roi.h / monH;
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: nx * w,
                    top: ny * h,
                    width: nw * w,
                    height: nh * h,
                    child: Builder(
                      builder: (context) {
                        final grad = spatialGradient;
                        return Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            DecoratedBox(decoration: _roiFillDecoration()),
                            if (grad != null && grad.length >= 8)
                              CustomPaint(
                                painter: _LedTickPainter(
                                  count: grad.length,
                                  edge: edge,
                                  lineColor: colorScheme.onSurface.withValues(alpha: 0.22),
                                ),
                              ),
                            if (noGradientHint != null)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    noGradientHint!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurface.withValues(alpha: 0.75),
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Text(
                      edgeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Jemné oddělení „LED“ ve výraznějším gradientu (volitelná vizuální vodítka).
class _LedTickPainter extends CustomPainter {
  _LedTickPainter({required this.count, required this.edge, required this.lineColor});

  final int count;
  final String edge;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final n = count - 1;
    switch (edge) {
      case 'left':
      case 'right':
        for (var i = 1; i < n; i++) {
          final y = size.height * i / n;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
        break;
      case 'top':
      case 'bottom':
      default:
        for (var i = 1; i < n; i++) {
          final x = size.width * i / n;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LedTickPainter oldDelegate) {
    return oldDelegate.count != count || oldDelegate.edge != edge || oldDelegate.lineColor != lineColor;
  }
}
