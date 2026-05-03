/// Základní validace řetězců hotkey (ctrl+shift+l apod.).
String? validateHotkeyField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final lower = v.toLowerCase();
  if (lower != v) return 'Použijte malá písmena (např. ctrl+shift+l).';
  if (!RegExp(r'^[a-z0-9+\s]+$').hasMatch(lower)) {
    return 'Povolená jsou písmena, čísla, + a mezery.';
  }
  final parts = lower.split('+').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  const mods = {'ctrl', 'shift', 'alt', 'meta', 'win', 'cmd'};
  for (final p in parts) {
    if (mods.contains(p)) continue;
    if (RegExp(r'^[a-z]$').hasMatch(p)) continue;
    if (RegExp(r'^[0-9]$').hasMatch(p)) continue;
    if (RegExp(r'^f([1-9]|1[0-2])$').hasMatch(p)) continue;
    if (RegExp(r'^[a-z0-9]{2,12}$').hasMatch(p)) continue;
    return 'Neplatný segment klávesy: $p';
  }
  return null;
}
