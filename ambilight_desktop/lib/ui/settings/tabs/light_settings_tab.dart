import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/ambi_color_picker_dialog.dart';
import '../../widgets/config_drag_slider.dart';
import '../../../l10n/context_ext.dart';
import '../../../l10n/generated/app_localizations.dart';

Future<List<int>?> _pickZoneColor(
  BuildContext context,
  List<int> initial,
  AmbilightAppController ctrl,
) {
  return showAmbiColorPickerDialog(
    context,
    title: AppLocalizations.of(context).lightZoneColorTitle,
    initialRgb: initial.length >= 3 ? initial : [255, 0, 0],
    onLiveRgb: (rgb) {
      if (rgb.length == 3) ctrl.previewStripColor(rgb[0], rgb[1], rgb[2], durationTicks: 72);
    },
  );
}

Color _colorFromRgb(List<int> rgb) {
  if (rgb.length < 3) return Colors.orange;
  return Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1);
}

Future<void> _pickLightPrimaryColor(
  BuildContext context,
  LightModeSettings lm,
  ValueChanged<LightModeSettings> onChanged,
) async {
  final ctrl = context.read<AmbilightAppController>();
  final r0 = lm.color.isNotEmpty ? lm.color[0] : 255;
  final g0 = lm.color.length > 1 ? lm.color[1] : 200;
  final b0 = lm.color.length > 2 ? lm.color[2] : 100;
  try {
    final res = await showAmbiColorPickerDialog(
      context,
      title: AppLocalizations.of(context).lightPrimaryColorTitle,
      initialRgb: [r0, g0, b0],
      onLiveRgb: (rgb) {
        if (rgb.length == 3) {
          ctrl.previewStripColor(rgb[0], rgb[1], rgb[2], durationTicks: 72);
        }
      },
    );
    if (res != null && res.length == 3) {
      onChanged(lm.copyWith(color: res));
    }
  } finally {
    ctrl.clearStripColorPreview();
  }
}

class LightSettingsTab extends StatelessWidget {
  const LightSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<LightModeSettings> onChanged;

  static const _effects = ['static', 'breathing', 'rainbow', 'chase', 'custom_zones'];

  static String _effectLabel(AppLocalizations l10n, String e) => switch (e) {
        'static' => l10n.lightEffectStatic,
        'breathing' => l10n.lightEffectBreathing,
        'rainbow' => l10n.lightEffectRainbow,
        'chase' => l10n.lightEffectChase,
        'custom_zones' => l10n.lightEffectCustomZones,
        _ => e,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lm = draft.lightMode;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);
    final zones = lm.customZones;

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
                title: l10n.lightSettingsHeader,
                subtitle: l10n.lightSettingsSubtitle,
                bottomSpacing: 12,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.lightPrimaryColorTile),
                subtitle: Text(l10n.lightPrimaryColorRgbHint(lm.color.join(', '))),
                trailing: IconButton.filledTonal(
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => _pickLightPrimaryColor(context, lm, onChanged),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: _colorFromRgb(lm.color),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l10n.fieldEffect, border: const OutlineInputBorder()),
                value: _effects.contains(lm.effect) ? lm.effect : 'static',
                items: _effects.map((e) => DropdownMenuItem(value: e, child: Text(_effectLabel(l10n, e)))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(lm.copyWith(effect: v));
                },
              ),
              const SizedBox(height: 12),
              Text(l10n.lightSpeedValue(lm.speed), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: lm.speed.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                label: '${lm.speed}',
                onChanged: (v) => onChanged(lm.copyWith(speed: v.round())),
              ),
              Text(l10n.lightExtraValue(lm.extra), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: lm.extra.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                label: '${lm.extra}',
                onChanged: (v) => onChanged(lm.copyWith(extra: v.round())),
              ),
              Text(l10n.lightBrightnessValue(lm.brightness), style: Theme.of(context).textTheme.labelLarge),
              ConfigDragSlider(
                value: lm.brightness.toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                label: '${lm.brightness}',
                onChanged: (v) => onChanged(lm.copyWith(brightness: v.round())),
              ),
              Text(l10n.lightSmoothingMs(lm.smoothingMs), style: Theme.of(context).textTheme.labelLarge),
              Text(
                l10n.lightSmoothingHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              ConfigDragSlider(
                value: lm.smoothingMs.toDouble(),
                min: 0,
                max: 500,
                divisions: 50,
                label: '${lm.smoothingMs}',
                onChanged: (v) => onChanged(lm.copyWith(smoothingMs: v.round())),
              ),
              SwitchListTile(
                title: Text(l10n.lightHomekitTile),
                subtitle: Text(l10n.lightHomekitSubtitle),
                value: lm.homekitEnabled,
                onChanged: (v) => onChanged(lm.copyWith(homekitEnabled: v)),
              ),
              const Divider(height: 32),
              Text(l10n.lightCustomZonesTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final nextZones = List<CustomZone>.from(zones)
                    ..add(
                      CustomZone(
                        name: l10n.lightZoneDefaultName(zones.length + 1),
                        start: 0,
                        end: 20,
                        color: const [255, 0, 0],
                      ),
                    );
                  onChanged(lm.copyWith(customZones: nextZones));
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.lightAddZone),
              ),
              const SizedBox(height: 12),
              ...zones.asMap().entries.map((e) {
                final zi = e.key;
                final z = e.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text(z.name),
                    subtitle: Text('${z.start.toStringAsFixed(0)}–${z.end.toStringAsFixed(0)} %'),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      TextFormField(
                        initialValue: z.name,
                        decoration: InputDecoration(labelText: l10n.fieldZoneName, border: const OutlineInputBorder()),
                        onChanged: (v) {
                          final list = List<CustomZone>.from(zones);
                          list[zi] = z.copyWith(name: v);
                          onChanged(lm.copyWith(customZones: list));
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: '${z.start}',
                              decoration: InputDecoration(
                                labelText: l10n.fieldStartPercent,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) {
                                final list = List<CustomZone>.from(zones);
                                list[zi] = z.copyWith(start: double.tryParse(v.replaceAll(',', '.')) ?? z.start);
                                onChanged(lm.copyWith(customZones: list));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: '${z.end}',
                              decoration: InputDecoration(
                                labelText: l10n.fieldEndPercent,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) {
                                final list = List<CustomZone>.from(zones);
                                list[zi] = z.copyWith(end: double.tryParse(v.replaceAll(',', '.')) ?? z.end);
                                onChanged(lm.copyWith(customZones: list));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: l10n.fieldZoneEffect,
                          border: const OutlineInputBorder(),
                        ),
                        value: ['static', 'pulse', 'blink'].contains(z.effect) ? z.effect : 'static',
                        items: [
                          DropdownMenuItem(value: 'static', child: Text(l10n.lightEffectStatic)),
                          DropdownMenuItem(value: 'pulse', child: Text(l10n.lightZoneEffectPulse)),
                          DropdownMenuItem(value: 'blink', child: Text(l10n.lightZoneEffectBlink)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          final list = List<CustomZone>.from(zones);
                          list[zi] = z.copyWith(effect: v);
                          onChanged(lm.copyWith(customZones: list));
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.lightZoneSpeedValue(z.speed), style: Theme.of(context).textTheme.labelLarge),
                      ConfigDragSlider(
                        value: z.speed.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        label: '${z.speed}',
                        onChanged: (v) {
                          final list = List<CustomZone>.from(zones);
                          list[zi] = z.copyWith(speed: v.round());
                          onChanged(lm.copyWith(customZones: list));
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.lightZoneColorTitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.palette_outlined),
                          onPressed: () async {
                            final ctrl = context.read<AmbilightAppController>();
                            try {
                              final res = await _pickZoneColor(context, z.color, ctrl);
                              if (res != null && res.length == 3) {
                                final list = List<CustomZone>.from(zones);
                                list[zi] = z.copyWith(color: res);
                                onChanged(lm.copyWith(customZones: list));
                              }
                            } finally {
                              ctrl.clearStripColorPreview();
                            }
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            final list = List<CustomZone>.from(zones)..removeAt(zi);
                            onChanged(lm.copyWith(customZones: list));
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.lightRemoveZone),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
