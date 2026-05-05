# Feedback — Agent A1 (nativní screen capture)

## Shrnutí (3–6 vět)

Agent A1 doplnil chybějící macOS implementaci method channelu `ambilight/screen_capture`, který už existoval na Windows (GDI + worker thread + `WM_APP`) a Linuxu (X11 + XRandR). Swift modul `ScreenCaptureChannel.swift` registruje stejné metody (`listMonitors`, `sessionInfo`, `requestPermission`, `capture`) jako ostatní platformy, včetně převodu souřadnic monitorů na konvenci Y dolů pro shodu s Windows virtual screen. Do `Info.plist` přibyl `NSScreenCaptureUsageDescription` pro TCC. Kompletní kontrakt je zdokumentován v `context/SCREEN_CAPTURE_CHANNEL.md`.

## Co se povedalo (bullet)

- macOS: nový `Runner/ScreenCaptureChannel.swift`, registrace z `MainFlutterWindow.swift`, soubor přidaný do `Runner.xcodeproj`.
- macOS: virtuální snímek (`monitorIndex == 0`) přes `CGWindowListCreateImage` na sjednocený rect, fallback na `CGDisplayCreateImage(CGMainDisplayID())`.
- macOS: per-monitor capture přes `CGDisplayCreateImage`, řazení displejů shodně s Win/Linux (x, pak y).
- `context/SCREEN_CAPTURE_CHANNEL.md` — jednotný popis kanálu pro A2 a koordinaci.
- Odkaz na dokument v `windows/runner/screen_capture_channel.h`.

## Co se nepovedalo / blokery (bullet)

- V tomto prostředí nebyl dostupný příkaz `flutter` / Xcode build — Swift kód nebyl kompilován CI zde; ověření: `flutter build macos` na macOS stroji.
- App Sandbox (`DebugProfile.entitlements`) zůstává zapnutý; pokud by `CGWindowListCreateImage` / `CGDisplayCreateImage` v sandboxu selhávaly i po uživatelském povolení Screen Recording, bude potřeba revize entitlements nebo dočasné vypnutí sandboxu pro vývoj (mimo scope tohoto běhu).

## Konflikty s jinými agenty (soubory + doporučení merge)

- Potenciální překryv s **A3** (overlay) pouze pokud by A3 měnil `MainFlutterWindow.swift` — sladit merge tak, aby zůstaly oba řádky: `RegisterGeneratedPlugins` + `ScreenCaptureChannel.register`.
- **A0** může sahat na `project.pbxproj` jinak — při konfliktu zachovat `ScreenCaptureChannel.swift` v *Sources* a ve skupině *Runner*.

## Otevřené TODO pro další běh

- Ověřit build na fyzickém Macu (Swift 5, deployment target projektu).
- Zvážit ScreenCaptureKit pro novější macOS, pokud `CGDisplayCreateImage` bude označen deprecated v cílové verzi.
- Linux Wayland / PipeWire portal — zůstává mimo A1 dokud není dohodnutý kanál s A2.

## Příkazy ověřené (např. flutter analyze, flutter test)

- `flutter` nebyl v PATH na Windows agentním prostředí — příkazy neproběhly zde. Doporučené ověření: `cd ambilight_desktop && flutter analyze && flutter test && flutter build macos`.
