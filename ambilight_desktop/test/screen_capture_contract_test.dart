import 'dart:typed_data';

import 'package:ambilight_desktop/features/screen_capture/screen_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenFrame', () {
    test('isValid matches RGBA byte length', () {
      const w = 2;
      const h = 2;
      final rgba = Uint8List(w * h * 4);
      final f = ScreenFrame(width: w, height: h, monitorIndex: 1, rgba: rgba);
      expect(f.isValid, isTrue);
      expect(ScreenFrame(width: 0, height: 1, monitorIndex: 0, rgba: Uint8List(0)).isValid, isFalse);
    });

    test('detachForIsolate roundtrip', () {
      final initial = Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]);
      final f = ScreenFrame(width: 1, height: 2, monitorIndex: 1, rgba: initial);
      final td = f.detachForIsolate();
      final copy = ScreenFrame.importFromIsolate(td);
      expect(copy, Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]));
    });
  });

  group('MethodChannelScreenCaptureSource', () {
    test('captureFrame maps channel payload to ScreenFrame', () async {
      const channel = MethodChannel('ambilight/screen_capture');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'capture') {
          return <String, Object?>{
            'width': 1,
            'height': 1,
            'monitorIndex': 1,
            'rgba': Uint8List.fromList([1, 2, 3, 4]),
          };
        }
        return null;
      });

      final src = MethodChannelScreenCaptureSource(channel: channel);
      final frame = await src.captureFrame(1);
      expect(frame, isNotNull);
      expect(frame!.width, 1);
      expect(frame.height, 1);
      expect(frame.monitorIndex, 1);
      expect(frame.rgba, Uint8List.fromList([1, 2, 3, 4]));
    });

    test('listMonitors maps entries', () async {
      const channel = MethodChannel('ambilight/screen_capture');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'listMonitors') {
          return <Object?>[
            <String, Object?>{
              'mssStyleIndex': 0,
              'left': 0,
              'top': 0,
              'width': 3840,
              'height': 1080,
              'isPrimary': false,
            },
            <String, Object?>{
              'mssStyleIndex': 1,
              'left': 0,
              'top': 0,
              'width': 1920,
              'height': 1080,
              'isPrimary': true,
            },
          ];
        }
        return null;
      });

      final src = MethodChannelScreenCaptureSource(channel: channel);
      final mons = await src.listMonitors();
      expect(mons.length, 2);
      expect(mons[1].mssStyleIndex, 1);
      expect(mons[1].isPrimary, isTrue);
    });
  });

  test('NonWindowsScreenCaptureSource returns null and empty monitors', () async {
    final stub = NonWindowsScreenCaptureSource();
    expect(await stub.captureFrame(1), isNull);
    expect(await stub.listMonitors(), isEmpty);
  });
}
