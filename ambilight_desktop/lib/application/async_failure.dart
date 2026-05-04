import 'dart:async';

import 'package:logging/logging.dart';

import 'app_crash_log.dart';

final _log = Logger('AsyncFailure');

/// Politika: neočekávané chyby v async řetězcích logovat vždy; do souboru jen při [persist] nebo kritických cestách.
void logUnexpectedAsyncFailure(
  String context,
  Object error,
  StackTrace stack, {
  bool persistToCrashLog = false,
}) {
  _log.warning('$context: $error', error, stack);
  if (persistToCrashLog) {
    unawaited(AppCrashLog.append(context, error: error, stack: stack));
  }
}

/// Transport reconnect apod. — bez uživatelského banneru, jen log (šum při odpojeném Wi‑Fi).
void logTransportBackgroundFailure(String context, Object error, StackTrace stack) {
  logUnexpectedAsyncFailure(context, error, stack, persistToCrashLog: false);
}
