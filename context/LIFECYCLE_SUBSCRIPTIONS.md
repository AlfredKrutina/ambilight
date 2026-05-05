# Ambilight Desktop — odběry, časovače, dispose

Krátký audit pro plán stability (Fáze 2). Cíl: žádné „visící“ handlery po zavření widgetu / dispose controlleru.

## Procesová úroveň (život = běh aplikace)

| Zdroj | Soubor | Poznámka |
|-------|--------|----------|
| `Logger.root.onRecord.listen` | `lib/main.dart` | Záměrně po celou dobu procesu (desktop exit ukončí VM). |

## AmbilightAppController

| Prvek | Zrušení |
|-------|---------|
| `_timer` (hlavní smyčka) | `stopLoop`, `dispose` |
| `_pcHealthTimer` | `_restartPcHealthTimer`, `dispose` |
| `_applyDebounceTimer` | před novým apply, `dispose` |
| Spotify / SystemMedia polling | `stopPolling`, `dispose` |
| Transporty | `dispose` + `flushPendingDispose` |

## Desktop shell / tray

| Prvek | Soubor | Zrušení |
|-------|--------|---------|
| `_trayMenuDebounce`, `_trayClickTimer` | `desktop_chrome_io.dart` | `disposeDesktopShell` |
| Window/tray listener | `desktop_chrome_io.dart` | `disposeDesktopShell` |

## Widgety

| Prvek | Soubor |
|-------|--------|
| `TabController` | `settings_page.dart` → `dispose` |
| `_thumbDebounce`, `ui.Image` | `screen_scan_settings_tab.dart` → `dispose` |
| `_thumb` decode | při náhradě snímku předchozí `dispose` |

## Služby

| Služba | Odběr |
|--------|--------|
| `MusicAudioService` | `_sub?.cancel()` v `_stopInternal` |
| `LedDiscoveryService` | `sub.cancel()` po timeoutu v `scan` / `queryPong` |
| `SpotifyService.connectPkce` | `HttpServer` + `sub.cancel()` v `finally` |
| `SpotifyService` polling | `_pollTimer` v `stopPolling` |

## Singletony / statické reference

- `desktop_chrome_io.dart`: `_controller`, listener reference — drží se do `disposeDesktopShell` (aktuálně aplikace typicky nevolá při běžném ukončení z tray — volitelné rozšíření: zavolat před `exit`).
