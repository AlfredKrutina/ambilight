import 'dart:async';

/// Bez `dart:io` (web / test bez desktopových cest) — žádná akce.
abstract final class StartupCrashGuard {
  static Future<void> runPreBootstrapRecovery() async {}

  static Future<void> markSessionClean() async {}

  static void scheduleWarmupCompletion() {}
}
