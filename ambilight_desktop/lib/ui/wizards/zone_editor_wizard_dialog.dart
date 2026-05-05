import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../../engine/screen/screen_color_pipeline.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/config_drag_slider.dart';
import 'wizard_dialog_shell.dart';

String _zoneEdgeLabel(AppLocalizations l10n, String edge) {
  switch (edge) {
    case 'top':
      return l10n.zoneEdgeTop;
    case 'bottom':
      return l10n.zoneEdgeBottom;
    case 'left':
      return l10n.zoneEdgeLeft;
    case 'right':
      return l10n.zoneEdgeRight;
    default:
      return edge;
  }
}

String _zoneMusicEffectLabel(AppLocalizations l10n, String id) {
  switch (id) {
    case 'default':
      return l10n.zoneMusicEffectDefault;
    case 'smart_music':
      return l10n.zoneMusicEffectSmartMusic;
    case 'energy':
      return l10n.zoneMusicEffectEnergy;
    case 'spectrum':
      return l10n.zoneMusicEffectSpectrum;
    case 'spectrum_rotate':
      return l10n.zoneMusicEffectSpectrumRotate;
    case 'spectrum_punchy':
      return l10n.zoneMusicEffectSpectrumPunchy;
    case 'strobe':
      return l10n.zoneMusicEffectStrobe;
    case 'vumeter':
      return l10n.zoneMusicEffectVumeter;
    case 'vumeter_spectrum':
      return l10n.zoneMusicEffectVumeterSpectrum;
    case 'pulse':
      return l10n.zoneMusicEffectPulse;
    case 'reactive_bass':
      return l10n.zoneMusicEffectReactiveBass;
    default:
      return id;
  }
}

String _zoneRoleLabel(AppLocalizations l10n, String role) {
  switch (role) {
    case 'auto':
      return l10n.zoneRoleAuto;
    case 'bass':
      return l10n.zoneRoleBass;
    case 'mids':
      return l10n.zoneRoleMids;
    case 'highs':
      return l10n.zoneRoleHighs;
    case 'ambience':
      return l10n.zoneRoleAmbience;
    default:
      return role;
  }
}

/// D11 — editor [LedSegment] (pole odpovídající PyQt tabulce segmentů v nastavení).
class ZoneEditorWizardDialog extends StatefulWidget {
  const ZoneEditorWizardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(context: context, builder: (_) => const ZoneEditorWizardDialog());
  }

  @override
  State<ZoneEditorWizardDialog> createState() => _ZoneEditorWizardDialogState();
}

class _ZoneEditorWizardDialogState extends State<ZoneEditorWizardDialog> {
  static const _edges = ['top', 'bottom', 'left', 'right'];
  static const _musicEffects = [
    'default',
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
  static const _roles = ['auto', 'bass', 'mids', 'highs', 'ambience'];

  List<LedSegment> _segments = [];
  bool _loaded = false;
  AmbilightAppController? _ambiForDispose;
  bool _acquiredHighFidelityPreview = false;

  int _maxLed(AppConfig c) {
    final ds = c.globalSettings.devices;
    if (ds.isEmpty) return c.globalSettings.ledCount.clamp(1, 4096);
    return ds.map((d) => d.ledCount).reduce(math.max).clamp(1, 4096);
  }

  /// [DropdownButtonFormField] vyžaduje, aby [value] byl v seznamu položek — po odebrání zařízení jinak pád.
  static String? _deviceIdForDropdown(LedSegment s, List<DeviceSettings> devices) {
    final id = s.deviceId;
    if (id == null) return null;
    if (devices.any((d) => d.id == id)) return id;
    return null;
  }

  static int _devicesSignature(List<DeviceSettings> ds) {
    var h = 0;
    for (final d in ds) {
      h = Object.hash(h, d.id, d.name, d.type, d.port, d.ipAddress, d.udpPort, d.ledCount);
    }
    return h;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ambiForDispose ??= context.read<AmbilightAppController>();
    if (!_acquiredHighFidelityPreview) {
      _acquiredHighFidelityPreview = true;
      _ambiForDispose!.acquireHighFidelityPreviewUi();
    }
    if (_loaded) return;
    _loaded = true;
    final ctrl = _ambiForDispose!;
    _segments = List<LedSegment>.from(ctrl.config.screenMode.segments);
  }

  @override
  void dispose() {
    _ambiForDispose?.releaseHighFidelityPreviewUi();
    super.dispose();
  }

  void _addSegment() {
    final c = context.read<AmbilightAppController>().config;
    final ctrl = context.read<AmbilightAppController>();
    final d = c.globalSettings.devices.isNotEmpty ? c.globalSettings.devices.first : null;
    final mon = c.screenMode.monitorIndex;
    final fr = ctrl.latestScreenFrame;
    final rw = (fr != null && fr.isValid) ? fr.width : 1920;
    final rh = (fr != null && fr.isValid) ? fr.height : 1080;
    setState(() {
      _segments.add(
        LedSegment(
          ledStart: 0,
          ledEnd: 0,
          monitorIdx: mon,
          edge: 'top',
          depth: 10,
          reverse: false,
          deviceId: d?.id,
          pixelStart: 0,
          pixelEnd: rw,
          refWidth: rw,
          refHeight: rh,
          musicEffect: 'default',
          role: 'auto',
        ),
      );
    });
  }

  void _applyRefFromCapture(int i) {
    final ctrl = context.read<AmbilightAppController>();
    final fr = ctrl.latestScreenFrame;
    if (fr == null || !fr.isValid) return;
    setState(() {
      _segments[i] = _segments[i].copyWith(
        refWidth: fr.width,
        refHeight: fr.height,
        monitorIdx: fr.monitorIndex,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AmbilightAppController, AppConfig>(
      selector: (_, ctrl) => ctrl.config,
      builder: (context, _, __) {
        final c = context.read<AmbilightAppController>();
        return ListenableBuilder(
          listenable: c.previewFrameNotifier,
          builder: (context, _) {
        final l10n = context.l10n;
        final fr = c.latestScreenFrame;
        final px =
            (fr != null && fr.isValid) ? math.max(fr.width, fr.height).clamp(800, 8192) : -1;
        final sig = (px, _devicesSignature(c.config.globalSettings.devices));
        final pxCap = sig.$1 < 0 ? 4096 : sig.$1;
        final maxL = _maxLed(c.config);

        return WizardDialogShell(
      title: l10n.zoneEditorTitle,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton.tonal(
          onPressed: _addSegment,
          child: Text(l10n.zoneEditorAddSegment),
        ),
        FilledButton(
          onPressed: () async {
            await c.applyConfigAndPersist(
              c.config.copyWith(screenMode: c.config.screenMode.copyWith(segments: _segments)),
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.zoneEditorSavedSegments(_segments.length))),
              );
            }
          },
          child: Text(l10n.save),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.zoneEditorIntro(maxL),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              if (_segments.isEmpty) return const SizedBox.shrink();
              final draftCfg = c.config.copyWith(
                screenMode: c.config.screenMode.copyWith(segments: _segments),
              );
              final warn = ScreenColorPipeline.screenSegmentCaptureWarnings(draftCfg);
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
          if (_segments.isEmpty)
            Text(
              l10n.zoneEditorEmpty,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _segments.length,
              onReorder: (a, b) {
                setState(() {
                  if (b > a) b--;
                  final x = _segments.removeAt(a);
                  _segments.insert(b, x);
                });
              },
              itemBuilder: (ctx, i) {
                final s = _segments[i];
                return Card(
                  key: ValueKey('seg-$i-${s.ledStart}-${s.ledEnd}-${s.edge}-${s.monitorIdx}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(
                      l10n.zoneEditorSegmentLine(
                        i,
                        _zoneEdgeLabel(l10n, s.edge),
                        s.ledStart,
                        s.ledEnd,
                        s.monitorIdx,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: l10n.zoneEditorDeleteTooltip,
                      icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                      onPressed: () => setState(() => _segments.removeAt(i)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.zoneFieldLedStart(s.ledStart), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.ledStart.clamp(0, maxL - 1).toDouble(),
                              min: 0,
                              max: (maxL - 1).toDouble(),
                              divisions: math.max(1, maxL - 1),
                              label: '${s.ledStart}',
                              onChanged: (v) {
                                final nv = v.round();
                                setState(() {
                                  var end = s.ledEnd;
                                  if (end < nv) end = nv;
                                  _segments[i] = s.copyWith(ledStart: nv, ledEnd: end);
                                });
                              },
                            ),
                            Text(l10n.zoneFieldLedEnd(s.ledEnd), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.ledEnd.clamp(0, maxL - 1).toDouble(),
                              min: 0,
                              max: (maxL - 1).toDouble(),
                              divisions: math.max(1, maxL - 1),
                              label: '${s.ledEnd}',
                              onChanged: (v) {
                                final nv = v.round();
                                setState(() {
                                  var st = s.ledStart;
                                  if (st > nv) st = nv;
                                  _segments[i] = s.copyWith(ledStart: st, ledEnd: nv);
                                });
                              },
                            ),
                            Text(l10n.zoneFieldMonitorIndex(s.monitorIdx), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.monitorIdx.clamp(0, 32).toDouble(),
                              min: 0,
                              max: 32,
                              divisions: 32,
                              label: '${s.monitorIdx}',
                              onChanged: (v) => setState(() {
                                _segments[i] = s.copyWith(monitorIdx: v.round());
                              }),
                            ),
                            DropdownButtonFormField<String>(
                              value: _edges.contains(s.edge) ? s.edge : 'top',
                              decoration: InputDecoration(
                                labelText: l10n.zoneFieldEdge,
                                border: const OutlineInputBorder(),
                              ),
                              items: _edges
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(_zoneEdgeLabel(l10n, e)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (e) {
                                if (e == null) return;
                                setState(() => _segments[i] = s.copyWith(edge: e));
                              },
                            ),
                            Text(l10n.zoneFieldDepthScan(s.depth), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.depth.clamp(1, 50).toDouble(),
                              min: 1,
                              max: 50,
                              divisions: 49,
                              label: '${s.depth}',
                              onChanged: (v) => setState(() {
                                _segments[i] = s.copyWith(depth: v.round());
                              }),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.zoneFieldReverse),
                              value: s.reverse,
                              onChanged: (v) => setState(() => _segments[i] = s.copyWith(reverse: v)),
                            ),
                            DropdownButtonFormField<String?>(
                              value: _deviceIdForDropdown(s, c.config.globalSettings.devices),
                              decoration: InputDecoration(
                                labelText: l10n.zoneFieldDeviceId,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(l10n.zoneDeviceAllDefault),
                                ),
                                ...c.config.globalSettings.devices.map(
                                  (d) => DropdownMenuItem<String?>(
                                    value: d.id,
                                    child: Text('${d.name} (${d.id})'),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _segments[i] = v == null
                                    ? s.copyWith(nullifyDeviceId: true)
                                    : s.copyWith(deviceId: v);
                              }),
                            ),
                            Text(l10n.zoneFieldPixelStart(s.pixelStart), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.pixelStart.clamp(0, pxCap).toDouble(),
                              min: 0,
                              max: pxCap.toDouble(),
                              divisions: math.min(100, pxCap),
                              label: '${s.pixelStart}',
                              onChanged: (v) => setState(() {
                                _segments[i] = s.copyWith(pixelStart: v.round());
                              }),
                            ),
                            Text(l10n.zoneFieldPixelEnd(s.pixelEnd), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.pixelEnd.clamp(0, pxCap).toDouble(),
                              min: 0,
                              max: pxCap.toDouble(),
                              divisions: math.min(100, pxCap),
                              label: '${s.pixelEnd}',
                              onChanged: (v) => setState(() {
                                _segments[i] = s.copyWith(pixelEnd: v.round());
                              }),
                            ),
                            Text(l10n.zoneFieldRefWidth(s.refWidth), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.refWidth.clamp(0, pxCap).toDouble(),
                              min: 0,
                              max: pxCap.toDouble(),
                              divisions: math.min(100, pxCap),
                              label: '${s.refWidth}',
                              onChanged: (v) => setState(() {
                                _segments[i] = s.copyWith(refWidth: v.round());
                              }),
                            ),
                            Text(l10n.zoneFieldRefHeight(s.refHeight), style: Theme.of(context).textTheme.labelLarge),
                            ConfigDragSlider(
                              value: s.refHeight.clamp(0, pxCap).toDouble(),
                              min: 0,
                              max: pxCap.toDouble(),
                              divisions: math.min(100, pxCap),
                              label: '${s.refHeight}',
                              onChanged: (v) => setState(() {
                                _segments[i] = s.copyWith(refHeight: v.round());
                              }),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _applyRefFromCapture(i),
                              icon: const Icon(Icons.aspect_ratio, size: 18),
                              label: Text(l10n.zoneRefFromCapture),
                            ),
                            DropdownButtonFormField<String>(
                              value: _musicEffects.contains(s.musicEffect) ? s.musicEffect : 'default',
                              decoration: InputDecoration(
                                labelText: l10n.zoneFieldMusicEffect,
                                border: const OutlineInputBorder(),
                              ),
                              items: _musicEffects
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(_zoneMusicEffectLabel(l10n, e)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (e) {
                                if (e == null) return;
                                setState(() => _segments[i] = s.copyWith(musicEffect: e));
                              },
                            ),
                            DropdownButtonFormField<String>(
                              value: _roles.contains(s.role) ? s.role : 'auto',
                              decoration: InputDecoration(
                                labelText: l10n.zoneFieldRole,
                                border: const OutlineInputBorder(),
                              ),
                              items: _roles
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(_zoneRoleLabel(l10n, e)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (e) {
                                if (e == null) return;
                                setState(() => _segments[i] = s.copyWith(role: e));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
        );
          },
        );
      },
    );
  }
}
