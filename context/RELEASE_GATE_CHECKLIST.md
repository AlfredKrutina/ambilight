# Release gate — Ambilight Desktop (Fáze 12)

Před označením buildu za „ship“ projdi bod za bodem.

## Build a kvalita

- [ ] `flutter analyze` bez chyb (v `ambilight_desktop/`).
- [ ] `flutter test` zelené.
- [ ] Release build na primární cílové OS (Windows).

## Funkční smoke

- [ ] Start, přepnutí režimů light / screen / music / pc health.
- [ ] USB i Wi‑Fi výstup (alespoň jeden známý hardware).
- [ ] Banner při úmyslně poškozeném `default.json` nebo obnova zálohy.

## Dokumentace uživatele

- [ ] Instalace / stažení artefaktu z CI (viz workflow upload).
- [ ] Firewall: UDP port zařízení (výchozí často 4210).
- [ ] Mikrofon / oprávnění snímání obrazovky — odkazy v aplikaci nebo `context/README_PERMISSIONS.md`.
- [ ] Známá omezení (loopback hudby atd.) — `context/MUSIC_PORT_STATUS.md` kde relevantní.

## Rollback

- [ ] Předchozí verze: uchovat zip předchozího `flutter build windows --release` nebo GitHub Releases tag.

## Paměť (doporučeno před major verzí)

- [ ] ~30–60 min běh + DevTools Memory — bez nekonečného růstu heap (Fáze 9).
- [ ] Vyplnit tabulku v `context/MEMORY_PROFILING_TEMPLATE.md` (alespoň jeden běh).

## Telemetrie

- [ ] Bez opt-in žádné odesílání dat — viz `context/TELEMETRY_POLICY.md`.
