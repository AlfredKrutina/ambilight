import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/models/config_models.dart';
import '../../../services/music/music_audio_service.dart';
import '../../../services/music/music_types.dart';
import '../settings_common.dart';
import '../../dashboard_ui.dart';
import '../../guides/music_spotify_integration_guide.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/ambi_color_picker_dialog.dart';
import '../../widgets/config_drag_slider.dart';

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
    'smart_music',
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
        'smart_music' => 'Smart Music',
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
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () => MusicSpotifyIntegrationGuide.show(context),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Nápověda: hudba a obaly'),
        ),
      ),
      const SizedBox(height: 8),
      devicePicker,
      Selector<AmbilightAppController, ({bool locked, bool pending})>(
        selector: (_, ctrl) => (locked: ctrl.musicPaletteLocked, pending: ctrl.musicPaletteLockCapturePending),
        builder: (context, v, _) {
          final ctrl = context.read<AmbilightAppController>();
          return SwitchListTile(
            title: const Text('Zamknout výstup barev na pásek (hudba)'),
            subtitle: Text(
              v.locked
                  ? 'Posílá se zmrazená paleta (stejné jako položka v tray).'
                  : v.pending
                      ? 'Čeká na další snímek, pak se paleta zmrazí.'
                      : 'Jen v music módu má smysl; přepnutím režimu se zámek zruší.',
            ),
            value: v.locked || v.pending,
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
          'Barvu vybírej jako v Home / Hue — náhled na pásku při úpravě.',
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
      if (m.effect == 'smart_music') ...[
        const SizedBox(height: 6),
        Text(
          'Smart Music: spektrum, beat a melodie se mapují na pásek v reálném čase (lokálně, bez cloudu).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
      Text('Jas (music): ${m.brightness}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.brightness.toDouble(),
        min: 0,
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
      ConfigDragSlider(
        value: m.beatThreshold,
        min: 1.05,
        max: 3.0,
        divisions: 39,
        label: m.beatThreshold.toStringAsFixed(2),
        onChanged: (v) => widget.onChanged(m.copyWith(beatThreshold: v)),
      ),
      Text('Celková citlivost: ${m.sensitivity}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.sensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        label: '${m.sensitivity}',
        onChanged: (v) => widget.onChanged(m.copyWith(sensitivity: v.round())),
      ),
      Text('Citlivost pásem (bas / středy / výšky / celkově)', style: Theme.of(context).textTheme.labelSmall),
      Text('Bass: ${m.bassSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.bassSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(bassSensitivity: v.round())),
      ),
      Text('Mid: ${m.midSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.midSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(midSensitivity: v.round())),
      ),
      Text('High: ${m.highSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.highSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(highSensitivity: v.round())),
      ),
      Text('Global: ${m.globalSensitivity}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.globalSensitivity.toDouble(),
        min: 0,
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
      ConfigDragSlider(
        value: m.smoothingMs.toDouble(),
        min: 0,
        max: 500,
        divisions: 50,
        label: '${m.smoothingMs}',
        onChanged: (v) => widget.onChanged(m.copyWith(smoothingMs: v.round())),
      ),
      Text('min_brightness (music): ${m.minBrightness}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.minBrightness.toDouble(),
        min: 0,
        max: 255,
        divisions: 51,
        label: '${m.minBrightness}',
        onChanged: (v) => widget.onChanged(m.copyWith(minBrightness: v.round())),
      ),
      Text('rotation_speed: ${m.rotationSpeed}', style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.rotationSpeed.toDouble(),
        min: 0,
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

  Future<void> _openPicker() async {
    final ctrl = context.read<AmbilightAppController>();
    final r = widget.rgb.isNotEmpty ? widget.rgb[0].clamp(0, 255) : 255;
    final g = widget.rgb.length > 1 ? widget.rgb[1].clamp(0, 255) : 0;
    final b = widget.rgb.length > 2 ? widget.rgb[2].clamp(0, 255) : 255;
    try {
      final res = await showAmbiColorPickerDialog(
        context,
        title: 'Pevná barva (hudba)',
        initialRgb: [r, g, b],
        onLiveRgb: (rgb) {
          if (rgb.length == 3) {
            ctrl.previewStripColor(rgb[0], rgb[1], rgb[2], durationTicks: 72);
          }
        },
      );
      if (res != null && res.length == 3) {
        widget.onRgbChanged(res);
      }
    } finally {
      ctrl.clearStripColorPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.rgb.isNotEmpty ? widget.rgb[0].clamp(0, 255) : 255;
    final g = widget.rgb.length > 1 ? widget.rgb[1].clamp(0, 255) : 0;
    final b = widget.rgb.length > 2 ? widget.rgb[2].clamp(0, 255) : 255;
    final fill = Color.fromARGB(255, r, g, b);
    final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    final onFill = lum > 0.55 ? Colors.black87 : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPicker,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              height: 96,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: fill.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, color: onFill.withValues(alpha: 0.9)),
                  const SizedBox(width: 10),
                  Text(
                    'Upravit barvu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: onFill,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'RGB $r · $g · $b',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
