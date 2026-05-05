import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/app_error_safety.dart';
import '../../core/models/config_models.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';
import '../dashboard_ui.dart';
import '../theme_catalog.dart';
import '../wizards/led_strip_wizard_dialog.dart';
import 'onboarding_device_actions.dart';

/// Omezí šířku na ultrawide / velkých monitorech.
const double _kOnboardingMaxContentWidth = 720;

const int _kWizardSteps = 5;

/// Celoplošný interaktivní průvodce prvním spuštěním.
class AmbilightOnboardingLayer extends StatelessWidget {
  const AmbilightOnboardingLayer({super.key});

  static Future<void> _finish(BuildContext context) async {
    final ctrl = context.read<AmbilightAppController>();
    await ctrl.applyConfigAndPersist(
      ctrl.config.copyWith(
        globalSettings:
            ctrl.config.globalSettings.copyWith(onboardingCompleted: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.97),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = math
                .min(_kOnboardingMaxContentWidth, c.maxWidth - 16)
                .clamp(280.0, _kOnboardingMaxContentWidth);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: w),
                child: AmbilightOnboardingWizard(
                  onSkip: () => unawaited(_finish(context)),
                  onComplete: () => unawaited(_finish(context)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AmbilightOnboardingWizard extends StatefulWidget {
  const AmbilightOnboardingWizard({
    super.key,
    required this.onSkip,
    required this.onComplete,
  });

  final VoidCallback onSkip;
  final VoidCallback onComplete;

  @override
  State<AmbilightOnboardingWizard> createState() =>
      _AmbilightOnboardingWizardState();
}

class _AmbilightOnboardingWizardState extends State<AmbilightOnboardingWizard>
    with SingleTickerProviderStateMixin {
  AmbilightAppController? _ctrl;
  late AnimationController _rainbowCtrl;

  int _step = 0;
  bool _previewSetupDone = false;
  bool _previewRestored = false;
  late bool _savedRainbow;
  late String _savedStartMode;
  bool _didSwitchStartMode = false;

  @override
  void initState() {
    super.initState();
    _rainbowCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= context.read<AmbilightAppController>();
    if (_previewSetupDone) return;
    _previewSetupDone = true;
    dismissAppFault();
    final c = _ctrl!;
    _savedRainbow = c.rainbowSynthBypassCapture;
    _savedStartMode = c.config.globalSettings.startMode;
    _didSwitchStartMode = _savedStartMode != 'screen';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _ctrl == null) return;
      final ctrl = _ctrl!;
      ctrl.setRainbowSynthBypassCapture(true);
      if (_didSwitchStartMode) {
        await ctrl.applyConfigAndPersist(
          ctrl.config.copyWith(
            globalSettings:
                ctrl.config.globalSettings.copyWith(startMode: 'screen'),
          ),
        );
      }
    });
  }

  void _restorePreview() {
    final c = _ctrl;
    if (c == null || _previewRestored) return;
    _previewRestored = true;
    c.setRainbowSynthBypassCapture(_savedRainbow);
    if (_didSwitchStartMode) {
      unawaited(
        c.applyConfigAndPersist(
          c.config.copyWith(
            globalSettings:
                c.config.globalSettings.copyWith(startMode: _savedStartMode),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _restorePreview();
    _rainbowCtrl.dispose();
    super.dispose();
  }

  void _applyTheme(String canonicalKey) {
    final c = context.read<AmbilightAppController>();
    final theme = normalizeAmbilightUiTheme(canonicalKey);
    c.queueConfigApply(c.config.copyWith(
        globalSettings: c.config.globalSettings.copyWith(theme: theme)));
  }

  void _applyControlLevel(String level) {
    final c = context.read<AmbilightAppController>();
    final norm = normalizeAmbilightUiControlLevel(level);
    var sm = c.config.screenMode;
    if (norm == 'simple' && sm.scanMode == 'advanced') {
      sm = sm.copyWith(scanMode: 'simple');
    }
    c.queueConfigApply(
      c.config.copyWith(
        globalSettings: c.config.globalSettings.copyWith(uiControlLevel: norm),
        screenMode: sm,
      ),
    );
  }

  void _next() {
    if (_step >= _kWizardSteps - 1) {
      _restorePreview();
      widget.onComplete();
      return;
    }
    setState(() => _step++);
  }

  void _prev() {
    if (_step <= 0) return;
    setState(() => _step--);
  }

  Widget _rainbowPreviewBar(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _rainbowCtrl,
      builder: (context, _) {
        final t = _rainbowCtrl.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 5,
            child: CustomPaint(
              painter: _RainbowBarPainter(progress: t),
            ),
          ),
        );
      },
    );
  }

  Widget _choiceTile({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 32, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant, height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: scheme.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _integrationCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBody(AppLocalizations l10n) {
    final c = context.watch<AmbilightAppController>();
    final g = c.config.globalSettings;
    final themeKey = normalizeAmbilightUiTheme(g.theme);
    final levelKey = normalizeAmbilightUiControlLevel(g.uiControlLevel);

    switch (_step) {
      case 0:
        final themeOptions = AmbilightUiThemeCatalog.options;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepThemeSubtitle,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            for (final option in themeOptions)
              _choiceTile(
                selected: themeKey == option.key,
                onTap: () => _applyTheme(option.key),
                icon: option.icon,
                title: AmbilightUiThemeCatalog.title(context, option.key),
                subtitle: AmbilightUiThemeCatalog.onboardingSubtitle(
                    context, option.key),
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepComplexitySubtitle,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _choiceTile(
              selected: levelKey == 'simple',
              onTap: () => _applyControlLevel('simple'),
              icon: Icons.tune,
              title: l10n.onboardWizardComplexitySimpleTitle,
              subtitle: l10n.onboardWizardComplexitySimpleSubtitle,
            ),
            _choiceTile(
              selected: levelKey == 'advanced',
              onTap: () => _applyControlLevel('advanced'),
              icon: Icons.tune_outlined,
              title: l10n.onboardWizardComplexityAdvancedTitle,
              subtitle: l10n.onboardWizardComplexityAdvancedSubtitle,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepDeviceSubtitle,
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(onboardingOpenWifiDiscovery(context)),
              icon: const Icon(Icons.wifi_find_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.onboardWizardScanWifi,
                    textAlign: TextAlign.center),
              ),
              style: FilledButton.styleFrom(alignment: Alignment.centerLeft),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(onboardingSetupSerialUsb(context)),
              icon: const Icon(Icons.usb_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.onboardWizardSetupUsb,
                    textAlign: TextAlign.center),
              ),
              style: FilledButton.styleFrom(alignment: Alignment.centerLeft),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepMappingSubtitle,
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => unawaited(LedStripWizardDialog.show(context)),
              icon: const Icon(Icons.linear_scale_rounded),
              label: Text(l10n.onboardWizardOpenMapping),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _next,
              child: Text(l10n.onboardWizardMappingSkip),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepIntegrationsSubtitle,
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            _integrationCard(
              icon: Icons.hub_rounded,
              title: l10n.onboardWizardHaCardTitle,
              body: l10n.onboardWizardHaCardBody,
            ),
            _integrationCard(
              icon: Icons.graphic_eq_rounded,
              title: l10n.onboardWizardSpotifyCardTitle,
              body: l10n.onboardWizardSpotifyCardBody,
            ),
            _integrationCard(
              icon: Icons.monitor_heart_outlined,
              title: l10n.onboardWizardPcHealthCardTitle,
              body: l10n.onboardWizardPcHealthCardBody,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _stepTitle(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return l10n.onboardWizardStepThemeTitle;
      case 1:
        return l10n.onboardWizardStepComplexityTitle;
      case 2:
        return l10n.onboardWizardStepDeviceTitle;
      case 3:
        return l10n.onboardWizardStepMappingTitle;
      case 4:
        return l10n.onboardWizardStepIntegrationsTitle;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final l10n = context.l10n;
    final last = _step >= _kWizardSteps - 1;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              TextButton(onPressed: widget.onSkip, child: Text(l10n.skip)),
              const Spacer(),
              Text(
                l10n.onboardProgress(_step + 1, _kWizardSteps),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              _rainbowPreviewBar(scheme),
              const SizedBox(height: 6),
              Text(
                l10n.onboardWizardPreviewHint,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _stepTitle(l10n),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: instant
                        ? Duration.zero
                        : const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic));
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(position: offset, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_step),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AmbiGlassPanel(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 14),
                          child: _buildStepBody(l10n),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 400;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_kWizardSteps, (i) {
                      final on = i == _step;
                      return Semantics(
                        button: true,
                        label: l10n.onboardSlideDotA11y(i + 1, _kWizardSteps),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 6),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i == _step) return;
                              setState(() => _step = i);
                            },
                            child: AnimatedScale(
                              scale: on ? 1.15 : 1,
                              duration: instant
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              child: AnimatedContainer(
                                duration: instant
                                    ? Duration.zero
                                    : const Duration(milliseconds: 240),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: on ? 24 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: on
                                      ? scheme.primary
                                      : scheme.outlineVariant
                                          .withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (!instant)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.onboardKeysHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (narrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _next,
                          child:
                              Text(last ? l10n.onboardWizardFinish : l10n.next),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                            onPressed: _step > 0 ? _prev : null,
                            child: Text(l10n.back)),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 148,
                          child: OutlinedButton(
                              onPressed: _step > 0 ? _prev : null,
                              child: Text(l10n.back)),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 220,
                          child: FilledButton(
                            onPressed: _next,
                            child: Text(
                                last ? l10n.onboardWizardFinish : l10n.next),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _next();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _prev();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onSkip();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: body,
    );
  }
}

class _RainbowBarPainter extends CustomPainter {
  _RainbowBarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shift = progress * 360;
    final colors = <Color>[];
    const stops = 8;
    for (var i = 0; i <= stops; i++) {
      final h = ((i / stops) * 360 + shift) % 360;
      colors.add(HSLColor.fromAHSL(1, h, 0.85, 0.55).toColor());
    }
    final shader = LinearGradient(colors: colors).createShader(rect);
    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _RainbowBarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
