import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../../services/music/music_audio_service.dart';
import '../../../services/music/music_types.dart';
import '../settings_common.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';

/// D6 — napojení na `MusicModeSettings` + enumerace vstupů (`MusicAudioService`, agent A4).
class MusicSettingsTab extends StatefulWidget {
  const MusicSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<MusicModeSettings> onChanged;

  @override
  State<MusicSettingsTab> createState() => _MusicSettingsTabState();
}

class _MusicSettingsTabState extends State<MusicSettingsTab> {
  Future<List<MusicCaptureDeviceInfo>>? _devicesFuture;

  static const _effects = [
    'energy',
    'spectrum',
    'spectrum_rotate',
    'spectrum_punchy',
    'strobe',
    'vumeter',
    'vumeter_spectrum',
    'pulse',
    'reactive_bass',
  ];

  static String _musicEffectLabel(String e) => switch (e) {
        'energy' => 'Energie',
        'spectrum' => 'Spektrum',
        'spectrum_rotate' => 'Rotující spektrum',
        'spectrum_punchy' => 'Spektrum (výrazné)',
        'strobe' => 'Stroboskop',
        'vumeter' => 'VU měřič',
        'vumeter_spectrum' => 'VU + spektrum',
        'pulse' => 'Pulz',
        'reactive_bass' => 'Reaktivní basy',
        _ => e,
      };

  @override
  void initState() {
    super.initState();
    _devicesFuture = MusicAudioService.listDevices();
  }

  void _reloadDevices() {
    setState(() {
      _devicesFuture = MusicAudioService.listDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.draft.musicMode;
    final innerMax = AppBreakpoints.maxContentWidth(widget.maxWidth).clamp(280.0, widget.maxWidth);

    final devicePicker = FutureBuilder<List<MusicCaptureDeviceInfo>>(
      future: _devicesFuture,
      builder: (context, snap) {
        final devices = snap.data ?? const <MusicCaptureDeviceInfo>[];
        if (snap.connectionState == ConnectionState.waiting && devices.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text(
            'Zařízení: ${snap.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        int? effectiveIndex = m.audioDeviceIndex;
        if (effectiveIndex != null && (effectiveIndex < 0 || effectiveIndex >= devices.length)) {
          effectiveIndex = null;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                decoration: const InputDecoration(
                  labelText: 'Vstupní zvukové zařízení',
                  border: OutlineInputBorder(),
                ),
                value: effectiveIndex,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Výchozí (první vhodné)'),
                  ),
                  ...devices.map(
                    (d) => DropdownMenuItem<int?>(
                      value: d.index,
                      child: Text(d.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) {
                    widget.onChanged(m.copyWith(clearAudioDeviceIndex: true));
                  } else {
                    widget.onChanged(m.copyWith(audioDeviceIndex: v));
                  }
                },
              ),
            ),
            IconButton(
              tooltip: 'Obnovit seznam',
              onPressed: _reloadDevices,
              icon: const Icon(Icons.refresh),
            ),
          ],
        );
      },
    );

    final fields = <Widget>[
      AmbiSectionHeader(
        title: 'Hudba',
        subtitle:
            'Zdroj zvuku, efekty a náhled barev. Režim Hudba na přehledu musí být aktivní, aby se výstup promítl na pásky.',
        bottomSpacing: 12,
      ),
      devicePicker,
      Consumer<AmbilightAppController>(
        builder: (context, ctrl, _) {
          return SwitchListTile(
            title: const Text('Zamknout výstup barev na pásek (hudba)'),
            subtitle: Text(
              ctrl.musicPaletteLocked
                  ? 'Posílá se zmrazená paleta (stejné jako položka v tray).'
                  : ctrl.musicPaletteLockCapturePending
                      ? 'Čeká na další snímek, pak se paleta zmrazí.'
                      : 'Jen v music módu má smysl; přepnutím režimu se zámek zruší.',
            ),
            value: ctrl.musicPaletteLocked || ctrl.musicPaletteLockCapturePending,
            onChanged: (_) => ctrl.toggleMusicPaletteLock(),
          );
        },
      ),
      SwitchListTile(
        title: const Text('Preferovat mikrofon'),
        subtitle: const Text('Pokud není vybráno zařízení, hledá se vhodný vstup mimo smyčku reproduktorů.'),
        value: m.micEnabled,
        onChanged: (v) => widget.onChanged(m.copyWith(micEnabled: v)),
      ),
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Zdroj barev', border: OutlineInputBorder()),
        value: ['fixed', 'spectrum', 'monitor'].contains(m.colorSource) ? m.colorSource : 'fixed',
        items: const [
          DropdownMenuItem(value: 'fixed', child: Text('Pevná barva')),
          DropdownMenuItem(value: 'spectrum', child: Text('Spektrum zvuku')),
          DropdownMenuItem(value: 'monitor', child: Text('Barvy z monitoru (Ambilight)')),
        ],
        onChanged: (v) {
          if (v == null) return;
          widget.onChanged(m.copyWith(colorSource: v));
        },
      ),
      if (m.colorSource == 'fixed') ...[
        const SizedBox(height: 8),
        Text('Barva při pevné barvě', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Posuvníky krátce rozsvítí náhled na pásku.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _MusicFixedColorSliders(
          rgb: m.fixedColor,
          onRgbChanged: (rgb) => widget.onChanged(m.copyWith(fixedColor: rgb)),
        ),
      ],
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: 'Vizuální efekt', border: OutlineInputBorder()),
        value: _effects.contains(m.effect) ? m.effect : 'energy',
        items: _effects.map((e) => DropdownMenuItem(value: e, child: Text(_musicEffectLabel(e)))).toList(),
        onChanged: (v) {
          if (v == null) return;
          widget.onChanged(m.copyWith(effect: v));
        },
      ),
      Text('Jas (music): ${m.brightness}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.brightness.toDouble().clamp(0, 255),
        max: 255,
        divisions: 255,
        label: '${m.brightness}',
        onChanged: (v) => widget.onChanged(m.copyWith(brightness: v.round())),
      ),
      SwitchListTile(
        title: const Text('Detekce beatu'),
        value: m.beatDetectionEnabled,
        onChanged: (v) => widget.onChanged(m.copyWith(beatDetectionEnabled: v)),
      ),
      Text('Prah detekce beatu: ${m.beatThreshold.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.beatThreshold.clamp(1.05, 3.0),
        min: 1.05,
        max: 3.0,
        divisions: 39,
        label: m.beatThreshold.toStringAsFixed(2),
        onChanged: (v) => widget.onChanged(m.copyWith(beatThreshold: v)),
      ),
      Text('Celková citlivost: ${m.sensitivity}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.sensitivity.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        label: '${m.sensitivity}',
        onChanged: (v) => widget.onChanged(m.copyWith(sensitivity: v.round())),
      ),
      Text('Citlivost pásem (bas / středy / výšky / celkově)', style: Theme.of(context).textTheme.labelSmall),
      Text('Bass: ${m.bassSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.bassSensitivity.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(bassSensitivity: v.round())),
      ),
      Text('Mid: ${m.midSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.midSensitivity.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(midSensitivity: v.round())),
      ),
      Text('High: ${m.highSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.highSensitivity.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(highSensitivity: v.round())),
      ),
      Text('Global: ${m.globalSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.globalSensitivity.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(globalSensitivity: v.round())),
      ),
      SwitchListTile(
        title: const Text('Automatické zesílení'),
        subtitle: const Text('Vyrovná hlasitost vstupu podle dynamiky skladby.'),
        value: m.autoGain,
        onChanged: (v) => widget.onChanged(m.copyWith(autoGain: v)),
      ),
      SwitchListTile(
        title: const Text('Auto středy'),
        value: m.autoMid,
        onChanged: (v) => widget.onChanged(m.copyWith(autoMid: v)),
      ),
      SwitchListTile(
        title: const Text('Auto výšky'),
        value: m.autoHigh,
        onChanged: (v) => widget.onChanged(m.copyWith(autoHigh: v)),
      ),
      Text('Vyhlazení v čase: ${m.smoothingMs} ms', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.smoothingMs.toDouble().clamp(0, 500),
        max: 500,
        divisions: 50,
        label: '${m.smoothingMs}',
        onChanged: (v) => widget.onChanged(m.copyWith(smoothingMs: v.round())),
      ),
      Text('min_brightness (music): ${m.minBrightness}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.minBrightness.toDouble().clamp(0, 255),
        max: 255,
        divisions: 51,
        label: '${m.minBrightness}',
        onChanged: (v) => widget.onChanged(m.copyWith(minBrightness: v.round())),
      ),
      Text('rotation_speed: ${m.rotationSpeed}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: m.rotationSpeed.toDouble().clamp(0, 100),
        max: 100,
        divisions: 100,
        label: '${m.rotationSpeed}',
        onChanged: (v) => widget.onChanged(m.copyWith(rotationSpeed: v.round())),
      ),
      TextFormField(
        initialValue: m.activePreset,
        decoration: const InputDecoration(labelText: 'active_preset', border: OutlineInputBorder()),
        onChanged: (v) => widget.onChanged(m.copyWith(activePreset: v.trim().isEmpty ? m.activePreset : v.trim())),
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

/// RGB při `color_source=fixed` + náhled na pásku (stejný mechanismus jako Světlo).
class _MusicFixedColorSliders extends StatefulWidget {
  const _MusicFixedColorSliders({
    required this.rgb,
    required this.onRgbChanged,
  });

  final List<int> rgb;
  final ValueChanged<List<int>> onRgbChanged;

  @override
  State<_MusicFixedColorSliders> createState() => _MusicFixedColorSlidersState();
}

class _MusicFixedColorSlidersState extends State<_MusicFixedColorSliders> {
  @override
  void dispose() {
    try {
      context.read<AmbilightAppController>().clearStripColorPreview();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<AmbilightAppController>();
    final r = widget.rgb.isNotEmpty ? widget.rgb[0].clamp(0, 255) : 255;
    final g = widget.rgb.length > 1 ? widget.rgb[1].clamp(0, 255) : 0;
    final b = widget.rgb.length > 2 ? widget.rgb[2].clamp(0, 255) : 255;

    void push(int nr, int ng, int nb) {
      widget.onRgbChanged([nr, ng, nb]);
      ctrl.previewStripColor(nr, ng, nb, durationTicks: 72);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Color.fromRGBO(r, g, b, 1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 8),
        Text('R $r', style: Theme.of(context).textTheme.labelSmall),
        Slider(
          value: r.toDouble(),
          max: 255,
          divisions: 255,
          label: '$r',
          onChanged: (v) => push(v.round(), g, b),
        ),
        Text('G $g', style: Theme.of(context).textTheme.labelSmall),
        Slider(
          value: g.toDouble(),
          max: 255,
          divisions: 255,
          label: '$g',
          onChanged: (v) => push(r, v.round(), b),
        ),
        Text('B $b', style: Theme.of(context).textTheme.labelSmall),
        Slider(
          value: b.toDouble(),
          max: 255,
          divisions: 255,
          label: '$b',
          onChanged: (v) => push(r, g, v.round()),
        ),
      ],
    );
  }
}
