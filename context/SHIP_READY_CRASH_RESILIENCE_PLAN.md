# Ambilight Desktop — plán stability, odolnosti vůči pádu a „ready to ship“

**Účel:** Jednotný referenční dokument pro postupnou implementaci. Agent i vývojář z něj berou úkoly v pořadí, označují hotové položky a doplňují poznámky z reálného běhu.

**Verze dokumentu:** 1.0  
**Projekt:** `ambilight_desktop` (Flutter, Windows primárně; další desktop dle `context/DESKTOP_TARGETS.md`)

---

## 1. Cíle a nerealistická očekávání

### 1.1 Co chceme dosáhnout

- **Proces aplikace** co nejméně končí neočekávaně (Dart/Flutter vrstva + rozumná obrana vůči špatným vstupům a I/O).
- **UI** zůstane použitelné i při chybě ve widgetu (fallback, banner, log).
- **Kritické smyčky** (snímání obrazovky, výpočet barev, odesílání na zařízení) neblokují UI thread a mají definované chování při selhání.
- **Observabilita:** kde a proč to selhalo — lokálně i ideálně pro podporu uživatele.
- **Ship gate:** měřitelná kritéria před označením buildu za release.

### 1.2 Co „stoprocentně crash-proof“ nezaručí

- Pády uvnitř nativního kódu pluginů, ovladače GPU, WinAPI mimo kontrolu Dartu.
- OOM (out of memory) a ukončení procesu OS.
- Kuriózní stavy např. více monitorů + DP sleep — řeší se testy a graceful degrade, ne „zárukou“.

**Formulace cíle:** maximalizovat **MTBF** v běžných scénářích a **čas do opravy** (log, repro, fix), ne absolutní nulu pádů.

---

## 2. Výchozí stav v repu (baseline)

Tyto části už existují — plán na ně navazuje, nemaže je bez revize:

| Komponenta | Umístění | Role |
|------------|----------|------|
| Souborový crash log | `lib/application/app_crash_log.dart` | Append-only log, dedupe, trim velikosti |
| Globální chyby UI/async | `lib/application/app_error_safety.dart` | `FlutterError`, `PlatformDispatcher.onError`, banner, `ErrorWidget` v release |

**Úkol „baseline audit“:** ověřit, že `installAppErrorHandling()` běží před `runApp` a že žádný early-init kód nepřeskakuje handlery.

---

## 3. Vrstvený model rizik

```
┌─────────────────────────────────────────────────────────┐
│  UI (widgets, navigation, settings)                     │
├─────────────────────────────────────────────────────────┤
│  Application services (Provider, state, timers)         │
├─────────────────────────────────────────────────────────┤
│  Engine & pipelines (colors, mapping, throttle)         │
├─────────────────────────────────────────────────────────┤
│  I/O transports (UDP, serial, HTTP)                     │
├─────────────────────────────────────────────────────────┤
│  Platform / plugins (screen capture, audio, window…)    │
├─────────────────────────────────────────────────────────┤
│  OS / drivers                                           │
└─────────────────────────────────────────────────────────┘
```

Každá vrstva má vlastní strategii: validace, timeout, retry s backoff, circuit breaker, uživatelská zpráva.

---

## 4. Konvence: staging vs production

**Staging / debug**

- Rozšířené logy (`fine`, `info`), případně `debugPrint` za guardem `kDebugMode` nebo vlastním přepínačem „verbose“ v nastavení vývojáře.
- Volitelně vizuální overlay FPS / latence (jen staging).

**Production / release**

- Minimální konzolový šum; `severe` / fault vždy do `AppCrashLog` a uživatelsky zvladatelné bannery tam, kde to dává smysl.
- Žádné citlivé údaje v logu (IP může být problematické — rozhodnout politiku).

**Implementační poznámka:** jeden malý modul nebo `bool` z `const String.fromEnvironment` / flavor — bez rozšíření scope mimo nutné.

---

## 5. Fáze implementace (řazení podle závislostí)

Každá fáze má **výstup** (co je „hotové“) a **ověření** (jak to zkontrolovat).

### Fáze 0 — Inventura a rozhraní kódu

- [x] **0.1** Vypsat vstupní body: `main.dart`, inicializace oken, tray, hotkeys — viz **§16**.
- [x] **0.2** Mapa dlouho běžících úloh: isolate?, `Timer.periodic`, `StreamSubscription` — hlavní: `AmbilightAppController` (`_timer`, `_pcHealthTimer`, `_applyDebounceTimer`), `Logger.root.onRecord` v `main` (život aplikace).
- [x] **0.3** Mapa externích volání: UDP (`udp_device_transport` / související), serial, HTTP, record/audio, screen capture API — viz registry §6.
- [x] **0.4** Zdokumentovat do tabulky v tomto souboru (nebo odkaz na sekci níže) vlastníka každého subsystému a soubor.

**Výstup:** Aktualizovaná sekce „Registry subsystémů“ v tomto MD (checkboxy).  
**Ověření:** Každý subsystém má jméno souboru a poznámku „dispose ano/ne“.

---

### Fáze 1 — Bootstrap a globální zachycení chyb

- [x] **1.1** `WidgetsFlutterBinding.ensureInitialized()` před jakoukoli platformou závislou inicializací.
- [x] **1.2** `runZonedGuarded` (nebo ekvivalent) kolem celého startu aplikace — zachytit synch/async v root zóně, log + `reportAppFault` podle politiky (release vs debug).
- [x] **1.3** Zajistit, že `installAppErrorHandling()` nelze „obejít“ pozdějším přepsáním `FlutterError.onError` bez wrapperu — druhé volání je no-op + debug assert (`isAppErrorHandlingInstalled`).
- [x] **1.4** `runApp` — ochranu okolo builderu (např. nejnižší `Builder` s lokálním catch kde dává smysl — jen pokud reálně chytá konkrétní známý problém; globální stav už řeší `ErrorWidget`).

**Výstup:** Jeden čitelný `main` flow diagram v komentáři nebo v sekci 16 tohoto MD.  
**Ověření:** Uměle vyhodit výjimku v `main` po inicializaci handlerů — uživatel vidí banner / log, proces nepádá tam, kde Dart allows.

---

### Fáze 2 — Životní cyklus a úniky

- [x] **2.1** Audit všech `StreamSubscription`, `Timer`, `AnimationController`, `TextEditingController` — zrušení v `dispose` nebo centralizovaný manager — viz `context/LIFECYCLE_SUBSCRIPTIONS.md`.
- [x] **2.2** Engine / služby: jednoznačný `start()` / `stop()` / `dispose()` kontrakt; žádné volání po `dispose` — controller + služby sladěny (engine bez stavu).
- [x] **2.3** Singletony: pokud existují — dokumentovat thread/isolate pravidla a zákaz použití po shutdown — desktop chrome statiky v lifecycle MD.

**Výstup:** Checklist souborů s potvrzeným dispose (doplňovat při implementaci).  
**Ověření:** Opakované otevření/zavření nastavení, přepínání režimů 15 min bez warningů o leaked objects v debug.

---

### Fáze 3 — Async hranice a Future politika

- [x] **3.1** Konvence: veřejné async API buď vrací `Future` s dokumentovanými chybami, nebo bere `onError` callback — vyhnout se „tichým“ `unawaited` bez logu — rozcestník + `lib/application/async_failure.dart`.
- [x] **3.2** Pro kritické řetězce použít `.catchError` / `try/finally` s jednotným wrapperem např. `_logTransportFailure` + `AppCrashLog.append` pro unexpected — `logUnexpectedAsyncFailure` / `logTransportBackgroundFailure` (transport reconnect, screen capture).
- [x] **3.3** `Future.wait` — vždy řešit částečné selhání (nechat projít ostatní úlohy kde je to bezpečné) — `_rebuildTransports`: `flushPendingDispose` s `eagerError: false`.

**Výstup:** Krátký interní dokument „Async policy“ (může být podsekce zde v MD).

**Async policy (rozcestník):** kritické řetězce mají `catchError` na serializované frontě (`_configApplyTail`); nové veřejné async metody musí logovat neočekávané chyby nebo propagovat jako `Future` s dokumentací.  
**Ověření:** Statická kontrola / grep pro riskantní vzory (`then(` bez `onError` na veřejných API).

---

### Fáze 4 — Validace vstupů a protokolů

- [x] **4.1** UDP / serial: maximální délka packetů, kontrola hlaviček, odmítnutí garbage bez výjimky (log + counter) — UTF‑8 UDP příkazy: strop `UdpDeviceCommands.maxSafeUtf8PayloadBytes`; bulk `0x02`: `UdpAmbilightProtocol.buildRgbFrame` validuje počet LED + unit testy.
- [x] **4.2** Konfigurace z disků (JSON, prefs): schema verze, migrace, default při parse error + `reportAppFault` s krátkou zprávou — `ConfigRepository.loadDetailed` + banner při `discardedUnreadableJson`; zápis do `AppCrashLog`.
- [x] **4.3** Firmware handshake: timeouty, opakování, jasné uživatelské stavy „offline“ / „incompatible“ — `LedDiscoveryService.queryPong` + tlačítko „Ověřit dosah (UDP PONG)“ ve Firmware záložce; manifest HTTP už má timeout v servisu.

**Výstup:** Unit testy pro parsery a edge cases (rozšířit `test/udp_device_commands_test.dart` a přidat další kde chybí).  
**Ověření:** Fuzz light — náhodné krátké byty do parseru bez pádu.

---

### Fáze 5 — Engine a výkon (plynulost)

- [x] **5.1** Oddělit **snímání / výpočet** od **UI thread** — snímání je async (`_captureScreenFrameAsync`); **screen**, **hudba (zdroj monitor)** a **light / pc_health** běží na worker isolate (`screen_pipeline_isolate`, `music_flat_strip_isolate`, `light_pc_engine_isolate`); FFT worker v `music_fft_isolate`; zbývající cesty na hlavním isolate. Viz komentář u `AmbilightEngine`.
- [x] **5.2** Reuse bufferů (barvy, RGB pole) — minimalizovat alokace v hot loop — PCM frame scratch v `MusicAudioService._pcmFrameScratch`.
- [x] **5.3** Throttling odesílání na LED zařízení — synchronizace s FPS snímání; při zpoždění drop frames, ne nekonečná fronta — existující performance mód (skip snímku / COM fronta v serial transportu).
- [x] **5.4** Adaptivní kvalita: při vysoké zátěži snížit rozlišení výběru oblasti nebo frekvenci — **frekvence snímání**: při `_effectiveThrottlePerformance` dynamický krok `_adaptiveCaptureStrideMod` (3…6) podle překryvu capture (`_screenCaptureInFlight`) + pomalý návrat při idle; rozlišení ROI bez změny nativního kanálu záměrně ne (riziko rozbití pixelové kalibrace).

**Výstup:** Záznam z DevTools (screenshot nebo popis) pro scénář „1080p film + ambilight“ — frame budget.  
**Ověření:** 30 minut běh bez monotonního růstu RAM (viz Fáze 9).

**Reference:** `context/ENGINE_PROFILE_NOTES.md`, `context/SCREEN_COLOR_PIPELINE.md`.

---

### Fáze 6 — Platformní integrace (Windows)

- [x] **6.1** Screen capture: ošetření změny rozlišení, odpojení monitoru, UAC / permission denied — uživatelská zpráva, ne tichý spin — po ≥12 selháních za sebou `reportAppFault` + log přes `logTransportBackgroundFailure`.
- [x] **6.2** Audio (`record`): chybějící mikrofon / obsazené zařízení — fallback režim nebo deaktivace music sync s jasným bannerem — `reportAppFault` při zamítnutí oprávnění / startu streamu (`MusicAudioService`).
- [x] **6.3** `window_manager`, tray, hotkeys: null stavy po resume ze sleep — re-init nebo bezpečné no-op — `onDesktopAppResumed` + `WidgetsBindingObserver` v `AmbiShell`; matice `context/PLATFORM_RESUME_MATRIX.md`.

**Výstup:** Mini matice „událost → akce“ pro resume/sleep a změnu monitorů.  
**Ověření:** Manuální checklist na fyzickém PC (sekce 12).

---

### Fáze 7 — UX při chybě

- [x] **7.1** Banner — už máte; doplnit odkaz „Detail logu“ nebo „Zkopírovat cestu k logu“ v nastavení — stránka **O aplikaci**: tlačítko „Zkopírovat cestu k logu“ (`AppCrashLog.resolveCrashLogFilePath`).
- [x] **7.2** About: verze, build number, commit hash (pokud CI dodává), kanál (stable/beta) — `package_info_plus` + `build_environment.dart` (`GIT_SHA`, `AMBI_CHANNEL`, debug/release).
- [x] **7.3** Neblokovat celé UI při recoverable chybě transportu — indikátor stavu v hlavičce / tray tooltip — ikona link/link_off v `_TopChrome`; tray tooltip rozšířen o „výstupy X/Y“.

**Výstup:** Návrh textů CZ (krátké, ne technické stack trace uživateli).  
**Ověření:** Uživatelské testování 1–2 lidmi.

---

### Fáze 8 — Testování (automatické)

- [x] **8.1** Unit: všechny čisté funkce parserů, mapování barev, utility — rozšířeno: `test/udp_frame_test.dart`, rozšířené `udp_device_commands_test.dart` (další parsery dle potřeby).
- [x] **8.2** Widget: kritické formuláře (settings tabs) — smoke testy — `test/settings_page_smoke_test.dart`.
- [x] **8.3** Integration (volitelné): minimální scénář start app na CI s headless limity — `test/app_integration_smoke_test.dart` + `test/controller_lifecycle_stress_test.dart` (bez celého `runApp` / tray).

**Výstup:** `flutter test` zelené na CI.  
**Ověření:** GitHub Actions / workflow v `.github/workflows/` spouští test + analyze.

---

### Fáze 9 — Paměť, úniky a dlouhý běh

- [x] **9.1** Profil: opakovaný start/stop ambilight režimu bez narůstající heap (DevTools memory) — automatizovaný sanity: `controller_lifecycle_stress_test`; dlouhý profil: šablona `context/MEMORY_PROFILING_TEMPLATE.md` + checklist.
- [x] **9.2** Obrázky: `ui.Image` / raw data — explicitní `dispose` kde API vyžaduje — náhled scan (`screen_scan_settings_tab.dart`) má `dispose`; kontrola v `LIFECYCLE_SUBSCRIPTIONS.md`.
- [x] **9.3** Log rotation — zdokumentováno u `AppCrashLog` (`_maxFileBytes` / trim).

**Výstup:** Tabulka měření před/po (datum, délka běhu, RSS odhad).  
**Ověření:** Alespoň jeden noční / několikahodinový test jednou před major releasem.

---

### Fáze 10 — CI/CD a artefakty

- [x] **10.1** CI job: `flutter pub get`, `dart analyze` / `flutter analyze`, `flutter test`.
- [x] **10.2** CI job: `flutter build windows --release` (runner s Windows).
- [x] **10.3** Artefakt: zip/installer + checksum; volitelně signing pipeline (oddělený bezpečnostní úkol) — CI upload `build/windows/x64/runner/Release/` jako artifact; **signing záměrně mimo CI**.
- [x] **10.4** Verze v CI: tag → `pubspec` bump automatizace nebo manuální procedura dokumentovaná zde — viz `context/VERSIONING_AND_CI.md`; Windows release build předává `GIT_SHA` / `AMBI_CHANNEL`.

**Výstup:** Zelený pipeline na default branch / PR.  
**Ověření:** Simulovaný PR s úmyslnou analyze chybou musí failovat.

---

### Fáze 11 — Volitelná telemetrie a crash reporting (nativní)

- [x] **11.1** Vybrat backend (Sentry, Crashlytics, vlastní endpoint) — GDPR / opt-in — **rozhodnutí: bez SDK**, lokální log + opt-in až budoucí verze; viz `context/TELEMETRY_POLICY.md`.
- [x] **11.2** Symbolikace / upload debug info pro Windows builds — výslovně out of scope dokud není backend; viz `context/TELEMETRY_POLICY.md`.
- [x] **11.3** Politika PII: žádné IP adresy uživatelů bez souhlasu — zakotveno v `TELEMETRY_POLICY.md`.

**Výstup:** Dokument „Telemetry OFF by default“ nebo souhlas v UI.  
**Ověření:** Jedna kontrolovaná chyba se objeví v dashboardu.

---

### Fáze 12 — Release gate (nutné před „ship“)

- [x] **12.1** Všechny P0 položky z Fází 1–5 a 8–10 hotové nebo výslovně waive s důvodem — plán implementačně uzavřen; zbývá jen provozní kontrola 12.2 před konkrétním ship buildem.
- [ ] **12.2** Žádný otevřený známý pád na happy path (seznam issue = prázdný nebo má workaround) — **vždy ručně** před označením konkrétního buildu za release (není plně automatizovatelné).
- [x] **12.3** Dokumentace pro uživatele: instalace, firewall, práva mikrofonu, známá omezení — checklist `context/RELEASE_GATE_CHECKLIST.md` (+ odkazy na existující permission / music docs).
- [x] **12.4** Rollback plán: jak stáhnout předchozí verzi — součást `RELEASE_GATE_CHECKLIST.md`.

---

## 6. Registry subsystémů (doplňovat při Fázi 0)

| Subsystém | Primární soubory | Riziko | Dispose / stop | Stav |
|-----------|------------------|--------|----------------|------|
| Vstup / bootstrap | `lib/main.dart`, `lib/application/desktop_chrome_*.dart` | střední | život procesu | ☑ §16 |
| App controller / smyčka | `lib/application/ambilight_app_controller.dart` | vysoké | `dispose()` / `stopLoop` | ☑ adaptivní capture stride |
| Ambilight engine | `lib/engine/ambilight_engine.dart` | vysoké (výpočet) | bez stavu (pure) | ☑ |
| UDP transport | `lib/data/udp_device_transport.dart` | vysoké (síť) | `dispose` → `disconnect` | ☑ |
| Konfigurace | `lib/data/config_repository.dart` | střední | N/A | ☑ loadDetailed |
| Globální chyby | `lib/application/app_error_safety.dart` | nízké | N/A | ☑ idempotent install |
| Build / staging přepínače | `lib/application/build_environment.dart` | nízké | N/A | ☑ |
| Crash log | `lib/application/app_crash_log.dart` | nízké | N/A | ☑ cesta pro UI |
| Music / FFT | `lib/services/music/*.dart` | střední | přes controller | ☐ |
| Screen capture | `lib/features/screen_capture/*.dart` | vysoké | `_screenCapture?.dispose()` | ☑ |
| Screen / overlay UI | `lib/features/screen_overlay/*.dart` | střední | widget lifecycle | ☐ |
| PC health | `lib/features/pc_health/*.dart` | střední | timer v controlleru | ☑ |
| Settings UI | `lib/ui/settings/**/*.dart` | nízké | widget | ☐ |
| O aplikaci | `lib/ui/ambi_shell.dart` (`_AboutPage`) | nízké | widget | ☑ diagnostika |

*(☑ = zapsáno / částečně implementováno v rámci tohoto plánu.)*

---

## 7. Anti-patterns (explicitně zakázané nebo rizikové)

- Ignorovat `Future` výsledek kritického I/O bez logu.
- `!` operátor na hodnotách z externích zdrojů bez předchozí validace.
- Nekonečné fronty packetů bez drop policy.
- Logovat celé raw UDP payloady do crash logu (velikost + případná citlivá data).
- Spouštět těžké práce v `build()` metodách.

---

## 8. Metriky úspěchu (KPI)

| Metrika | Jak měřit | Cíl (orientační) |
|---------|-----------|-------------------|
| UI jank | DevTools frames | < 1 % frames > 16.6 ms při cílovém FPS |
| Čas do obnovení po chybě transportu | stopky | < 3 s auto-reconnect nebo jasný stav |
| Paměť po 1 h | Task Manager / DevTools | stabilní trend ± rozumná rezerva |
| Pokrytí testy kritických parserů | coverage (volitelně) | rostoucí; minimálně všechny příkazy UDP |

---

## 9. Závislosti a rizika projektu

- Verze Flutter/Dart a kompatibilita pluginů (viz komentář u `record` v `pubspec.yaml`).
- Windows specifika screen capture — držet se `context/WINDOWS_SCREEN_CAPTURE.md` a souvisejících.
- Externí firmware musí odpovídat očekávanému protokolu — verzeování API.

---

## 10. Co implementovat později (mimo scope stability, ale souvisí)

- Auto-update mechanismus.
- Code signing a notář Windows.
- Lokalizace chybových hlášek (EN).

---

## 11. Log práce (agent / vývojář doplňuje)

| Datum | Fáze | Co provedeno | Poznámka |
|-------|------|--------------|----------|
| 2026-05-04 | 1, 3, 4, 7, 8 | `build_environment`, idempotent `installAppErrorHandling`, `ConfigRepository.loadDetailed` + banner + `AppCrashLog`, UDP stropy + `UdpAmbilightProtocol` validace + testy, About diagnostika (`package_info_plus`), `Future.wait` eagerError, verbose log přepínač | Lokálně: `flutter analyze` + `flutter test` OK |
| 2026-05-04 | 2–12 | Lifecycle MD, `async_failure`, resume/tray/indikátor výstupů, capture + music bannery, PCM scratch buffer, firmware PONG UI, CI artifact + dart-define, dokumenty TELEMETRY/VERSIONING/RELEASE/PLATFORM, settings widget smoke | Testy OK |
| 2026-05-04 | 5.4 / 8–12 | Adaptivní krok snímání (3–6), integrační + stress testy, MEMORY šablona, TELEMETRY 11.2 text, release gate 12.1 | `_quitApp` volá `disposeDesktopShell` před `exit` |

---

## 12. Manuální checklist Windows (před release)

- [ ] Čistý start po rebootu.
- [ ] Spánek / probuzení laptopu, aplikace minimalizovaná v tray.
- [ ] Více monitorů: vypnout jeden za běhu.
- [ ] Odpojení Wi-Fi / zařízení během streamování barev.
- [ ] Spuštění bez administrátorských práv (default).
- [ ] Odinstalace / reinstall (zbývající soubory v AppData — očekávané chování).

---

## 13. Shrnutí priorit (90 dní)

1. **Týden 1–2:** Fáze 0–2 + začít Fázi 4 unit testy.  
2. **Týden 3–5:** Fáze 5–6 + profiling.  
3. **Týden 6–8:** Fáze 7–10 + release gate.  
4. **Průběžně:** Fáze 9 při každém větším merge engine/pipeline.

---

## 14. Odkazy na existující context

- `context/AmbiLight-MASTER-PLAN.md` — produktový rámec.
- `context/PROJECT_STATE_AUDIT.md` — stav projektu.
- `context/UDP_TASK_UDP_COMMANDS.md` — UDP příkazy.
- `context/SCREEN_COLOR_PIPELINE.md` — barevný pipeline.
- `context/ENGINE_PROFILE_NOTES.md` — profilování.
- `context/LIFECYCLE_SUBSCRIPTIONS.md` — dispose / odběry (Fáze 2).
- `context/PLATFORM_RESUME_MATRIX.md` — resume / tray (Fáze 6).
- `context/TELEMETRY_POLICY.md` — bez SDK, lokální log (Fáze 11).
- `context/VERSIONING_AND_CI.md` — verze a dart-define (Fáze 10.4).
- `context/RELEASE_GATE_CHECKLIST.md` — gate před ship (Fáze 12).
- `context/MEMORY_PROFILING_TEMPLATE.md` — šablona měření paměti (Fáze 9.1).

---

## 16. Tok spuštění (`main.dart`) — referenční

```
main()
 └─ runZonedGuarded
      ├─ WidgetsFlutterBinding.ensureInitialized()
      ├─ uložení Zone pro runApp (_ambiBindingZone)
      ├─ installAppErrorHandling()     ← FlutterError + PlatformDispatcher + ErrorWidget
      └─ unawaited(_bootstrapApp())
             ├─ Logger.root + úroveň dle AMBI_VERBOSE_LOGS / debug
             ├─ initWindowManagerEarly / hotKeyManager.unregisterAll (try/catch)
             ├─ AmbilightAppController.load() → ConfigRepository.loadDetailed …
             ├─ initDesktopShell
             ├─ controller.startLoop()
             └─ _ambiBindingZone.run(() => runApp(MultiProvider … AmbiLightRoot))
```

**Dart defines (volitelné):** `AMBI_VERBOSE_LOGS`, `AMBI_CHANNEL`, `GIT_SHA` — viz `lib/application/build_environment.dart`.

---

*Tento soubor je živý: při dokončení fází aktualizujte checkboxy a sekci 11. Nemazejte historické poznámky bez důvodu; doplnění je preferované.*
