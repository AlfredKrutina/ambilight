import 'package:flutter/foundation.dart';

/// Kanál buildu (`--dart-define=AMBI_CHANNEL=beta`). V CI lze předat např. `stable`.
const String ambilightReleaseChannel = String.fromEnvironment('AMBI_CHANNEL', defaultValue: 'stable');

/// Zkrácený Git SHA (`--dart-define=GIT_SHA=…`). GitHub Actions: předej `${{ github.sha }}`.
const String ambilightGitSha = String.fromEnvironment('GIT_SHA', defaultValue: '');

/// JSON manifest desktopové aktualizace (`desktop-manifest.json` u posledního GitHub Release).
/// Fork: `--dart-define=AMBI_DESKTOP_UPDATE_MANIFEST_URL=https://…/desktop-manifest.json`
const String ambilightDesktopUpdateManifestUrl = String.fromEnvironment(
  'AMBI_DESKTOP_UPDATE_MANIFEST_URL',
  defaultValue: 'https://github.com/AlfredKrutina/ambilight/releases/latest/download/desktop-manifest.json',
);

/// Rozšířené logy (`--dart-define=AMBI_VERBOSE_LOGS=true`) i v release — jen staging / diagnostika.
bool get ambilightVerboseLogsEnabled =>
    kDebugMode || const bool.fromEnvironment('AMBI_VERBOSE_LOGS', defaultValue: false);

/// Velmi detailní trace (`--dart-define=AMBI_DEBUG_TRACE=true`) — [ambilightDebugTrace], probe UDP bindu, tiky smyčky.
bool get ambilightDebugTraceEnabled =>
    kDebugMode || const bool.fromEnvironment('AMBI_DEBUG_TRACE', defaultValue: false);

/// Root logger [Level.FINE] pro širší diagnostiku (verbose nebo debug trace).
bool get ambilightDetailedLogsEnabled =>
    ambilightVerboseLogsEnabled || ambilightDebugTraceEnabled;

/// Vypne automatickou obnovu po opakovaných pádech při startu (`StartupCrashGuard`).
/// Vývoj: `--dart-define=AMBI_DISABLE_STARTUP_CRASH_RECOVERY=true`
bool get ambilightStartupCrashRecoveryDisabled =>
    const bool.fromEnvironment('AMBI_DISABLE_STARTUP_CRASH_RECOVERY', defaultValue: false);

/// Přepíše periodu hlavní smyčky ve výkonovém režimu při snímání obrazovky (ms). `-1` = z konfigurace.
/// Staging: `--dart-define=AMBI_PERF_SCREEN_TICK_MS=25`
int get ambilightPerfScreenTickMsOverride {
  const v = int.fromEnvironment('AMBI_PERF_SCREEN_TICK_MS', defaultValue: -1);
  if (v >= 16 && v <= 40) return v;
  return -1;
}
