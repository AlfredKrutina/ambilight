import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo / ikona s jemným pulzem.
class OnboardingPulseLogo extends StatefulWidget {
  const OnboardingPulseLogo({
    super.key,
    required this.child,
    this.size = 120,
  });

  final Widget child;
  final double size;

  @override
  State<OnboardingPulseLogo> createState() => _OnboardingPulseLogoState();
}

class _OnboardingPulseLogoState extends State<OnboardingPulseLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
        final scale = 1 + 0.06 * math.sin(t.value * math.pi);
        return Transform.scale(
          scale: scale,
          child: SizedBox(width: widget.size, height: widget.size, child: widget.child),
        );
      },
    );
  }
}

/// Monitor + LED pásek s běžící duhou po okrajích.
class OnboardingAmbilightScreenDemo extends StatefulWidget {
  const OnboardingAmbilightScreenDemo({super.key});

  @override
  State<OnboardingAmbilightScreenDemo> createState() => _OnboardingAmbilightScreenDemoState();
}

class _OnboardingAmbilightScreenDemoState extends State<OnboardingAmbilightScreenDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final hue = (_c.value * 360) % 360;
        final glow = HSVColor.fromAHSV(1, hue, 0.65, 1).toColor();
        final glow2 = HSVColor.fromAHSV(1, (hue + 40) % 360, 0.55, 1).toColor();
        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth.clamp(120.0, 340.0);
            final h = w * 0.62;
            return CustomPaint(
              size: Size(w, h + 28),
              painter: _AmbilightFramePainter(
                progress: _c.value,
                glow: glow,
                glow2: glow2,
                surface: scheme.surfaceContainerHigh,
              ),
            );
          },
        );
      },
    );
  }
}

class _AmbilightFramePainter extends CustomPainter {
  _AmbilightFramePainter({
    required this.progress,
    required this.glow,
    required this.glow2,
    required this.surface,
  });

  final double progress;
  final Color glow;
  final Color glow2;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(14, 8, size.width - 28, size.height - 36),
      const Radius.circular(10),
    );
    final stripRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, size.height - 22, size.width - 16, 14),
      const Radius.circular(7),
    );

    final wave = math.sin(progress * math.pi * 2);
    final sweep = SweepGradient(
      colors: [glow, glow2, glow],
      stops: const [0, 0.5, 1],
      transform: GradientRotation(progress * math.pi * 2),
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final glowStrip = Paint()
      ..shader = sweep
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 3 * wave.abs());
    canvas.drawRRect(stripRect.inflate(5 + 2 * wave.abs()), glowStrip);

    final glowMon = Paint()
      ..shader = sweep
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(rect.inflate(3), glowMon);

    canvas.drawRRect(rect, Paint()..color = surface);
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glow.withValues(alpha: 0.35),
    );

    final stripFill = Paint()
      ..shader = LinearGradient(colors: [glow, glow2]).createShader(stripRect.outerRect);
    canvas.drawRRect(stripRect, stripFill);
    canvas.drawRRect(
      stripRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white24,
    );

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final sr = stripRect.outerRect;
    for (var i = 0; i < 11; i++) {
      final x = sr.left + 8 + i * (sr.width - 16) / 10;
      final y = stripRect.outerRect.center.dy + math.sin(progress * math.pi * 2 + i * 0.6) * 2;
      canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbilightFramePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.glow != glow;
}

/// Ekvalizér — sloupce reagují na „beat“.
class OnboardingMusicBarsDemo extends StatefulWidget {
  const OnboardingMusicBarsDemo({super.key});

  @override
  State<OnboardingMusicBarsDemo> createState() => _OnboardingMusicBarsDemoState();
}

class _OnboardingMusicBarsDemoState extends State<OnboardingMusicBarsDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = CurvedAnimation(parent: _c, curve: Curves.easeInOut).value;
        final heights = List<double>.generate(
          12,
          (i) => 0.35 + 0.65 * math.sin(v * math.pi + i * 0.55).abs(),
        );
        return SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < heights.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: Duration.zero,
                    width: 12,
                    height: 28 + heights[i] * 92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          scheme.tertiary,
                          Color.lerp(scheme.primary, scheme.secondary, i / heights.length)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          spreadRadius: 0,
                          color: scheme.primary.withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Čtyři dlaždice režimů s jemným výsuvom.
class OnboardingModesTilesDemo extends StatefulWidget {
  const OnboardingModesTilesDemo({super.key});

  @override
  State<OnboardingModesTilesDemo> createState() => _OnboardingModesTilesDemoState();
}

class _OnboardingModesTilesDemoState extends State<OnboardingModesTilesDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _tiles = <({IconData icon, List<Color> colors})>[
    (icon: Icons.light_mode_rounded, colors: [Color(0xFFFB923C), Color(0xFFF472B6)]),
    (icon: Icons.desktop_windows_rounded, colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]),
    (icon: Icons.graphic_eq_rounded, colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
    (icon: Icons.monitor_heart_rounded, colors: [Color(0xFF0D9488), Color(0xFF22C55E)]),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              _AnimatedTile(
                delay: i * 0.18,
                phase: _c.value,
                icon: _tiles[i].icon,
                colors: _tiles[i].colors,
              ),
          ],
        );
      },
    );
  }
}

class _AnimatedTile extends StatelessWidget {
  const _AnimatedTile({
    required this.delay,
    required this.phase,
    required this.icon,
    required this.colors,
  });

  final double delay;
  final double phase;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final local = (phase + delay) % 1.0;
    final lift = 4 * math.sin(local * math.pi * 2);
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.45),
              blurRadius: 12 + lift,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 34),
      ),
    );
  }
}

/// USB kabel + Wi‑Fi vlny.
class OnboardingConnectivityDemo extends StatefulWidget {
  const OnboardingConnectivityDemo({super.key});

  @override
  State<OnboardingConnectivityDemo> createState() => _OnboardingConnectivityDemoState();
}

class _OnboardingConnectivityDemoState extends State<OnboardingConnectivityDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.usb_rounded, size: 52, color: scheme.primary),
              const SizedBox(height: 8),
              Text('USB / sériový', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ],
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(100, 100),
                painter: _WifiRipplesPainter(progress: _c.value, color: scheme.tertiary),
              );
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_rounded, size: 52, color: scheme.tertiary),
              const SizedBox(height: 8),
              Text('UDP / Wi‑Fi', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WifiRipplesPainter extends CustomPainter {
  _WifiRipplesPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final p = (progress + i / 3) % 1.0;
      final r = 18 + p * 38;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: (1 - p) * 0.55);
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WifiRipplesPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Průběh výstupu — blesk + šipka na pásek.
class OnboardingOutputDemo extends StatefulWidget {
  const OnboardingOutputDemo({super.key});

  @override
  State<OnboardingOutputDemo> createState() => _OnboardingOutputDemoState();
}

class _OnboardingOutputDemoState extends State<OnboardingOutputDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final e = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
        final glow = scheme.tertiary.withValues(alpha: 0.35 + 0.45 * e.value);
        return Column(
          children: [
            Icon(Icons.bolt_rounded, size: 56, color: glow),
            const SizedBox(height: 8),
            Icon(Icons.arrow_downward_rounded, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Container(
              height: 22,
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.5 + 0.45 * e.value),
                    scheme.secondary.withValues(alpha: 0.55),
                  ],
                ),
                boxShadow: [
                  BoxShadow(blurRadius: 14, color: scheme.primary.withValues(alpha: 0.45 * e.value)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Barvy jedou na pásek',
              style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ],
        );
      },
    );
  }
}

/// Termometry / graf styl PC Health.
class OnboardingPcHealthDemo extends StatefulWidget {
  const OnboardingPcHealthDemo({super.key});

  @override
  State<OnboardingPcHealthDemo> createState() => _OnboardingPcHealthDemoState();
}

class _OnboardingPcHealthDemoState extends State<OnboardingPcHealthDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final cpu = 0.45 + 0.35 * math.sin(_c.value * math.pi * 2);
        final gpu = 0.38 + 0.4 * math.cos(_c.value * math.pi * 2 + 1);
        return SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MeterBar(label: 'CPU', value: cpu, color: scheme.primary),
              const SizedBox(width: 28),
              _MeterBar(label: 'GPU', value: gpu, color: scheme.tertiary),
            ],
          ),
        );
      },
    );
  }
}

class _MeterBar extends StatelessWidget {
  const _MeterBar({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          width: 44,
          height: 88,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
              ),
              FractionallySizedBox(
                heightFactor: value.clamp(0.15, 1.0),
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [color.withValues(alpha: 0.65), color],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Knihovna / záloha styl.
class OnboardingSettingsDemo extends StatelessWidget {
  const OnboardingSettingsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MiniCard(icon: Icons.tune_rounded, label: 'Režimy', scheme: scheme),
        const SizedBox(width: 14),
        _MiniCard(icon: Icons.cloud_download_rounded, label: 'Firmware', scheme: scheme),
        const SizedBox(width: 14),
        _MiniCard(icon: Icons.save_alt_rounded, label: 'Záloha JSON', scheme: scheme),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.primary, size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
