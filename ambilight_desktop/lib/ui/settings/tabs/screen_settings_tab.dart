import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/ambilight_presets.dart';
import '../../../core/models/config_models.dart';
import '../../../features/screen_capture/screen_capture_source.dart';
import '../../../features/screen_overlay/scan_overlay_controller.dart';
import '../../../features/screen_overlay/screen_scan_settings_tab.dart';
import '../settings_common.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/config_drag_slider.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonitors());
  }

  Future<void> _loadMonitors() async {
    if (kIsWeb) return;
    try {
      final list = await ScreenCaptureSource.platform().listMonitors();
      if (mounted) setState(() => _monitors = list);
    } catch (_) {}
  }

  bool get _advanced => widget.draft.screenMode.scanMode == 'advanced';

  void _patch(ScreenModeSettings next) => widget.onChanged(next);

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
    if (_monitors.isEmpty) return wanted;
    final ids = _monitors.map((e) => e.mssStyleIndex).toSet();
    if (ids.contains(wanted)) return wanted;
    return _monitors.first.mssStyleIndex;
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
    final s = widget.draft.screenMode;
    final presetDropdownItems = _activePresetDropdownItems(s);
    final presetDropdownValue = _activePresetDropdownValue(s, presetDropdownItems);
    final calProfileItems = _calibrationProfileDropdownItems(s);
    final calProfileValue = _calibrationProfileDropdownValue(s, calProfileItems);
    final innerMax = AppBreakpoints.maxContentWidth(widget.maxWidth).clamp(280.0, widget.maxWidth);

    Widget modeBar() {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Režim nastavení', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'simple', label: Text('Jednoduchý'), icon: Icon(Icons.tune)),
                  ButtonSegment(
                    value: 'advanced',
                    label: Text('Rozšířený'),
                    icon: Icon(Icons.tune_outlined),
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
                _advanced
                    ? 'Zobrazí se všechna pole včetně barevných křivek, technického indexu monitoru a per‑hrana v sekci náhledu.'
                    : 'Stačí monitor, jas, plynulost a jednotná hloubka / odsazení skenu. Detailní zóny v náhledu dole.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    Widget monitorSimple() {
      if (_monitors.isEmpty) {
        return TextFormField(
          key: ValueKey('mon-${s.monitorIndex}'),
          initialValue: '${s.monitorIndex}',
          decoration: const InputDecoration(
            labelText: 'Monitor (index)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            final n = int.tryParse(v) ?? s.monitorIndex;
            _patch(s.copyWith(monitorIndex: n.clamp(0, 32)));
          },
        );
      }
      return DropdownButtonFormField<int>(
        decoration: const InputDecoration(
          labelText: 'Monitor (shodně se snímáním)',
          border: OutlineInputBorder(),
        ),
        value: _validMonitorDropdownValue(s.monitorIndex),
        items: _monitors
            .map(
              (m) => DropdownMenuItem(
                value: m.mssStyleIndex,
                child: Text(
                  '${m.mssStyleIndex}: ${m.width}×${m.height} @ (${m.left},${m.top})${m.isPrimary ? ' ★' : ''}',
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          _patch(s.copyWith(monitorIndex: v));
        },
      );
    }

    Widget unifiedScanSliders() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hloubka snímání (jednotně): ${s.scanDepthPercent} %',
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
          Text('Odsazení (jednotně): ${s.paddingPercent} %', style: Theme.of(context).textTheme.labelLarge),
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
        ],
      );
    }

    final baseCard = <Widget>[
      AmbiSectionHeader(
        title: 'Obrazovka',
        subtitle:
            'Režim screen: barvy z okrajů monitoru. Kalibraci a segmenty upravíš i v Zařízeních. '
            'Náhled zón při ladění je jen vrstva v okně aplikace (zvýrazněné pruhy skenu, bez přesunu okna).',
        bottomSpacing: 12,
      ),
      if (!kIsWeb)
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
                    Text('Snímání obrazovky', style: Theme.of(context).textTheme.titleSmall),
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
                          label: const Text('Obnovit diagnostiku'),
                        ),
                        if (Platform.isMacOS)
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final ok = await ctrl.requestOsScreenCapturePermission();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Oprávnění obrazovky: OK / zkontroluj Soukromí.'
                                        : 'Oprávnění zamítnuto nebo nedostupné.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.security, size: 18),
                            label: const Text('macOS: žádost o snímání obrazovky'),
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
      modeBar(),
      const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Obraz a výstup', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              if (!_advanced) monitorSimple(),
              Text('Jas (screen): ${s.brightness}', style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.brightness.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                label: '${s.brightness}',
                onChanged: (v) => _patch(s.copyWith(brightness: v.round())),
              ),
              Text('Interpolace (ms): ${s.interpolationMs}', style: Theme.of(context).textTheme.labelLarge),
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
              Text('Oblast snímání (jednotné)', style: Theme.of(context).textTheme.titleSmall),
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
              Text('Technický monitor a jednotná oblast', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('mi-${s.monitorIndex}'),
                initialValue: '${s.monitorIndex}',
                decoration: const InputDecoration(
                  labelText: 'monitor_index (MSS, 0–32)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v) ?? s.monitorIndex;
                  _patch(s.copyWith(monitorIndex: n.clamp(0, 32)));
                },
              ),
              if (_monitors.isNotEmpty) ...[
                const SizedBox(height: 10),
                monitorSimple(),
              ],
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
              Text('Barvy a sken (podrobně)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text('Gamma: ${s.gamma.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.gamma,
                min: 0.5,
                max: 4.0,
                divisions: 35,
                label: s.gamma.toStringAsFixed(2),
                onChanged: (v) => _patch(s.copyWith(gamma: v)),
              ),
              Text('Saturation boost: ${s.saturationBoost.toStringAsFixed(2)}',
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
                title: const Text('Ultra saturace'),
                value: s.ultraSaturation,
                onChanged: (v) => _patch(s.copyWith(ultraSaturation: v)),
              ),
              Text('Ultra amount: ${s.ultraSaturationAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.ultraSaturationAmount,
                min: 1.0,
                max: 5.0,
                divisions: 40,
                label: s.ultraSaturationAmount.toStringAsFixed(2),
                onChanged: (v) => _patch(s.copyWith(ultraSaturationAmount: v)),
              ),
              Text('Min. jas (LED): ${s.minBrightness}', style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: s.minBrightness.toDouble(),
                min: 0,
                max: 255,
                divisions: 25,
                label: '${s.minBrightness}',
                onChanged: (v) => _patch(s.copyWith(minBrightness: v.round())),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Barevný preset obrazovky',
                  helperText: 'Rychlé presety, výchozí názvy a uložené user_screen_presets',
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Aktivní kalibrační profil',
                  helperText: 'Klíče z calibration_profiles v konfiguraci',
                  border: OutlineInputBorder(),
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
      Consumer<AmbilightAppController>(
        builder: (context, ctrl, _) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Značky na pásku', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Zelené LED v rozích (jako PyQt kalibrace). Při indikaci se použije max. délka pro transport '
                    '(USB až 2000 LED s wide rámcem 0xFC, Wi‑Fi dle UDP), ne zadaný počet LED v zařízení — aby šly rozsvítit i vysoké indexy. '
                    '„Vypnout“ před uložením nebo při přepnutí záložky.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => ctrl.setCalibrationLedMarkers('top_left'),
                        child: const Text('Levý horní'),
                      ),
                      OutlinedButton(
                        onPressed: () => ctrl.setCalibrationLedMarkers('top_right'),
                        child: const Text('Pravý horní'),
                      ),
                      OutlinedButton(
                        onPressed: () => ctrl.setCalibrationLedMarkers('bottom_right'),
                        child: const Text('Pravý spodní'),
                      ),
                      OutlinedButton(
                        onPressed: () => ctrl.setCalibrationLedMarkers('bottom_left'),
                        child: const Text('Levý spodní'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => ctrl.setCalibrationLedMarkers(null),
                        child: const Text('Vypnout značky'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Segmenty'),
        subtitle: Text('Počet: ${s.segments.length} (editor zón A7)'),
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
