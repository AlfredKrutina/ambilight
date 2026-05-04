import 'package:logging/logging.dart';

import 'build_environment.dart';

final _log = Logger('AmbiDebug');

/// Husté diagnostické řádky jen při `kDebugMode` nebo `--dart-define=AMBI_DEBUG_TRACE=true`.
void ambilightDebugTrace(String message, [Object? error, StackTrace? stackTrace]) {
  if (!ambilightDebugTraceEnabled) return;
  if (error != null) {
    _log.fine(message, error, stackTrace);
  } else {
    _log.fine(message);
  }
}
