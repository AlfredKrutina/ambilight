import 'package:flutter/material.dart';

import '../../../core/models/config_models.dart';
import '../../../l10n/context_ext.dart';
import '../config_backup_section.dart';
import '../settings_common.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';
import '../../theme_catalog.dart';
import '../../widgets/config_drag_slider.dart';

List<Widget> globalSettingsFields(
  BuildContext context,
  GlobalSettings g,
  ValueChanged<GlobalSettings> onChanged,
) {
  final l10n = context.l10n;
  final langVal = normalizeAmbilightUiLanguage(g.uiLanguage);
  final langDropdown = langVal == 'system' ? 'system' : langVal;
  final simpleUi = normalizeAmbilightUiControlLevel(g.uiControlLevel) == 'simple';

  return [
    DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.languageLabel,
        border: const OutlineInputBorder(),
      ),
      value: langDropdown,
      items: [
        DropdownMenuItem(value: 'system', child: Text(l10n.languageSystem)),
        DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
        DropdownMenuItem(value: 'cs', child: Text(l10n.languageCzech)),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(g.copyWith(uiLanguage: v));
      },
    ),
    DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.startModeLabel,
        border: const OutlineInputBorder(),
      ),
      value: g.startMode,
      items: [
        DropdownMenuItem(value: 'light', child: Text(l10n.startModeLight)),
        DropdownMenuItem(value: 'screen', child: Text(l10n.startModeScreen)),
        DropdownMenuItem(value: 'music', child: Text(l10n.startModeMusic)),
        DropdownMenuItem(value: 'pchealth', child: Text(l10n.startModePcHealth)),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(g.copyWith(startMode: v));
      },
    ),
    DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.themeLabel,
        border: const OutlineInputBorder(),
        helperText: l10n.themeHelper,
      ),
      value: normalizeAmbilightUiTheme(g.theme),
      items: [
        for (final option in AmbilightUiThemeCatalog.options)
          DropdownMenuItem(
            value: option.key,
            child: Text(AmbilightUiThemeCatalog.title(context, option.key)),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(g.copyWith(theme: v));
      },
    ),
    DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.uiControlLevelLabel,
        border: const OutlineInputBorder(),
        helperText: l10n.uiControlLevelHelper,
      ),
      value: normalizeAmbilightUiControlLevel(g.uiControlLevel),
      items: [
        DropdownMenuItem(value: 'simple', child: Text(l10n.uiControlLevelSimple)),
        DropdownMenuItem(value: 'advanced', child: Text(l10n.uiControlLevelAdvanced)),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(g.copyWith(uiControlLevel: normalizeAmbilightUiControlLevel(v)));
      },
    ),
    SwitchListTile(
      title: Text(l10n.uiAnimationsTitle),
      subtitle: Text(l10n.uiAnimationsSubtitle),
      value: g.uiAnimationsEnabled,
      onChanged: (v) => onChanged(g.copyWith(uiAnimationsEnabled: v)),
    ),
    if (!simpleUi) ...[
      SwitchListTile(
        title: Text(l10n.performanceModeTitle),
        subtitle: Text(l10n.performanceModeSubtitle),
        value: g.performanceMode,
        onChanged: (v) => onChanged(g.copyWith(performanceMode: v)),
      ),
      if (g.performanceMode) ...[
        Text(
          l10n.performanceScreenLoopPeriodLabel(g.performanceScreenLoopPeriodMs),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.performanceScreenLoopPeriodHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        ConfigDragSlider(
          value: g.performanceScreenLoopPeriodMs.toDouble(),
          min: 16,
          max: 40,
          divisions: 24,
          label: '${g.performanceScreenLoopPeriodMs}',
          onChanged: (v) => onChanged(
            g.copyWith(performanceScreenLoopPeriodMs: v.round()),
          ),
        ),
        const SizedBox(height: 8),
      ],
      DropdownButtonFormField<int>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.screenRefreshRateTitle,
          border: const OutlineInputBorder(),
          helperText: g.performanceMode ? l10n.screenRefreshRateDisabledHint : l10n.screenRefreshRateSubtitle,
        ),
        value: normalizeAmbilightScreenRefreshRateHz(g.screenRefreshRateHz),
        items: [
          for (final hz in kAmbilightScreenRefreshRatesHz)
            DropdownMenuItem(
              value: hz,
              child: Text(
                switch (hz) {
                  60 => l10n.screenRefreshRateHz60,
                  120 => l10n.screenRefreshRateHz120,
                  _ => l10n.screenRefreshRateHz240,
                },
              ),
            ),
        ],
        onChanged: g.performanceMode
            ? null
            : (v) {
                if (v == null) return;
                onChanged(g.copyWith(screenRefreshRateHz: v));
              },
      ),
    ],
    SwitchListTile(
      title: Text(l10n.autostartTitle),
      subtitle: Text(l10n.autostartSubtitle),
      value: g.autostart,
      onChanged: (v) => onChanged(g.copyWith(autostart: v)),
    ),
    SwitchListTile(
      title: Text(l10n.startMinimizedTitle),
      value: g.startMinimized,
      onChanged: (v) => onChanged(g.copyWith(startMinimized: v)),
    ),
    if (!simpleUi)
      Builder(
        builder: (context) {
          final trimmed = g.captureMethod.trim();
          final value = trimmed.isEmpty || trimmed == 'mss' ? 'mss' : trimmed;
          final items = <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'mss', child: Text(l10n.captureMethodNativeMss)),
            if (value != 'mss')
              DropdownMenuItem(
                value: value,
                child: Text(l10n.captureMethodCustomSaved(value)),
              ),
          ];
          return DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.captureMethodLabel,
              border: const OutlineInputBorder(),
              helperText: l10n.captureMethodHelper,
            ),
            value: value,
            items: items,
            onChanged: (v) {
              if (v == null) return;
              onChanged(g.copyWith(captureMethod: v));
            },
          );
        },
      ),
  ];
}

class GlobalSettingsTab extends StatelessWidget {
  const GlobalSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
    this.onImportedFromDisk,
    this.onReplayOnboarding,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<GlobalSettings> onChanged;
  final VoidCallback? onImportedFromDisk;
  /// Okamžitě uloží `onboarding_completed: false` a znovu zobrazí úvodní průvodce (nad hlavním UI).
  final VoidCallback? onReplayOnboarding;

  @override
  Widget build(BuildContext context) {
    final g = draft.globalSettings;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);
    final fields = globalSettingsFields(context, g, onChanged);
    const splitAt = 4;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AmbiSectionHeader(
                title: context.l10n.globalSectionTitle,
                subtitle: context.l10n.globalSectionSubtitle,
                bottomSpacing: 12,
              ),
              if (AppBreakpoints.formColumnsForWidth(innerMax) >= 2)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: paddedSettingsColumn(fields.take(splitAt))),
                    const SizedBox(width: 16),
                    Expanded(child: paddedSettingsColumn(fields.skip(splitAt))),
                  ],
                )
              else
                paddedSettingsColumn(fields),
              if (onReplayOnboarding != null) ...[
                const SizedBox(height: 22),
                Text(
                  context.l10n.onboardingReplayTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.onboardingReplayBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onReplayOnboarding,
                  icon: const Icon(Icons.auto_stories_outlined, size: 20),
                  label: Text(context.l10n.replayOnboardingButton),
                ),
              ],
              ConfigBackupSection(onImported: onImportedFromDisk),
            ],
          ),
        ),
      ),
    );
  }
}
