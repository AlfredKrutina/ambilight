import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../../features/screen_overlay/screen_scan_settings_tab.dart';
import '../settings_common.dart';
import '../../layout_breakpoints.dart';

/// D5 — základní pole `ScreenModeSettings` (plný segment editor = A7 / A3).
class ScreenSettingsTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final s = draft.screenMode;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);

    final fields = <Widget>[
      Text('Obrazovka (screen_mode)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Kalibrace wizard (D12) a plný segment editor (A7) navazují zde; scan overlay viz sekce níže.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (!kIsWeb)
        Consumer<AmbilightAppController>(
          builder: (context, ctrl, _) {
            final s = ctrl.captureSessionInfo;
            final buf = StringBuffer()
              ..write('${s.platform} · ${s.sessionType}')
              ..write(s.captureBackend != null ? ' · ${s.captureBackend}' : '');
            if (s.note != null && s.note!.isNotEmpty) {
              buf.write('\n${s.note}');
            }
            return Card(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Snímání obrazovky (nativní)', style: Theme.of(context).textTheme.titleSmall),
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
                                SnackBar(content: Text(ok ? 'Oprávnění obrazovky: OK / zkontroluj Soukromí.' : 'Oprávnění zamítnuto nebo nedostupné.')),
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
      const SizedBox(height: 12),
      TextFormField(
        initialValue: '${s.monitorIndex}',
        decoration: const InputDecoration(
          labelText: 'monitor_index',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          final n = int.tryParse(v) ?? s.monitorIndex;
          onChanged(s.copyWith(monitorIndex: n.clamp(0, 32)));
        },
      ),
      Text('Jas (screen): ${s.brightness}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.brightness.toDouble().clamp(0, 255),
        max: 255,
        divisions: 255,
        label: '${s.brightness}',
        onChanged: (v) => onChanged(s.copyWith(brightness: v.round())),
      ),
      Text('Interpolace (ms): ${s.interpolationMs}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.interpolationMs.toDouble().clamp(0, 500),
        max: 500,
        divisions: 50,
        label: '${s.interpolationMs}',
        onChanged: (v) => onChanged(s.copyWith(interpolationMs: v.round())),
      ),
      Text('Gamma: ${s.gamma.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.gamma.clamp(0.5, 4.0),
        min: 0.5,
        max: 4.0,
        divisions: 35,
        label: s.gamma.toStringAsFixed(2),
        onChanged: (v) => onChanged(s.copyWith(gamma: v)),
      ),
      Text('Saturation boost: ${s.saturationBoost.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.saturationBoost.clamp(0.5, 3.0),
        min: 0.5,
        max: 3.0,
        divisions: 25,
        label: s.saturationBoost.toStringAsFixed(2),
        onChanged: (v) => onChanged(s.copyWith(saturationBoost: v)),
      ),
      SwitchListTile(
        title: const Text('Ultra saturace'),
        value: s.ultraSaturation,
        onChanged: (v) => onChanged(s.copyWith(ultraSaturation: v)),
      ),
      Text('Ultra amount: ${s.ultraSaturationAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.ultraSaturationAmount.clamp(1.0, 5.0),
        min: 1.0,
        max: 5.0,
        divisions: 40,
        label: s.ultraSaturationAmount.toStringAsFixed(2),
        onChanged: (v) => onChanged(s.copyWith(ultraSaturationAmount: v)),
      ),
      Text('Min. jas (LED): ${s.minBrightness}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.minBrightness.toDouble().clamp(0, 255),
        max: 255,
        divisions: 25,
        label: '${s.minBrightness}',
        onChanged: (v) => onChanged(s.copyWith(minBrightness: v.round())),
      ),
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'scan_mode', border: OutlineInputBorder()),
        value: ['simple', 'advanced'].contains(s.scanMode) ? s.scanMode : 'simple',
        items: const [
          DropdownMenuItem(value: 'simple', child: Text('simple')),
          DropdownMenuItem(value: 'advanced', child: Text('advanced')),
        ],
        onChanged: (v) {
          if (v == null) return;
          onChanged(s.copyWith(scanMode: v));
        },
      ),
      Text('Scan depth %: ${s.scanDepthPercent}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.scanDepthPercent.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        label: '${s.scanDepthPercent}',
        onChanged: (v) => onChanged(s.copyWith(scanDepthPercent: v.round())),
      ),
      Text('Padding %: ${s.paddingPercent}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: s.paddingPercent.toDouble().clamp(0, 50),
        max: 50,
        divisions: 50,
        label: '${s.paddingPercent}',
        onChanged: (v) => onChanged(s.copyWith(paddingPercent: v.round())),
      ),
      TextFormField(
        initialValue: s.activePreset,
        decoration: const InputDecoration(
          labelText: 'active_preset',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => onChanged(s.copyWith(activePreset: v.trim().isEmpty ? s.activePreset : v.trim())),
      ),
      TextFormField(
        initialValue: s.activeCalibrationProfile,
        decoration: const InputDecoration(
          labelText: 'active_calibration_profile',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) =>
            onChanged(s.copyWith(activeCalibrationProfile: v.trim().isEmpty ? s.activeCalibrationProfile : v.trim())),
      ),
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
                    'Zelené LED v rozích (jako PyQt kalibrace). „Vypnout“ před uložením nebo při přepnutí záložky.',
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
        draft: draft,
        maxWidth: maxWidth,
        onScreenModeChanged: onChanged,
      ),
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
