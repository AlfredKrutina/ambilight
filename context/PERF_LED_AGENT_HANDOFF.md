# Výkon LED / latence — handoff a prompty pro agenta

**Účel:** jedno místo pro iterativní opravy plynulosti, FPS na pásku a nízké latence ve `ambilight_desktop/`. Doplňuje [FLUTTER_VS_PYQT_GAP_ANALYSIS.md](./FLUTTER_VS_PYQT_GAP_ANALYSIS.md), [WINDOWS_SCREEN_CAPTURE.md](./WINDOWS_SCREEN_CAPTURE.md), [SCREEN_COLOR_PIPELINE.md](./SCREEN_COLOR_PIPELINE.md), [SCREEN_CAPTURE_CHANNEL.md](./SCREEN_CAPTURE_CHANNEL.md).

**Obecná pravidla:** viz [AGENT_PROMPTS_AMBILIGHT_FLUTTER.md](./AGENT_PROMPTS_AMBILIGHT_FLUTTER.md) (nemaž soubory bez pokynu, `flutter analyze` / `flutter test`, firmware neměň bez pokynu).

---

## Ověřený stav (kód / diff)

### Duplicitní submit screen pipeline (Windows push)

- **Push:** jediný submit z `_onWindowsPushFrame` → `unawaited(_submitScreenPipelineFrameAsync(f))`.
- **`_tick`:** při `mode == 'screen'` a platném `capFrame` se `_submitScreenPipelineFrameAsync(capFrame)` volá **jen pokud** `!(_eligibleForWindowsScreenPush() && _windowsScreenCaptureStreamSub != null)` — tedy při běžícím push streamu se **neduplikuje**.
- **Bootstrap:** když ještě není `pushActive` (subscribe se navazuje), `_tick` může dál posílat `capFrame` z `_screenFrameLatest`.

Soubor: `ambilight_desktop/lib/application/ambilight_app_controller.dart`.

### Lifecycle (stručně)

- `stopLoop()` / dispose → `unawaited(_stopWindowsPushCapture())`; listener kontroluje `_controllerDisposed` a režim.
- Očekávatelné krátké okno bez nového submitu: do prvního snímku ze streamu nebo po vyčištění `capFrame`; při změně sig resubscribe může krátce „držet“ starý frame až do nového push (spíš téma crop parity než úplná tma).

### Izolát — kopie pixelů (iterace 2 — hotovo)

- **Před iterací 2:** hlavní izolát `setRange` → `TransferableTypedData`, worker znovu `Uint8List` + `setRange` z materializovaného view (dvě plné kopie).
- **Po iteraci 2:** hlavní izolát posílá `TransferableTypedData.fromList(<TypedData>[frame.rgba])` (jedna kopie přes hranici izolátů; `rgba` na UI zůstává platná). Worker použije `materialize().asUint8List()` přímo jako `ScreenFrame.rgba` (případně `Uint8List.sublistView`, pokud je buffer delší než `w*h*4`). Komentáře v `screen_frame.dart` (`detachForIsolate` / `importFromIsolate`); v controlleru kontrola `!f.isValid` před zvýšením `submitSeq` v `_submitScreenPipelineFrameAsync`.

### Crop u MethodChannel `capture` (iterace 2 — hotovo, Windows)

- C++: `ParseCropFromEncodableMap`, `TryParseDxgiTimeoutMsFromEncodableMap`, společné pro `capture` i Event stream; `capture` plní `CaptureJob.has_crop` / `crop_desktop` / `dxgi_acquire_timeout_ms`, fronta přes `EnqueueCaptureJob`.
- Dart: `ScreenCaptureSource.captureFrame(..., windowsCaptureExtras?)`, `MethodChannelScreenCaptureSource` slučuje extras do `invoke('capture')`; `_windowsMethodCapturePullExtras()` + cache (iterace 2: podpis `jsonEncode(screenMode)|backend`), invalidace v `_applyConfigCore`, `load()`, `dispose`; pull volá `captureFrame` s crop + `dxgiAcquireTimeoutMs: 16` jen když `computeStreamCropUnion` vrátí výřez. `non_windows_screen_capture_source.dart` v souladu s API. *(Iterace 3 doplňuje signaturu z `listMonitors` a 2 s throttle — viz „Iterace 3 (hotovo)“.)*
- Testy: `test/screen_capture_contract_test.dart` (na Windows ověření předaných klíčů).

### UI (iterace 2 — hotovo)

- `DropdownButtonFormField` v `global_settings_fields` — `isExpanded: true` → `settings_page_smoke_test` prošel.

---

## Baseline CI (poslední ověření po iteraci 3)

- `flutter analyze` — bez problémů.
- `flutter test` — **78/78** zelených (ověřeno po iteraci 3).

### Iterace 3 (hotovo — stručně)

- **DXGI / stream lifecycle (Windows C++):** po zastavení push stream vlákna (`StopStreamCaptureWorker`) se volá `AmbilightDxgiShutdown()`, aby se ne držela duplikace bez aktivního streamu; na konci těla smyčky stream workeru `Sleep(0)` proti busy-spin v degenerovaných případech.
- **Controller / režim:** `setStartMode` a `replaceConfig` vždy volají `_ensureScreenCaptureDriverTimer()` — synchronizace push streamu vs. pull driveru i když se perioda hlavního timeru nemění.
- **Emit / jitter:** u běžného `_distribute` v `_tick` pro cestu se screen pipeline izolátem je `flushImmediately: useScreenIsolate` (méně odstupu o jeden microtask oproti dřívějšímu vždy batch režimu).
- **Cache pull cropu:** signatura `screenMode`+backend + `listMonitors` (`mssStyleIndex:WxH`); při stejné konfiguraci se `listMonitors` znovu volá nejdříve po 2 s (omezení zátěže při pull driveru 8 ms).
- **Linux dokumentace:** `context/SCREEN_CAPTURE_CHANNEL.md` — ignorace crop/dxgi mimo Windows.
- **Metriky sinceCapture vs sinceLastEmit:** záměrně neuděláno (širší změna mapování času v UDP diag + kontrakt s C++; nízká priorita vůči lifecycle).

Diagnostika výkonu: `--dart-define=AMBI_PIPELINE_DIAGNOSTICS=true`; Windows DebugView: `[ambilight] CAPTURE path=` z nativní vrstvy.

**Návrh commit message (iterace 2):**  
`perf(screen): single-copy pipeline isolate buffer; Windows capture crop parity; fix settings dropdown overflow`

**Návrh commit message (iterace 3):**  
`fix(win): DXGI shutdown after stream stop; sync capture driver on mode change; flush screen isolate distribute`

---

## Prioritní backlog (stav po iteraci 3)

| # | Úkol | Stav | Soubory (orientačně) |
|---|------|------|----------------------|
| 1 | Jedna plná kopie méně do screen pipeline isolátu | **Hotovo** | `screen_pipeline_isolate.dart`, `screen_frame.dart`, `ambilight_app_controller.dart` |
| 2 | Crop u MethodChannel `capture` (parita stream, Windows) | **Hotovo** | `screen_capture_channel.cpp`, `screen_capture_source.dart`, `method_channel_screen_capture_source.dart`, `non_windows_screen_capture_source.dart`, `ambilight_app_controller.dart`, contract test |
| 3 | Metriky `sinceCapture` vs `sinceLastEmit` | **Neuděláno** (iter. 3) | `pipeline_diagnostics.dart`, `udp_device_transport.dart` — zůstává backlog |
| 4 | DXGI lifecycle / žádné „naprázdno“ po změně režimu | **Hotovo** (iter. 3) | `screen_capture_channel.cpp`, `ambilight_app_controller.dart` |
| 5 | Emit po výsledku isolátu (flush / scheduler) | **Částečně** (iter. 3: `flushImmediately` při screen izolátu v `_tick`) | `ambilight_app_controller.dart` |
| 6 | Ladění gate / UDP podle diag | **Další iterace** | controller, `udp_device_transport.dart` |
| 7 | Cache pull cropu vs změna rozlišení monitoru bez změny JSON `screenMode` | **Hotovo** (iter. 3) | `ambilight_app_controller.dart` |
| 8 | Linux pull crop (parita args) | **Dokumentováno** (iter. 3) | `context/SCREEN_CAPTURE_CHANNEL.md`; implementace v linux runneru backlog |
| 9 | Sampling LED v C++ (PyQt parita) | Až po 4–8 | nativní + pipeline |

---

# Prompt #2 — archiv (iterace 2 dokončena)

*Pro novou práci použij **Prompt #3** níže. Tento blok nechávám pro historii / jinou větev.*

```
Jsi senior Flutter/Dart + Windows C++ vývojář. Repozitář: Ambilight, kořen workspace. Hlavní app: ambilight_desktop/. Kontext handoff: context/PERF_LED_AGENT_HANDOFF.md.

OVĚŘENÝ STAV (k datu zadání Promptu #2)
- Duplicitní submit screen pipeline při Windows push je opravený (_onWindowsPushFrame submituje; _tick přeskakuje submit když pushActive). Nevracej tuto regresi.
- Izolát: hlavní technický dluh byl dvojí kopie pixelů — řešeno v dokončené iteraci 2 (viz sekce „Izolát — kopie pixelů“ výše).

ÚKOLY (priorita)
1) Snížit kopírování pixelů do screen pipeline isolátu na jednu bezpečnou cestu (UI náhled nesmí číst uvolněný buffer). Dotčené: lib/engine/screen/screen_pipeline_isolate.dart, screen_frame.dart, volání z bridge/controlleru.
2) Rozšířit MethodChannel capture o stejné crop argumenty jako u screen_capture_stream v screen_capture_channel.cpp; Dart: method_channel_screen_capture_source.dart + _captureScreenFrameAsync. macOS/Linux: API bez rozbití abstrakce (ignorované args nebo no-op).
3) Pokud zbude čas: oprav RenderFlex overflow v lib/ui/settings/tabs/global_settings_tab.dart (Dropdown ~řádek 133) aby prošel test/settings_page_smoke_test.dart.

PRAVIDLA
- Nemaž soubory bez schválení uživatele.
- Po změnách: flutter analyze + flutter test v ambilight_desktop/.
- Malé commity; bez širokých refaktorů mimo úkol.

HOTOV = analyze čistý, testy zelené (včetně UI fixu pokud ho vezmeš), krátký souhrn změn a souborů.
```

---

# Prompt #3 — archiv (iterace 3 dokončena)

*Pro novou práci použij **Prompt #4** níže. Tento blok nechávám pro historii / jinou větev. Výsledek iterace 3 je v sekci „Iterace 3 (hotovo)“ a v backlogu výše — nekopíruj zastaralý úkol z fenced bloku níže.*

```
Jsi senior Flutter/Dart + Windows C++ vývojář. Repozitář Ambilight, app ambilight_desktop/. Přečti context/PERF_LED_AGENT_HANDOFF.md — iterace 2 je hotová (jedna kopie méně do screen pipeline isolátu, Windows MethodChannel capture crop parita se streamem, dropdown isExpanded, 78 testů zelených).

CÍL TÉTO ITERACE (priorita)
1) DXGI / nativní lifecycle: po přepnutí mimo screen (a při dispose) ověř a případně oprav, že duplikace/stream/worker neběží „naprázdno“ a nežere CPU — screen_capture_channel.cpp (Unregister, StopStream, worker fronta), sladění s ambilight_app_controller.dart při změně startMode.
2) Emit / jitter: zvaž odeslání na zařízení těsněji vázané na nový výsledek screen pipeline isolátu (např. flush nebo lehký scheduler), aby výstup nebyl výhradně svázaný s periodou _tick + scheduleMicrotask — jen pokud měření nebo čitelnost kódu ukáže přínos; žádný masivní přepis distribuce.
3) Volitelně: metriky sinceCapture vs sinceLastEmit (pipeline_diagnostics.dart, udp_device_transport.dart), aby logy nelhaly při UDP skip — pokud nestihneš, explicitně napiš „neuděláno“ a proč.

ZNÁMÉ DALŠÍ DLUHY (můžeš vzít místo 2 nebo jako podúkol)
- Cache pull cropu ignoruje změnu rozlišení monitoru bez změny screenMode JSON — zvážit invalidaci signaturou z listMonitors() nebo periodickou invalidaci.
- Linux: C++ crop jen Windows; buď doplnit linux runner stejnými argumenty, nebo krátce zdokumentovat v context/ že se ignorují.

PRAVIDLA
- Nemaž soubory bez schválení uživatele.
- flutter analyze + flutter test v ambilight_desktop/ na konci.
- Malé, reviewovatelné změny.

HOTOV = stručný souhrn + návrh Promptu #4 (co zbývá).
```

---

# Prompt #4 — copy-paste pro dalšího agenta (po iteraci 3)

```
Jsi senior Flutter/Dart + Windows C++ vývojář. Repozitář Ambilight, app ambilight_desktop/. Kontext: context/PERF_LED_AGENT_HANDOFF.md (iterace 3 hotová: DXGI shutdown po stop stream, driver timer po setStartMode/replaceConfig, flushImmediately u screen izolátu v _tick, pull crop cache + monSig, Linux crop zdokumentováno).

CÍL (priorita)
1) Metriky sinceCapture vs sinceLastEmit — upřesnit pipeline_diagnostics + udp_device_transport tak, aby při skip/noUpdate/music režimu logy nelhaly (bez změny produkčního chování LED mimo diag).
2) Gate / UDP tuning podle AMBI_PIPELINE_DIAGNOSTICS (Windows screen + Wi‑Fi), případně koaleskovaný emit přímo z onResult isolátu (s ochranou proti duplicitám s _tick).
3) Volitelně: Linux pull crop v screen_capture_linux.cc (parita volitelných klíčů z MethodChannel) — nebo ponechat jen dokumentaci, pokud ROI na Linuxu není priorita.

PRAVIDLA: nemaž soubory bez schválení; flutter analyze + flutter test; malé diffy.

HOTOV = souhrn + návrh Promptu #5.
```

---

# Prompt #5 — zástupný (po výsledku #4)

*Doplň po iteraci 4 např.: Linux `screen_capture_linux.cc` crop parita, C++ LED sampling (PyQt), nebo profiling podle metrik z #4.*

---

## Historie promptů (pro člověka)

| Iterace | Obsah |
|---------|--------|
| 1 | Roadmap výkonu, PyQt vs Flutter tok, duplicitní submit (opraveno) |
| 2 | Jedna kopie méně do isolátu; Windows capture crop; UI dropdown; 78 testů |
| 3 | DXGI shutdown po stop stream, driver timer při změně režimu, `flushImmediately` u screen izolátu, pull crop `monSig` + 2 s throttle `listMonitors`, Linux doc |
| 4 | Viz blok „Prompt #4“ výše — metriky sinceCapture/emit, gate/UDP, volitelně Linux crop |

*Aktualizuj tento soubor po každé agentní iteraci (stav, baseline testů).*
