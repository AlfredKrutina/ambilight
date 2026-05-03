# Feedback — Agent A4 (hudba — zbytek parity)

## Shrnutí (3–6 vět)

Doplněna chybějící část C7 z MASTER: `melody` / `melody_smart`, AGC (`auto_gain`, `auto_mid`, `auto_high`), barvy z obrazovky pro `color_source == monitor` (sdílený screen capture v controlleru) a per-segment `music_effect`. Přidány moduly `music_melody_analyzer.dart`, `music_melody_smart_effect.dart`, `music_monitor_palette.dart`; rozšířen `MusicAnalysisSnapshot` o melodii z FFT; `MUSIC_PORT_STATUS.md` aktualizován. FW se nedotýkal.

## Co se povedalo (bullet)

- Melodie z magnitudes stejného FFT jako pásmová analýza (bez druhé FFT).
- `melody_smart`: čtyři zóny + onset / decay stav jako v Python `app.py`.
- AGC a auto_mid/auto_high v `MusicSegmentRenderer`.
- Monitor jako zdroj barev: capture při `music` + monitor, dominantní RGB z downsample snímku.
- `LedSegment.musicEffect` místo globálního efektu kde je v configu nastaveno.

## Co se nepovedlo / blokery (bullet)

- `flutter analyze` / `flutter test` nebyly spuštěny v tomto prostředí (chybí `dart` v PATH na Windows agentovi).
- Plná parita s `MelodyDetector` v Pythonu (více pitchů do směsi barev) zatím ne — jedna dominantní nota + confidence.

## Konflikty s jinými agenty (soubory + doporučení merge)

- `lib/application/ambilight_app_controller.dart` — vlastník A3/A6 pro UI; změna jen větev capture (`music` + monitor). Při konfliktu nechat logiku `needScreenCapture` a sloučit s případným screen tickem od A2.
- `lib/engine/ambilight_engine.dart` — A2 vlastní engine; doplněn jen argument `monitorSample` přes existující `screenFrame`.

## Otevřené TODO pro další běh

- Melody „multi-pitch“ směs barev jako v Python `note_classes`.
- Výkon: při `music`+monitor zvážit nižší frekvenci capture než každý tick request (in-flight už omezuje).
- Ověřit na CI `flutter test` po dostupnosti SDK.

## Příkazy ověřené (např. flutter analyze, flutter test)

- IDE linter na upravených souborech: bez hlášených problémů (read_lints).
- `flutter analyze` / `flutter test`: nespouštěno (SDK nedostupné v shellu).
