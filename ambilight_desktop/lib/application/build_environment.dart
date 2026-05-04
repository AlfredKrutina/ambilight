import 'package:flutter/foundation.dart';

/// Kanál buildu (`--dart-define=AMBI_CHANNEL=beta`). V CI lze předat např. `stable`.
const String ambilightReleaseChannel = String.fromEnvironment('AMBI_CHANNEL', defaultValue: 'stable');

/// Zkrácený Git SHA (`--dart-define=GIT_SHA=…`). GitHub Actions: předej `${{ github.sha }}`.
const String ambilightGitSha = String.fromEnvironment('GIT_SHA', defaultValue: '');

/// Rozšířené logy (`--dart-define=AMBI_VERBOSE_LOGS=true`) i v release — jen staging / diagnostika.
bool get ambilightVerboseLogsEnabled =>
    kDebugMode || const bool.fromEnvironment('AMBI_VERBOSE_LOGS', defaultValue: false);

/// Velmi detailní trace (`--dart-define=AMBI_DEBUG_TRACE=true`) — [ambilightDebugTrace], probe UDP bindu, tiky smyčky.
bool get ambilightDebugTraceEnabled =>
    kDebugMode || const bool.fromEnvironment('AMBI_DEBUG_TRACE', defaultValue: false);

/// Root logger [Level.FINE] pro širší diagnostiku (verbose nebo debug trace).
bool get ambilightDetailedLogsEnabled =>
    ambilightVerboseLogsEnabled || ambilightDebugTraceEnabled;
