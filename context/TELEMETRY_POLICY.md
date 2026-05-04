# Telemetrie a crash reporting — Ambilight Desktop

**Stav:** výchozí build **neobsahuje** žádný SDK třetí strany (Sentry, Crashlytics, vlastní beacon).

**Diagnostika uživatele:**

- Lokální soubor `crash_log.txt` v Application Support (`AppCrashLog`).
- UI: **O aplikaci** → zkopírovat cestu k logu.

**Plán Fáze 11:** jakékoli zapnutí telemetrie musí být **explicitní opt-in** v nastavení + právní text (GDPR). Do té doby žádné automatické odesílání stack trace ani IP.

**Fáze 11.2 (symbolikace / upload debug info):** neprovádí se — bez zvoleného backendu (11.1) není co nahrávat. Až bude opt-in SDK, doplnit upload symbolů pro Windows do samostatného release skriptu.
