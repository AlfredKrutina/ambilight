import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';

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
  var r = lm.color.isNotEmpty ? lm.color[0] : 255;
  var g = lm.color.length > 1 ? lm.color[1] : 200;
  var b = lm.color.length > 2 ? lm.color[2] : 100;
  try {
    final res = await showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Barva RGB'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Náhled na pásku při posuvnících.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(r, g, b, 1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  Slider(
                    label: 'R $r',
                    value: r.toDouble(),
                    max: 255,
                    divisions: 255,
                    onChanged: (v) {
                      setLocal(() => r = v.round());
                      ctrl.previewStripColor(r, g, b, durationTicks: 72);
                    },
                  ),
                  Slider(
                    label: 'G $g',
                    value: g.toDouble(),
                    max: 255,
                    divisions: 255,
                    onChanged: (v) {
                      setLocal(() => g = v.round());
                      ctrl.previewStripColor(r, g, b, durationTicks: 72);
                    },
                  ),
                  Slider(
                    label: 'B $b',
                    value: b.toDouble(),
                    max: 255,
                    divisions: 255,
                    onChanged: (v) {
                      setLocal(() => b = v.round());
                      ctrl.previewStripColor(r, g, b, durationTicks: 72);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušit')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, [r, g, b]),
              child: const Text('OK'),
            ),
          ],
        );
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

  static String _effectLabel(String e) => switch (e) {
        'static' => 'Statická',
        'breathing' => 'Dýchání',
        'rainbow' => 'Duha',
        'chase' => 'Honění',
        'custom_zones' => 'Vlastní zóny',
        _ => e,
      };

  @override
  Widget build(BuildContext context) {
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
                title: 'Světlo',
                subtitle: 'Statické barvy a efekty na pásku bez snímání obrazovky. Výběr barvy může krátce rozsvítit náhled na pásku.',
                bottomSpacing: 12,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Základní barva'),
                subtitle: Text('RGB(${lm.color.join(", ")})'),
                trailing: IconButton.filledTonal(
                  icon: const Icon(Icons.color_lens_outlined),
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
                decoration: const InputDecoration(labelText: 'Efekt', border: OutlineInputBorder()),
                value: _effects.contains(lm.effect) ? lm.effect : 'static',
                items: _effects.map((e) => DropdownMenuItem(value: e, child: Text(_effectLabel(e)))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(lm.copyWith(effect: v));
                },
              ),
              const SizedBox(height: 12),
              Text('Rychlost: ${lm.speed}', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: lm.speed.toDouble().clamp(0, 255),
                max: 255,
                divisions: 255,
                label: '${lm.speed}',
                onChanged: (v) => onChanged(lm.copyWith(speed: v.round())),
              ),
              Text('Extra: ${lm.extra}', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: lm.extra.toDouble().clamp(0, 255),
                max: 255,
                divisions: 255,
                label: '${lm.extra}',
                onChanged: (v) => onChanged(lm.copyWith(extra: v.round())),
              ),
              Text('Jas: ${lm.brightness}', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: lm.brightness.toDouble().clamp(0, 255),
                max: 255,
                divisions: 255,
                label: '${lm.brightness}',
                onChanged: (v) => onChanged(lm.copyWith(brightness: v.round())),
              ),
              SwitchListTile(
                title: const Text('HomeKit (FW / MQTT — neposílat barvy z PC)'),
                subtitle: const Text('homekit_enabled'),
                value: lm.homekitEnabled,
                onChanged: (v) => onChanged(lm.copyWith(homekitEnabled: v)),
              ),
              const Divider(height: 32),
              Text('Vlastní zóny', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final nextZones = List<CustomZone>.from(zones)
                    ..add(
                      CustomZone(
                        name: 'Zóna ${zones.length + 1}',
                        start: 0,
                        end: 20,
                        color: const [255, 0, 0],
                      ),
                    );
                  onChanged(lm.copyWith(customZones: nextZones));
                },
                icon: const Icon(Icons.add),
                label: const Text('Přidat zónu'),
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
                        decoration: const InputDecoration(labelText: 'Název', border: OutlineInputBorder()),
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
                              decoration: const InputDecoration(
                                labelText: 'Start %',
                                border: OutlineInputBorder(),
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
                              decoration: const InputDecoration(
                                labelText: 'Konec %',
                                border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Efekt zóny',
                          border: OutlineInputBorder(),
                        ),
                        value: ['static', 'pulse', 'blink'].contains(z.effect) ? z.effect : 'static',
                        items: const [
                          DropdownMenuItem(value: 'static', child: Text('static')),
                          DropdownMenuItem(value: 'pulse', child: Text('pulse')),
                          DropdownMenuItem(value: 'blink', child: Text('blink')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          final list = List<CustomZone>.from(zones);
                          list[zi] = z.copyWith(effect: v);
                          onChanged(lm.copyWith(customZones: list));
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Rychlost zóny: ${z.speed}', style: Theme.of(context).textTheme.labelLarge),
                      Slider(
                        value: z.speed.toDouble().clamp(0, 255),
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
                        title: const Text('Barva zóny'),
                        trailing: IconButton(
                          icon: const Icon(Icons.palette_outlined),
                          onPressed: () async {
                            final ctrl = context.read<AmbilightAppController>();
                            var r = z.color[0];
                            var g = z.color.length > 1 ? z.color[1] : 0;
                            var b = z.color.length > 2 ? z.color[2] : 0;
                            try {
                              final res = await showDialog<List<int>>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Barva zóny'),
                                  content: StatefulBuilder(
                                    builder: (context, setLocal) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Slider(
                                            value: r.toDouble(),
                                            max: 255,
                                            label: 'R $r',
                                            onChanged: (v) {
                                              setLocal(() => r = v.round());
                                              ctrl.previewStripColor(r, g, b, durationTicks: 72);
                                            },
                                          ),
                                          Slider(
                                            value: g.toDouble(),
                                            max: 255,
                                            label: 'G $g',
                                            onChanged: (v) {
                                              setLocal(() => g = v.round());
                                              ctrl.previewStripColor(r, g, b, durationTicks: 72);
                                            },
                                          ),
                                          Slider(
                                            value: b.toDouble(),
                                            max: 255,
                                            label: 'B $b',
                                            onChanged: (v) {
                                              setLocal(() => b = v.round());
                                              ctrl.previewStripColor(r, g, b, durationTicks: 72);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušit')),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, [r, g, b]),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
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
                          label: const Text('Odebrat zónu'),
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
