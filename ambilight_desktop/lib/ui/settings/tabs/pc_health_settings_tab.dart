import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/models/config_models.dart';
import '../../dashboard_ui.dart';
import '../../layout_breakpoints.dart';

/// D7 — `PcHealthSettings` (metriky JSON; plný editor A5).
class PcHealthSettingsTab extends StatelessWidget {
  const PcHealthSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<PcHealthSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = draft.pcHealth;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);

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
                    'Vizualizace teplot a zátěže na pásku. Zapni režim PC Health na přehledu, aby se výstup promítl.',
                bottomSpacing: 12,
              ),
              SwitchListTile(
                title: const Text('Zapnuto'),
                value: p.enabled,
                onChanged: (v) => onChanged(p.copyWith(enabled: v)),
              ),
              Text('Interval aktualizace (ms): ${p.updateRate}', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: p.updateRate.toDouble().clamp(100, 5000),
                min: 100,
                max: 5000,
                divisions: 49,
                label: '${p.updateRate}',
                onChanged: (v) => onChanged(p.copyWith(updateRate: v.round())),
              ),
              Text('Jas: ${p.brightness}', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: p.brightness.toDouble().clamp(0, 255),
                max: 255,
                divisions: 255,
                label: '${p.brightness}',
                onChanged: (v) => onChanged(p.copyWith(brightness: v.round())),
              ),
              const Divider(height: 24),
              Text('Metriky (${p.metrics.length})', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (p.metrics.isEmpty)
                Text(
                  'Žádné metriky v configu — přidání editoru v agentovi A5.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...p.metrics.asMap().entries.map((e) {
                  final i = e.key;
                  final m = e.value;
                  String preview;
                  try {
                    preview = const JsonEncoder.withIndent('  ').convert(m);
                  } catch (_) {
                    preview = m.toString();
                  }
                  if (preview.length > 220) {
                    preview = '${preview.substring(0, 220)}…';
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      title: Text(m['name']?.toString() ?? 'Metrika $i'),
                      subtitle: Text(m['type']?.toString() ?? ''),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            preview,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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
