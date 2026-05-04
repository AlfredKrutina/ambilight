import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/ambilight_app_controller.dart';
import '../../core/models/config_models.dart';
import '../../core/protocol/serial_frame.dart';
import '../../features/screen_capture/screen_capture_source.dart';
import '../../l10n/context_ext.dart';
import '../../l10n/generated/app_localizations.dart';
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
  _SideStep({required this.captureKey, required this.title, required this.description});
  final String captureKey;
  final String title;
  final String description;
}

class _LedStripWizardDialogState extends State<LedStripWizardDialog> {
  static const _order = ['left', 'top', 'right', 'bottom'];

  Map<String, List<_SideStep>> _sideSteps(AppLocalizations l10n) => {
        'left': [
          _SideStep(
            captureKey: 'left_start',
            title: l10n.ledWizLeftStartTitle,
            description: l10n.ledWizLeftStartBody,
          ),
          _SideStep(
            captureKey: 'left_end',
            title: l10n.ledWizLeftEndTitle,
            description: l10n.ledWizLeftEndBody,
          ),
        ],
        'top': [
          _SideStep(
            captureKey: 'top_start',
            title: l10n.ledWizTopStartTitle,
            description: l10n.ledWizTopStartBody,
          ),
          _SideStep(
            captureKey: 'top_end',
            title: l10n.ledWizTopEndTitle,
            description: l10n.ledWizTopEndBody,
          ),
        ],
        'right': [
          _SideStep(
            captureKey: 'right_start',
            title: l10n.ledWizRightStartTitle,
            description: l10n.ledWizRightStartBody,
          ),
          _SideStep(
            captureKey: 'right_end',
            title: l10n.ledWizRightEndTitle,
            description: l10n.ledWizRightEndBody,
          ),
        ],
        'bottom': [
          _SideStep(
            captureKey: 'bottom_start',
            title: l10n.ledWizBottomStartTitle,
            description: l10n.ledWizBottomStartBody,
          ),
          _SideStep(
            captureKey: 'bottom_end',
            title: l10n.ledWizBottomEndTitle,
            description: l10n.ledWizBottomEndBody,
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
      final l10n = AppLocalizations.of(context);
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
        _steps = [_WizardStep.config(l10n)];
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

  void _buildStepsAfterConfig(AppLocalizations l10n) {
    final sides = <String>[];
    if (_chkLeft) sides.add('left');
    if (_chkTop) sides.add('top');
    if (_chkRight) sides.add('right');
    if (_chkBottom) sides.add('bottom');
    final sideMap = _sideSteps(l10n);
    final next = <_WizardStep>[_steps.first];
    for (final side in _order) {
      if (!sides.contains(side)) continue;
      for (final p in sideMap[side]!) {
        next.add(_WizardStep.point(p));
      }
    }
    next.add(_WizardStep.finish(l10n));
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
      final snack = AppLocalizations.of(context).ledWizSavedSnack(
        newSegs.length,
        newLedCount,
        _monitorMss,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snack)),
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
    final c = context.read<AmbilightAppController>();
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([c, c.previewFrameNotifier]),
      builder: (context, _) {
        final l10n = context.l10n;
        final dev = _findDevice(c.config);
        final monLocked = widget.overrideMonitorIndex != null;

        final step = _steps.isEmpty || _stepIndex >= _steps.length
            ? _WizardStep.config(l10n)
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
        title: dev != null ? l10n.ledWizTitleWithDevice(dev.name) : l10n.ledWizTitle,
        actions: _actions(context, l10n, c, step, dev),
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
                        l10n.ledWizMonitorLocked(_monitorMss),
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    if (widget.appendMode)
                      Text(
                        l10n.ledWizAppendBadge,
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
              l10n.ledWizStepProgress(_stepIndex + 1, _steps.isEmpty ? 1 : _steps.length),
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
                  l10n.ledWizAddDeviceFirst,
                  style: TextStyle(color: scheme.error),
                )
              else
                DropdownButtonFormField<String>(
                  value: _resolvedDeviceId(c.config)!,
                  decoration: InputDecoration(
                    labelText: l10n.ledWizDeviceLabel,
                    border: const OutlineInputBorder(),
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
              Text(l10n.ledWizStripSides, style: Theme.of(context).textTheme.titleSmall),
              CheckboxListTile(
                value: _chkLeft,
                onChanged: (v) => setState(() => _chkLeft = v ?? false),
                title: Text(l10n.scanEdgeLeft),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _chkTop,
                onChanged: (v) => setState(() => _chkTop = v ?? false),
                title: Text(l10n.scanEdgeTop),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _chkRight,
                onChanged: (v) => setState(() => _chkRight = v ?? false),
                title: Text(l10n.scanEdgeRight),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _chkBottom,
                onChanged: (v) => setState(() => _chkBottom = v ?? false),
                title: Text(l10n.scanEdgeBottom),
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
                    decoration: InputDecoration(
                      labelText: l10n.ledWizRefMonitorLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final m in _monitors)
                        DropdownMenuItem(
                          value: m.mssStyleIndex,
                          child: Text(
                            l10n.ledWizMonitorLine(
                              m.mssStyleIndex,
                              m.width,
                              m.height,
                              m.isPrimary ? l10n.ledWizPrimarySuffix : '',
                            ),
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
                    decoration: InputDecoration(
                      labelText: l10n.ledWizMonitorManualLabel,
                      border: const OutlineInputBorder(),
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
                  title: Text(l10n.ledWizAppendSegmentsTitle),
                  subtitle: Text(l10n.ledWizAppendSegmentsSubtitle),
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
                label: l10n.ledWizLedIndexSlider(_sliderValue.round()),
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
                  Text(l10n.ledWizLedIndexRow(_sliderValue.round())),
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
          ],
        ),
      ),
    );
      },
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AppLocalizations l10n,
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
        child: Text(l10n.cancel),
      ),
      if (_stepIndex > 0)
        TextButton(
          onPressed: () {
            setState(() {
              _stepIndex--;
              if (_steps[_stepIndex].kind == _WizardStepKind.config) {
                _steps = [_WizardStep.config(l10n)];
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
          child: Text(l10n.back),
        ),
      if (step.kind == _WizardStepKind.config)
        FilledButton(
          onPressed: dev == null
              ? null
              : () {
                  if (!_chkLeft && !_chkTop && !_chkRight && !_chkBottom) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.ledWizPickOneSideSnack)),
                    );
                    return;
                  }
                  final id = _resolvedDeviceId(c.config);
                  if (id != null) {
                    c.announceStripLengthForDevice(id);
                  }
                  _buildStepsAfterConfig(l10n);
                },
          child: Text(l10n.ledWizStartCalibration),
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
          child: Text(_stepIndex == _steps.length - 2 ? l10n.ledWizSummary : l10n.ledWizNext),
        )
      else
        FilledButton(
          onPressed: dev == null ? null : () => unawaited(_finish(c)),
          child: Text(l10n.ledWizSaveClose),
        ),
    ];
  }
}

enum _WizardStepKind { config, point, finish }

class _WizardStep {
  _WizardStep(this.kind, this.title, this.description, this.sideStep);

  factory _WizardStep.config(AppLocalizations l10n) => _WizardStep(
        _WizardStepKind.config,
        l10n.ledWizConfigTitle,
        l10n.ledWizConfigBody,
        null,
      );

  factory _WizardStep.point(_SideStep s) => _WizardStep(
        _WizardStepKind.point,
        s.title,
        s.description,
        s,
      );

  factory _WizardStep.finish(AppLocalizations l10n) => _WizardStep(
        _WizardStepKind.finish,
        l10n.ledWizFinishTitle,
        l10n.ledWizFinishBody,
        null,
      );

  final _WizardStepKind kind;
  final String title;
  final String description;
  final _SideStep? sideStep;
}
