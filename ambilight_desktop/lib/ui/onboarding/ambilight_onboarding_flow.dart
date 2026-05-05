import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../application/build_environment.dart';
import '../../l10n/context_ext.dart';
import '../dashboard_ui.dart';
import 'onboarding_illustrations.dart';

final _log = Logger('Onboarding');

/// Celoplošný průvodce prvním spuštěním (nebo po resetu z „O aplikaci“).
class AmbilightOnboardingLayer extends StatelessWidget {
  const AmbilightOnboardingLayer({super.key});

  static Future<void> _finish(BuildContext context, {required bool skipped}) async {
    final ctrl = context.read<AmbilightAppController>();
    if (ambilightVerboseLogsEnabled) {
      debugPrint('[Onboarding] dokončeno (skipped=$skipped)');
    }
    _log.fine('dokončeno skipped=$skipped');
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
        child: AmbilightOnboardingFlow(
          onSkip: () => unawaited(_finish(context, skipped: true)),
          onComplete: () => unawaited(_finish(context, skipped: false)),
        ),
      ),
    );
  }
}

class AmbilightOnboardingFlow extends StatefulWidget {
  const AmbilightOnboardingFlow({
    super.key,
    required this.onSkip,
    required this.onComplete,
  });

  final VoidCallback onSkip;
  final VoidCallback onComplete;

  @override
  State<AmbilightOnboardingFlow> createState() => _AmbilightOnboardingFlowState();
}

class _OnboardingPageSpec {
  const _OnboardingPageSpec({
    required this.title,
    required this.body,
    required this.illustration,
  });

  final String title;
  final String body;
  final Widget illustration;
}

class _AmbilightOnboardingFlowState extends State<AmbilightOnboardingFlow> {
  final PageController _pageController = PageController();
  int _index = 0;

  List<_OnboardingPageSpec> _pages(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;
    return [
      _OnboardingPageSpec(
        title: l.onboardWelcomeTitle,
        body: l.onboardWelcomeBody,
        illustration: Column(
          children: [
            OnboardingPulseLogo(
              size: 112,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  dark ? 'assets/branding/app_icon_dark.png' : 'assets/branding/app_icon_light.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.blur_circular, size: 72, color: scheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
      _OnboardingPageSpec(
        title: l.onboardHowTitle,
        body: l.onboardHowBody,
        illustration: const OnboardingAmbilightScreenDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardOutputTitle,
        body: l.onboardOutputBody,
        illustration: const OnboardingOutputDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardModesTitle,
        body: l.onboardModesBody,
        illustration: const OnboardingModesTilesDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardDevicesTitle,
        body: l.onboardDevicesBody,
        illustration: const OnboardingConnectivityDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardScreenTitle,
        body: l.onboardScreenBody,
        illustration: const OnboardingAmbilightScreenDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardMusicTitle,
        body: l.onboardMusicBody,
        illustration: const OnboardingMusicBarsDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardSmartTitle,
        body: l.onboardSmartBody,
        illustration: const OnboardingPcHealthDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardFirmwareTitle,
        body: l.onboardFirmwareBody,
        illustration: const OnboardingSettingsDemo(),
      ),
      _OnboardingPageSpec(
        title: l.onboardReadyTitle,
        body: l.onboardReadyBody,
        illustration: Icon(Icons.rocket_launch_rounded, size: 72, color: scheme.primary),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    final n = _pages(context).length;
    if (_index >= n - 1) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _prev() {
    if (_index <= 0) return;
    _pageController.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final pages = _pages(context);
    final last = _index >= pages.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              TextButton(
                onPressed: widget.onSkip,
                child: Text(context.l10n.skip),
              ),
              const Spacer(),
              Text(
                context.l10n.onboardProgress(_index + 1, pages.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: instant ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = pages[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: SingleChildScrollView(
                          child: AmbiGlassPanel(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: p.illustration,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      p.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Text(
                          p.body,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  final on = i == _index;
                  return AnimatedContainer(
                    duration: instant ? Duration.zero : const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: on ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: on ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _index > 0 ? _prev : null,
                      child: Text(context.l10n.back),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(last ? context.l10n.onboardStartUsing : context.l10n.next),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
