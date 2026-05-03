import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('AppErrorSafety');

/// Globální handlery — neodstraňují logiku chyb ve službách, ale zabraňují pádu procesu kvůli neodchyceným výjimkám.
void installAppErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _log.severe(
      'FlutterError: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _log.severe('Neodchycená asynchronní chyba: $error', error, stack);
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return Material(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.35),
              children: [
                const TextSpan(
                  text: 'Chyba při vykreslení widgetu. Aplikace dál běží.\n\n',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
  _log.severe('runZonedGuarded: $error', error, stack);
}
