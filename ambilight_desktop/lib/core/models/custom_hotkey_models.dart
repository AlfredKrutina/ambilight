import '../json/json_utils.dart';

/// Akce odpovídající Python `settings_dialog` / `_handle_action_main_thread` (řetězce v JSON).
enum CustomAmbilightAction {
  brightUp('bright_up'),
  brightDown('bright_down'),
  brightMax('bright_max'),
  brightMin('bright_min'),
  togglePower('toggle_power'),
  modeMusic('mode_music'),
  modeScreen('mode_screen'),
  modeLight('mode_light'),
  modeNext('mode_next'),
  effectNext('effect_next'),
  presetNext('preset_next'),
  calibAuto('calib_auto'),
  unknown('');

  const CustomAmbilightAction(this.wireValue);

  final String wireValue;

  static CustomAmbilightAction parse(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return CustomAmbilightAction.unknown;
    for (final v in CustomAmbilightAction.values) {
      if (v != CustomAmbilightAction.unknown && v.wireValue == s) {
        return v;
      }
    }
    return CustomAmbilightAction.unknown;
  }
}

/// Jedna položka z `custom_hotkeys` (Python: `{ name, key, action, payload }`).
class CustomHotkeyEntry {
  const CustomHotkeyEntry({
    this.name = '',
    required this.key,
    required this.action,
    this.payload = const {},
  });

  final String name;
  /// Stejný formát jako globální hotkeys, např. `ctrl+shift+l`.
  final String key;
  final CustomAmbilightAction action;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'name': name,
        'key': key,
        'action': action.wireValue,
        'payload': payload,
      };

  factory CustomHotkeyEntry.fromJson(Map<String, dynamic> j) {
    return CustomHotkeyEntry(
      name: asString(j['name'], ''),
      key: asString(j['key'], ''),
      action: CustomAmbilightAction.parse(j['action']?.toString()),
      payload: j['payload'] is Map
          ? Map<String, dynamic>.from(j['payload'] as Map)
          : const {},
    );
  }
}
