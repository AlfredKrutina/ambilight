import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../l10n/app_locale_bridge.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_crash_log.dart';

final _log = Logger('AppErrorSafety');

bool _appErrorHandlingInstalled = false;

/// `true` po prvním úspěšném [installAppErrorHandling] — druhé volání v debug jen assert hlášku.
bool get isAppErrorHandlingInstalled => _appErrorHandlingInstalled;

void _persistFault(String headline, {Object? error, StackTrace? stack}) {
  unawaited(AppCrashLog.append(headline, error: error, stack: stack));
}

/// Krátké chybové hlášení pro uživatele (horní pruh v [AmbiLightRoot]).
final ValueNotifier<String?> appFaultBannerNotifier = ValueNotifier<String?>(null);

Timer? _dismissFaultTimer;

void dismissAppFault() {
  _dismissFaultTimer?.cancel();
  _dismissFaultTimer = null;
  appFaultBannerNotifier.value = null;
}

/// Zobrazí horní banner a zapíše do logu. [autoDismiss] vynuluje stejný text po timeoutu.
void reportAppFault(String message, {Duration autoDismiss = const Duration(seconds: 14)}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return;
  final brief = trimmed.length > 420 ? '${trimmed.substring(0, 420)}…' : trimmed;
  _dismissFaultTimer?.cancel();
  appFaultBannerNotifier.value = brief;
  _dismissFaultTimer = Timer(autoDismiss, () {
    if (appFaultBannerNotifier.value == brief) {
      dismissAppFault();
    }
  });
  _log.warning('AppFault: $brief');
  _persistFault('AppFault: $brief');
}

/// Globální handlery — logují chyby a v release módu dávají uživateli krátkou zpětnou vazbu.
void installAppErrorHandling() {
  if (_appErrorHandlingInstalled) {
    assert(() {
      debugPrint('installAppErrorHandling: ignorováno — již nainstalováno');
      return true;
    }());
    return;
  }
  _appErrorHandlingInstalled = true;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    _log.severe(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    _persistFault(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stack: details.stack,
    );
    // V debug už je detail v konzoli / presentError; banner jen v release, ať UI neruší vývoj.
    if (!kDebugMode) {
      final line = details.exceptionAsString().split('\n').first.trim();
      if (line.isNotEmpty) {
        reportAppFault(AppLocaleBridge.strings.faultUiError(line));
      }
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _log.severe('Neodchycená asynchronní chyba: $error', error, stack);
    _persistFault('PlatformDispatcher.onError: $error', error: error, stack: stack);
    final msg = error.toString();
    final first = msg.split('\n').first.trim();
    reportAppFault(first.isEmpty ? AppLocaleBridge.strings.faultUncaughtAsync : first);
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    final head = AppLocaleBridge.strings.errorWidgetTitle;
    return Material(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.35),
              children: [
                TextSpan(
                  text: head,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: details.exceptionAsString()),
              ],
            ),
          ),
        ),
      ),
    );
  };
}

void logZoneError(Object error, StackTrace stack) {
  _log.severe('runZonedGuarded / zóna: $error', error, stack);
  _persistFault('runZonedGuarded: $error', error: error, stack: stack);
}

/// Vloží nad [child] plovou lištu s [appFaultBannerNotifier] (volá se z [MaterialApp.builder]).
Widget wrapWithAppFaultBanner(Widget child) {
  return ValueListenableBuilder<String?>(
    valueListenable: appFaultBannerNotifier,
    builder: (context, fault, inner) {
      final base = inner ?? const SizedBox.shrink();
      if (fault == null) return base;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          base,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 12,
              color: const Color(0xFFB91C1C),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 4),
                        child: Icon(Icons.error_outline, color: Colors.white, size: 22),
                      ),
                      Expanded(
                        child: SelectableText(
                          fault,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(context).closeBannerTooltip,
                        color: Colors.white,
                        onPressed: dismissAppFault,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    child: child,
  );
}
