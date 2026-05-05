import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Výběr RGB ve stylu Home / Hue: velký náhled, duhový pruh odstínu, pole sytost–jas, předvolby.
Future<List<int>?> showAmbiColorPickerDialog(
  BuildContext context, {
  required List<int> initialRgb,
  String title = 'Barva',
  ValueChanged<List<int>>? onLiveRgb,
}) {
  return showDialog<List<int>>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _AmbiColorPickerDialog(
      title: title,
      initialRgb: initialRgb,
      onLiveRgb: onLiveRgb,
    ),
  );
}

List<int> _rgbFromColor(Color c) {
  return [c.red, c.green, c.blue];
}

class _AmbiColorPickerDialog extends StatefulWidget {
  const _AmbiColorPickerDialog({
    required this.title,
    required this.initialRgb,
    this.onLiveRgb,
  });

  final String title;
  final List<int> initialRgb;
  final ValueChanged<List<int>>? onLiveRgb;

  @override
  State<_AmbiColorPickerDialog> createState() => _AmbiColorPickerDialogState();
}

class _AmbiColorPickerDialogState extends State<_AmbiColorPickerDialog> {
  static const _presets = <List<int>>[
    [255, 255, 255],
    [255, 250, 240],
    [255, 220, 180],
    [255, 160, 60],
    [255, 60, 40],
    [255, 0, 128],
    [180, 60, 255],
    [80, 120, 255],
    [0, 200, 255],
    [0, 220, 140],
    [120, 255, 80],
    [255, 255, 0],
    [40, 40, 45],
    [0, 0, 0],
  ];

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRgb.isNotEmpty ? widget.initialRgb[0].clamp(0, 255) : 255;
    final g = widget.initialRgb.length > 1 ? widget.initialRgb[1].clamp(0, 255) : 255;
    final b = widget.initialRgb.length > 2 ? widget.initialRgb[2].clamp(0, 255) : 255;
    _hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitLive());
  }

  void _emitLive() {
    final rgb = _rgbFromColor(_hsv.toColor());
    widget.onLiveRgb?.call(rgb);
  }

  void _setHueFromDx(double dx, double width) {
    final t = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _hsv = _hsv.withHue(t * 360.0);
    });
    _emitLive();
  }

  void _setSv(Offset local, Size size) {
    final sat = (local.dx / size.width).clamp(0.0, 1.0);
    final val = (1.0 - local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _hsv = _hsv.withSaturation(sat).withValue(val);
    });
    _emitLive();
  }

  void _applyPreset(List<int> p) {
    final c = Color.fromARGB(255, p[0].clamp(0, 255), p[1].clamp(0, 255), p[2].clamp(0, 255));
    setState(() => _hsv = HSVColor.fromColor(c));
    _emitLive();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rgb = _rgbFromColor(_hsv.toColor());
    final hex =
        '#${rgb[0].toRadixString(16).padLeft(2, '0')}${rgb[1].toRadixString(16).padLeft(2, '0')}${rgb[2].toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();

    final viewH = MediaQuery.sizeOf(context).height;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final maxDialogH = ((viewH - kb) * 0.88).clamp(280.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxDialogH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _hsv.toColor().withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: _hsv.toColor(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(hex, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
              Text('RGB ${rgb.join(' · ')}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 18),
              Text('Odstín', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, cons) {
                  final w = cons.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (e) => _setHueFromDx(e.localPosition.dx, w),
                    onPanUpdate: (e) => _setHueFromDx(e.localPosition.dx, w),
                    child: SizedBox(
                      height: 40,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                /* Stejné pořadí jako [HSVColor.hue] 0→360: červená vlevo, pak OYGCBM a znovu červená. */
                                colors: [
                                  for (var h = 0.0; h < 360.0; h += 60.0)
                                    HSVColor.fromAHSV(1, h, 1, 1).toColor(),
                                  HSVColor.fromAHSV(1, 0, 1, 1).toColor(),
                                ],
                              ),
                              border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
                            ),
                            child: const SizedBox.expand(),
                          ),
                          Positioned(
                            left: (_hsv.hue / 360.0) * w - 11,
                            top: 2,
                            child: IgnorePointer(
                              child: Container(
                                width: 22,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Sytost a jas', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              AspectRatio(
                aspectRatio: 1.25,
                child: LayoutBuilder(
                  builder: (context, cons) {
                    final sz = Size(cons.maxWidth, cons.maxHeight);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _SvPlanePainter(hue: _hsv.hue)),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanDown: (e) => _setSv(e.localPosition, sz),
                            onPanUpdate: (e) => _setSv(e.localPosition, sz),
                            child: const SizedBox.expand(),
                          ),
                          Positioned(
                            left: _hsv.saturation * sz.width - 12,
                            top: (1.0 - _hsv.value) * sz.height - 12,
                            child: IgnorePointer(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text('Předvolby', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in _presets)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _applyPreset(p),
                        customBorder: const CircleBorder(),
                        child: Ink(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromARGB(255, p[0], p[1], p[2]),
                            border: Border.all(
                              color: scheme.outline.withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Zrušit'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, rgb),
                    child: const Text('Hotovo'),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SvPlanePainter extends CustomPainter {
  _SvPlanePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 3.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        final sat = (x / size.width).clamp(0.0, 1.0);
        final val = (1.0 - y / size.height).clamp(0.0, 1.0);
        final c = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
        final rect = Rect.fromLTWH(x, y, math.min(step + 0.5, size.width - x), math.min(step + 0.5, size.height - y));
        canvas.drawRect(rect, Paint()..color = c);
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000),
    );
  }

  @override
  bool shouldRepaint(covariant _SvPlanePainter oldDelegate) => oldDelegate.hue != hue;
}
