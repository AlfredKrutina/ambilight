# SettingsPage — textová struktura widgetů (D3/D4/A5)

Pro PR / dokumentaci: hierarchie po úpravách v `ambilight_desktop/lib/ui/settings_page.dart` a `layout_breakpoints.dart`.

## Kořen

- `SettingsPage` (**StatefulWidget** + `SingleTickerProviderStateMixin`)
  - `LayoutBuilder`
    - `Form` (`GlobalKey<FormState>`)
      - **Šířka ≥ 600 dp (`AppBreakpoints.useSettingsSideRail`):** `Row`
        - `NavigationRail` (3 cíle: Globální, Zařízení, Světlo) — `extended` od ≥ 1200 dp
        - `VerticalDivider`
        - `Column`
          - `Expanded` → `TabBarView` (`TabController`, `NeverScrollableScrollPhysics`)
          - spodní lišta akcí (viz níže)
      - **Šířka < 600 dp:** `Column`
        - `TabBar` (stejné 3 záložky, `TabController`)
        - `Expanded` → `TabBarView` (swipe zapnuto)
        - stejná spodní lišta akcí

### Spodní lišta (oba layouty)

- `Material` → `SafeArea` → `Padding` → `Row`
  - indikátor „Neuložené změny“ (jen pokud draft změněn)
  - `TextButton` „Zrušit“ (obnoví `AppConfig` z `AmbilightAppController`, bump `_formSeed`)
  - `FilledButton` „Použít a uložit“ → `validate()` + `applyConfigAndPersist(_draft)`

### `TabBarView` — děti (každá obalená `KeyedSubtree` + `ValueKey('tab-*-$_formSeed')` pro reset polí)

1. **`_GlobalSettingsTab`**
   - `Align` → `SingleChildScrollView` → `ConstrainedBox` (`maxWidth` z `AppBreakpoints.maxContentWidth`)
   - **≥ 600 dp:** `Row` se dvěma `Expanded` sloupci (`_paddedFieldColumn` na `fields.take(5)` / `skip(5)`)
   - **< 600 dp:** jeden `_paddedFieldColumn` se všemi poli
   - Pole: `DropdownButtonFormField` (start_mode), `SegmentedButton` (theme dark/light), `SwitchListTile`×2, `TextFormField` (capture_method), `SwitchListTile` (hotkeys), `TextFormField`×4 (hotkeys + validátor)

2. **`_DevicesTab`**
   - `Align` → `SingleChildScrollView` → `ConstrainedBox` → `Column`
   - `FilledButton.tonalIcon` „Přidat zařízení“
   - pro každé `DeviceSettings`: `Card` → `Column` (název, id, typ serial/wifi, podle typu port/IP/UDP, `led_count`, `SwitchListTile` control_via_ha, smazání pokud >1)

3. **`_LightSettingsTab`**
   - `Align` → `SingleChildScrollView` → `ConstrainedBox` → `Column`
   - náhled barvy + dialog RGB (`AlertDialog` + `StatefulBuilder` + slidery)
   - `DropdownButtonFormField` (efekt: static / breathing / rainbow / chase / custom_zones)
   - slidery speed, extra, brightness
   - `SwitchListTile` homekit_enabled
   - vlastní zóny: `FilledButton.tonalIcon` přidat; pro každou zónu `Card` → `ExpansionTile` (název, start/konec %, efekt zóny, rychlost, barva dialogem, odebrat)

## Téma aplikace (A5)

- `main.dart` → `AmbiLightRoot` → `AnimatedBuilder` (`AmbilightAppController`)
  - `MaterialApp.themeMode` z `global_settings.theme` (`light` vs jinak `dark`)
  - `theme` / `darkTheme`: `ThemeData` + `ColorScheme.fromSeed` pro světlý / tmavý jas

## Sdílené breakpointy (G1 / P13)

- `lib/ui/layout_breakpoints.dart` — `AppBreakpoints.compactMaxWidth` (600), `mediumMaxWidth` (1200), `useSettingsSideRail`, `formColumnsForWidth`, `maxContentWidth`
- Pomocná funkce `settingsFormGrid` pro budoucí dvousloupcové formuláře (`Wrap`)
