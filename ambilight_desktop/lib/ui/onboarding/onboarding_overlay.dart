import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/app_error_safety.dart';
import '../../core/models/config_models.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';
import '../dashboard_ui.dart';
import '../wizards/led_strip_wizard_dialog.dart';
import 'onboarding_device_actions.dart';

const double _kOverlayMaxWidth = 720;

/// Celoplošný interaktivní průvodce nastavením (náhrada pasivního slideshow).
class OnboardingOverlay extends StatelessWidget {
  const OnboardingOverlay({super.key});

  static Future<void> _persistOnboardingDone(BuildContext context) async {
    final ctrl = context.read<AmbilightAppController>();
    await ctrl.applyConfigAndPersist(
      ctrl.config.copyWith(
        globalSettings: ctrl.config.globalSettings.copyWith(onboardingCompleted: true),
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
            final w = math.min(_kOverlayMaxWidth, c.maxWidth - 16).clamp(280.0, _kOverlayMaxWidth);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: w),
                child: SetupWizard(
                  onSkip: () => unawaited(_persistOnboardingDone(context)),
                  onComplete: () => unawaited(_persistOnboardingDone(context)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Zachová název z dřívějšího API.
class AmbilightOnboardingLayer extends OnboardingOverlay {
  const AmbilightOnboardingLayer({super.key});
}

/// Kroky 0–5 obsah, krok 6 dokončení.
const int _kSetupStepCount = 7;

class SetupWizard extends StatefulWidget {
  const SetupWizard({
    super.key,
    required this.onSkip,
    required this.onComplete,
  });

  final VoidCallback onSkip;
  final VoidCallback onComplete;

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> with TickerProviderStateMixin {
  AmbilightAppController? _ctrl;
  late AnimationController _rainbowCtrl;
  late AnimationController _radarCtrl;

  int _step = 0;
  bool _wifiBusy = false;
  bool _faultCleared = false;

  bool _mappingPreviewOn = false;
  bool _savedRainbow = false;
  String _savedStartMode = 'screen';
  bool _forcedScreenForMapping = false;

  List<String> _comPorts = const [];
  bool _comLoading = false;

  @override
  void initState() {
    super.initState();
    _rainbowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        dismissAppFault();
        unawaited(_syncMappingPreview());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= context.read<AmbilightAppController>();
    if (!_faultCleared) {
      _faultCleared = true;
      dismissAppFault();
    }
    if (!_comLoading && _comPorts.isEmpty && !kIsWeb) {
      unawaited(_refreshComPorts());
    }
  }

  Future<void> _refreshComPorts() async {
    setState(() => _comLoading = true);
    try {
      final list = AmbilightAppController.serialPorts();
      if (mounted) setState(() => _comPorts = list);
    } finally {
      if (mounted) setState(() => _comLoading = false);
    }
  }

  Future<void> _syncMappingPreview() async {
    final c = _ctrl;
    if (c == null || !mounted) return;
    if (_step == 4) {
      if (_mappingPreviewOn) return;
      _mappingPreviewOn = true;
      _savedRainbow = c.rainbowSynthBypassCapture;
      _savedStartMode = c.config.globalSettings.startMode;
      c.setRainbowSynthBypassCapture(true);
      if (_savedStartMode != 'screen') {
        _forcedScreenForMapping = true;
        await c.applyConfigAndPersist(
          c.config.copyWith(
            globalSettings: c.config.globalSettings.copyWith(startMode: 'screen'),
          ),
        );
      }
      if (mounted) setState(() {});
    } else {
      if (!_mappingPreviewOn) return;
      _mappingPreviewOn = false;
      c.setRainbowSynthBypassCapture(_savedRainbow);
      if (_forcedScreenForMapping) {
        _forcedScreenForMapping = false;
        await c.applyConfigAndPersist(
          c.config.copyWith(
            globalSettings: c.config.globalSettings.copyWith(startMode: _savedStartMode),
          ),
        );
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _teardownMappingPreview() async {
    final c = _ctrl;
    if (c == null || !_mappingPreviewOn) return;
    _mappingPreviewOn = false;
    c.setRainbowSynthBypassCapture(_savedRainbow);
    if (_forcedScreenForMapping) {
      _forcedScreenForMapping = false;
      await c.applyConfigAndPersist(
        c.config.copyWith(
          globalSettings: c.config.globalSettings.copyWith(startMode: _savedStartMode),
        ),
      );
    }
  }

  @override
  void dispose() {
    _rainbowCtrl.dispose();
    _radarCtrl.dispose();
    final c = _ctrl;
    if (c != null && _mappingPreviewOn) {
      _mappingPreviewOn = false;
      c.setRainbowSynthBypassCapture(_savedRainbow);
      if (_forcedScreenForMapping) {
        _forcedScreenForMapping = false;
        unawaited(
          c.applyConfigAndPersist(
            c.config.copyWith(
              globalSettings: c.config.globalSettings.copyWith(startMode: _savedStartMode),
            ),
          ),
        );
      }
    }
    super.dispose();
  }

  Future<void> _afterStepChange() async {
    await _syncMappingPreview();
  }

  Future<void> _applyLanguage(String code) async {
    final c = context.read<AmbilightAppController>();
    await c.applyConfigAndPersist(
      c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(uiLanguage: code)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _applyTheme(bool dark) async {
    final c = context.read<AmbilightAppController>();
    final theme = dark ? 'dark_blue' : 'light';
    await c.applyConfigAndPersist(
      c.config.copyWith(globalSettings: c.config.globalSettings.copyWith(theme: theme)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _applyControlLevel(String level) async {
    final c = context.read<AmbilightAppController>();
    final norm = normalizeAmbilightUiControlLevel(level);
    var sm = c.config.screenMode;
    if (norm == 'simple' && sm.scanMode == 'advanced') {
      sm = sm.copyWith(scanMode: 'simple');
    }
    await c.applyConfigAndPersist(
      c.config.copyWith(
        globalSettings: c.config.globalSettings.copyWith(uiControlLevel: norm),
        screenMode: sm,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _runWifiScan() async {
    setState(() => _wifiBusy = true);
    try {
      await onboardingOpenWifiDiscovery(context);
    } finally {
      if (mounted) setState(() => _wifiBusy = false);
    }
  }

  void _setStep(int s) {
    setState(() => _step = s.clamp(0, _kSetupStepCount - 1));
    unawaited(_afterStepChange());
  }

  void _next() {
    if (_step >= _kSetupStepCount - 1) return;
    _setStep(_step + 1);
  }

  void _prev() {
    if (_step <= 0) return;
    _setStep(_step - 1);
  }

  Future<void> _letsGlow() async {
    await _teardownMappingPreview();
    dismissAppFault();
    widget.onComplete();
  }

  int _ledsOnEdge(List<LedSegment> segments, String edge) {
    var total = 0;
    for (final s in segments) {
      if (s.edge.toLowerCase() != edge.toLowerCase()) continue;
      final lo = math.min(s.ledStart, s.ledEnd);
      final hi = math.max(s.ledStart, s.ledEnd);
      total += hi - lo + 1;
    }
    return total;
  }

  Widget _rainbowBar() {
    return AnimatedBuilder(
      animation: _rainbowCtrl,
      builder: (context, _) {
        final t = _rainbowCtrl.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 5,
            child: CustomPaint(painter: _RainbowBarPainter(progress: t)),
          ),
        );
      },
    );
  }

  Widget _radarPulse(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _radarCtrl,
      builder: (context, _) {
        final t = _radarCtrl.value;
        return CustomPaint(
          painter: _RadarPainter(progress: t, color: scheme.primary),
          size: const Size(120, 120),
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
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(icon, size: 36, color: scheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
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
            Icon(icon, size: 30, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
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
    final segs = c.config.screenMode.segments;
    final themeKey = normalizeAmbilightUiTheme(g.theme);
    final levelKey = normalizeAmbilightUiControlLevel(g.uiControlLevel);
    final lang = normalizeAmbilightUiLanguage(g.uiLanguage);

    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupWizardLanguageSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            _choiceTile(
              selected: lang == 'en',
              onTap: () => unawaited(_applyLanguage('en')),
              icon: Icons.language_rounded,
              title: l10n.setupWizardLanguageEnglishTitle,
              subtitle: l10n.setupWizardLanguageEnglishSubtitle,
            ),
            _choiceTile(
              selected: lang == 'cs',
              onTap: () => unawaited(_applyLanguage('cs')),
              icon: Icons.translate_rounded,
              title: l10n.setupWizardLanguageCzechTitle,
              subtitle: l10n.setupWizardLanguageCzechSubtitle,
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupWizardAppearanceSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            _choiceTile(
              selected: themeKey == 'light',
              onTap: () => unawaited(_applyTheme(false)),
              icon: Icons.light_mode_rounded,
              title: l10n.onboardWizardThemeLightTitle,
              subtitle: l10n.onboardWizardThemeLightSubtitle,
            ),
            _choiceTile(
              selected: themeKey != 'light',
              onTap: () => unawaited(_applyTheme(true)),
              icon: Icons.dark_mode_rounded,
              title: l10n.onboardWizardThemeDarkTitle,
              subtitle: l10n.onboardWizardThemeDarkSubtitle,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepComplexitySubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            _choiceTile(
              selected: levelKey == 'simple',
              onTap: () => unawaited(_applyControlLevel('simple')),
              icon: Icons.tune,
              title: l10n.onboardWizardComplexitySimpleTitle,
              subtitle: l10n.setupWizardExpertiseSimpleExplain,
            ),
            _choiceTile(
              selected: levelKey == 'advanced',
              onTap: () => unawaited(_applyControlLevel('advanced')),
              icon: Icons.tune_outlined,
              title: l10n.onboardWizardComplexityAdvancedTitle,
              subtitle: l10n.onboardWizardComplexityAdvancedSubtitle,
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepDeviceSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l10n.setupWizardComDtrRtsHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _wifiBusy ? null : () => unawaited(_runWifiScan()),
                  icon: const Icon(Icons.wifi_find_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.onboardWizardScanWifi, textAlign: TextAlign.center),
                  ),
                  style: FilledButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size.fromHeight(52)),
                ),
                if (_wifiBusy) ...[
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
                    ),
                  ),
                  _radarPulse(Theme.of(context).colorScheme),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(l10n.setupWizardUsbListTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  onPressed: _comLoading ? null : () => unawaited(_refreshComPorts()),
                  icon: _comLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (kIsWeb)
              Text(l10n.setupWizardUsbWebHint, style: Theme.of(context).textTheme.bodySmall)
            else if (_comPorts.isEmpty)
              Text(l10n.setupWizardUsbEmpty, style: Theme.of(context).textTheme.bodySmall)
            else
              ..._comPorts.map(
                (p) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(p),
                    trailing: FilledButton(
                      onPressed: () => unawaited(onboardingConnectComPort(context, p)),
                      child: Text(l10n.setupWizardUsbConnect),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => unawaited(onboardingSetupSerialUsb(context)),
              icon: const Icon(Icons.usb_rounded),
              label: Text(l10n.onboardWizardSetupUsb),
            ),
          ],
        );
      case 4:
        final top = _ledsOnEdge(segs, 'top');
        final bottom = _ledsOnEdge(segs, 'bottom');
        final left = _ledsOnEdge(segs, 'left');
        final right = _ledsOnEdge(segs, 'right');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.onboardWizardStepMappingSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(l10n.setupWizardMappingEdgesTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _edgeCountRow(l10n.scanEdgeTop, top),
            _edgeCountRow(l10n.scanEdgeBottom, bottom),
            _edgeCountRow(l10n.scanEdgeLeft, left),
            _edgeCountRow(l10n.scanEdgeRight, right),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => unawaited(LedStripWizardDialog.show(context)),
              icon: const Icon(Icons.linear_scale_rounded),
              label: Text(l10n.onboardWizardOpenMapping),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _next,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(l10n.onboardWizardMappingSkip, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupWizardWhatsNextSubtitle, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            _featureCard(
              icon: Icons.graphic_eq_rounded,
              title: l10n.setupWizardCardSpotifyTitle,
              body: l10n.setupWizardCardSpotifyBody,
            ),
            _featureCard(
              icon: Icons.hub_rounded,
              title: l10n.setupWizardCardHaTitle,
              body: l10n.setupWizardCardHaBody,
            ),
            _featureCard(
              icon: Icons.monitor_heart_outlined,
              title: l10n.setupWizardCardPcHealthTitle,
              body: l10n.setupWizardCardPcHealthBody,
            ),
          ],
        );
      case 6:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              l10n.setupWizardFinalHeadline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.setupWizardFinalSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => unawaited(_letsGlow()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
              child: Text(l10n.setupWizardLetsGlow),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _edgeCountRow(String edgeLabel, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(edgeLabel, style: Theme.of(context).textTheme.titleSmall)),
          Text('$count', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _stepTitle(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return l10n.setupWizardLanguageHeader;
      case 1:
        return l10n.setupWizardAppearanceHeader;
      case 2:
        return l10n.onboardWizardStepComplexityTitle;
      case 3:
        return l10n.onboardWizardStepDeviceTitle;
      case 4:
        return l10n.onboardWizardStepMappingTitle;
      case 5:
        return l10n.setupWizardWhatsNextTitle;
      case 6:
        return '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final l10n = context.l10n;
    final isFinal = _step == 6;
    final progress = (_step + 1) / _kSetupStepCount;

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
                l10n.setupWizardStepCounter(_step + 1, _kSetupStepCount),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (_step == 4) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Column(
              children: [
                _rainbowBar(),
                const SizedBox(height: 4),
                Text(
                  l10n.setupWizardMappingRainbowHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_stepTitle(l10n).isNotEmpty) ...[
                  Text(
                    _stepTitle(l10n),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: instant ? Duration.zero : const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
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
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress, minHeight: 4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_kSetupStepCount, (i) {
                  final on = i == _step;
                  return Semantics(
                    button: true,
                    label: l10n.onboardSlideDotA11y(i + 1, _kSetupStepCount),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setStep(i),
                        child: AnimatedContainer(
                          duration: instant ? Duration.zero : const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: on ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: on ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        if (!isFinal)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 400;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(onPressed: _next, child: Text(l10n.next)),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _step > 0 ? _prev : null, child: Text(l10n.back)),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 148,
                      child: OutlinedButton(onPressed: _step > 0 ? _prev : null, child: Text(l10n.back)),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: FilledButton(onPressed: _next, child: Text(l10n.next)),
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
          if (!isFinal) _next();
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
  bool shouldRepaint(covariant _RainbowBarPainter oldDelegate) => oldDelegate.progress != progress;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i * 0.33) % 1.0;
      final r = maxR * t;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.55);
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
