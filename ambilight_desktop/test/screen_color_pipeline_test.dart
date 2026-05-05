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

    test('legacy pixel span scales by refWidth to downscaled frame', () {
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
        pixelEnd: 960,
        refWidth: 1920,
        refHeight: 1080,
      );
      final r = ScreenColorPipeline.segmentRoi(seg, sm, 256, 144);
      expect(r.x, 0);
      expect(r.w, 128);
    });

    test('vertical edge span scales by refHeight to downscaled frame', () {
      const sm = ScreenModeSettings(
        scanDepthLeft: 10,
        paddingPercent: 0,
        paddingLeft: 0,
        paddingRight: 0,
        paddingTop: 0,
        paddingBottom: 0,
      );
      const seg = LedSegment(
        ledStart: 0,
        ledEnd: 3,
        edge: 'left',
        pixelStart: 0,
        pixelEnd: 540,
        refWidth: 1920,
        refHeight: 1080,
      );
      final r = ScreenColorPipeline.segmentRoi(seg, sm, 256, 144);
      expect(r.y, 0);
      expect(r.h, 72);
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
      ScreenColorPipeline.sampleRoiColors(frame, roi, 'top', 4, out, colorSampling: 'average');
      expect(out[0], greaterThan(180));
      expect(out[1], lessThan(40));
      expect(out[2], lessThan(40));
    });

    test('median vs average: outlier pixel favors median channel values', () {
      const w = 9;
      const h = 3;
      final rgba = Uint8List(w * h * 4);
      rgba.fillRange(0, rgba.length, 0);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final o = (y * w + x) * 4;
          rgba[o] = 200;
          rgba[o + 1] = 10;
          rgba[o + 2] = 10;
          rgba[o + 3] = 255;
        }
      }
      final center = (1 * w + 4) * 4;
      rgba[center] = 255;
      rgba[center + 1] = 255;
      rgba[center + 2] = 255;
      final frame = ScreenFrame(monitorIndex: 0, width: w, height: h, rgba: rgba);
      const roi = SegmentRoiRect(x: 0, y: 0, w: w, h: h);
      final avgOut = Uint8List(3);
      final medOut = Uint8List(3);
      ScreenColorPipeline.sampleRoiColors(frame, roi, 'top', 1, avgOut, colorSampling: 'average');
      ScreenColorPipeline.sampleRoiColors(frame, roi, 'top', 1, medOut, colorSampling: 'median');
      expect(medOut[0], lessThanOrEqualTo(avgOut[0]));
      expect(medOut[0], greaterThan(190));
    });

    test('reusable strip longer than ledCount (max segment buffer) is OK', () {
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
      final out = Uint8List(64 * 3);
      ScreenColorPipeline.sampleRoiColors(frame, roi, 'top', 4, out, colorSampling: 'average');
      expect(out[0], greaterThan(180));
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

  group('screenSegmentCaptureWarnings', () {
    test('mismatch between segment monitor and capture monitor yields warning', () {
      final cfg = AppConfig.defaults().copyWith(
        screenMode: const ScreenModeSettings(
          monitorIndex: 2,
          segments: [
            LedSegment(
              ledStart: 0,
              ledEnd: 3,
              edge: 'top',
              monitorIdx: 0,
            ),
          ],
          interpolationMs: 0,
        ),
      );
      final w = ScreenColorPipeline.screenSegmentCaptureWarnings(cfg);
      expect(w, isNotEmpty);
      expect(w.first.segmentMonitorIdx, 0);
      expect(w.first.captureMonitorIndex, 2);
    });

    test('legacy segment idx 0 vs capture 1 matches — no warning', () {
      final cfg = AppConfig.defaults().copyWith(
        screenMode: const ScreenModeSettings(
          monitorIndex: 1,
          segments: [
            LedSegment(
              ledStart: 0,
              ledEnd: 3,
              edge: 'top',
              monitorIdx: 0,
            ),
          ],
          interpolationMs: 0,
        ),
      );
      expect(ScreenColorPipeline.screenSegmentCaptureWarnings(cfg), isEmpty);
    });
  });

  group('cornerMarkerLedIndices', () {
    test('implicit 66 LEDs — junctions match strip left→top→right→bottom order', () {
      final cfg = AppConfig.defaults().copyWith(
        globalSettings: AppConfig.defaults().globalSettings.copyWith(
          ledCount: 66,
          devices: [
            const DeviceSettings(id: 'primary', name: 'x', type: 'serial', ledCount: 66),
          ],
        ),
        screenMode: const ScreenModeSettings(
          monitorIndex: 1,
          segments: [],
          interpolationMs: 0,
        ),
      );
      expect(ScreenColorPipeline.cornerMarkerLedIndices(config: cfg, deviceId: 'primary', corner: 'top_left'), [16, 17]);
      expect(ScreenColorPipeline.cornerMarkerLedIndices(config: cfg, deviceId: 'primary', corner: 'top_right'), [33, 34]);
      expect(ScreenColorPipeline.cornerMarkerLedIndices(config: cfg, deviceId: 'primary', corner: 'bottom_right'), [49, 50]);
      expect(ScreenColorPipeline.cornerMarkerLedIndices(config: cfg, deviceId: 'primary', corner: 'bottom_left'), [0, 65]);
    });

    test('explicit segments — corners use strip index junctions', () {
      const sm = ScreenModeSettings(
        monitorIndex: 1,
        interpolationMs: 0,
        segments: [
          LedSegment(ledStart: 0, ledEnd: 9, monitorIdx: 1, edge: 'left', reverse: true),
          LedSegment(ledStart: 10, ledEnd: 19, monitorIdx: 1, edge: 'top', reverse: false),
          LedSegment(ledStart: 20, ledEnd: 29, monitorIdx: 1, edge: 'right', reverse: false),
          LedSegment(ledStart: 30, ledEnd: 39, monitorIdx: 1, edge: 'bottom', reverse: true),
        ],
      );
      final cfg = AppConfig.defaults().copyWith(
        globalSettings: AppConfig.defaults().globalSettings.copyWith(
          devices: [
            const DeviceSettings(id: 'd1', name: 'x', type: 'serial', ledCount: 40),
          ],
        ),
        screenMode: sm,
      );
      expect(ScreenColorPipeline.cornerMarkerLedIndices(config: cfg, deviceId: 'd1', corner: 'top_left'), [9, 10]);
      expect(ScreenColorPipeline.cornerMarkerLedIndices(config: cfg, deviceId: 'd1', corner: 'bottom_left'), [0, 39]);
    });
  });
}
