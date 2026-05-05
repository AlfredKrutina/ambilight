import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../../../application/pipeline_diagnostics.dart' show ambilightPipelineDiagnosticsEnabled;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/ambilight_presets.dart';
import '../../../core/models/config_models.dart';
import '../../../engine/screen/screen_color_pipeline.dart';
import '../../../features/screen_capture/screen_capture_source.dart';
import '../../../features/screen_overlay/scan_overlay_controller.dart';
import '../../../features/screen_overlay/screen_scan_settings_tab.dart';
import '../settings_common.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/config_drag_slider.dart';
import '../../../l10n/context_ext.dart';

/// D5 — [ScreenModeSettings]: jednoduchý / rozšířený režim, plná funkčnost zachována.
class ScreenSettingsTab extends StatefulWidget {
  const ScreenSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<ScreenModeSettings> onChanged;

  @override
  State<ScreenSettingsTab> createState() => _ScreenSettingsTabState();
}

class _ScreenSettingsTabState extends State<ScreenSettingsTab> {
  List<MonitorInfo> _monitors = const [];
  bool _monitorsLoading = false;

  /// Když [listMonitors] selže / vrátí prázdný seznam — MSS indexy 0…12 jako rozumný fallback (0 = virtuální plocha).
  static List<MonitorInfo> _syntheticMonitorPickList() {
    return [
      const MonitorInfo(mssStyleIndex: 0, left: 0, top: 0, width: 0, height: 0),
      for (var i = 1; i <= 12; i++)
        MonitorInfo(mssStyleIndex: i, left: 0, top: 0, width: 0, height: 0),
    ];
  }

  List<MonitorInfo> get _monitorsForUi =>
      _monitors.isNotEmpty ? _monitors : _syntheticMonitorPickList();

  bool get _monitorsAreSynthetic => _monitors.isEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonitors());
  }

  Future<void> _loadMonitors() async {
    if (kIsWeb) return;
    setState(() => _monitorsLoading = true);
    try {
      final list = await ScreenCaptureSource.platform().listMonitors();
      if (!mounted) return;
      setState(() => _monitors = list);
    } catch (_) {
      if (mounted) setState(() => _monitors = const []);
    } finally {
      if (mounted) setState(() => _monitorsLoading = false);
    }
  }

  bool get _simpleUi =>
      normalizeAmbilightUiControlLevel(widget.draft.globalSettings.uiControlLevel) == 'simple';

  bool get _advanced => !_simpleUi && widget.draft.screenMode.scanMode == 'advanced';

  void _patch(ScreenModeSettings next) => widget.onChanged(next);

  /// Shodně s [ScreenColorPipeline] / JSON PyQt `color_sampling`.
  static String _normalizeColorSamplingDropdown(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'average' || t == 'mean' || t == 'avg') return 'average';
    return 'median';
  }

  void _onLiveScanWhileDragging(ScreenModeSettings next) {
    unawaited(
      context.read<ScanOverlayController>().ensureShownForLivePreview(
            next,
            next.monitorIndex,
          ),
    );
  }

  void _onLiveScanAfterRelease() {
    context.read<ScanOverlayController>().scheduleAutoHideAfterSliderRelease();
  }

  int _validMonitorDropdownValue(int wanted) {
    final list = _monitorsForUi;
    final ids = list.map((e) => e.mssStyleIndex).toSet();
    if (ids.contains(wanted)) return wanted;
    return list.first.mssStyleIndex;
  }

  String _monitorDropdownLabel(BuildContext context, MonitorInfo m) {
    final l10n = context.l10n;
    if (!_monitorsAreSynthetic) {
      return '${m.mssStyleIndex}: ${m.width}×${m.height} @ (${m.left},${m.top})${m.isPrimary ? ' ★' : ''}';
    }
    if (m.mssStyleIndex == 0) return l10n.screenMonitorVirtualDesktopChoice;
    return l10n.scanMonitorNoEnum(m.mssStyleIndex);
  }

  static const _builtinScreenPresetLabels = <String>['Balanced', 'Custom'];

  List<String> _activePresetDropdownItems(ScreenModeSettings sm) {
    final set = <String>{
      ...AmbilightPresets.screenNames,
      ..._builtinScreenPresetLabels,
      ...widget.draft.userScreenPresets.keys,
      sm.activePreset,
    };
    final out = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  String _activePresetDropdownValue(ScreenModeSettings sm, List<String> items) {
    if (items.contains(sm.activePreset)) return sm.activePreset;
    return items.isNotEmpty ? items.first : sm.activePreset;
  }

  List<String> _calibrationProfileDropdownItems(ScreenModeSettings sm) {
    final set = <String>{
      'Default',
      ...sm.calibrationProfiles.keys,
      sm.activeCalibrationProfile,
    };
    final out = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  String _calibrationProfileDropdownValue(ScreenModeSettings sm, List<String> items) {
    if (items.contains(sm.activeCalibrationProfile)) return sm.activeCalibrationProfile;
    return items.isNotEmpty ? items.first : sm.activeCalibrationProfile;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.draft.screenMode;
    final presetDropdownItems = _activePresetDropdownItems(s);
    final presetDropdownValue = _activePresetDropdownValue(s, presetDropdownItems);
    final calProfileItems = _calibrationProfileDropdownItems(s);
    final calProfileValue = _calibrationProfileDropdownValue(s, calProfileItems);
    final innerMax = AppBreakpoints.settingsContentInnerMax(widget.maxWidth);

    Widget modeBar() {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.screenSettingsLayoutTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'simple',
                    label: Text(l10n.screenModeSimpleLabel),
                    icon: const Icon(Icons.tune),
                  ),
                  ButtonSegment(
                    value: 'advanced',
                    label: Text(l10n.screenModeAdvancedLabel),
                    icon: const Icon(Icons.tune_outlined),
                  ),
                ],
                selected: {_advanced ? 'advanced' : 'simple'},
                onSelectionChanged: (set) {
                  final v = set.first;
                  _patch(s.copyWith(scanMode: v));
                },
              ),
              const SizedBox(height: 6),
              Text(
                _advanced ? l10n.screenModeHintAdvanced : l10n.screenModeHintSimple,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    Widget monitorPicker() {
      final list = _monitorsForUi;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: _monitorsAreSynthetic
                        ? l10n.fieldMonitorIndexLabel
                        : l10n.fieldMonitorSameAsCaptureLabel,
                    border: const OutlineInputBorder(),
                  ),
                  value: _validMonitorDropdownValue(s.monitorIndex),
                  items: [
                    for (final m in list)
                      DropdownMenuItem<int>(
                        value: m.mssStyleIndex,
                        child: Text(_monitorDropdownLabel(context, m)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _patch(s.copyWith(monitorIndex: v.clamp(0, 32)));
                  },
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l10n.screenMonitorRefreshTooltip,
                  onPressed: _monitorsLoading ? null : () => unawaited(_loadMonitors()),
                  icon: _monitorsLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ],
          ),
          if (_monitorsAreSynthetic && !kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.screenMonitorListFallbackHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
        ],
      );
    }

    List<Widget> windowsCaptureBackendWidgets() {
      if (kIsWeb || !Platform.isWindows) return const <Widget>[];
      final v = s.windowsCaptureBackend;
      return <Widget>[
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: l10n.screenWindowsCaptureBackendLabel,
            helperText: l10n.screenWindowsCaptureBackendHint,
            border: const OutlineInputBorder(),
          ),
          value: v == 'dxgi' ? 'dxgi' : 'gdi',
          items: [
            DropdownMenuItem(value: 'gdi', child: Text(l10n.screenWindowsCaptureBackendCpu)),
            DropdownMenuItem(value: 'dxgi', child: Text(l10n.screenWindowsCaptureBackendGpu)),
          ],
          onChanged: (nv) {
            if (nv == null) return;
            _patch(s.copyWith(windowsCaptureBackend: nv));
          },
        ),
      ];
    }

    Widget unifiedScanSliders() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.screenScanDepthUniformPct(s.scanDepthPercent),
              style: Theme.of(context).textTheme.labelLarge),
          ConfigDragSlider(
            value: s.scanDepthPercent.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${s.scanDepthPercent}',
            onChanged: (v) {
              final next = s.copyWith(scanDepthPercent: v.round());
              _patch(next);
              _onLiveScanWhileDragging(next);
            },
            onChangeEnd: _onLiveScanAfterRelease,
          ),
          Text(l10n.screenPaddingUniformPct(s.paddingPercent), style: Theme.of(context).textTheme.labelLarge),
          ConfigDragSlider(
            value: s.paddingPercent.toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            label: '${s.paddingPercent}',
            onChanged: (v) {
              final next = s.copyWith(paddingPercent: v.round());
              _patch(next);
              _onLiveScanWhileDragging(next);
            },
            onChangeEnd: _onLiveScanAfterRelease,
          ),
          const SizedBox(height: 12),
          Text(l10n.screenColorSamplingLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _normalizeColorSamplingDropdown(s.colorSampling),
            decoration: InputDecoration(
              isDense: true,
              helperText: l10n.screenColorSamplingHint,
            ),
            items: [
              DropdownMenuItem(value: 'median', child: Text(l10n.screenColorSamplingMedian)),
              DropdownMenuItem(value: 'average', child: Text(l10n.screenColorSamplingAverage)),
            ],
            onChanged: (v) {
              if (v == null) return;
              final next = s.copyWith(colorSampling: v);
              _patch(next);
              _onLiveScanWhileDragging(next);
            },
          ),
        ],
      );
    }

    final baseCard = <Widget>[
      AmbiSectionHeader(
        title: l10n.screenSectionTitle,
        subtitle: l10n.screenSectionSubtitle,
        bottomSpacing: 12,
      ),
      if (!kIsWeb && !_simpleUi)
        Selector<AmbilightAppController, ScreenSessionInfo>(
          selector: (_, ctrl) => ctrl.captureSessionInfo,
          builder: (context, cap, _) {
            final ctrl = context.read<AmbilightAppController>();
            final buf = StringBuffer()
              ..write('${cap.platform} · ${cap.sessionType}')
              ..write(cap.captureBackend != null ? ' · ${cap.captureBackend}' : '');
            if (cap.note != null && cap.note!.isNotEmpty) {
              buf.write('\n${cap.note}');
            }
            return Card(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.screenCaptureCardTitle, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    SelectableText(buf.toString(), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => ctrl.refreshCaptureSessionInfo(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(l10n.refreshDiagnostics),
                        ),
                        if (Platform.isMacOS)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final ok = await ctrl.requestOsScreenCapturePermission();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok ? l10n.screenCapturePermissionOk : l10n.screenCapturePermissionDenied,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.security, size: 18),
                            label: Text(l10n.macosRequestScreenCapture),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      const SizedBox(height: 8),
      if (!_simpleUi) modeBar(),
      if (!_simpleUi) const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.screenImageOutputTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              if (!_advanced) monitorPicker(),
              ...windowsCaptureBackendWidgets(),
              Text(l10n.screenBrightnessValue(s.brightness), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.brightness.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                label: '${s.brightness}',
                onChanged: (v) => _patch(s.copyWith(brightness: v.round())),
              ),
              Text(l10n.screenInterpolationMs(s.interpolationMs), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.interpolationMs.toDouble(),
                min: 0,
                max: 500,
                divisions: 50,
                label: '${s.interpolationMs}',
                onChanged: (v) => _patch(s.copyWith(interpolationMs: v.round())),
              ),
            ],
          ),
        ),
      ),
    ];

    final simpleExtra = <Widget>[
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.screenUniformRegionTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              unifiedScanSliders(),
            ],
          ),
        ),
      ),
    ];

    final advancedExtra = <Widget>[
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.screenTechMonitorTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              monitorPicker(),
              ...windowsCaptureBackendWidgets(),
              const SizedBox(height: 12),
              unifiedScanSliders(),
            ],
          ),
        ),
      ),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.screenColorsDetailTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(l10n.screenGammaValue(s.gamma.toStringAsFixed(2)), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.gamma,
                min: 0.5,
                max: 4.0,
                divisions: 35,
                label: s.gamma.toStringAsFixed(2),
                onChanged: (v) => _patch(s.copyWith(gamma: v)),
              ),
              Text(l10n.screenSaturationBoostValue(s.saturationBoost.toStringAsFixed(2)),
                  style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.saturationBoost,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: s.saturationBoost.toStringAsFixed(2),
                onChanged: (v) => _patch(s.copyWith(saturationBoost: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.screenUltraSaturation),
                value: s.ultraSaturation,
                onChanged: (v) => _patch(s.copyWith(ultraSaturation: v)),
              ),
              Text(l10n.screenUltraAmountValue(s.ultraSaturationAmount.toStringAsFixed(2)),
                  style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.ultraSaturationAmount,
                min: 1.0,
                max: 5.0,
                divisions: 40,
                label: s.ultraSaturationAmount.toStringAsFixed(2),
                onChanged: (v) => _patch(s.copyWith(ultraSaturationAmount: v)),
              ),
              Text(l10n.screenMinBrightnessLed(s.minBrightness), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.minBrightness.toDouble(),
                min: 0,
                max: 255,
                divisions: 25,
                label: '${s.minBrightness}',
                onChanged: (v) => _patch(s.copyWith(minBrightness: v.round())),
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: l10n.fieldScreenColorPreset,
                  helperText: l10n.helperScreenColorPreset,
                  border: const OutlineInputBorder(),
                ),
                value: presetDropdownValue,
                items: presetDropdownItems
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _patch(s.copyWith(activePreset: v));
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: l10n.fieldActiveCalibrationProfile,
                  helperText: l10n.helperCalibrationProfileKeys,
                  border: const OutlineInputBorder(),
                ),
                value: calProfileValue,
                items: calProfileItems
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _patch(s.copyWith(activeCalibrationProfile: v));
                },
              ),
            ],
          ),
        ),
      ),
    ];

    final tail = <Widget>[
      if (!_simpleUi)
        Consumer<AmbilightAppController>(
          builder: (context, ctrl, _) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.stripMarkersTitle, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      l10n.stripMarkersBody,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => ctrl.setCalibrationLedMarkers('top_left'),
                          child: Text(l10n.markerTopLeft),
                        ),
                        OutlinedButton(
                          onPressed: () => ctrl.setCalibrationLedMarkers('top_right'),
                          child: Text(l10n.markerTopRight),
                        ),
                        OutlinedButton(
                          onPressed: () => ctrl.setCalibrationLedMarkers('bottom_right'),
                          child: Text(l10n.markerBottomRight),
                        ),
                        OutlinedButton(
                          onPressed: () => ctrl.setCalibrationLedMarkers('bottom_left'),
                          child: Text(l10n.markerBottomLeft),
                        ),
                        FilledButton.tonal(
                          onPressed: () => ctrl.setCalibrationLedMarkers(null),
                          child: Text(l10n.markerOff),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      if (!_simpleUi && (kDebugMode || ambilightPipelineDiagnosticsEnabled))
        Consumer<AmbilightAppController>(
          builder: (context, ctrl, _) {
            final scheme = Theme.of(context).colorScheme;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.screenRainbowSynthSectionTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.screenRainbowSynthSwitchTitle),
                      subtitle: Text(
                        l10n.screenRainbowSynthSwitchSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      value: ctrl.rainbowSynthBypassCapture,
                      onChanged: ctrl.setRainbowSynthBypassCapture,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      if (!_simpleUi)
        Builder(
          builder: (context) {
            final warn = ScreenColorPipeline.screenSegmentCaptureWarnings(widget.draft);
            if (warn.isEmpty) return const SizedBox.shrink();
            final scheme = Theme.of(context).colorScheme;
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
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.segmentsTileTitle),
        subtitle: Text(l10n.segmentsZoneEditorSubtitle(s.segments.length)),
      ),
      ScreenScanOverlaySection(
        draft: widget.draft,
        maxWidth: widget.maxWidth,
        onScreenModeChanged: widget.onChanged,
        advancedScanLayout: _advanced,
      ),
    ];

    final fields = <Widget>[
      ...baseCard,
      if (!_advanced) ...simpleExtra else ...advancedExtra,
      ...tail,
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: paddedSettingsColumn(fields),
        ),
      ),
    );
  }
}
