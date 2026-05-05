# Verze a CI (Fáze 10.4)

## Verze v aplikaci

- Zdroj pravdy: `ambilight_desktop/pubspec.yaml` → pole `version:` (např. `0.1.1+2`).
- Za běhu: `package_info_plus` na stránce **O aplikaci**.

## Dart defines (volitelné)

Při buildu z CI lze předat:

- `GIT_SHA` — zkrácený commit zobrazený v About (celý hash se může předat a UI bere prefix).
- `AMBI_CHANNEL` — např. `stable`, `beta`, `ci`.

Příklad:

```bash
flutter build windows --release --dart-define=GIT_SHA=abc123 --dart-define=AMBI_CHANNEL=ci
```

## Ruční procedura před release

1. Zvedni `version` v `pubspec.yaml` (semver + build number za `+`).
2. Spusť lokálně `flutter analyze` a `flutter test`.
3. Ověř release build cílové platformy.
4. Tag v git (`v0.1.2`) volitelně v souladu s `version`.

Automatický bump z tagu do `pubspec` není v tomto repu povinný — lze doplnit skript později.
