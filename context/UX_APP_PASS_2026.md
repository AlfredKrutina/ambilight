# UX průchod aplikací (2026)

## Cíle
- Jednotná hierarchie: nadpis stránky → sekce → obsah.
- Méně „vývojářského“ jazyka (interní klíče, zkratky A7/D5) v běžných textech.
- Konzistentní mezery a typografie napříč Přehled / Zařízení / Nastavení / O aplikaci.
- Lepší orientace: krátké podnadpisy, tooltips u spodní navigace, srozumitelné stavy (engine, Spotify).
- Zachovat pokročilé údaje (capture diagnostika, hotkeys) — ale nerušit první dojem.

## Fáze implementace
1. **Sdílené widgety** — `AmbiPageHeader`, `AmbiSectionHeader` v `dashboard_ui.dart`; sémantika u `AmbiGradientTile`.
2. **Téma** — `SnackBarTheme`, zaoblené dialogy, čitelnější tooltips.
3. **Shell** — tooltips u položek navigace; „O aplikaci“ bez odkazu na soubor v repu; ladící tick schovaný.
4. **Přehled (Home)** — sjednocené hlavičky sekcí; přívětivější engine blok; sekce zařízení bez matoucího „vlevo“ u spodní lišty; Spotify podnadpis bez surového URL v klidovém stavu.
5. **Zařízení** — stejný page header jako jinde.
6. **Nastavení – záložky** — úvodní řádky u Globální / Světlo / Obrazovka / Hudba / PC Health / Spotify; lidské popisky výchozího režimu a některých polí (music color source, vstup zvuku).

## Mimo rozsah (další kolo)
- Plná lokalizace `intl`/ARB.
- Přímé deeplinky „Přejít na Zařízení“ z Přehledu (vyžaduje stav shellu / callback).

---

## Stav implementace (shrnutí)
- Hotovo: `AmbiPageHeader` / `AmbiSectionHeader`, téma SnackBar/Dialog/Tooltip, navigace (tooltips, „Navigace“), O aplikaci, Přehled (hlavičky, služba, Spotify, zařízení), Zařízení (page header), všechny záložky Nastavení (úvodní sekce + české popisky u globálního režimu, světla, obrazovky, hudby, PC Health, Spotify; část hudby dříve raw `auto_gain` / `smoothing_ms`).
- Viz kód: `lib/ui/dashboard_ui.dart`, `app_theme.dart`, `ambi_shell.dart`, `home_page.dart`, `devices_page.dart`, `settings/tabs/*.dart`, `settings/settings_page.dart`.
