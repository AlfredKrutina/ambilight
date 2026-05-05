# Feedback — Agent A7 (wizards + dialogy)

## Shrnutí (3–6 vět)

Přidána složka `lib/ui/wizards/` se sdíleným obalem `WizardDialogShell` (G2 — scroll, max šířka přes `AppBreakpoints`). **D9** nahrazuje jednoduchý `AlertDialog` discovery plnohodnotným průvodcem se skenem, identify a rychlým „Přidat“ do configu. **D10** je dvoukrokový průvodce šablon segmentů (rám 20/30/20/zbytek nebo jen horní lišta) a přepnutím na `screen`. **D11** je editor segmentů s `ReorderableListView` a slidery `led_start` / `led_end` / `edge`. **D12** a **D14** jsou zatím úzké dialogy: výběr aktivního kalibračního profilu z `calibration_profiles`, resp. uložení snapshotu `screen_mode` do `user_screen_presets`. Stránka Zařízení odkazuje na všechny průvodce + responzivní Wrap/Column pod ~520 px.

## Co se povedlo (bullet)

- `wizard_dialog_shell.dart` — společný `Dialog` + `ConstrainedBox` + scroll (G2).
- `discovery_wizard_dialog.dart` — D9: auto-sken, znovu skenovat, identify, přidat zařízení.
- `led_strip_wizard_dialog.dart` — D10: šablony segmentů, přepnutí `start_mode` na `screen`.
- `zone_editor_wizard_dialog.dart` — D11: reorder segmentů, slidery, výběr hrany.
- `calibration_wizard_dialog.dart` — D12: přepnutí `active_calibration_profile` pokud existují klíče v JSON.
- `config_profile_wizard_dialog.dart` — D14: zápis `screen_mode.toJson()` pod vlastní jméno do `user_screen_presets`.
- `wizards.dart` — barrel export.
- `devices_page.dart` — vstupy na průvodce; discovery přes nový dialog.

## Co se nepovedlo / blokery (bullet)

- **`flutter` / `dart` nebyl v PATH** na agentním shellu — neproběhl `flutter analyze` / `flutter test` z CLI (ověření jen přes IDE linter na vybraných souborech).
- **D9 „polish“** — chybí pokročilá akce z PyQt (hromadné přidání, filtrování); ruční „Uložit zařízení“ sheet zůstává pro editaci názvu před uložením.
- **D11** — žádný drag segmentů na náhledu monitoru / žádný živý overlay (čeká na **A3**).
- **D12** — bez editoru křivek a bez wizardu den/noc v plné paritě s PyQt.
- **D14** — není výběr souboru profilu z disku ani import více `default.json`; jen user preset v paměti configu.

## Konflikty s jinými agenty (soubory + doporučení merge)

- **`lib/ui/devices_page.dart`** — může se křížit s **A6** (přesun záložek / struktura). Doporučení: při refaktoru A6 přesunout jen řádky tlačítek do nového widgetu, API `*.show(context)` nechat.
- **Žádný zásah** do `windows/runner/*`, `lib/engine/screen/*`, `settings_page.dart` (vlastník A6 pro rozštěpení).

## Otevřené TODO pro další běh

- Napojit **D13** náhled (thumbnail / schéma) z posledního `ScreenFrame` do nastavení nebo do shellu (A2/A3/A8 podle domluvy).
- Rozšířit D9 o volbu „Otevřít detail“ → existující `_openSaveDeviceSheet` s předvyplněným presetem.
- D12 plný wizard + zápis do `calibration_profiles` z UI (potřebuje modely/UI z A2/A6).
- Golden test: otevření dialogů bez výjimky (A8).

## Příkazy ověřené (např. flutter analyze, flutter test)

- `read_lints` na `devices_page.dart`, `lib/ui/wizards/*.dart` — bez hlášených problémů v IDE.
- `flutter analyze` / `flutter test` — **nespuštěno** (chybí `flutter` v PATH prostředí agenta).
