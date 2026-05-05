import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/context_ext.dart';

void _syncLoopingAnimation(AnimationController c, BuildContext context, {bool reverse = false}) {
  if (MediaQuery.disableAnimationsOf(context)) {
    c.stop();
    c.value = 0;
    return;
  }
  if (!c.isAnimating) {
    if (reverse) {
      c.repeat(reverse: true);
    } else {
      c.repeat();
    }
  }
}

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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final CurvedAnimation _ease = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context, reverse: true);
  }

  @override
  void dispose() {
    _ease.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = 1 + 0.06 * math.sin(_ease.value * math.pi);
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  /// Posun náhledové barvy (interakce posuvníkem).
  double _hueTweak = 0.35;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final hue = ((_c.value * 360) + _hueTweak * 200) % 360;
        final glow = HSVColor.fromAHSV(1, hue, 0.65, 1).toColor();
        final glow2 = HSVColor.fromAHSV(1, (hue + 40) % 360, 0.55, 1).toColor();
        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth.clamp(120.0, 340.0);
            final h = w * 0.62;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomPaint(
                  size: Size(w, h + 28),
                  painter: _AmbilightFramePainter(
                    progress: _c.value,
                    glow: glow,
                    glow2: glow2,
                    surface: scheme.surfaceContainerHigh,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      // Bez Overlay (MaterialApp.builder) by value indicator házel chybu.
                      showValueIndicator: ShowValueIndicator.never,
                    ),
                    child: Slider(
                      value: _hueTweak,
                      divisions: 24,
                      onChanged: (v) => setState(() => _hueTweak = v),
                    ),
                  ),
                ),
                Text(
                  l10n.onboardScreenHuePreview,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final CurvedAnimation _ease = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  int? _pulseBar;
  Timer? _pulseTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context, reverse: true);
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _ease.dispose();
    _c.dispose();
    super.dispose();
  }

  void _tapBar(int i) {
    _pulseTimer?.cancel();
    setState(() => _pulseBar = i);
    _pulseTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _pulseBar = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _ease.value;
        final heights = List<double>.generate(
          12,
          (i) => 0.35 + 0.65 * math.sin(v * math.pi + i * 0.55).abs(),
        );
        return SizedBox(
          height: 148,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < heights.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _tapBar(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 12,
                        height: (28 + heights[i] * 92) * (_pulseBar == i ? 1.22 : 1.0),
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
                              blurRadius: _pulseBar == i ? 16 : 8,
                              spreadRadius: 0,
                              color: scheme.primary.withValues(alpha: _pulseBar == i ? 0.65 : 0.35),
                            ),
                          ],
                        ),
                      ),
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  int _selected = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context);
  }

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

  List<String> _modeNames(BuildContext context) {
    final l = context.l10n;
    return [l.modeLightTitle, l.modeScreenTitle, l.modeMusicTitle, l.modePcHealthTitle];
  }

  void _onTileTap(int i) {
    setState(() => _selected = i);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(_modeNames(context)[i]),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _tiles.length; i++)
              _InteractiveModeTile(
                delay: i * 0.18,
                phase: _c.value,
                icon: _tiles[i].icon,
                colors: _tiles[i].colors,
                selected: _selected == i,
                label: _modeNames(context)[i],
                onTap: () => _onTileTap(i),
                ring: scheme.primary,
              ),
          ],
        );
      },
    );
  }
}

class _InteractiveModeTile extends StatelessWidget {
  const _InteractiveModeTile({
    required this.delay,
    required this.phase,
    required this.icon,
    required this.colors,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.ring,
  });

  final double delay;
  final double phase;
  final IconData icon;
  final List<Color> colors;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final local = (phase + delay) % 1.0;
    final lift = 4 * math.sin(local * math.pi * 2);
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Semantics(
        label: label,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: colors),
                border: Border.all(
                  color: selected ? ring : ring.withValues(alpha: 0.28),
                  width: selected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: selected ? 0.55 : 0.38),
                    blurRadius: selected ? 18 : 12 + lift,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 34),
              ),
            ),
          ),
        ),
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    void snack(String msg) {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.hideCurrentSnackBar();
      m?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }

    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => snack(l10n.onboardConnectivityUsbTap),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.usb_rounded, size: 52, color: scheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      l10n.onboardingUsbSerialLabel,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => snack(l10n.onboardConnectivityWifiTap),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_rounded, size: 52, color: scheme.tertiary),
                    const SizedBox(height: 8),
                    Text(
                      l10n.onboardingUdpWifiLabel,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
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

/// Průběh výstupu — přepínač (náhled) + animace na pásek.
class OnboardingOutputDemo extends StatefulWidget {
  const OnboardingOutputDemo({super.key});

  @override
  State<OnboardingOutputDemo> createState() => _OnboardingOutputDemoState();
}

class _OnboardingOutputDemoState extends State<OnboardingOutputDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final CurvedAnimation _ease = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  bool _demoOn = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context, reverse: true);
  }

  @override
  void dispose() {
    _ease.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Switch(
              value: _demoOn,
              onChanged: (v) => setState(() => _demoOn = v),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _demoOn ? l10n.onboardingOutputDemoOn : l10n.onboardingOutputDemoOff,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.onboardOutputTourOnlyHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _ease.value;
            final glow = scheme.tertiary.withValues(alpha: (_demoOn ? 0.35 : 0.12) + (_demoOn ? 0.45 : 0) * t);
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _demoOn ? 1 : 0.38,
              child: Column(
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
                          scheme.primary.withValues(alpha: (_demoOn ? 0.5 : 0.2) + (_demoOn ? 0.45 : 0) * t),
                          scheme.secondary.withValues(alpha: _demoOn ? 0.55 : 0.25),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 14,
                          color: scheme.primary.withValues(alpha: (_demoOn ? 0.45 : 0.08) * t),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.onboardIllustColorsToStrip,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
              _MeterBar(label: l10n.onboardIllustCpuLabel, value: cpu, color: scheme.primary),
              const SizedBox(width: 28),
              _MeterBar(label: l10n.onboardIllustGpuLabel, value: gpu, color: scheme.tertiary),
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
    final l10n = context.l10n;
    void snack(String msg) {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.hideCurrentSnackBar();
      m?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MiniCard(
          icon: Icons.tune_rounded,
          label: l10n.onboardingModesDemoLabel,
          scheme: scheme,
          onTap: () => snack(l10n.onboardSettingsSnackModes),
        ),
        const SizedBox(width: 14),
        _MiniCard(
          icon: Icons.cloud_download_rounded,
          label: l10n.tabFirmware,
          scheme: scheme,
          onTap: () => snack(l10n.onboardSettingsSnackFirmware),
        ),
        const SizedBox(width: 14),
        _MiniCard(
          icon: Icons.save_alt_rounded,
          label: l10n.onboardIllustMiniBackup,
          scheme: scheme,
          onTap: () => snack(l10n.onboardSettingsSnackBackup),
        ),
      ],
    );
  }
}

/// Závěrečná stránka — raketa s jemným pohybem.
class OnboardingReadyIllustration extends StatefulWidget {
  const OnboardingReadyIllustration({super.key});

  @override
  State<OnboardingReadyIllustration> createState() => _OnboardingReadyIllustrationState();
}

class _OnboardingReadyIllustrationState extends State<OnboardingReadyIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoopingAnimation(_c, context, reverse: true);
  }

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
        final t = Curves.easeInOut.transform(_c.value);
        final lift = 6 * math.sin(t * math.pi * 2);
        final rot = 0.12 * math.sin((t + 0.25) * math.pi * 2);
        return Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.rotate(
            angle: rot,
            child: Icon(Icons.rocket_launch_rounded, size: 88, color: scheme.primary),
          ),
        );
      },
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
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
        ),
      ),
    );
  }
}
