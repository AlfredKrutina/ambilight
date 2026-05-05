import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/smart_lights_models.dart';
import '../../../features/smart_lights/virtual_room_effects.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Plánek místnosti: TV, uživatel, směr pohledu, tažná světla a parametry efektů + živý náhled.
class VirtualRoomEditor extends StatefulWidget {
  const VirtualRoomEditor({
    super.key,
    required this.sl,
    required this.onChanged,
  });

  final SmartLightsSettings sl;
  final ValueChanged<SmartLightsSettings> onChanged;

  static const double roomPaintHeight = 248;

  /// Rozměr náhledové žárovky včetně záře — musí sedět s offsetem v [_fixtureMarkers].
  static const double previewLampExtent = 56;

  @override
  State<VirtualRoomEditor> createState() => _VirtualRoomEditorState();
}

class _VirtualRoomEditorState extends State<VirtualRoomEditor> with SingleTickerProviderStateMixin {
  late final AnimationController _previewTick;
  bool _previewAnimated = true;

  @override
  void initState() {
    super.initState();
    _previewTick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 48),
    )..repeat();
  }

  @override
  void dispose() {
    _previewTick.dispose();
    super.dispose();
  }

  SmartLightsSettings get sl => widget.sl;

  void _patch(SmartLightsSettings next) => widget.onChanged(next);

  String _effectLabel(AppLocalizations loc, SmartRoomEffectKind k) => switch (k) {
        SmartRoomEffectKind.none => loc.virtualRoomEffectNone,
        SmartRoomEffectKind.wave => loc.virtualRoomEffectWave,
        SmartRoomEffectKind.breath => loc.virtualRoomEffectBreath,
        SmartRoomEffectKind.chase => loc.virtualRoomEffectChase,
        SmartRoomEffectKind.sparkle => loc.virtualRoomEffectSparkle,
      };

  String _effectHint(AppLocalizations loc, SmartRoomEffectKind k) => switch (k) {
        SmartRoomEffectKind.none => loc.virtualRoomEffectHintNone,
        SmartRoomEffectKind.wave => loc.virtualRoomEffectHintWave,
        SmartRoomEffectKind.breath => loc.virtualRoomEffectHintBreath,
        SmartRoomEffectKind.chase => loc.virtualRoomEffectHintChase,
        SmartRoomEffectKind.sparkle => loc.virtualRoomEffectHintSparkle,
      };

  String _geometryLabel(AppLocalizations loc, SmartRoomWaveGeometry g) => switch (g) {
        SmartRoomWaveGeometry.radialFromTv => loc.virtualRoomGeometryRadial,
        SmartRoomWaveGeometry.alongUserView => loc.virtualRoomGeometryAlongView,
        SmartRoomWaveGeometry.horizontalRoom => loc.virtualRoomGeometryHorizontal,
        SmartRoomWaveGeometry.verticalRoom => loc.virtualRoomGeometryVertical,
        SmartRoomWaveGeometry.customAngle => loc.virtualRoomGeometryCustom,
      };

  @override
  Widget build(BuildContext context) {
    final vr = sl.virtualRoom;
    final scheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final showSpatial = vr.roomEffect == SmartRoomEffectKind.wave ||
        vr.roomEffect == SmartRoomEffectKind.chase ||
        vr.roomEffect == SmartRoomEffectKind.sparkle;
    final showDistance = showSpatial;
    final chaseRanks =
        vr.roomEffect == SmartRoomEffectKind.chase ? VirtualRoomEffects.chaseRanks(room: vr, fixtures: sl.fixtures) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth.clamp(280.0, 720.0);
            final size = Size(w, VirtualRoomEditor.roomPaintHeight);
            return SizedBox(
              width: w,
              height: VirtualRoomEditor.roomPaintHeight,
              child: AnimatedBuilder(
                animation: _previewTick,
                builder: (context, _) {
                  final tick = _previewAnimated ? (DateTime.now().millisecondsSinceEpoch ~/ 48) : 0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RoomGridPainter(
                              color: scheme.outline.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                        _tvMarker(vr, size, scheme, loc),
                        ..._fixtureMarkers(
                          size,
                          scheme,
                          vr,
                          tick,
                          chaseRanks,
                        ),
                        _userMarker(vr, size, scheme, loc),
                        // Kužel nad ikonami — vizuálně navázaný na uživatele; dotyky musí projít na TV / žárovky / osobu.
                        Positioned(
                          left: 0,
                          top: 0,
                          width: size.width,
                          height: size.height,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: size,
                              painter: _SightPainter(
                                layoutSize: size,
                                vr: vr,
                                fillColor: scheme.primary.withValues(alpha: 0.14),
                                strokeColor: scheme.primary.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(loc.virtualRoomPreviewToggle),
          subtitle: Text(loc.virtualRoomPreviewSubtitle, style: Theme.of(context).textTheme.bodySmall),
          value: _previewAnimated,
          onChanged: (v) => setState(() => _previewAnimated = v),
        ),
        const SizedBox(height: 8),
        Text(loc.virtualRoomEffectLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        DropdownButtonFormField<SmartRoomEffectKind>(
          value: vr.roomEffect,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: [
            for (final k in SmartRoomEffectKind.values)
              DropdownMenuItem(value: k, child: Text(_effectLabel(loc, k))),
          ],
          onChanged: (k) {
            if (k == null) return;
            _patch(sl.copyWith(virtualRoom: vr.copyWith(roomEffect: k)));
          },
        ),
        const SizedBox(height: 6),
        Text(_effectHint(loc, vr.roomEffect), style: Theme.of(context).textTheme.bodySmall),
        if (vr.roomEffect != SmartRoomEffectKind.none) ...[
          const SizedBox(height: 12),
          Text(loc.virtualRoomWaveStrength((vr.waveStrength * 100).round()), style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: vr.waveStrength.clamp(0.0, 1.0),
            onChanged: (v) => _patch(sl.copyWith(virtualRoom: vr.copyWith(waveStrength: v))),
          ),
          Text(loc.virtualRoomWaveSpeed, style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: vr.waveSpeed.clamp(0.01, 0.35),
            min: 0.01,
            max: 0.35,
            onChanged: (v) => _patch(sl.copyWith(virtualRoom: vr.copyWith(waveSpeed: v))),
          ),
        ],
        if (showDistance) ...[
          Text(loc.virtualRoomDistanceSens, style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: vr.waveDistanceScale.clamp(0.5, 15.0),
            min: 0.5,
            max: 15.0,
            onChanged: (v) => _patch(sl.copyWith(virtualRoom: vr.copyWith(waveDistanceScale: v))),
          ),
        ],
        if (showSpatial) ...[
          const SizedBox(height: 8),
          Text(loc.virtualRoomGeometryLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          DropdownButtonFormField<SmartRoomWaveGeometry>(
            value: vr.waveGeometry,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              for (final g in SmartRoomWaveGeometry.values)
                DropdownMenuItem(value: g, child: Text(_geometryLabel(loc, g))),
            ],
            onChanged: (g) {
              if (g == null) return;
              _patch(sl.copyWith(virtualRoom: vr.copyWith(waveGeometry: g)));
            },
          ),
        ],
        if (showSpatial && vr.waveGeometry == SmartRoomWaveGeometry.customAngle) ...[
          Text(loc.virtualRoomCustomAngle(vr.waveExtraAngleDeg.round()), style: Theme.of(context).textTheme.bodySmall),
          Slider(
            value: vr.waveExtraAngleDeg.clamp(-180.0, 180.0),
            min: -180,
            max: 180,
            onChanged: (v) => _patch(sl.copyWith(virtualRoom: vr.copyWith(waveExtraAngleDeg: v))),
          ),
        ],
        if (vr.roomEffect != SmartRoomEffectKind.none) ...[
          const SizedBox(height: 8),
          Text(loc.virtualRoomBrightnessModLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<SmartRoomBrightnessModulate>(
            segments: [
              ButtonSegment(value: SmartRoomBrightnessModulate.both, label: Text(loc.virtualRoomBrightnessBoth)),
              ButtonSegment(value: SmartRoomBrightnessModulate.rgbOnly, label: Text(loc.virtualRoomBrightnessRgb)),
              ButtonSegment(value: SmartRoomBrightnessModulate.brightnessOnly, label: Text(loc.virtualRoomBrightnessBri)),
            ],
            selected: {vr.brightnessModulation},
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              _patch(sl.copyWith(virtualRoom: vr.copyWith(brightnessModulation: s.first)));
            },
          ),
        ],
        const SizedBox(height: 12),
        Text(loc.virtualRoomFacing(vr.userFacingDeg.round()), style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: vr.userFacingDeg.clamp(-90.0, 90.0),
          min: -90,
          max: 90,
          onChanged: (v) => _patch(sl.copyWith(virtualRoom: vr.copyWith(userFacingDeg: v))),
        ),
      ],
    );
  }

  Widget _tvMarker(VirtualRoomLayout vr, Size size, ColorScheme scheme, AppLocalizations loc) {
    const tw = 72.0;
    const th = 44.0;
    return Positioned(
      left: vr.tvX * size.width - tw / 2,
      top: vr.tvY * size.height - th / 2,
      child: GestureDetector(
        onPanUpdate: (d) {
          final nx = (vr.tvX + d.delta.dx / size.width).clamp(0.06, 0.94);
          final ny = (vr.tvY + d.delta.dy / size.height).clamp(0.06, 0.94);
          _patch(sl.copyWith(virtualRoom: vr.copyWith(tvX: nx, tvY: ny)));
        },
        child: Tooltip(
          message: loc.virtualRoomDragTv,
          child: Container(
            width: tw,
            height: th,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.tv_rounded, size: 28, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  /// Náhled žárovky: světlý „papír“ pod modulaci + halo podle [SmartEffectOutput.brightnessMul] a luminance.
  Widget _fixturePreviewLamp({
    required SmartFixture f,
    required ColorScheme scheme,
    required VirtualRoomLayout vr,
    required (int, int, int) previewBaseRgb,
    required int tick,
    required Map<String, int>? chaseRanks,
  }) {
    final extent = VirtualRoomEditor.previewLampExtent;
    if (!f.enabled) {
      return SizedBox(
        width: extent,
        height: extent,
        child: Icon(
          Icons.lightbulb_outline_rounded,
          size: 30,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      );
    }
    if (vr.roomEffect == SmartRoomEffectKind.none) {
      return SizedBox(
        width: extent,
        height: extent,
        child: Icon(
          Icons.lightbulb_rounded,
          size: 34,
          color: scheme.tertiary,
        ),
      );
    }
    final out = VirtualRoomEffects.apply(
      room: vr,
      fixture: f,
      base: previewBaseRgb,
      animationTick: tick,
      chaseRanks: chaseRanks,
    );
    final c = Color.fromARGB(255, out.r, out.g, out.b);
    final luma = (0.2126 * out.r + 0.7152 * out.g + 0.0722 * out.b) / 255.0;
    final glow = (luma * 0.62 + out.brightnessMul * 0.38).clamp(0.0, 1.0);
    final disk = 26.0 + 18.0 * glow;
    final iconSize = 28.0 + 8.0 * glow;
    final filament = Color.lerp(
      scheme.onSurfaceVariant.withValues(alpha: 0.5),
      Color.lerp(scheme.surfaceContainerHighest, c, 0.92)!,
      0.35 + 0.65 * glow,
    )!;

    return SizedBox(
      width: extent,
      height: extent,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: extent * 0.88,
            height: extent * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.12 + 0.5 * glow),
                  blurRadius: 2 + 16 * glow,
                  spreadRadius: 0.5 + 5 * glow,
                ),
                BoxShadow(
                  color: c.withValues(alpha: 0.06 + 0.22 * glow),
                  blurRadius: 8 + 22 * glow,
                  spreadRadius: -2,
                ),
              ],
            ),
          ),
          Container(
            width: disk,
            height: disk,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  c.withValues(alpha: 0.5 + 0.45 * glow),
                  c.withValues(alpha: 0.06 * glow),
                ],
              ),
            ),
          ),
          Icon(Icons.lightbulb_rounded, size: iconSize, color: filament),
        ],
      ),
    );
  }

  List<Widget> _fixtureMarkers(
    Size size,
    ColorScheme scheme,
    VirtualRoomLayout vr,
    int tick,
    Map<String, int>? chaseRanks,
  ) {
    final neutralRgb = (
      (scheme.tertiary.r * 255.0).round().clamp(0, 255),
      (scheme.tertiary.g * 255.0).round().clamp(0, 255),
      (scheme.tertiary.b * 255.0).round().clamp(0, 255),
    );
    // Teplá téměř bílá — na tmavém plánku je výrazný rozdíl při „zhasínání“ efektem.
    const vividPreviewRgb = (255, 248, 228);
    final previewBaseRgb =
        vr.roomEffect == SmartRoomEffectKind.none ? neutralRgb : vividPreviewRgb;
    final half = VirtualRoomEditor.previewLampExtent / 2;
    return [
      for (final f in sl.fixtures)
        Positioned(
          left: f.roomX * size.width - half,
          top: f.roomY * size.height - half,
          child: GestureDetector(
            onPanUpdate: (d) {
              final nx = (f.roomX + d.delta.dx / size.width).clamp(0.04, 0.96);
              final ny = (f.roomY + d.delta.dy / size.height).clamp(0.04, 0.96);
              _patch(sl.copyWith(
                fixtures: sl.fixtures
                    .map((x) => x.id == f.id ? x.copyWith(roomX: nx, roomY: ny) : x)
                    .toList(),
              ));
            },
            child: Tooltip(
              message: f.displayName,
              child: _fixturePreviewLamp(
                f: f,
                scheme: scheme,
                vr: vr,
                previewBaseRgb: previewBaseRgb,
                tick: tick,
                chaseRanks: chaseRanks,
              ),
            ),
          ),
        ),
    ];
  }

  Widget _userMarker(VirtualRoomLayout vr, Size size, ColorScheme scheme, AppLocalizations loc) {
    const r = 22.0;
    final hitBox = 2 * r;
    return Positioned(
      left: vr.userX * size.width - r,
      top: vr.userY * size.height - r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final nx = (vr.userX + details.delta.dx / size.width).clamp(0.06, 0.94);
          final ny = (vr.userY + details.delta.dy / size.height).clamp(0.06, 0.94);
          _patch(sl.copyWith(virtualRoom: vr.copyWith(userX: nx, userY: ny)));
        },
        child: Tooltip(
          message: loc.virtualRoomDragUser,
          child: SizedBox(
            width: hitBox,
            height: hitBox,
            child: Center(
              child: CircleAvatar(
                radius: r,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomGridPainter extends CustomPainter {
  _RoomGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomGridPainter oldDelegate) => oldDelegate.color != color;
}

class _SightPainter extends CustomPainter {
  _SightPainter({
    required this.layoutSize,
    required this.vr,
    required this.fillColor,
    required this.strokeColor,
  });

  /// Rozměry z LayoutBuilder — stejné jako Stack; nepřepoléhat na [size] z callbacku při výjimkách layoutu.
  final Size layoutSize;
  final VirtualRoomLayout vr;
  final Color fillColor;
  final Color strokeColor;

  static const double _userAvatarRadiusPx = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final w = layoutSize.width;
    final h = layoutSize.height;
    final userCx = vr.userX * w;
    final userCy = vr.userY * h;
    final ux = userCx;
    final uy = userCy - _userAvatarRadiusPx * 0.72;
    final tx = vr.tvX * w;
    final ty = vr.tvY * h;
    final base = math.atan2(ty - uy, tx - ux);
    final dir = base + vr.userFacingDeg * math.pi / 180;
    final spread = 0.38;
    final reach = math.min(w, h) * 0.42;
    final path = Path()..moveTo(ux, uy);
    path.lineTo(ux + reach * math.cos(dir - spread), uy + reach * math.sin(dir - spread));
    path.lineTo(ux + reach * math.cos(dir + spread), uy + reach * math.sin(dir + spread));
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _SightPainter o) {
    if (o.fillColor != fillColor || o.strokeColor != strokeColor) return true;
    if (o.layoutSize != layoutSize) return true;
    final a = o.vr;
    return a.tvX != vr.tvX ||
        a.tvY != vr.tvY ||
        a.userX != vr.userX ||
        a.userY != vr.userY ||
        a.userFacingDeg != vr.userFacingDeg;
  }
}
