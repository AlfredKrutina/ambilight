import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/context_ext.dart';
import '../../ui/app_navigator.dart';
import 'windows_desktop_updater.dart';

/// Persistovaný výsledek Windows OTA — app ho přečte po restartu a ukáže uživateli.
class DesktopOtaUserReport {
  const DesktopOtaUserReport({
    required this.state,
    required this.message,
    required this.logPath,
    required this.atIso,
  });

  /// `ok` | `error` | `pending` | `interrupted`
  final String state;
  final String message;
  final String logPath;
  final String atIso;

  bool get isSuccess => state == 'ok';
  bool get isFailure => state == 'error' || state == 'interrupted';
}

abstract final class DesktopOtaReportStore {
  static String get _path => WindowsDesktopUpdater.statusPath;
  static String get _consumedPath =>
      p.join(WindowsDesktopUpdater.otaRoot, 'ambi_update_status.shown.json');

  static Future<void> writePending({required String detail}) async {
    if (!Platform.isWindows) return;
    await _write({
      'state': 'pending',
      'message': detail,
      'logPath': WindowsDesktopUpdater.updateLogPath,
      'at': DateTime.now().toUtc().toIso8601String(),
      'pid': pid,
    });
  }

  static Future<void> writeHostFailure(String message) async {
    if (!Platform.isWindows) return;
    await _write({
      'state': 'error',
      'message': message,
      'logPath': WindowsDesktopUpdater.updateLogPath,
      'at': DateTime.now().toUtc().toIso8601String(),
      'source': 'host',
    });
  }

  static Future<void> _write(Map<String, dynamic> map) async {
    try {
      final dir = Directory(WindowsDesktopUpdater.otaRoot);
      await dir.create(recursive: true);
      await File(_path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(map),
        flush: true,
      );
    } catch (_) {}
  }

  /// Přečte status a označí jako zobrazený (přesun do `.shown`).
  static Future<DesktopOtaUserReport?> consumePendingReport() async {
    if (!Platform.isWindows) return null;
    try {
      final f = File(_path);
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final map = Map<String, dynamic>.from(j);
      var state = '${map['state'] ?? ''}'.trim().toLowerCase();
      final message = '${map['message'] ?? ''}'.trim();
      final logPath = '${map['logPath'] ?? WindowsDesktopUpdater.updateLogPath}'.trim();
      final atIso = '${map['at'] ?? ''}'.trim();

      if (state.isEmpty) return null;

      // Stale pending = update never finished after app relaunch.
      if (state == 'pending' || state == 'running' || state == 'applying') {
        final at = DateTime.tryParse(atIso)?.toLocal();
        final age = at == null ? const Duration(days: 1) : DateTime.now().difference(at);
        if (age > const Duration(minutes: 2)) {
          state = 'interrupted';
        } else {
          // Still in progress / race — don't spam user.
          return null;
        }
      }

      try {
        await f.copy(_consumedPath);
        await f.delete();
      } catch (_) {
        try {
          await f.writeAsString(
            jsonEncode({...map, 'consumed': true}),
            flush: true,
          );
        } catch (_) {}
      }

      if (state == 'ok' || state == 'error' || state == 'interrupted') {
        final msg = message.isNotEmpty
            ? message
            : (state == 'interrupted'
                ? 'Update did not finish (interrupted or updater crashed).'
                : '');
        return DesktopOtaUserReport(
          state: state == 'ok' ? 'ok' : (state == 'interrupted' ? 'interrupted' : 'error'),
          message: msg,
          logPath: logPath.isEmpty ? WindowsDesktopUpdater.updateLogPath : logPath,
          atIso: atIso,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Po startu UI — dialog úspěch/chyba + odkaz na log.
  ///
  /// Updater zapisuje `ok` až po (nebo těsně před) relaunch; nový proces proto
  /// často najde ještě `running`/`pending`. Jednorázové čtení by dialog přeskočilo
  /// navždy — pollujeme, dokud není terminální stav nebo timeout.
  static void scheduleStartupReportDialog() {
    if (!Platform.isWindows) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (true) {
        final report = await consumePendingReport();
        if (report != null) {
          final ctx = ambiNavigatorKey.currentContext;
          if (ctx == null || !ctx.mounted) return;
          await showDesktopOtaReportDialog(ctx, report);
          return;
        }

        final statusFile = File(_path);
        if (!await statusFile.exists()) {
          return;
        }

        // Still in progress (pending/running) — wait for PS to flip to ok/error.
        if (DateTime.now().isAfter(deadline)) {
          // Force-consume stale in-progress as interrupted.
          try {
            final raw = await statusFile.readAsString();
            final j = jsonDecode(raw);
            if (j is Map) {
              final map = Map<String, dynamic>.from(j);
              final state = '${map['state'] ?? ''}'.trim().toLowerCase();
              if (state == 'pending' || state == 'running' || state == 'applying') {
                map['state'] = 'interrupted';
                map['message'] = map['message'] ??
                    'Update did not finish (interrupted or updater crashed).';
                await statusFile.writeAsString(jsonEncode(map), flush: true);
                final late = await consumePendingReport();
                if (late != null) {
                  final ctx = ambiNavigatorKey.currentContext;
                  if (ctx == null || !ctx.mounted) return;
                  await showDesktopOtaReportDialog(ctx, late);
                }
              }
            }
          } catch (_) {}
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    });
  }
}

Future<void> showDesktopOtaReportDialog(
  BuildContext context,
  DesktopOtaUserReport report,
) async {
  final l10n = context.l10n;
  final isOk = report.isSuccess;
  final title = isOk ? l10n.desktopUpdateResultSuccessTitle : l10n.desktopUpdateResultFailTitle;
  final body = isOk
      ? l10n.desktopUpdateResultSuccessBody
      : (report.message.isNotEmpty
          ? l10n.desktopUpdateResultFailBody(report.message)
          : l10n.desktopUpdateResultFailBodyGeneric);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline : Icons.error_outline,
            color: isOk ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(body),
            if (!isOk) ...[
              const SizedBox(height: 12),
              Text(l10n.desktopUpdateLogPathLabel, style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(report.logPath, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        if (!isOk)
          TextButton(
            onPressed: () async {
              final dir = Directory(WindowsDesktopUpdater.otaRoot);
              if (!await dir.exists()) await dir.create(recursive: true);
              await Process.run('explorer.exe', [dir.path]);
            },
            child: Text(l10n.openLogFolder),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

/// Blokující dialog při přípravě updateru (před exit).
Future<void> showDesktopOtaProgressDialog(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(context.l10n.desktopUpdateProgressTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    ),
  );
}
