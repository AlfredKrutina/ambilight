import 'package:flutter/material.dart';

import '../../../core/models/config_models.dart';
import '../config_backup_section.dart';
import '../hotkey_validation.dart';
import '../settings_common.dart';
import '../../layout_breakpoints.dart';

List<Widget> globalSettingsFields(
  BuildContext context,
  GlobalSettings g,
  ValueChanged<GlobalSettings> onChanged,
) {
  return [
    DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Výchozí režim po startu',
        border: OutlineInputBorder(),
      ),
      value: g.startMode,
      items: const [
        DropdownMenuItem(value: 'light', child: Text('light')),
        DropdownMenuItem(value: 'screen', child: Text('screen')),
        DropdownMenuItem(value: 'music', child: Text('music')),
        DropdownMenuItem(value: 'pchealth', child: Text('pchealth')),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(g.copyWith(startMode: v));
      },
    ),
    Builder(
      builder: (context) {
        final themeKey = g.theme.toLowerCase() == 'light' ? 'light' : 'dark';
        return SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'dark', label: Text('Tmavé'), icon: Icon(Icons.dark_mode_outlined)),
            ButtonSegment(value: 'light', label: Text('Světlé'), icon: Icon(Icons.light_mode_outlined)),
          ],
          selected: {themeKey},
          onSelectionChanged: (s) {
            if (s.isEmpty) return;
            onChanged(g.copyWith(theme: s.first));
          },
        );
      },
    ),
    SwitchListTile(
      title: const Text('Animace rozhraní'),
      subtitle: const Text(
        'Krátké přechody mezi sekcemi. Vypni při opakované práci — respektuje i systémové snížení animací.',
      ),
      value: g.uiAnimationsEnabled,
      onChanged: (v) => onChanged(g.copyWith(uiAnimationsEnabled: v)),
    ),
    SwitchListTile(
      title: const Text('Autostart'),
      value: g.autostart,
      onChanged: (v) => onChanged(g.copyWith(autostart: v)),
    ),
    SwitchListTile(
      title: const Text('Spustit minimalizovaně'),
      value: g.startMinimized,
      onChanged: (v) => onChanged(g.copyWith(startMinimized: v)),
    ),
    TextFormField(
      initialValue: g.captureMethod,
      decoration: const InputDecoration(
        labelText: 'Metoda snímání obrazovky (capture_method)',
        hintText: 'mss, dxcam, …',
        border: OutlineInputBorder(),
      ),
      onChanged: (v) => onChanged(g.copyWith(captureMethod: v)),
    ),
    SwitchListTile(
      title: const Text('Globální zkratky zapnuty'),
      subtitle: const Text('macOS: Accessibility — context/README_PERMISSIONS.md'),
      value: g.hotkeysEnabled,
      onChanged: (v) => onChanged(g.copyWith(hotkeysEnabled: v)),
    ),
    TextFormField(
      initialValue: g.hotkeyToggle,
      decoration: const InputDecoration(
        labelText: 'Hotkey — přepnutí',
        border: OutlineInputBorder(),
      ),
      validator: validateHotkeyField,
      onChanged: (v) => onChanged(g.copyWith(hotkeyToggle: v)),
    ),
    TextFormField(
      initialValue: g.hotkeyModeLight,
      decoration: const InputDecoration(
        labelText: 'Hotkey — režim light (volitelné)',
        border: OutlineInputBorder(),
      ),
      validator: validateHotkeyField,
      onChanged: (v) => onChanged(g.copyWith(hotkeyModeLight: v)),
    ),
    TextFormField(
      initialValue: g.hotkeyModeScreen,
      decoration: const InputDecoration(
        labelText: 'Hotkey — režim screen (volitelné)',
        border: OutlineInputBorder(),
      ),
      validator: validateHotkeyField,
      onChanged: (v) => onChanged(g.copyWith(hotkeyModeScreen: v)),
    ),
    TextFormField(
      initialValue: g.hotkeyModeMusic,
      decoration: const InputDecoration(
        labelText: 'Hotkey — režim music (volitelné)',
        border: OutlineInputBorder(),
      ),
      validator: validateHotkeyField,
      onChanged: (v) => onChanged(g.copyWith(hotkeyModeMusic: v)),
    ),
  ];
}

class GlobalSettingsTab extends StatelessWidget {
  const GlobalSettingsTab({
    super.key,
    required this.draft,
    required this.maxWidth,
    required this.onChanged,
    this.onImportedFromDisk,
  });

  final AppConfig draft;
  final double maxWidth;
  final ValueChanged<GlobalSettings> onChanged;
  final VoidCallback? onImportedFromDisk;

  @override
  Widget build(BuildContext context) {
    final g = draft.globalSettings;
    final innerMax = AppBreakpoints.maxContentWidth(maxWidth).clamp(280.0, maxWidth);
    final fields = globalSettingsFields(context, g, onChanged);
    const splitAt = 5;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: innerMax),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (AppBreakpoints.formColumnsForWidth(innerMax) >= 2)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: paddedSettingsColumn(fields.take(splitAt))),
                    const SizedBox(width: 16),
                    Expanded(child: paddedSettingsColumn(fields.skip(splitAt))),
                  ],
                )
              else
                paddedSettingsColumn(fields),
              ConfigBackupSection(onImported: onImportedFromDisk),
            ],
          ),
        ),
      ),
    );
  }
}
