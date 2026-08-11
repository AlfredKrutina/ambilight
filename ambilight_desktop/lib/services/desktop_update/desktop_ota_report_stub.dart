import 'package:flutter/material.dart';

/// Stub — OTA report jen na IO desktopech.
class DesktopOtaUserReport {
  const DesktopOtaUserReport({
    required this.state,
    required this.message,
    required this.logPath,
    required this.atIso,
  });

  final String state;
  final String message;
  final String logPath;
  final String atIso;

  bool get isSuccess => false;
  bool get isFailure => false;
}

abstract final class DesktopOtaReportStore {
  static Future<void> writePending({required String detail}) async {}
  static Future<void> writeHostFailure(String message) async {}
  static Future<DesktopOtaUserReport?> consumePendingReport() async => null;
  static void scheduleStartupReportDialog() {}
}

Future<void> showDesktopOtaReportDialog(BuildContext context, DesktopOtaUserReport report) async {}

Future<void> showDesktopOtaProgressDialog(BuildContext context, {required String message}) async {}
