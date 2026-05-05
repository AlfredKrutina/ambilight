# Method channel `ambilight/screen_capture`

Jednotný kontrakt mezi Dartem (`MethodChannelScreenCaptureSource`) a nativními runnery **Windows**, **Linux**, **macOS**.

## Kanál

| Vlastnost | Hodnota |
|-----------|---------|
| Název | `ambilight/screen_capture` |
| Codec | StandardMethodCodec |

## Metody

### `listMonitors`

**Návratová hodnota:** `List<Object>` — každý prvek je `Map` s klíči:

| Klíč | Typ | Význam |
|------|-----|--------|
| `mssStyleIndex` | `int` | `0` = virtuální plocha (sjednocení všech monitorů). `1`…`N` = fyzické monitory v **stabilním pořadí** (řazení podle `left`, pak `top` v souřadnicích s **Y dolů**). Odpovídá indexům používaným v Python `mss`. |
| `left` | `int` | Levý okraj obdélníku ve virtuální ploše (px). |
| `top` | `int` | Horní okraj ve virtuální ploše s osou **Y dolů** (jako Windows `GetMonitorInfo` / virtual screen). |
| `width` | `int` | Šířka (px). |
| `height` | `int` | Výška (px). |
| `isPrimary` | `bool` | Primární monitor (jen u položek `mssStyleIndex >= 1`). U položky `0` typicky `false`. |

### `sessionInfo`

**Návratová hodnota:** `Map` — informativní; Dart mapuje na `ScreenSessionInfo`.

Doporučené klíče: `os` (`windows` \| `linux` \| `macos`), `sessionType`, `captureBackend`, `note` (lidsky čitelné limity / HDR / Wayland).

### `requestPermission`

**Argumenty:** žádné.  
**Návratová hodnota:** `bool` — uživatel povolil / není potřeba (Windows často vždy `true`). Na macOS 10.15+ může vyvolat dialog Screen Recording.

### `capture`

**Argumenty:** `Map` s polem:

| Klíč | Typ | Význam |
|------|-----|--------|
| `monitorIndex` | `int` | `0` = celá virtuální plocha. `>= 1` = konkrétní monitor podle `listMonitors`. Mimo rozsah: chování jako Windows — použije se první monitor a vrátí se korigovaný `monitorIndex`. |

**Volitelné argumenty (jen Windows nativní runner):** stejné jako u Event kanálu `ambilight/screen_capture_stream` — `cropLeft`, `cropTop`, `cropWidth`, `cropHeight` (desktop souřadnice), `dxgiAcquireTimeoutMs`. Dart je posílá při pull `capture` pro paritu s push streamem.

**Linux a macOS:** volitelné klíče v mapě argumentů **ignorují** se (žádná chyba); snímek zůstává celý monitor / výřez daný jen implementací backendu. Parita cropu na Linuxu není v tomto kanálu implementovaná — rozšíření by patřilo do `linux/runner/screen_capture_linux.cc`.

**Návratová hodnota (úspěch):** `Map`:

| Klíč | Typ | Význam |
|------|-----|--------|
| `width` | `int` | Šířka snímku. |
| `height` | `int` | Výška snímku. |
| `monitorIndex` | `int` | Skutečně použitý index (po případné korekci). |
| `rgba` | `Uint8List` / typed bytes | Raw RGBA, **8 bitů na kanál**, řádky shora dolů, pixely v pořadí R, G, B, A. |

**Chyba:** `PlatformException` s `code` např. `capture_failed`, `no_display`, `no_window` (Windows).

## Nativní implementace (kde co je)

| OS | Soubory | Backend |
|----|---------|---------|
| Windows | `windows/runner/screen_capture_channel.*`, hook v `flutter_window.cpp` | GDI `BitBlt`, výsledek z worker vlákna přes `WM_APP` na hlavní okno. |
| Linux | `linux/runner/screen_capture_linux.cc`, registrace v `my_application.cc` | X11 `XGetImage` + XRandR; při `WAYLAND_DISPLAY` poznámka v `sessionInfo`. |
| macOS | `macos/Runner/ScreenCaptureChannel.swift`, registrace v `MainFlutterWindow.swift` | `CGWindowListCreateImage` (virtuální plocha) / `CGDisplayCreateImage` (per monitor). |

## Oprávnění

- **macOS:** `NSScreenCaptureUsageDescription` v `Info.plist`; uživatel musí povolit **Screen Recording** (Soukromí a zabezpečení). App Sandbox může vyžadovat další úpravy pro distribuci — viz Apple TN.
- **Linux:** běžně `DISPLAY` a X11; čistý Wayland bez XWayland není v této vrstvě řešen.
- **Windows:** bez zvláštního oprávnění; HDR / exclusive fullscreen mohou měnit výsledek (viz `note` ve `sessionInfo`).
