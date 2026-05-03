import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../application/ambilight_app_controller.dart';
import '../../../core/json/json_utils.dart';
import '../../../core/models/config_models.dart';
import '../../../core/models/pc_health_defaults.dart';
import '../../../features/pc_health/pc_health_frame.dart';
import '../../../features/pc_health/pc_health_snapshot.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';
import '../../widgets/config_drag_slider.dart';

const _kUpdateRateMin = 200.0;
const _kUpdateRateMax = 10000.0;

const _kMetricChoices = <(String, String)>[
  ('cpu_usage', 'CPU zátěž'),
  ('ram_usage', 'RAM'),
  ('net_usage', 'Síť (odhad)'),
  ('cpu_temp', 'Teplota CPU'),
  ('gpu_usage', 'GPU zátěž'),
  ('gpu_temp', 'Teplota GPU'),
  ('disk_usage', 'Disk'),
];

const _kScaleChoices = <String>[
  'blue_green_red',
  'cool_warm',
  'cyan_yellow',
  'rainbow',
  'custom',
];

const _kZoneChoices = <String>['left', 'right', 'top', 'bottom'];

double _finiteOr(double? v, double fallback) {
  if (v == null || !v.isFinite) return fallback;
  return v;
}

/// D7 — `PcHealthSettings` (metriky JSON; editor + náhled).
class PcHealthSettingsTab extends StatefulWidget {
  const PcHealthSettingsTab({
    super.key,
    required this.controller,
    required this.maxWidth,
    required this.onChanged,
  });

  final AmbilightAppController controller;
  final double maxWidth;
  final ValueChanged<PcHealthSettings> onChanged;

  @override
  State<PcHealthSettingsTab> createState() => _PcHealthSettingsTabState();
}

class _PcHealthSettingsTabState extends State<PcHealthSettingsTab> {
  bool _collectBusy = false;
  PcHealthSnapshot? _manualSnapshot;

  PcHealthSnapshot _effectiveSnapshot(AppConfig draft) {
    final tracking =
        draft.globalSettings.startMode == 'pchealth' && draft.pcHealth.enabled;
    if (tracking) return widget.controller.pcHealthSnapshot;
    return _manualSnapshot ?? widget.controller.pcHealthSnapshot;
  }

  Future<void> _measureNow() async {
    setState(() => _collectBusy = true);
    try {
      final s = await widget.controller.collectPcHealthNow();
      if (mounted) setState(() => _manualSnapshot = s);
    } finally {
      if (mounted) setState(() => _collectBusy = false);
    }
  }

  String _platformHint() {
    if (kIsWeb) {
      return 'Na webu se systémové metriky nečtou.';
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'macOS: CPU zátěž je odhad z load average / počet jader; disk z df; síť ze součtu Ibytes v netstat. '
          'Teplotu CPU bez rozšíření typu powermetrics nelze v běžném účtu spolehlivě číst — může zůstat 0. '
          'NVIDIA GPU jen pokud je v PATH nástroj nvidia-smi.';
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'Linux: využití disku v metrice disk_usage zatím není v collectoru naplněné (0). Ostatní z /proc a tepelné zóny.';
    }
    return 'Windows: disk první pevný disk; teplota CPU z ACPI WMI, pokud systém poskytuje data.';
  }

  Future<void> _editMetric(BuildContext context, PcHealthSettings p, int? index) async {
    final isNew = index == null;
    final base = isNew
        ? <String, dynamic>{
            'enabled': true,
            'name': 'Nová metrika',
            'type': 'system',
            'metric': 'net_usage',
            'min_value': 0,
            'max_value': 100,
            'color_scale': 'blue_green_red',
            'brightness_mode': 'dynamic',
            'brightness_min': 50,
            'brightness_max': 255,
            'zones': <String>['left'],
          }
        : Map<String, dynamic>.from(p.metrics[index!]);

    final nameCtrl = TextEditingController(text: base['name']?.toString() ?? '');
    final minCtrl = TextEditingController(text: '${asDouble(base['min_value'], 0)}');
    final maxCtrl = TextEditingController(text: '${asDouble(base['max_value'], 100)}');
    final knownMetrics = {for (final e in _kMetricChoices) e.$1};
    var metricKey = asString(base['metric'], 'cpu_usage');
    if (!knownMetrics.contains(metricKey)) metricKey = _kMetricChoices.first.$1;
    var scale = asString(base['color_scale'], 'blue_green_red');
    if (!_kScaleChoices.contains(scale)) scale = 'blue_green_red';
    var brightMode = asString(base['brightness_mode'], 'dynamic');
    var brightStatic = asInt(base['brightness'], 200);
    var brightMin = asInt(base['brightness_min'], 50);
    var brightMax = asInt(base['brightness_max'], 255);
    var enabled = asBool(base['enabled'], true);
    final zones = <String>{
      for (final z in (base['zones'] as List?) ?? const <dynamic>[]) z.toString().toLowerCase(),
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(isNew ? 'Nová metrika' : 'Upravit metriku'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      title: const Text('Zapnuto'),
                      value: enabled,
                      onChanged: (v) => setLocal(() => enabled = v),
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Název'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: metricKey,
                      decoration: const InputDecoration(labelText: 'Metrika'),
                      items: [
                        for (final e in _kMetricChoices)
                          DropdownMenuItem(value: e.$1, child: Text('${e.$2} (${e.$1})')),
                      ],
                      onChanged: (v) => setLocal(() => metricKey = v ?? metricKey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            decoration: const InputDecoration(labelText: 'Min'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            decoration: const InputDecoration(labelText: 'Max'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: scale,
                      decoration: const InputDecoration(labelText: 'Barevná škála'),
                      items: [
                        for (final s in _kScaleChoices) DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setLocal(() => scale = v ?? scale),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: brightMode,
                      decoration: const InputDecoration(labelText: 'Jas'),
                      items: const [
                        DropdownMenuItem(value: 'static', child: Text('Statický')),
                        DropdownMenuItem(value: 'dynamic', child: Text('Dynamický (podle hodnoty)')),
                      ],
                      onChanged: (v) => setLocal(() => brightMode = v ?? brightMode),
                    ),
                    if (brightMode == 'static') ...[
                      Text('Jas: $brightStatic', style: Theme.of(context).textTheme.labelLarge),
                      ConfigDragSlider(
                        value: brightStatic.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        label: '$brightStatic',
                        onChanged: (v) => setLocal(() => brightStatic = v.round()),
                      ),
                    ] else ...[
                      Text('Jas min: $brightMin', style: Theme.of(context).textTheme.labelLarge),
                      ConfigDragSlider(
                        value: brightMin.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        label: '$brightMin',
                        onChanged: (v) => setLocal(() => brightMin = v.round()),
                      ),
                      Text('Jas max: $brightMax', style: Theme.of(context).textTheme.labelLarge),
                      ConfigDragSlider(
                        value: brightMax.toDouble(),
                        min: 0,
                        max: 255,
                        divisions: 255,
                        label: '$brightMax',
                        onChanged: (v) => setLocal(() => brightMax = v.round()),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text('Zóny', style: Theme.of(context).textTheme.titleSmall),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final z in _kZoneChoices)
                          FilterChip(
                            label: Text(z),
                            selected: zones.contains(z),
                            onSelected: (sel) => setLocal(() {
                              if (sel) {
                                zones.add(z);
                              } else {
                                zones.remove(z);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zrušit')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uložit')),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;

    final out = <String, dynamic>{
      'enabled': enabled,
      'name': nameCtrl.text.trim().isEmpty ? 'Metrika' : nameCtrl.text.trim(),
      'type': 'system',
      'metric': metricKey,
      'min_value': _finiteOr(double.tryParse(minCtrl.text.replaceAll(',', '.')), 0),
      'max_value': _finiteOr(double.tryParse(maxCtrl.text.replaceAll(',', '.')), 100),
      'color_scale': scale,
      'brightness_mode': brightMode,
      'zones': zones.toList(),
    };
    if (brightMode == 'static') {
      out['brightness'] = brightStatic.clamp(0, 255);
    } else {
      out['brightness_min'] = brightMin.clamp(0, 255);
      out['brightness_max'] = brightMax.clamp(0, 255);
    }
    if (scale == 'custom') {
      out['color_low'] = base['color_low'] ?? [0, 0, 255];
      out['color_mid'] = base['color_mid'] ?? [0, 255, 0];
      out['color_high'] = base['color_high'] ?? [255, 0, 0];
    }

    final list = List<Map<String, dynamic>>.from(p.metrics);
    if (isNew) {
      list.add(out);
    } else {
      list[index!] = out;
    }
    widget.onChanged(p.copyWith(metrics: list));
  }

  void _removeMetric(PcHealthSettings p, int i) {
    final list = List<Map<String, dynamic>>.from(p.metrics)..removeAt(i);
    widget.onChanged(p.copyWith(metrics: list));
  }

  void _reorder(PcHealthSettings p, int oldIndex, int newIndex) {
    final list = List<Map<String, dynamic>>.from(p.metrics);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    widget.onChanged(p.copyWith(metrics: list));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final draft = widget.controller.config;
        final p = draft.pcHealth;
        final innerMax = AppBreakpoints.maxContentWidth(widget.maxWidth).clamp(280.0, widget.maxWidth);
        final snap = _effectiveSnapshot(draft);
        final tracking =
            draft.globalSettings.startMode == 'pchealth' && draft.pcHealth.enabled;
        final theme = Theme.of(context);

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
                    title: 'PC Health',
                    subtitle:
                        'Barvy okrajů pásku podle systémových metrik. Na přehledu zvol režim PC Health, aby se výstup posílal na zařízení.',
                    bottomSpacing: 12,
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_platformHint(), style: theme.textTheme.bodySmall),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('PC Health zapnuto'),
                    subtitle: const Text('Vypnuto = černý výstup v tomto režimu.'),
                    value: p.enabled,
                    onChanged: (v) => widget.onChanged(p.copyWith(enabled: v)),
                  ),
                  Text(
                    'Interval aktualizace: ${p.updateRate} ms',
                    style: theme.textTheme.labelLarge,
                  ),
                  ConfigDragSlider(
                    value: p.updateRate.toDouble(),
                    min: _kUpdateRateMin,
                    max: _kUpdateRateMax,
                    divisions: 49,
                    label: '${p.updateRate}',
                    onChanged: (v) => widget.onChanged(p.copyWith(updateRate: v.round())),
                  ),
                  Text('Globální jas: ${p.brightness}', style: theme.textTheme.labelLarge),
                  ConfigDragSlider(
                    value: p.brightness.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: '${p.brightness}',
                    onChanged: (v) => widget.onChanged(p.copyWith(brightness: v.round())),
                  ),
                  const Divider(height: 28),
                  Text('Živý náhled hodnot', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  if (!tracking)
                    Text(
                      'Aktivní režim není PC Health — zobrazuje se poslední snímek nebo ruční měření.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _collectBusy ? null : _measureNow,
                        icon: _collectBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_collectBusy ? 'Měřím…' : 'Změřit teď'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetricPreviewGrid(snapshot: snap, settings: p),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(child: Text('Metriky (${p.metrics.length})', style: theme.textTheme.titleSmall)),
                      TextButton.icon(
                        onPressed: () => _editMetric(context, p, null),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Přidat'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          widget.onChanged(
                            p.copyWith(
                              metrics: builtinPcHealthMetrics().map((e) => Map<String, dynamic>.from(e)).toList(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.restore, size: 20),
                        label: const Text('Výchozí'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (p.metrics.isEmpty)
                    Text('Žádné metriky.', style: theme.textTheme.bodySmall)
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: p.metrics.length,
                      onReorder: (a, b) => _reorder(p, a, b),
                      itemBuilder: (context, i) {
                        final m = p.metrics[i];
                        final title = m['name']?.toString() ?? 'Metrika $i';
                        final type = m['metric']?.toString() ?? '';
                        return Card(
                          key: ValueKey<String>('pc-health-metric-$i-$title'),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text('$type · ${m['zones'] ?? []}'),
                            leading: ReorderableDragStartListener(
                              index: i,
                              child: const Icon(Icons.drag_handle),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Upravit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editMetric(context, p, i),
                                ),
                                IconButton(
                                  tooltip: 'Smazat',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeMetric(p, i),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Text('[staging] PC Health: náhled + editor metrik', style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricPreviewGrid extends StatelessWidget {
  const _MetricPreviewGrid({
    required this.snapshot,
    required this.settings,
  });

  final PcHealthSnapshot snapshot;
  final PcHealthSettings settings;

  static String _fmt(String metric, double v) {
    if (metric.contains('temp')) return v.toStringAsFixed(1);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = settings.metrics.where((m) => asBool(m['enabled'], true)).length;
    final ledPreview = n > 0 ? 48 : 8;
    final colors = PcHealthFrame.compute(
      AppConfig(
        globalSettings: const GlobalSettings(devices: []),
        lightMode: const LightModeSettings(),
        screenMode: const ScreenModeSettings(),
        musicMode: const MusicModeSettings(),
        spotify: const SpotifySettings(),
        systemMediaAlbum: const SystemMediaAlbumSettings(),
        pcHealth: settings,
      ),
      snapshot,
      virtualLedCount: ledPreview,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in settings.metrics)
              if (asBool(m['enabled'], true))
                Chip(
                  avatar: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _fmt(asString(m['metric'], ''), snapshot.valueForMetric(asString(m['metric'], 'cpu_usage'))),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  label: Text(m['name']?.toString() ?? m['metric']?.toString() ?? ''),
                ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Barevný pruh (náhled)', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (var i = 0; i < colors.length; i++)
                  Expanded(
                    child: ColoredBox(
                      color: Color.fromARGB(
                        255,
                        colors[i].$1,
                        colors[i].$2,
                        colors[i].$3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
