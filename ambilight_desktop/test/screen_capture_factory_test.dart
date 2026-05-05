import 'dart:io' show Platform;

import 'package:ambilight_desktop/features/screen_capture/method_channel_screen_capture_source.dart';
import 'package:ambilight_desktop/features/screen_capture/non_windows_screen_capture_source.dart';
import 'package:ambilight_desktop/features/screen_capture/screen_capture_source.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('create() is alias for platform()', () {
    final a = ScreenCaptureSource.create();
    final b = ScreenCaptureSource.platform();
    expect(a.runtimeType, b.runtimeType);
  });

  test('desktop OS uses MethodChannel implementation', () {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      expect(ScreenCaptureSource.create(), isA<MethodChannelScreenCaptureSource>());
    } else {
      expect(ScreenCaptureSource.create(), isA<NonWindowsScreenCaptureSource>());
    }
  });
}
