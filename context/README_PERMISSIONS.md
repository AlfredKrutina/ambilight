# Oprávnění a OS integrace (AmbiLight Desktop / Flutter)

## Globální hotkeys (`hotkey_manager`)

### macOS

- **Accessibility**: systémové zkratky vyžadují přístup pro ovládání počítače.
  - *System Settings → Privacy & Security → Accessibility* — povolte AmbiLight (nebo váš IDE při vývoji).
- Podrobnosti k pluginu: [hotkey_manager na pub.dev](https://pub.dev/packages/hotkey_manager).

### Linux

- Nainstalujte závislost **keybinder-3.0** (viz README `hotkey_manager`), např.  
  `sudo apt-get install libkeybinder-3.0-0` (název balíčku se může lišit podle distribuce).

### Windows

- Bez speciálního oprávnění nad rámec běžné aplikace; případné konflikty s jinými globálními hotkeys řešte v nastavení druhých aplikací.

---

## Autostart (`launch_at_startup`)

- **Windows**: zápis do autostartu běžného uživatele (obdoba Python `startup.py` / `HKCU\...\Run`).
- **Linux**: `.desktop` v autostart adresáři (podle implementace pluginu).
- **macOS**: často **Launch at Login** helper; u balíčku `launch_at_startup` je potřeba doplnit **Swift / SPM** (`LaunchAtLogin`) a případně build fázi podle [oficiálního README launch_at_startup](https://github.com/leanflutter/launch_at_startup#macos-support). Do macOS 13+ část kroků může být zbytečná — držte se aktuální dokumentace pluginu.

---

## COM auto-discovery

- Žádná speciální oprávnění nad rámec přístupu k sériovému portu, který už používá `flutter_libserialport`.
