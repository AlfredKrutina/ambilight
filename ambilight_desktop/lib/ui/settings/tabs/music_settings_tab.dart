import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/ambilight_presets.dart';
import '../../../core/models/config_models.dart';
import '../../../services/music/music_audio_service.dart';
import '../../../services/music/music_segment_renderer.dart';
import '../../../services/music/music_types.dart';
import '../settings_common.dart';
import '../../dashboard_ui.dart';
import '../../guides/music_macos_loopback_guide.dart';
import '../../guides/music_spotify_integration_guide.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/ambi_color_picker_dialog.dart';
import '../../widgets/config_drag_slider.dart';
import '../../../l10n/context_ext.dart';
import '../../../l10n/generated/app_localizations.dart';

/// D6 — napojení na `MusicModeSettings` + enumerace vstupů (`MusicAudioService`, agent A4).
class MusicSettingsTab extends StatefulWidget {
  const MusicSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
    this.onAppConfig,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<MusicModeSettings> onChanged;
  /// Uložení `user_music_presets` / import — volitelné (např. z [SettingsPage]).
  final ValueChanged<AppConfig>? onAppConfig;

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

  static String _musicEffectLabel(AppLocalizations l10n, String e) => switch (e) {
        'smart_music' => l10n.musicEffectSmartMusic,
        'energy' => l10n.musicEffectEnergy,
        'spectrum' => l10n.musicEffectSpectrum,
        'spectrum_rotate' => l10n.musicEffectSpectrumRotate,
        'spectrum_punchy' => l10n.musicEffectSpectrumPunchy,
        'strobe' => l10n.musicEffectStrobe,
        'vumeter' => l10n.musicEffectVuMeter,
        'vumeter_spectrum' => l10n.musicEffectVuSpectrum,
        'pulse' => l10n.musicEffectPulse,
        'reactive_bass' => l10n.musicEffectReactiveBass,
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

  static const _builtinMusicPresetExtras = <String>['Custom'];

  List<String> _musicActivePresetDropdownItems(MusicModeSettings mm) {
    final set = <String>{
      ...AmbilightPresets.musicNames,
      ..._builtinMusicPresetExtras,
      ...widget.draft.userMusicPresets.keys,
      mm.activePreset,
    };
    final out = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  String _musicActivePresetDropdownValue(MusicModeSettings mm, List<String> items) {
    if (items.contains(mm.activePreset)) return mm.activePreset;
    return items.isNotEmpty ? items.first : mm.activePreset;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = widget.draft.musicMode;
    final musicPresetItems = _musicActivePresetDropdownItems(m);
    final musicPresetValue = _musicActivePresetDropdownValue(m, musicPresetItems);
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
            l10n.musicDeviceError(snap.error!),
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
                decoration: InputDecoration(
                  labelText: l10n.musicInputDeviceLabel,
                  border: const OutlineInputBorder(),
                ),
                value: effectiveIndex,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.musicDefaultInputDevice),
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
            Semantics(
              label: l10n.musicRefreshDeviceListTooltip,
              button: true,
              child: IconButton(
                tooltip: '',
                onPressed: _reloadDevices,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        );
      },
    );

    final fields = <Widget>[
      AmbiSectionHeader(
        title: l10n.musicSettingsHeader,
        subtitle: l10n.musicSettingsSubtitle,
        bottomSpacing: 12,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => MusicSpotifyIntegrationGuide.show(context),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(l10n.musicGuideMusicArtwork),
          ),
        ),
      ),
      const SizedBox(height: 8),
      devicePicker,
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          l10n.musicSystemLoopbackHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      if (Platform.isMacOS) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => MusicMacosLoopbackGuide.show(context),
            icon: const Icon(Icons.headphones_outlined),
            label: Text(l10n.musicGuideMacosAudio),
          ),
        ),
      ],
      Selector<AmbilightAppController, ({bool locked, bool pending})>(
        selector: (_, ctrl) => (locked: ctrl.musicPaletteLocked, pending: ctrl.musicPaletteLockCapturePending),
        builder: (context, v, _) {
          final ctrl = context.read<AmbilightAppController>();
          return SwitchListTile(
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(l10n.musicLockPaletteTitle)),
                AmbiHelpIcon(message: l10n.musicLockPaletteHelpTooltip),
              ],
            ),
            subtitle: Text(
              v.locked
                  ? l10n.musicLockPaletteFrozen
                  : v.pending
                      ? l10n.musicLockPalettePending
                      : l10n.musicLockPaletteIdle,
            ),
            value: v.locked || v.pending,
            onChanged: (_) => ctrl.toggleMusicPaletteLock(),
          );
        },
      ),
      SwitchListTile(
        title: Text(l10n.musicPreferMicTitle),
        subtitle: Text(l10n.musicPreferMicSubtitle),
        value: m.micEnabled,
        onChanged: (v) => widget.onChanged(m.copyWith(micEnabled: v)),
      ),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: l10n.musicColorSourceLabel, border: const OutlineInputBorder()),
        value: ['fixed', 'spectrum', 'monitor'].contains(m.colorSource) ? m.colorSource : 'fixed',
        items: [
          DropdownMenuItem(value: 'fixed', child: Text(l10n.musicColorSourceFixed)),
          DropdownMenuItem(value: 'spectrum', child: Text(l10n.musicColorSourceSpectrum)),
          DropdownMenuItem(value: 'monitor', child: Text(l10n.musicColorSourceMonitor)),
        ],
        onChanged: (v) {
          if (v == null) return;
          widget.onChanged(m.copyWith(colorSource: v));
        },
      ),
      if (m.colorSource == 'fixed') ...[
        const SizedBox(height: 8),
        Text(l10n.musicFixedColorHeader, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.musicFixedColorHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _MusicFixedColorSliders(
          rgb: m.fixedColor,
          onRgbChanged: (rgb) => widget.onChanged(m.copyWith(fixedColor: rgb)),
        ),
      ],
      if (m.colorSource == 'spectrum') ...[
        const SizedBox(height: 8),
        Text(l10n.musicSpectrumPaletteHeader, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.musicSpectrumPaletteHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _MusicSpectrumBandColors(
          settings: m,
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(l10n.musicMelodySpectrumTintTitle),
          subtitle: Text(l10n.musicMelodySpectrumTintSubtitle),
          value: m.melodySpectrumTintEnabled,
          onChanged: (v) => widget.onChanged(m.copyWith(melodySpectrumTintEnabled: v)),
        ),
        if (m.melodySpectrumTintEnabled) ...[
          Text(
            l10n.musicMelodySpectrumTintAmount((m.melodySpectrumTint * 100).round()),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ConfigDragSlider(
            value: m.melodySpectrumTint,
            min: 0,
            max: 1,
            divisions: 20,
            label: m.melodySpectrumTint.toStringAsFixed(2),
            onChanged: (v) => widget.onChanged(m.copyWith(melodySpectrumTint: v)),
          ),
        ],
      ],
      DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: l10n.musicVisualEffectLabel, border: const OutlineInputBorder()),
        value: _effects.contains(m.effect) ? m.effect : 'energy',
        items: _effects.map((e) => DropdownMenuItem(value: e, child: Text(_musicEffectLabel(l10n, e)))).toList(),
        onChanged: (v) {
          if (v == null) return;
          widget.onChanged(m.copyWith(effect: v));
        },
      ),
      if (m.effect == 'smart_music') ...[
        const SizedBox(height: 6),
        Text(
          l10n.musicSmartMusicHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
      Text(l10n.musicBrightnessValue(m.brightness), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.brightness.toDouble(),
        min: 0,
        max: 255,
        divisions: 255,
        label: '${m.brightness}',
        onChanged: (v) => widget.onChanged(m.copyWith(brightness: v.round())),
      ),
      SwitchListTile(
        title: Text(l10n.musicBeatDetection),
        value: m.beatDetectionEnabled,
        onChanged: (v) => widget.onChanged(m.copyWith(beatDetectionEnabled: v)),
      ),
      Text(l10n.musicBeatThreshold(m.beatThreshold.toStringAsFixed(2)), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.beatThreshold,
        min: 1.05,
        max: 3.0,
        divisions: 39,
        label: m.beatThreshold.toStringAsFixed(2),
        onChanged: (v) => widget.onChanged(m.copyWith(beatThreshold: v)),
      ),
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: l10n.musicBeatSyncLabel,
          helperText: l10n.musicBeatSyncHint,
          border: const OutlineInputBorder(),
        ),
        value: const {'off', 'gradient_step', 'color_pulse'}.contains(m.beatSyncMode) ? m.beatSyncMode : 'off',
        items: [
          DropdownMenuItem(value: 'off', child: Text(l10n.musicBeatSyncOff)),
          DropdownMenuItem(value: 'gradient_step', child: Text(l10n.musicBeatSyncGradientStep)),
          DropdownMenuItem(value: 'color_pulse', child: Text(l10n.musicBeatSyncColorPulse)),
        ],
        onChanged: (v) {
          if (v == null) return;
          widget.onChanged(m.copyWith(beatSyncMode: v));
        },
      ),
      if (widget.draft.smartLights.enabled) ...[
        const SizedBox(height: 8),
        Text(
          l10n.musicHaIntegrationFootnote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
      Text(l10n.musicOverallSensitivity(m.sensitivity), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.sensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        label: '${m.sensitivity}',
        onChanged: (v) => widget.onChanged(m.copyWith(sensitivity: v.round())),
      ),
      Text(l10n.musicBandSensitivityCaption, style: Theme.of(context).textTheme.labelSmall),
      Text(l10n.musicBassValue(m.bassSensitivity), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.bassSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(bassSensitivity: v.round())),
      ),
      Text(l10n.musicMidValue(m.midSensitivity), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.midSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(midSensitivity: v.round())),
      ),
      Text(l10n.musicHighValue(m.highSensitivity), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.highSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(highSensitivity: v.round())),
      ),
      Text(l10n.musicGlobalValue(m.globalSensitivity), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.globalSensitivity.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        onChanged: (v) => widget.onChanged(m.copyWith(globalSensitivity: v.round())),
      ),
      SwitchListTile(
        title: Text(l10n.musicPerBandSensitivityTitle),
        subtitle: Text(l10n.musicPerBandSensitivitySubtitle),
        value: m.perBandSensitivityEnabled,
        onChanged: (v) {
          if (v) {
            final b = m.bandSensitivities.length == 7
                ? List<int>.from(m.bandSensitivities)
                : List<int>.generate(
                    7,
                    (i) => i < 2 ? m.bassSensitivity : (i < 4 ? m.midSensitivity : m.highSensitivity),
                  );
            widget.onChanged(m.copyWith(perBandSensitivityEnabled: true, bandSensitivities: b));
          } else {
            widget.onChanged(m.copyWith(perBandSensitivityEnabled: false));
          }
        },
      ),
      if (m.perBandSensitivityEnabled) ...[
        _PerBandSensitivitySliders(
          settings: m,
          onChanged: widget.onChanged,
        ),
      ],
      SwitchListTile(
        title: Text(l10n.musicAutoGainTitle),
        subtitle: Text(l10n.musicAutoGainSubtitle),
        value: m.autoGain,
        onChanged: (v) => widget.onChanged(m.copyWith(autoGain: v)),
      ),
      if (m.autoGain) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ValueListenableBuilder<double>(
            valueListenable: MusicSegmentRenderer.agcPeakNotifier,
            builder: (context, peak, _) {
              return ValueListenableBuilder<double>(
                valueListenable: MusicSegmentRenderer.agcGainNotifier,
                builder: (context, gain, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.musicAgcMeterTitle, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: peak.clamp(0.0, 1.0)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.musicAgcMeterPeak(peak.toStringAsFixed(3)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        l10n.musicAgcMeterGain(gain.toStringAsFixed(3)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
      SwitchListTile(
        title: Text(l10n.musicAutoMidTitle),
        value: m.autoMid,
        onChanged: (v) => widget.onChanged(m.copyWith(autoMid: v)),
      ),
      SwitchListTile(
        title: Text(l10n.musicAutoHighTitle),
        value: m.autoHigh,
        onChanged: (v) => widget.onChanged(m.copyWith(autoHigh: v)),
      ),
      Text(l10n.musicSmoothingMs(m.smoothingMs), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.smoothingMs.toDouble(),
        min: 0,
        max: 500,
        divisions: 50,
        label: '${m.smoothingMs}',
        onChanged: (v) => widget.onChanged(m.copyWith(smoothingMs: v.round())),
      ),
      Text(l10n.musicMinBrightnessValue(m.minBrightness), style: Theme.of(context).textTheme.labelLarge),
      ConfigDragSlider(
        value: m.minBrightness.toDouble(),
        min: 0,
        max: 255,
        divisions: 51,
        label: '${m.minBrightness}',
        onChanged: (v) => widget.onChanged(m.copyWith(minBrightness: v.round())),
      ),
      if (m.effect.contains('rotate')) ...[
        SwitchListTile(
          title: Text(l10n.musicSpectrumRotationTitle),
          subtitle: Text(l10n.musicSpectrumRotationSubtitle),
          value: m.spectrumRotationEnabled,
          onChanged: (v) => widget.onChanged(m.copyWith(spectrumRotationEnabled: v)),
        ),
        if (m.spectrumRotationEnabled) ...[
          Text(l10n.musicRotationSpeedValue(m.rotationSpeed), style: Theme.of(context).textTheme.labelLarge),
          ConfigDragSlider(
            value: m.rotationSpeed.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${m.rotationSpeed}',
            onChanged: (v) => widget.onChanged(m.copyWith(rotationSpeed: v.round())),
          ),
        ],
      ],
      if (widget.onAppConfig != null)
        _MusicUserPresetsPanel(
          draft: widget.draft,
          onAppConfig: widget.onAppConfig!,
        ),
      DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.musicActivePresetField,
          helperText: l10n.helperMusicActivePreset,
          border: const OutlineInputBorder(),
        ),
        value: musicPresetValue,
        items: musicPresetItems
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          final user = widget.draft.userMusicPresets[v];
          if (user != null) {
            try {
              final loaded = MusicModeSettings.fromJson(Map<String, dynamic>.from(user)).copyWith(activePreset: v);
              widget.onChanged(loaded);
              return;
            } catch (_) {}
          }
          final patch = AmbilightPresets.musicPatch(v);
          if (patch != null) {
            widget.onChanged(
              m.withBandSensitivity(
                bass: patch.bass,
                mid: patch.mid,
                high: patch.high,
                activePreset: v,
                effect: patch.effect,
              ),
            );
            return;
          }
          widget.onChanged(m.copyWith(activePreset: v));
        },
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

class _PerBandSensitivitySliders extends StatelessWidget {
  const _PerBandSensitivitySliders({
    required this.settings,
    required this.onChanged,
  });

  final MusicModeSettings settings;
  final ValueChanged<MusicModeSettings> onChanged;

  List<int> _baseBands() {
    if (settings.bandSensitivities.length == 7) {
      return List<int>.from(settings.bandSensitivities);
    }
    return List<int>.generate(
      7,
      (i) => i < 2 ? settings.bassSensitivity : (i < 4 ? settings.midSensitivity : settings.highSensitivity),
    );
  }

  void _setIndex(int idx, int v) {
    final b = _baseBands();
    b[idx] = v.clamp(0, 100);
    onChanged(settings.copyWith(bandSensitivities: b, perBandSensitivityEnabled: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.musicSpectrumBandSubBass,
      l10n.musicSpectrumBandBass,
      l10n.musicSpectrumBandLowMid,
      l10n.musicSpectrumBandMid,
      l10n.musicSpectrumBandHighMid,
      l10n.musicSpectrumBandPresence,
      l10n.musicSpectrumBandBrilliance,
    ];
    final bands = _baseBands();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++) ...[
          Text('${labels[i]}: ${bands[i]}', style: Theme.of(context).textTheme.labelLarge),
          ConfigDragSlider(
            value: bands[i].toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${bands[i]}',
            onChanged: (nv) => _setIndex(i, nv.round()),
          ),
        ],
      ],
    );
  }
}

class _MusicUserPresetsPanel extends StatefulWidget {
  const _MusicUserPresetsPanel({
    required this.draft,
    required this.onAppConfig,
  });

  final AppConfig draft;
  final ValueChanged<AppConfig> onAppConfig;

  @override
  State<_MusicUserPresetsPanel> createState() => _MusicUserPresetsPanelState();
}

class _MusicUserPresetsPanelState extends State<_MusicUserPresetsPanel> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final next = Map<String, Map<String, dynamic>>.from(widget.draft.userMusicPresets);
    next[name] = Map<String, dynamic>.from(widget.draft.musicMode.toJson());
    widget.onAppConfig(
      widget.draft.copyWith(
        userMusicPresets: next,
        musicMode: widget.draft.musicMode.copyWith(activePreset: name),
      ),
    );
    if (mounted) {
      _nameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).musicUserPresetsSavedOk)),
      );
    }
  }

  void _delete(String key) {
    final next = Map<String, Map<String, dynamic>>.from(widget.draft.userMusicPresets);
    next.remove(key);
    widget.onAppConfig(widget.draft.copyWith(userMusicPresets: next));
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(widget.draft.userMusicPresets)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).musicUserPresetsCopied)),
      );
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.single;
    String? text;
    final bytes = f.bytes;
    if (bytes != null) {
      text = utf8.decode(bytes);
    } else if (f.path != null) {
      try {
        text = await File(f.path!).readAsString();
      } catch (_) {
        text = null;
      }
    }
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.musicUserPresetsBadJson)));
      }
      return;
    }
    try {
      final dec = jsonDecode(text);
      if (dec is! Map) {
        throw const FormatException('root');
      }
      final merged = Map<String, Map<String, dynamic>>.from(widget.draft.userMusicPresets);
      for (final e in dec.entries) {
        if (e.value is Map) {
          merged[e.key.toString()] = Map<String, dynamic>.from(e.value as Map);
        }
      }
      widget.onAppConfig(widget.draft.copyWith(userMusicPresets: merged));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.musicUserPresetsMerged)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.musicUserPresetsBadJson)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keys = widget.draft.userMusicPresets.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(l10n.musicUserPresetsTitle),
        subtitle: Text(l10n.musicUserPresetsHint, style: Theme.of(context).textTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.musicUserPresetsNameLabel,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.musicUserPresetsSave),
              ),
            ),
          ),
          if (keys.isNotEmpty) const Divider(height: 24),
          ...keys.map(
            (k) => ListTile(
              dense: true,
              title: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: l10n.musicUserPresetsDelete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(k),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l10n.musicUserPresetsExport),
                ),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.musicUserPresetsImport),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sedm zastávek palety při `color_source=spectrum` (sub-bas → brilliance).
class _MusicSpectrumBandColors extends StatelessWidget {
  const _MusicSpectrumBandColors({
    required this.settings,
    required this.onChanged,
  });

  final MusicModeSettings settings;
  final ValueChanged<MusicModeSettings> onChanged;

  static Color _fill(List<int> rgb) {
    if (rgb.length < 3) return Colors.white;
    return Color.fromARGB(
      255,
      rgb[0].clamp(0, 255),
      rgb[1].clamp(0, 255),
      rgb[2].clamp(0, 255),
    );
  }

  Future<void> _openBand(BuildContext context, int band) async {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.musicSpectrumBandSubBass,
      l10n.musicSpectrumBandBass,
      l10n.musicSpectrumBandLowMid,
      l10n.musicSpectrumBandMid,
      l10n.musicSpectrumBandHighMid,
      l10n.musicSpectrumBandPresence,
      l10n.musicSpectrumBandBrilliance,
    ];
    final ctrl = context.read<AmbilightAppController>();
    final src = switch (band) {
      0 => settings.subBassColor,
      1 => settings.bassColor,
      2 => settings.lowMidColor,
      3 => settings.midColor,
      4 => settings.highMidColor,
      5 => settings.presenceColor,
      _ => settings.brillianceColor,
    };
    final r = src.isNotEmpty ? src[0].clamp(0, 255) : 255;
    final g = src.length > 1 ? src[1].clamp(0, 255) : 0;
    final b = src.length > 2 ? src[2].clamp(0, 255) : 255;
    try {
      final res = await showAmbiColorPickerDialog(
        context,
        title: l10n.musicSpectrumPickerTitle(labels[band]),
        initialRgb: [r, g, b],
        onLiveRgb: (rgb) {
          if (rgb.length == 3) {
            ctrl.previewStripColor(rgb[0], rgb[1], rgb[2], durationTicks: 72);
          }
        },
      );
      if (res != null && res.length == 3) {
        final copy = List<int>.from(res);
        onChanged(switch (band) {
          0 => settings.copyWith(subBassColor: copy),
          1 => settings.copyWith(bassColor: copy),
          2 => settings.copyWith(lowMidColor: copy),
          3 => settings.copyWith(midColor: copy),
          4 => settings.copyWith(highMidColor: copy),
          5 => settings.copyWith(presenceColor: copy),
          _ => settings.copyWith(brillianceColor: copy),
        });
      }
    } finally {
      ctrl.clearStripColorPreview();
    }
  }

  void _resetDefaults() {
    const d = MusicModeSettings();
    onChanged(settings.copyWith(
      subBassColor: List<int>.from(d.subBassColor),
      bassColor: List<int>.from(d.bassColor),
      lowMidColor: List<int>.from(d.lowMidColor),
      midColor: List<int>.from(d.midColor),
      highMidColor: List<int>.from(d.highMidColor),
      presenceColor: List<int>.from(d.presenceColor),
      brillianceColor: List<int>.from(d.brillianceColor),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bands = [
      settings.subBassColor,
      settings.bassColor,
      settings.lowMidColor,
      settings.midColor,
      settings.highMidColor,
      settings.presenceColor,
      settings.brillianceColor,
    ];
    final tooltips = [
      l10n.musicSpectrumBandSubBass,
      l10n.musicSpectrumBandBass,
      l10n.musicSpectrumBandLowMid,
      l10n.musicSpectrumBandMid,
      l10n.musicSpectrumBandHighMid,
      l10n.musicSpectrumBandPresence,
      l10n.musicSpectrumBandBrilliance,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 22,
            child: Row(
              children: List.generate(7, (i) {
                return Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: _fill(bands[i])),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 2, right: i == 6 ? 0 : 2),
                  child: Tooltip(
                    message: tooltips[i],
                    child: Material(
                      color: _fill(bands[i]),
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openBand(context, i),
                        child: Center(
                          child: Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: ThemeData.estimateBrightnessForColor(_fill(bands[i])) == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.restart_alt_outlined, size: 20),
            label: Text(l10n.musicSpectrumResetBands),
          ),
        ),
      ],
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
        title: AppLocalizations.of(context).musicFixedColorPickerTitle,
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
    final l10n = AppLocalizations.of(context);
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
                    l10n.musicEditColorButton,
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
          l10n.musicRgbTriple(r, g, b),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
