import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:ambilight_desktop/engine/brightness_schedule.dart';
import 'package:ambilight_desktop/engine/fallback_modes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scheduleBrightnessPctAt', () {
    test('interpolates between points', () {
      const pts = [
        BrightnessSchedulePoint(minutesOfDay: 0, brightnessPct: 0),
        BrightnessSchedulePoint(minutesOfDay: 60, brightnessPct: 100),
      ];
      expect(scheduleBrightnessPctAt(pts, DateTime(2026, 1, 1, 0, 0)), 0);
      expect(scheduleBrightnessPctAt(pts, DateTime(2026, 1, 1, 0, 30)), closeTo(50, 0.01));
      expect(scheduleBrightnessPctAt(pts, DateTime(2026, 1, 1, 1, 0)), 100);
    });

    test('wraps across midnight', () {
      const pts = [
        BrightnessSchedulePoint(minutesOfDay: 22 * 60, brightnessPct: 100),
        BrightnessSchedulePoint(minutesOfDay: 2 * 60, brightnessPct: 0),
      ];
      // 00:00 is halfway from 22:00 to 02:00 (4h span)
      expect(scheduleBrightnessPctAt(pts, DateTime(2026, 1, 1, 0, 0)), closeTo(50, 0.01));
    });
  });

  group('brightnessForMode screen master/schedule', () {
    AppConfig base({
      int brightness = 200,
      int master = 100,
      bool schedule = false,
      List<BrightnessSchedulePoint> points = const [],
      String startMode = 'screen',
    }) {
      return AppConfig.defaults().copyWith(
        globalSettings: AppConfig.defaults().globalSettings.copyWith(startMode: startMode),
        screenMode: ScreenModeSettings(
          brightness: brightness,
          masterBrightnessPct: master,
          brightnessScheduleEnabled: schedule,
          brightnessSchedule: points,
        ),
        lightMode: const LightModeSettings(brightness: 180),
      );
    }

    test('applies master multiplier only on screen', () {
      final c = base(brightness: 200, master: 50);
      expect(brightnessForMode(c), 100);
    });

    test('applies schedule when enabled', () {
      final c = base(
        brightness: 200,
        master: 100,
        schedule: true,
        points: const [
          BrightnessSchedulePoint(minutesOfDay: 0, brightnessPct: 50),
          BrightnessSchedulePoint(minutesOfDay: 1439, brightnessPct: 50),
        ],
      );
      expect(brightnessForMode(c, now: DateTime(2026, 1, 1, 12, 0)), 100);
    });

    test('other modes ignore screen master', () {
      final c = base(master: 10, schedule: true, startMode: 'light');
      expect(brightnessForMode(c), 180);
    });
  });
}
