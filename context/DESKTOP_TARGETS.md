# AmbiLight Desktop — cílové platformy

- Složka **`ambilight_desktop/`** je Flutter **desktop** projekt (Windows, Linux, macOS). Šablona byla doplněna přes `flutter create --platforms=windows,linux,macos` — **Android ani iOS** v tomto adresáři nejsou záměrně.
- Závislost **`flutter_libserialport`** nemá smysl na Androidu a často komplikuje multi-platform build. Pokud bys někdy přidával `android/`, použij **oddělený flavor** / modul bez serialu, nebo vyluč Android z CI pro tento balíček.

## Spuštění jen desktop

```bash
cd ambilight_desktop
flutter pub get
flutter run -d windows   # nebo linux / macos
```

Podrobnosti: `ambilight_desktop/README_RUN.md`.

## CI (GitHub Actions)

Workflow `.github/workflows/ambilight_desktop.yml` běží matici **ubuntu-latest**, **windows-latest**, **macos-latest**: `flutter pub get`, `flutter analyze`, `flutter test` a na každém OS **`flutter build <platform> --debug`** (ověření CMake / Xcode / MSVC bez release signing). Při výpadku macOS signingu v release režimu řeš samostatný release job — debug build v CI typicky stačí.
