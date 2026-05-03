import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../../core/protocol/serial_frame.dart';
import '../../features/screen_capture/screen_capture_source.dart';
import '../widgets/config_drag_slider.dart';
import 'wizard_dialog_shell.dart';

/// Interaktivní průvodce mapování LED na okraje monitoru (parita `led_wizard.py`).
///
/// Posuvník rozsvěcuje jednu zelenou LED; po průchodu stranami se vytvoří [LedSegment] a uloží config.
class LedStripWizardDialog extends StatefulWidget {
  const LedStripWizardDialog({
    super.key,
    this.initialDeviceId,
    this.overrideMonitorIndex,
    this.appendMode = false,
  });

  /// Volitelně předvybrané zařízení (např. z karty Zařízení).
  final String? initialDeviceId;

  /// Je-li kladné, index monitoru (MSS 1…n) je zamčený.
  final int? overrideMonitorIndex;

  /// Přidat segmenty k existujícím místo přepsání segmentů daného zařízení.
  final bool appendMode;

  static Future<void> show(
    BuildContext context, {
    String? deviceId,
    int? overrideMonitorIndex,
    bool appendMode = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LedStripWizardDialog(
        initialDeviceId: deviceId,
        overrideMonitorIndex: overrideMonitorIndex,
        appendMode: appendMode,
      ),
    );
  }

  @override
  State<LedStripWizardDialog> createState() => _LedStripWizardDialogState();
}

class _SideStep {
  const _SideStep({required this.captureKey, required this.title, required this.description});
  final String captureKey;
  final String title;
  final String description;
}

class _LedStripWizardDialogState extends State<LedStripWizardDialog> {
  static const _order = ['left', 'top', 'right', 'bottom'];
  static final Map<String, List<_SideStep>> _sideSteps = {
    'left': const [
      _SideStep(
        captureKey: 'left_start',
        title: 'Levá strana — začátek',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **začátku** levé strany (obvykle dole).',
      ),
      _SideStep(
        captureKey: 'left_end',
        title: 'Levá strana — konec',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **konci** levé strany (obvykle nahoře).',
      ),
    ],
    'top': const [
      _SideStep(
        captureKey: 'top_start',
        title: 'Horní strana — začátek',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **začátku** horní hrany (vlevo).',
      ),
      _SideStep(
        captureKey: 'top_end',
        title: 'Horní strana — konec',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **konci** horní hrany (vpravo).',
      ),
    ],
    'right': const [
      _SideStep(
        captureKey: 'right_start',
        title: 'Pravá strana — začátek',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **začátku** pravé strany (nahoře).',
      ),
      _SideStep(
        captureKey: 'right_end',
        title: 'Pravá strana — konec',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **konci** pravé strany (dole).',
      ),
    ],
    'bottom': const [
      _SideStep(
        captureKey: 'bottom_start',
        title: 'Spodní strana — začátek',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **začátku** spodní hrany (vpravo).',
      ),
      _SideStep(
        captureKey: 'bottom_end',
        title: 'Spodní strana — konec',
        description:
            'Posuňte posuvník tak, aby **zelená LED** byla na **konci** spodní hrany (vlevo).',
      ),
    ],
  };

  AmbilightAppController? _controller;

  int _stepIndex = 0;
  List<_WizardStep> _steps = [];

  String? _deviceId;
  bool _chkLeft = true;
  bool _chkTop = true;
  bool _chkRight = true;
  bool _chkBottom = false;
  int _monitorMss = 1;
  bool _append = false;

  double _sliderValue = 0;
  final Map<String, int> _captured = {};
  late final TextEditingController _monitorFieldCtrl;
  List<MonitorInfo> _monitors = [];
  bool _monitorsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<AmbilightAppController>();
  }

  @override
  void initState() {
    super.initState();
    _monitorFieldCtrl = TextEditingController(text: '1');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = context.read<AmbilightAppController>();
      final devs = c.config.globalSettings.devices;
      final devId = widget.initialDeviceId ??
          (devs.isNotEmpty ? devs.first.id : null);
      final mon = widget.overrideMonitorIndex ??
          c.config.screenMode.monitorIndex.clamp(1, 16);
      setState(() {
        _deviceId = devId;
        _monitorMss = mon;
        _append = widget.appendMode;
        _steps = [_WizardStep.config()];
      });
      _monitorFieldCtrl.text = '$_monitorMss';
      _syncSliderFromDevice(c);
      unawaited(_loadMonitors());
    });
  }

  Future<void> _loadMonitors() async {
    try {
      final src = ScreenCaptureSource.platform();
      final list = await src.listMonitors();
      src.dispose();
      if (!mounted) return;
      setState(() {
        _monitors = list;
        _monitorsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _monitorsLoaded = true);
    }
  }

  int _monitorDropdownValue() {
    if (_monitors.any((m) => m.mssStyleIndex == _monitorMss)) return _monitorMss;
    if (_monitors.isNotEmpty) return _monitors.first.mssStyleIndex;
    return _monitorMss.clamp(1, 32);
  }

  void _syncSliderFromDevice(AmbilightAppController c) {
    final d = _findDevice(c.config);
    final maxIdx = _sliderMaxForDevice(d);
    final ledN = d?.ledCount ?? c.config.globalSettings.ledCount;
    final v = (ledN ~/ 2).clamp(0, maxIdx).toDouble();
    setState(() => _sliderValue = v);
    _pushPreview(c);
  }

  /// Platné ID vůči aktuálnímu seznamu zařízení (dropdown nesmí mít hodnotu mimo items).
  String? _resolvedDeviceId(AppConfig cfg) {
    final ds = cfg.globalSettings.devices;
    if (ds.isEmpty) return null;
    final id = _deviceId;
    if (id != null && ds.any((d) => d.id == id)) return id;
    return ds.first.id;
  }

  DeviceSettings? _findDevice(AppConfig cfg) {
    final id = _resolvedDeviceId(cfg);
    if (id == null) return null;
    for (final d in cfg.globalSettings.devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  int _sliderMaxForDevice(DeviceSettings? d) {
    if (d == null) return SerialAmbilightProtocol.maxLedsPerDevice - 1;
    return math.max(0, SerialAmbilightProtocol.maxLedsPerDevice - 1);
  }

  void _pushPreview(AmbilightAppController c) {
    final id = _resolvedDeviceId(c.config);
    if (id == null) return;
    final step = _steps.isEmpty || _stepIndex >= _steps.length ? null : _steps[_stepIndex];
    if (step == null || step.kind != _WizardStepKind.point) {
      c.setWizardLedPreview(null, -1, 0, 0, 0);
      return;
    }
    c.setWizardLedPreview(id, _sliderValue.round(), 0, 255, 0);
  }

  void _buildStepsAfterConfig() {
    final sides = <String>[];
    if (_chkLeft) sides.add('left');
    if (_chkTop) sides.add('top');
    if (_chkRight) sides.add('right');
    if (_chkBottom) sides.add('bottom');
    final next = <_WizardStep>[_steps.first];
    for (final side in _order) {
      if (!sides.contains(side)) continue;
      for (final p in _sideSteps[side]!) {
        next.add(_WizardStep.point(p));
      }
    }
    next.add(_WizardStep.finish());
    setState(() {
      _steps = next;
      _stepIndex = 1;
    });
    final c = context.read<AmbilightAppController>();
    _syncSliderFromDevice(c);
  }

  (int, int) _monitorSize(AmbilightAppController c) {
    final f = c.latestScreenFrame;
    if (f != null && f.isValid && f.monitorIndex == _monitorMss) {
      return (f.width, f.height);
    }
    return (1920, 1080);
  }

  Future<void> _finish(AmbilightAppController c) async {
    final dev = _findDevice(c.config);
    final targetId = _resolvedDeviceId(c.config);
    if (dev == null || targetId == null) return;

    final (monW, monH) = _monitorSize(c);
    final padPct = c.config.screenMode.paddingPercent / 100.0;
    final padLeft = (monW * padPct).round();
    final padRight = (monW * padPct).round();
    final padTop = (monH * padPct).round();
    final padBottom = (monH * padPct).round();
    final effW = monW - padLeft - padRight;
    final effH = monH - padTop - padBottom;

    var maxLedIdx = 0;
    final newSegs = <LedSegment>[];
    final sides = <String>[];
    if (_chkLeft) sides.add('left');
    if (_chkTop) sides.add('top');
    if (_chkRight) sides.add('right');
    if (_chkBottom) sides.add('bottom');

    for (final side in sides) {
      final sKey = '${side}_start';
      final eKey = '${side}_end';
      final s = _captured[sKey] ?? 0;
      final e = _captured[eKey] ?? 0;
      maxLedIdx = math.max(maxLedIdx, math.max(s, e));

      final (pixelStart, pixelEnd) = (side == 'top' || side == 'bottom')
          ? (padLeft, padLeft + effW)
          : (padTop, padTop + effH);

      final autoReverse = side == 'bottom' || side == 'left';

      newSegs.add(LedSegment(
        ledStart: s,
        ledEnd: e,
        monitorIdx: _monitorMss,
        edge: side,
        depth: 10,
        reverse: autoReverse,
        deviceId: targetId,
        pixelStart: pixelStart,
        pixelEnd: pixelEnd,
        refWidth: monW,
        refHeight: monH,
      ));
    }

    final newLedCount = math.max(dev.ledCount, maxLedIdx + 1);
    final devs = c.config.globalSettings.devices
        .map((d) => d.id == targetId ? d.copyWith(ledCount: newLedCount) : d)
        .toList();

    List<LedSegment> merged;
    if (_append) {
      merged = List<LedSegment>.of(c.config.screenMode.segments);
    } else {
      merged = c.config.screenMode.segments
          .where((s) => s.deviceId != targetId)
          .toList();
    }
    merged.addAll(newSegs);

    c.setWizardLedPreview(null, -1, 0, 0, 0);

    await c.applyConfigAndPersist(
      c.config.copyWith(
        globalSettings: c.config.globalSettings.copyWith(
          devices: devs,
          startMode: 'screen',
        ),
        screenMode: c.config.screenMode.copyWith(
          segments: merged,
          monitorIndex: _monitorMss,
        ),
      ),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uloženo ${newSegs.length} segmentů, LED $newLedCount, monitor $_monitorMss.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _monitorFieldCtrl.dispose();
    _controller?.setWizardLedPreview(null, -1, 0, 0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AmbilightAppController>();
    final scheme = Theme.of(context).colorScheme;
    final dev = _findDevice(c.config);
    final monLocked = widget.overrideMonitorIndex != null;

    final step = _steps.isEmpty || _stepIndex >= _steps.length
        ? _WizardStep.config()
        : _steps[_stepIndex];

    final maxIdx = _sliderMaxForDevice(dev).toDouble();
    if (_sliderValue > maxIdx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sliderValue = maxIdx);
      });
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) c.setWizardLedPreview(null, -1, 0, 0, 0);
      },
      child: WizardDialogShell(
        title: dev != null ? 'Průvodce LED — ${dev.name}' : 'Průvodce LED',
        actions: _actions(context, c, step, dev),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.appendMode || widget.overrideMonitorIndex != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 12,
                  children: [
                    if (widget.overrideMonitorIndex != null)
                      Text(
                        'Monitor: $_monitorMss (zámek)',
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    if (widget.appendMode)
                      Text(
                        'Režim: přidat segmenty',
                        style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            LinearProgressIndicator(
              value: _steps.isEmpty ? null : (_stepIndex + 1) / _steps.length,
            ),
            const SizedBox(height: 12),
            Text(
              'Krok ${_stepIndex + 1} / ${_steps.isEmpty ? 1 : _steps.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(step.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(step.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (step.kind == _WizardStepKind.config) ...[
              if (c.config.globalSettings.devices.isEmpty)
                Text(
                  'Nejdřív přidejte zařízení (Discovery nebo ručně).',
                  style: TextStyle(color: scheme.error),
                )
              else
                DropdownButtonFormField<String>(
                  value: _resolvedDeviceId(c.config)!,
                  decoration: const InputDecoration(
                    labelText: 'Zařízení',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final d in c.config.globalSettings.devices)
                      DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.id})')),
                  ],
                  onChanged: (v) => setState(() {
                    _deviceId = v;
                    _syncSliderFromDevice(c);
                  }),
                ),
              const SizedBox(height: 12),
              Text('Strany pásku', style: Theme.of(context).textTheme.titleSmall),
              CheckboxListTile(
                value: _chkLeft,
                onChanged: (v) => setState(() => _chkLeft = v ?? false),
                title: const Text('Levá'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _chkTop,
                onChanged: (v) => setState(() => _chkTop = v ?? false),
                title: const Text('Horní'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _chkRight,
                onChanged: (v) => setState(() => _chkRight = v ?? false),
                title: const Text('Pravá'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _chkBottom,
                onChanged: (v) => setState(() => _chkBottom = v ?? false),
                title: const Text('Spodní'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (!monLocked) ...[
                const SizedBox(height: 8),
                if (!_monitorsLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_monitors.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: _monitorDropdownValue(),
                    decoration: const InputDecoration(
                      labelText: 'Referenční monitor (nativní seznam)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in _monitors)
                        DropdownMenuItem(
                          value: m.mssStyleIndex,
                          child: Text(
                            'Monitor ${m.mssStyleIndex} — ${m.width}×${m.height}'
                            '${m.isPrimary ? ' · primární' : ''}',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _monitorMss = v;
                        _monitorFieldCtrl.text = '$v';
                      });
                    },
                  )
                else
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Index monitoru (MSS, ručně — seznam nedostupný)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    controller: _monitorFieldCtrl,
                    onChanged: (t) {
                      final n = int.tryParse(t.trim());
                      if (n != null) setState(() => _monitorMss = n.clamp(1, 32));
                    },
                  ),
              ],
              if (widget.overrideMonitorIndex == null) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _append,
                  onChanged: (v) => setState(() => _append = v ?? false),
                  title: const Text('Přidat k existujícím segmentům (multi-monitor)'),
                  subtitle: const Text('Jinak se smažou segmenty jen tohoto zařízení.'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
            if (step.kind == _WizardStepKind.point) ...[
              ConfigDragSlider(
                value: _sliderValue.clamp(0, maxIdx),
                min: 0,
                max: maxIdx,
                divisions: maxIdx > 0 ? maxIdx.round() : null,
                label: 'LED index ${_sliderValue.round()}',
                onChanged: (v) {
                  setState(() => _sliderValue = v);
                  _pushPreview(c);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '−1',
                    onPressed: () {
                      setState(() {
                        _sliderValue = (_sliderValue - 1).clamp(0, maxIdx);
                      });
                      _pushPreview(c);
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  Text('Index LED: ${_sliderValue.round()}'),
                  IconButton(
                    tooltip: '+1',
                    onPressed: () {
                      setState(() {
                        _sliderValue = (_sliderValue + 1).clamp(0, maxIdx);
                      });
                      _pushPreview(c);
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
            if (step.kind == _WizardStepKind.finish) ...[
              Text(
                'Konfigurace je hotová. Uložením se nastaví režim Obrazovka, '
                'aktualizují se segmenty a případně počet LED u zařízení.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AmbilightAppController c,
    _WizardStep step,
    DeviceSettings? dev,
  ) {
    return [
      TextButton(
        onPressed: () {
          c.setWizardLedPreview(null, -1, 0, 0, 0);
          Navigator.pop(context);
        },
        child: const Text('Zrušit'),
      ),
      if (_stepIndex > 0)
        TextButton(
          onPressed: () {
            setState(() {
              _stepIndex--;
              if (_steps[_stepIndex].kind == _WizardStepKind.config) {
                _steps = [_WizardStep.config()];
                _stepIndex = 0;
              } else if (_steps[_stepIndex].kind == _WizardStepKind.point) {
                final key = _steps[_stepIndex].sideStep!.captureKey;
                final prev = _captured[key];
                if (prev != null) {
                  _sliderValue = prev.toDouble();
                }
              }
            });
            _pushPreview(c);
          },
          child: const Text('Zpět'),
        ),
      if (step.kind == _WizardStepKind.config)
        FilledButton(
          onPressed: dev == null
              ? null
              : () {
                  if (!_chkLeft && !_chkTop && !_chkRight && !_chkBottom) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vyberte alespoň jednu stranu.')),
                    );
                    return;
                  }
                  final id = _resolvedDeviceId(c.config);
                  if (id != null) {
                    c.announceStripLengthForDevice(id);
                  }
                  _buildStepsAfterConfig();
                },
          child: const Text('Spustit kalibraci'),
        )
      else if (step.kind == _WizardStepKind.point)
        FilledButton(
          onPressed: dev == null
              ? null
              : () {
                  final p = step.sideStep!;
                  _captured[p.captureKey] = _sliderValue.round();
                  if (_stepIndex < _steps.length - 1) {
                    setState(() {
                      _stepIndex++;
                      final next = _steps[_stepIndex];
                      if (next.kind == _WizardStepKind.point) {
                        final key = next.sideStep!.captureKey;
                        final existing = _captured[key];
                        if (existing != null) {
                          _sliderValue = existing.toDouble();
                        } else {
                          // Zachovat posuvník z předchozího kroku (ne reset na ledCount~/2).
                          final d = _findDevice(c.config);
                          final maxIdx = _sliderMaxForDevice(d).toDouble();
                          _sliderValue = _sliderValue.clamp(0, maxIdx);
                        }
                      }
                    });
                    final after = _steps[_stepIndex];
                    if (after.kind != _WizardStepKind.point) {
                      c.setWizardLedPreview(null, -1, 0, 0, 0);
                    }
                    _pushPreview(c);
                  }
                },
          child: Text(_stepIndex == _steps.length - 2 ? 'Shrnutí' : 'Další'),
        )
      else
        FilledButton(
          onPressed: dev == null ? null : () => unawaited(_finish(c)),
          child: const Text('Uložit a zavřít'),
        ),
    ];
  }
}

enum _WizardStepKind { config, point, finish }

class _WizardStep {
  const _WizardStep._(this.kind, this.title, this.description, this.sideStep);

  factory _WizardStep.config() => const _WizardStep._(
        _WizardStepKind.config,
        'Konfigurace',
        'V Nastavení → Zařízení nastav „Počet LED“ alespoň na horní odhad délky pásku '
            '(max. 2000). Před kalibrací aplikace pošle na ESP USB příkaz s tímto počtem. '
            'Pak vyber strany a monitor — u každého bodu posuneš zelenou LED na fyzické místo.',
        null,
      );

  factory _WizardStep.point(_SideStep s) => _WizardStep._(
        _WizardStepKind.point,
        s.title,
        s.description,
        s,
      );

  factory _WizardStep.finish() => const _WizardStep._(
        _WizardStepKind.finish,
        'Hotovo',
        'Segmenty se dopočítají z uložených indexů.',
        null,
      );

  final _WizardStepKind kind;
  final String title;
  final String description;
  final _SideStep? sideStep;
}
