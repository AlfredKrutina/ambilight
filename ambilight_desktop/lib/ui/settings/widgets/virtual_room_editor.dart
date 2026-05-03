import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/smart_lights_models.dart';

/// Plánek místnosti: TV, uživatel, směr pohledu, tažná světla a parametry vlnění.
class VirtualRoomEditor extends StatelessWidget {
  const VirtualRoomEditor({
    super.key,
    required this.sl,
    required this.onChanged,
  });

  final SmartLightsSettings sl;
  final ValueChanged<SmartLightsSettings> onChanged;

  static const double _roomH = 248;

  @override
  Widget build(BuildContext context) {
    final vr = sl.virtualRoom;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth.clamp(280.0, 720.0);
            final size = Size(w, _roomH);
            return SizedBox(
              width: w,
              height: _roomH,
              child: ClipRRect(
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
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SightPainter(
                          vr: vr,
                          fillColor: scheme.primary.withValues(alpha: 0.14),
                          strokeColor: scheme.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    _tvMarker(vr, size, scheme),
                    ..._fixtureMarkers(size, scheme),
                    _userMarker(vr, size, scheme),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vlna přes místnost'),
          subtitle: const Text('Modulace jasu podle vzdálenosti od TV a času snímku'),
          value: vr.waveEnabled,
          onChanged: (v) => onChanged(sl.copyWith(virtualRoom: vr.copyWith(waveEnabled: v))),
        ),
        Text('Síla vlny: ${(vr.waveStrength * 100).round()} %', style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: vr.waveStrength.clamp(0.0, 1.0),
          onChanged: (v) => onChanged(sl.copyWith(virtualRoom: vr.copyWith(waveStrength: v))),
        ),
        Text('Rychlost vlny', style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: vr.waveSpeed.clamp(0.01, 0.35),
          min: 0.01,
          max: 0.35,
          onChanged: (v) => onChanged(sl.copyWith(virtualRoom: vr.copyWith(waveSpeed: v))),
        ),
        Text('Citlivost na vzdálenost', style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: vr.waveDistanceScale.clamp(0.5, 15.0),
          min: 0.5,
          max: 15.0,
          onChanged: (v) => onChanged(sl.copyWith(virtualRoom: vr.copyWith(waveDistanceScale: v))),
        ),
        Text('Úchyl pohledu od osy k TV: ${vr.userFacingDeg.round()}°', style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: vr.userFacingDeg.clamp(-90.0, 90.0),
          min: -90,
          max: 90,
          divisions: 36,
          onChanged: (v) => onChanged(sl.copyWith(virtualRoom: vr.copyWith(userFacingDeg: v))),
        ),
      ],
    );
  }

  Widget _tvMarker(VirtualRoomLayout vr, Size size, ColorScheme scheme) {
    const tw = 72.0;
    const th = 44.0;
    return Positioned(
      left: vr.tvX * size.width - tw / 2,
      top: vr.tvY * size.height - th / 2,
      child: GestureDetector(
        onPanUpdate: (d) {
          final nx = (vr.tvX + d.delta.dx / size.width).clamp(0.06, 0.94);
          final ny = (vr.tvY + d.delta.dy / size.height).clamp(0.06, 0.94);
          onChanged(sl.copyWith(virtualRoom: vr.copyWith(tvX: nx, tvY: ny)));
        },
        child: Tooltip(
          message: 'TV (táhni)',
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

  List<Widget> _fixtureMarkers(Size size, ColorScheme scheme) {
    return [
      for (final f in sl.fixtures)
        Positioned(
          left: f.roomX * size.width - 16,
          top: f.roomY * size.height - 16,
          child: GestureDetector(
            onPanUpdate: (d) {
              final nx = (f.roomX + d.delta.dx / size.width).clamp(0.04, 0.96);
              final ny = (f.roomY + d.delta.dy / size.height).clamp(0.04, 0.96);
              onChanged(sl.copyWith(
                fixtures: sl.fixtures
                    .map((x) => x.id == f.id ? x.copyWith(roomX: nx, roomY: ny) : x)
                    .toList(),
              ));
            },
            child: Tooltip(
              message: f.displayName,
              child: Icon(
                Icons.lightbulb_rounded,
                size: 32,
                color: f.enabled ? scheme.tertiary : scheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _userMarker(VirtualRoomLayout vr, Size size, ColorScheme scheme) {
    const r = 22.0;
    return Positioned(
      left: vr.userX * size.width - r,
      top: vr.userY * size.height - r,
      child: GestureDetector(
        onPanUpdate: (d) {
          final nx = (vr.userX + d.delta.dx / size.width).clamp(0.06, 0.94);
          final ny = (vr.userY + d.delta.dy / size.height).clamp(0.06, 0.94);
          onChanged(sl.copyWith(virtualRoom: vr.copyWith(userX: nx, userY: ny)));
        },
        child: Tooltip(
          message: 'Ty (táhni)',
          child: CircleAvatar(
            radius: r,
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer, size: 26),
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
    required this.vr,
    required this.fillColor,
    required this.strokeColor,
  });

  final VirtualRoomLayout vr;
  final Color fillColor;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final ux = vr.userX * size.width;
    final uy = vr.userY * size.height;
    final tx = vr.tvX * size.width;
    final ty = vr.tvY * size.height;
    final base = math.atan2(ty - uy, tx - ux);
    final dir = base + vr.userFacingDeg * math.pi / 180;
    final spread = 0.38;
    final reach = math.min(size.width, size.height) * 0.42;
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
    final a = o.vr;
    return a.tvX != vr.tvX ||
        a.tvY != vr.tvY ||
        a.userX != vr.userX ||
        a.userY != vr.userY ||
        a.userFacingDeg != vr.userFacingDeg;
  }
}
