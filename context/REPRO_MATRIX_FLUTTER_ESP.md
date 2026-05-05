# Matice reprodukce: Flutter ↔ ESP (lampa)

Cíl: oddělit **síť** / **FW zámky** / **konflikt s HA** od chyb v aplikaci.

## Příprava

- UART log na ESP (115200) — sleduj `UDP Data`, `Dropped`, `unauthorized source`, `Locked`.
- V aplikaci lze zapnout rozšířené logy: `--dart-define=AMBI_VERBOSE_LOGS=true` (viz [build_environment.dart](../ambilight_desktop/lib/application/build_environment.dart)).

## Řádky matice

| # | Režim výstupu | HA automatizace na stejném světle | Očekávání |
|---|----------------|-----------------------------------|------------|
| A | Jen **Wi‑Fi** (v JSON jen `type: wifi`, platné IP + port; pro test **odstraň** nebo vyprázdněj COM u ostatních záznamů pokud testuješ jeden strip) | Vypnuto | Stabilní stream při dobré Wi‑Fi. |
| B | Jen **USB sériové** | Vypnuto | Stabilní; baud = FW. |
| C | **USB i Wi‑Fi** současně na **stejný** ESP (dva záznamy zařízení nebo COM stále otevřený) | Vypnuto | FW může **ignorovat UDP** ~2,5 s po sériové komunikaci (source lock v `ambilight.c`). |
| D | Wi‑Fi (nebo serial) | **Zapnuto** (scény mění barvu) | Souboj o LED buffer — trhání, „náhodné“ barvy. |

## Zápis výsledku

Pro každou buňku A–D zapiš: UI plynulost (ano/ne), pásek (plynule / trhá / mrtvé), výskyty v ESP logu.

## Související

- [ESP_UDP_TRANSPORT_NOTES.md](ESP_UDP_TRANSPORT_NOTES.md) — rate limit 15 ms na FW, pacing v klientovi.
- [HA_AMBILIGHT_COEXIST.md](HA_AMBILIGHT_COEXIST.md) — soužití s Home Assistant.
