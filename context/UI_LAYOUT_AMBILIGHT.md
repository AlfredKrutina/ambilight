# UI layout — AmbiLight Desktop (dashboard)

## Cíl
Desktop aplikace ve stylu **SaaS dashboardu / macOS Shortcuts**: tmavé pozadí, **glass** panely, **gradient** akcenty, přehledná **master–detail** navigace — ne „šedý formulář“.

## Hlavní navigace (4 sekce)
| Sekce | Účel | Častost |
|-------|------|--------|
| **Přehled** | Zap/vyp výstup, výběr režimu (karty), Spotify zkratka, náhled stavu zařízení | nejčastěji |
| **Zařízení** | Discovery, průvodci, ruční přidání, seznam hardware | často |
| **Nastavení** | Draft konfigurace podle oblastí (globální → režimy → integrace) | dle potřeby |
| **O aplikaci** | Verze, tick, odkaz na plán | zřídka |

**Široké okno:** levý **sidebar** (~260px) — ikona + název, zaoblený výběr, sekce „Menu“.  
**Úzké okno:** spodní **NavigationBar** (4 položky).

## Nastavení (vnitřní layout)
Levý **pod-sidebar** se skupinami:
- **Základ** — Globální, Zařízení  
- **Režimy** — Světlo, Obrazovka, Hudba, PC Health  
- **Integrace** — Spotify  

Vpravo obsah záložky + spodní lišta *Použít / Zrušit* (beze změny logiky).

## Přehled (dashboard)
- Horní řádek: velká **karta výstupu** (gradient) + kompaktní **stav** (tick engine).  
- **Mřížka režimů** — 4 barevné dlaždice (Shortcuts styl): Světlo / Obrazovka / Hudba / PC Health.  
- **Spotify** — jedna širší karta.  
- **Zařízení** — horizontální strip karet (náhled; detail v sekci Zařízení).

## Vizuální jazyk
- Pozadí: tmavá modro-šedá, jemný gradient.  
- Karty: `BackdropFilter` + poloprůhledná výplň + tenký okraj.  
- Akcenty: cyan/teal + fialová/růžová na hero prvcích.  
- Přechody stránek: `AnimatedSwitcher` (fade + lehký posuv).

## Technické
- **Žádný `NavigationRail`** v hlavním shellu (žádné asserty extended/labelType).  
- Nastavení: vlastní seznam místo rail.  
- Testy: kontrola klíče sidebaru / `NavigationBar` na úzkém okně.

## Responzivita a ultrawide
- `AppBreakpoints.maxContentWidth` ≈ **1320 px** — hlavní obsah (`ResponsiveBody`) je vycentrovaný, texty a formuláře se neroztahují přes celý monitor.  
- Shell, Přehled, Zařízení, O aplikaci i obsah nastavení používají stejný vzor.

## Ukládání konfigurace
- Změny v nastavení jdou přes **`queueConfigApply`** (~220 ms po poslední úpravě) → `applyConfigAndPersist` (presety / JSON beze změny struktury).  
- Průvodci a stránky mimo nastavení dál volají **`applyConfigAndPersist`** přímo tam, kde je potřeba okamžitý zápis.

## Animace (svizné, volitelně vypnuté)
- Přepínač **Globální → Animace rozhraní** (`ui_animations_enabled`): vypne dekorativní přechody (`MediaQuery.disableAnimations` + nulová délka `AnimatedSwitcher` v shellu).  
- Krátké přechody stránek (**120 ms**) pokud animace zapnuté; respektuje i systémové snížení animací.
