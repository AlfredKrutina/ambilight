import 'dart:typed_data';

import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/screen/screen_color_pipeline.dart';
import 'package:ambilight_desktop/engine/screen/screen_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('segmentRoi', () {
    test('top edge ROI lies in upper band', () {
      const sm = ScreenModeSettings(
        scanDepthTop: 10,
        paddingPercent: 0,
        paddingLeft: 0,
        paddingRight: 0,
        paddingTop: 0,
        paddingBottom: 0,
      );
      const seg = LedSegment(
        ledStart: 0,
        ledEnd: 3,
        edge: 'top',
        pixelStart: 0,
        pixelEnd: 0,
      );
      final r = ScreenColorPipeline.segmentRoi(seg, sm, 100, 80);
      expect(r.y, lessThan(20));
      expect(r.h, greaterThan(0));
      expect(r.w, 100);
    });
  });

  group('sampleRoiColors', () {
    test('solid red ROI yields red strip', () {
      const w = 20;
      const h = 10;
      final rgba = Uint8List(w * h * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 200;
        rgba[i + 1] = 10;
        rgba[i + 2] = 10;
        rgba[i + 3] = 255;
      }
      final frame = ScreenFrame(monitorIndex: 0, width: w, height: h, rgba: rgba);
      const roi = SegmentRoiRect(x: 0, y: 0, w: w, h: h);
      final out = Uint8List(4 * 3);
      ScreenColorPipeline.sampleRoiColors(frame, roi, 'top', 4, out);
      expect(out[0], greaterThan(180));
      expect(out[1], lessThan(40));
      expect(out[2], lessThan(40));
    });
  });

  group('applyTransforms', () {
    test('calibration gain scales red', () {
      const sm = ScreenModeSettings(
        saturationBoost: 1.0,
        gamma: 1.0,
        calibrationProfiles: {
          'P': {
            'enabled': true,
            'gain': [2.0, 1.0, 1.0],
            'gamma': [1.0, 1.0, 1.0],
            'offset': [0, 0, 0],
          },
        },
        activeCalibrationProfile: 'P',
      );
      final o = ScreenColorPipeline.applyTransforms(100, 0, 0, sm);
      expect(o.$1, greaterThanOrEqualTo(180));
    });

    test('minBrightness lifts near-black', () {
      const sm = ScreenModeSettings(minBrightness: 40, gamma: 2.2, saturationBoost: 1.0);
      final o = ScreenColorPipeline.applyTransforms(1, 1, 1, sm);
      final lum = 0.299 * o.$1 + 0.587 * o.$2 + 0.114 * o.$3;
      expect(lum, greaterThanOrEqualTo(35));
    });
  });

  group('extractCaptureMap', () {
    test('horizontal gradient top segment maps LEDs', () {
      final frame = MockScreenFrame.gradient(width: 40, height: 20, monitorIndex: 0);
      const seg = LedSegment(
        ledStart: 0,
        ledEnd: 3,
        edge: 'top',
        monitorIdx: 0,
        deviceId: 'primary',
      );
      const sm = ScreenModeSettings(
        segments: [seg],
        monitorIndex: 0,
        interpolationMs: 0,
      );
      final cap = ScreenColorPipeline.extractCaptureMap(
        frame: frame,
        sm: sm,
        segments: const [seg],
      );
      expect(cap.length, 4);
      final left = cap[ScreenColorPipeline.captureKey('primary', 0)]!;
      final right = cap[ScreenColorPipeline.captureKey('primary', 3)]!;
      expect(left.$1, lessThan(right.$1));
    });
  });
}
