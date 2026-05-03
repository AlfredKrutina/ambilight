# Paralelní sprint — 9 agentů (A0–A8) + koordinátor

**FW ESP se nemění.** Pracuj v `ambilight_desktop/` (a `context/` jen pro dokumentaci).  
**Všichni agenti běží paralelně** — nesmíte čekat na dokončení jiného agenta, kromě explicitních merge konfliktů (viz níže).

## Povinný feedback

Na **konci každého běhu** vyplň soubor `context/agent_feedback/FEEDBACK_Ax.md` (x = tvé číslo) podle šablony v [agent_feedback/README.md](./agent_feedback/README.md). Bez feedbacku koordinátor nevidí blokery.

## Koordinace merge (paralelní běh)

| Oblast | Primární vlastník | Ostatní needitují bez dohody |
|--------|-------------------|-----------------------------|
| `windows/runner/*`, `linux/runner/*`, `macos/Runner/*` | **A1** | A0 jen CI skripty, ne logiku capture |
| `lib/features/screen_capture/*`, `lib/engine/screen/*` | **A2** (Dart) + **A1** (native) | Dohodněte kanál; konflikt → A1 API, A2 volání |
| Overlay / nová okna / `window_manager` | **A3** | A6 nesahá na stejné soubory ve stejném commitu |
| `lib/services/music/*` | **A4** | |
| `lib/features/pc_health/*`, `lib/features/spotify/*` | **A5** | |
| `lib/ui/settings_page.dart` rozštěpení | **A6** | A7 vytváří `lib/ui/wizards/*` mimo monolit |
| `lib/ui/wizards/*`, discovery dialog | **A7** | |
| Testy `test/*`, `flutter analyze` CI, výkon | **A8** | |
| CI, `pubspec`, matrix buildů, „repo hygienu“ | **A0** | |

Při konfliktu: menší PR vyhrává rebase; **napiš do feedbacku** přesné soubory.

---

## Globální instrukce (pro všechny)

1. Před prací přečti [AmbiLight-MASTER-PLAN.md](./AmbiLight-MASTER-PLAN.md) — zejména sekci **D-detail** (scan overlay, náhled snímání).
2. Aktuální stav vs plán: [PROJECT_STATE_AUDIT.md](./PROJECT_STATE_AUDIT.md).
3. `flutter analyze` a `flutter test` musí projít po tvých změnách (necommituj rozbitý stav).
4. **Agent A0** může běžet první — ostatní **nepřestávají pracovat**; pokud chybí generované soubory platformy, A0 to řeší v feedbacku a ostatní pokračují na čistě Dart částech.

---

## Agent A0 — Bootstrap, CI, platformy (často první běžící)

**Cíl:** Ověřit / doplnit `flutter create --platforms=windows,linux,macos`, `pub get`, případně GitHub Actions nebo skript pro tři OS; opravit CMake / linker chyby; **neměnit business logiku** capture.

**Úkoly:**

- Matice buildů (win/linux/macos) v CI nebo dokumentovaný příkaz.
- Zkontrolovat, že root projektu je `ambilight_desktop/` a README v tomto repu odkazuje správně.
- Po dokončení: aktualizovat `FEEDBACK_A0.md` + řádek v tabulce `agent_feedback/README.md`.

**Prompt (copy-paste):**

```
Jsi Agent A0 (AmbiLight Flutter). Repo: ambilight. Pracuj jen v ambilight_desktop/ a context/.
Úkol: CI / flutter analyze / test matrix pro windows, linux, macos; oprav pubspec CMake pokud build padá; FW neměň.
Na konci vyplň context/agent_feedback/FEEDBACK_A0.md. MASTER: context/AmbiLight-MASTER-PLAN.md.
```

---

## Agent A1 — Nativní screen capture (C++ / Swift / platform channels)

**Cíl:** Stabilní bitmapu / raw buffer na všech troch OS; synchronizace s `ScreenModeSettings` (monitor index, rozlišení).

**Prompt:**

```
Jsi Agent A1. Vlastníš windows/runner/*, linux/runner/*, macos/Runner/* související se screen capture a MethodChannel názvy dohodnuté s Dart vrstvou.
Nesahej na Flutter UI. Dokumentuj channel kontrakt do context/ pokud chybí. FW neměň. Feedback: context/agent_feedback/FEEDBACK_A1.md.
```

---

## Agent A2 — Dart screen pipeline + engine

**Cíl:** `ScreenFrame` → barvy segmentů → `AmbilightEngine`; multi-monitor výběr; žádné pády při chybějícím frame.

**Prompt:**

```
Jsi Agent A2. Vlastníš lib/features/screen_capture/, lib/engine/screen/, napojení v ambilight_engine.dart.
Parita s Python capture segmenty; při nejasnosti čti context/SCREEN_COLOR_PIPELINE.md a PyQt. Nesahej na C++ kromě volání existujícího kanálu (to je A1). FW neměň. FEEDBACK_A2.md.
```

---

## Agent A3 — Scan overlay, kalibrace, náhled „odkud se snímá“

**Cíl:** Implementovat **MASTER → D-detail** bod po bodu: fullscreen overlay na monitoru, translucent, mouse pass-through, per-edge depth/padding stejně jako `scan_overlay.py`, live update při změně sliderů, mini náhled v nastavení (schéma + případně thumbnail z posledního frame).

**Prompt:**

```
Jsi Agent A3. Priorita: parita s led_strip_monitor_pokus - Copy/src/ui/scan_overlay.py a chování v nastavení screen režimu.
Použij window_manager nebo platform view podle best practice pro Win/Mac/Linux. Koordinuj s A2 (data rozměrů) a A6 (kam UI sliderů zapojit — můžeš přidat thin controller / callback zatím v lib/features/screen_overlay/).
Žádné mazání cizích souborů. FW neměň. FEEDBACK_A3.md — explicitně napiš které D-detail checkboxy jsi splnil.
```

---

## Agent A4 — Hudba — zbytek parity

**Cíl:** `melody` / `melody_smart`, AGC, barvy z obrazovky jako zdroj, per-segment `music_effect` pokud je v configu; aktualizovat `context/MUSIC_PORT_STATUS.md`.

**Prompt:**

```
Jsi Agent A4. Vlastníš lib/services/music/. Čti MUSIC_PORT_STATUS.md a MASTER tabulku efektů. FW neměň. FEEDBACK_A4.md s odškrtnutím řádků z MASTER hudby.
```

---

## Agent A5 — PC Health + Spotify + E7 příprava

**Cíl:** Rozšířit metriky, stabilitu, UI základ; Spotify OAuth edge cases; návrh API pro process-attached capture (E7) i když zatím stub.

**Prompt:**

```
Jsi Agent A5. Vlastníš lib/features/pc_health/, lib/features/spotify/ a napojení v ambilight_app_controller.dart kde už služby jsou.
FW neměň. FEEDBACK_A5.md — co z C8/C9/E7 je hotové.
```

---

## Agent A6 — Nastavení: struktura a nové záložky

**Cíl:** Rozdělit `settings_page.dart` na moduly (`lib/ui/settings/tabs/...`); přidat záložky **Screen, Music, PC Health, Spotify** s reálným nebo placeholder obsahem propojeným na config modely (ne prázdné TODO bez modelů).

**Prompt:**

```
Jsi Agent A6. Refaktoruj settings_page.dart bez ztráty chování Global/Devices/Light. Přidej záložky dle MASTER D3–D8. Respektuj layout_breakpoints.dart. Koordinace s A3/A4/A5: importuj jejich služby, nekopíruj je. FW neměň. FEEDBACK_A6.md.
```

---

## Agent A7 — Wizards a dialogy

**Cíl:** D9 discovery polish, D10 LED wizard, D11 zone editor, D12 calibration wizard, D14 profily — iterativně; každý wizard jako samostatný soubor pod `lib/ui/wizards/`.

**Prompt:**

```
Jsi Agent A7. Nové soubory pod lib/ui/wizards/. Inspirace PyQt v led_strip_monitor_pokus - Copy. Responzivita G. FW neměň. FEEDBACK_A7.md — které Dx jsou hotové.
```

---

## Agent A8 — Testy, shell, výkon

**Cíl:** F1–F3 posunout; `AmbiShell` adaptivní navigace (D15 část); golden config test; výkon engine (profilování dokumentovat v context/).

**Prompt:**

```
Jsi Agent A8. test/, případně .github/workflows. Rozšiř ambi_shell.dart o NavigationRail pro široké okno. Nezasahuj do nativního C++ (A1). FW neměň. FEEDBACK_A8.md s příkazy a výsledky testů.
```

---

## Koordinátor (ty + hlavní asistent)

Po kole běhů:

1. Přečti `FEEDBACK_A0.md` … `FEEDBACK_A8.md`.
2. Aktualizuj [PROJECT_STATE_AUDIT.md](./PROJECT_STATE_AUDIT.md) a checkboxy v MASTER tam, kde je 100% jistota.
3. Rozděl další kolo podle blokera (např. kanál A1↔A2).

---

*Dokument verze 2026-05-03 — navazuje na paralelní požadavek uživatele (9 agentů, feedback do repa, D-detail).*
