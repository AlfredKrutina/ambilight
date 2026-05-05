# Hudba — spektrální barvy a rozšíření

## Hotovo v kódu

- **Sedm zastávek** palety při „Spektrum zvuku“: Spectrum, VU+spectrum, Smart Music, **Energy**, **Pulse**, **Strobe** (mapa na paletu), **Reactive bass** (šok z basové energie na paletě).
- **Nastavení spektra**: lišta + 7 dlaždic, reset výchozích barev.
- **Citlivost po pásmech**: přepínač + 7 posuvníků (sub-bas … brilliance), JSON `per_band_sensitivity` + `band_sensitivities`.
- **Beat sync**: `beat_sync_mode` — `off` | `gradient_step` | `color_pulse` (spektrum / VU / energie).
- **AGC**: měkčí koleno u špičky + špičkový kompresní faktor; při `--dart-define=AMBI_PIPELINE_DIAGNOSTICS=true` log `music_agc`; při zapnutém AGC **metr špičky a gain** v nastavení Hudby (`MusicSegmentRenderer.agc*Notifier`).
- **Melodie + paleta**: při spektrálním zdroji volitelné tónování HSV směrem k paletě (`melody_spectrum_tint_*`).
- **Presety**: uložení aktuálního `music_mode` do `user_music_presets`, mazání, kopírování JSON, import JSON; výběr v „Preset hudby“ načte uživatelský preset nebo vestavěný Party/Chill/…
- **macOS**: tlačítko „Průvodce: macOS loopback“ + dialog s kroky a odkazem na BlackHole.

## Poznámky

- `flutter test` může selhat na nesouvisející chybě `virtual_room_editor.dart` (`waveEnabled`) — není z této úpravy.
- Tray rychlé presety (`applyQuickMusicPreset`) dál mění jen bas/střed/výška; plná uživatelská konfigurace je přes uložený preset + dropdown v nastavení.
