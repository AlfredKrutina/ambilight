import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'method_channel_screen_capture_source.dart';
import 'non_windows_screen_capture_source.dart';
import 'screen_frame.dart';

/// Geometrie monitoru v souřadnicích virtuální plochy (jako MSS `monitor` dict).
class MonitorInfo {
  const MonitorInfo({
    required this.mssStyleIndex,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.isPrimary = false,
  });

  /// Stejná konvence jako [ScreenFrame.monitorIndex] / MSS index v `monitors[]`.
  final int mssStyleIndex;
  final int left;
  final int top;
  final int width;
  final int height;
  final bool isPrimary;

  Map<String, Object?> toJson() => <String, Object?>{
        'mssStyleIndex': mssStyleIndex,
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        'isPrimary': isPrimary,
      };
}

/// Diagnostika prostředí (P5 matice / UI).
class ScreenSessionInfo {
  const ScreenSessionInfo({
    required this.platform,
    required this.sessionType,
    this.captureBackend,
    this.note,
  });

  final String platform;
  final String sessionType;
  final String? captureBackend;
  final String? note;

  static const ScreenSessionInfo unknown = ScreenSessionInfo(
    platform: 'unknown',
    sessionType: 'unknown',
    note: 'No session info from native layer.',
  );

  factory ScreenSessionInfo.fromMap(Map<Object?, Object?> m) {
    String s(Object? v) => v?.toString() ?? '';
    return ScreenSessionInfo(
      platform: s(m['os']),
      sessionType: s(m['sessionType']),
      captureBackend: m['captureBackend'] != null ? s(m['captureBackend']) : null,
      note: m['note'] != null ? s(m['note']) : null,
    );
  }
}

/// Jednotné API pro zachycení obrazovky (režim `screen`, Agent P6).
///
/// Implementace: Windows / Linux / macOS = [MethodChannelScreenCaptureSource] (`ambilight/screen_capture`);
/// web = [NonWindowsScreenCaptureSource].
abstract class ScreenCaptureSource {
  static const MethodChannel defaultChannel = MethodChannel('ambilight/screen_capture');

  /// Alias pro prompt P4/P5 (`ScreenCaptureSource.create()`).
  factory ScreenCaptureSource.create({
    MethodChannel channel = defaultChannel,
    BinaryMessenger? messenger,
  }) =>
      ScreenCaptureSource.platform(channel: channel, messenger: messenger);

  /// Výchozí zdroj pro běžící platformu.
  factory ScreenCaptureSource.platform({
    MethodChannel channel = defaultChannel,
    BinaryMessenger? messenger,
  }) {
    if (kIsWeb) {
      return NonWindowsScreenCaptureSource();
    }
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return MethodChannelScreenCaptureSource(
        channel: channel,
        messenger: messenger,
      );
    }
    return NonWindowsScreenCaptureSource();
  }

  /// Snímek jednoho monitoru / virtuální plochy. `monitorIndex` ve stylu MSS (viz [ScreenFrame]).
  Future<ScreenFrame?> captureFrame(int monitorIndex);

  /// Seznam monitorů pro UI / validaci [monitorIndex].
  Future<List<MonitorInfo>> listMonitors();

  /// Nativní popis prostředí (Linux X11/Wayland, macOS, …).
  Future<ScreenSessionInfo> getSessionInfo() async => ScreenSessionInfo.unknown;

  /// macOS: žádost o screen recording; ostatní OS typicky no-op `true`.
  Future<bool> requestScreenCapturePermission() async => true;

  void dispose();
}
