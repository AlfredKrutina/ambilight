# AmbiLight Desktop — spuštění

## Požadavky

- **Flutter SDK** stabilní kanál (desktop: Windows, Linux, macOS). Ověřeno v CI proti rozhraní podobnému Flutter **3.41+** / Dart **3.11+**.
- **macOS:** minimální verze **13.0 (Ventura)** — vyžaduje plugin `desktop_audio_capture` (system audio). `macos/Podfile` a Xcode `MACOSX_DEPLOYMENT_TARGET` jsou nastavené na 13.0.
- V repu je projekt jen s platformami **windows / linux / macos** (`flutter create --platforms=windows,linux,macos`). Android zde **není** — `flutter_libserialport` a nativní pluginy cílí desktop.

### Spotify tokeny (Windows build)

Spotify OAuth tokeny jsou v **`path_provider`** adresáři aplikace (`spotify_tokens.json`), ne přes `flutter_secure_storage` — aby **Windows build nepotřeboval ATL** (`atlstr.h` z MSVC pluginu). Pokud bys někdy `flutter_secure_storage` znovu přidal, k C++ workloadu bys musel doinstalovat **C++ ATL**.

### `flutter pub get`: „advisoriesUpdated must be a String“

Občas Pub při stahování **advisory metadat** z pub.dev spadne na `FormatException` (rozpor verze Pub klienta vs API). Pokud výstup končí **`Got dependencies!`**, závislosti jsou v pořádku — jde o šum při resolve. Řešení do budoucna: **`flutter upgrade`** na novější stable, až to opraví upstream.

### PowerShell: příkazy po řádcích

Nespojuj `cd`, `flutter pub get` a `flutter run` do jednoho řádku (vznikají rozbité řetězce jako `flutter pub getss`). Každý příkaz na **samostatný řádek** nebo použij `;` mezi nimi.

## Příkazy

```bash
cd ambilight_desktop
flutter pub get
flutter analyze
flutter test
```

### Ikona Windows (`.ico`)

Zdroje: `assets/branding/app_icon_dark.png` (výchozí pro `.exe`) a `app_icon_light.png` (light režim / marketing).  
Přegenerovat `windows/runner/resources/app_icon.ico` po změně PNG:

```bash
dart run tool/build_app_icon_ico.dart
# nebo z light PNG:
dart run tool/build_app_icon_ico.dart assets/branding/app_icon_light.png
```

Spuštění (zvol si cíl):

```bash
flutter run -d windows
flutter run -d linux
flutter run -d macos
```

## Tray a okno

- **Zavření okna (X)** skryje aplikaci do traye (neukončí). Úplné ukončení: položka **Ukončit** v menu tray ikony.
- **Dvojklik** na ikonu v liště (cca do 450 ms) otevře hlavní okno na záložce **Nastavení**; jeden klik po prodlevě jen zobrazí okno.

## macOS

- **CocoaPods / `flutter_libserialport`:** pod `libserialport` spouští `autogen.sh` → potřebuje **Homebrew** `automake` a `libtool` (`brew install automake libtool`). V CI to instalují workflow. Navíc je v repu **`macos/podspecs/libserialport.podspec`**, který pinuje **konkrétní git commit** (trunk používá annotovaný tag `libserialport-0.1.1`, u shallow clone z CocoaPods to umělo házet „is not a commit“ / rozbitý strom).
- **Okno / tray:** `window_manager` + `tray_manager`. Aplikace **nekončí** po zavření okna (běží v trayi); ukončení jen přes **Ukončit** v menu traye.
- **Snímání obrazovky:** v **Nastavení → Obrazovka** je karta s nativní diagnostikou a tlačítkem **macOS: žádost o snímání obrazovky** (TCC). V `Info.plist` je `NSScreenCaptureUsageDescription`.
- **Mikrofon (hudba):** `NSMicrophoneUsageDescription` v `Info.plist`; v entitlements je `com.apple.security.device.audio-input` (sandbox).
- **Tray ikona:** barva podle **režimu a zapnutí** (generovaný PNG/ICO v tempu); při chybě fallback na `AppIcon.icns`.
- **Sériový port:** v entitlements je **`com.apple.security.device.serial`** (spolu se síťovými a audio právy). Stále platí: podepsaný build a případně schválení u Apple podle kanálu distribuce.
- **Globální zkratky:** `NSInputMonitoringUsageDescription` v `Info.plist` — uživatel musí v **Soukromí a zabezpečení → Sledování vstupu** povolit AmbiLight.
- **HomeKit:** v repu nejsou v entitlements klíče vyžadující placený Apple Developer profil (kvůli CI / obecnému podepisování). Funkce přes kanál `ambilight/homekit` na distribuovaném buildu doplníš v Xcode: capability **HomeKit** + stejný klíč v `Release.entitlements` / profilu.
- **Větev `mac-app` + DMG:** Mac úpravy nejdřív na **mac-app**, pak sladit s `main`. Workflow **`desktop_release`** po tagu `desktop-v*` z CI vytvoří **nepodepsaný** DMG (ad-hoc) — uživatelům stačí při prvním spuštění *Otevřít* / Soukromí. Pokud chceš **podepsaný / notarizovaný** disk: `flutter build macos --release` na Macu (např. s vlastním `LocalSigning.xcconfig`), vlastní `create-dmg` nebo `hdiutil`, a soubor **`ambilight_desktop_macos.dmg`** nahraj k danému GitHub Release ručně (přepíše asset z CI, pokud použiješ stejný název).

## Linux (screen capture)

- Implementace je **X11** (`XGetImage` + XRandR) — spolehlivé na **X11 session** nebo často přes **XWayland**, pokud běží `DISPLAY`.
- Na čistém **Waylandu** bez XWayland může `XOpenDisplay` selhat; v diagnostice v aplikaci uvidíš `sessionType` / `note` z nativní vrstvy. Plná PipeWire cesta není v tomto repu — vyžaduje samostatný vývoj.

## Linux (tray)

Balíček `tray_manager` na Linuxu často vyžaduje knihovny indikátoru (např. `libayatana-appindicator3` — viz CI `apt-get` v `.github/workflows/ambilight_desktop.yml`). Vlastní PNG ikona v trayi zatím volitelná; tray může použít výchoční symbol.
