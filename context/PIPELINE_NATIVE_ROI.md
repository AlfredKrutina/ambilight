# Nativní ROI + pack (Fáze 3)

## Cíl

Přesunout **výběr oblastí + průměrování + RGB pack** z Dart worker izolátu do **C++** u zdroje capture (Windows Method Channel / DXGI cesta).

## Výstup do Dartu

- Přes bridge posílat jen **komprimovaný payload** (např. `deviceId → bytes` délka `ledCount * 3`), nikoli celé RGBA ~147 KiB / snímek.

## Závislosti

- Musí zůstat parita s `ScreenColorPipeline` / segmenty / `AppConfig` — buď duplikace pravidel v C++, nebo jednorázový export „tabulky ROI“ z Dartu při změně konfigurace.

## Odkaz

Detailnější backlog: [PERF_LED_AGENT_HANDOFF.md](PERF_LED_AGENT_HANDOFF.md).
