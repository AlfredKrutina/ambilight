# Feedback — Agent A6 (Nastavení: struktura + záložky)

## Shrnutí (3–6 vět)

Rozdělen monolit `lib/ui/settings_page.dart` na moduly pod `lib/ui/settings/` (společné `settings_common.dart`, `hotkey_validation.dart`, `tabs/*`). Původní soubor je tenký barrel (`export …`) kvůli existujícímu importu z `ambi_shell.dart`. Přidány čtyři záložky **Obrazovka, Hudba, PC Health, Spotify** s obsahem vázaným na `ScreenModeSettings`, `MusicModeSettings`, `PcHealthSettings`, `SpotifySettings`. Pro úpravu screen/music draftu doplněny `copyWith` metody do `config_models.dart` (`ScreenModeSettings`, `MusicModeSettings`, `PcHealthSettings`). Hudba volá `MusicAudioService.listDevices()` (vlastnictví A4 — jen import služby).

## Co se povedlo (bullet)

- `lib/ui/settings/tabs/global_settings_tab.dart`, `devices_tab.dart`, `light_settings_tab.dart` — přesun logiky bez změny chování Globální / Zařízení / Světlo.
- `screen_settings_tab.dart`, `music_settings_tab.dart`, `pc_health_settings_tab.dart`, `spotify_settings_tab.dart` — nové záložky D5–D8 s reálnými poli z modelů.
- `TabController` + `TabBar` / `NavigationRail` rozšířeny na 7 cílů; `AppBreakpoints.useSettingsSideRail` beze změny.
- `MusicSettingsTab`: obnovení seznamu vstupů, výběr `audio_device_index` včetně null = výchozí.

## Co se nepovedlo / blokery (bullet)

- `flutter analyze` / `flutter test` nebyly spuštěny v tomto prostředí (chybí `flutter` v PATH) — ověření prosím lokálně.
- Segment editor obrazovky a scan overlay zůstávají u A3/A7 — v Screen tab jen souhrn počtu segmentů a základní scalar pole.

## Konflikty s jinými agenty (soubory + doporučení merge)

- `lib/core/models/config_models.dart` — přidané `copyWith`; pokud A5/A8 mění stejnou třídu současně, rebase a sloučit signatury `copyWith`.
- `lib/ui/settings/tabs/music_settings_tab.dart` — import `MusicAudioService`; při změně API A4 sladit volání `listDevices`.

## Otevřené TODO pro další běh

- A5: OAuth tlačítka, naplnění tokenů, plný editor `metrics` v PC Health.
- A3/A7: segment editor, kalibrace, náhled snímání v záložce Obrazovka.
- A6 follow-up: per-edge padding/depth v UI (už jsou v modelu), barevné 7-pásmo hudby v jedné obrazovce.

## Příkazy ověřené (např. flutter analyze, flutter test)

- Neprovedeno (PATH). Doporučené: `cd ambilight_desktop && flutter analyze && flutter test`.
