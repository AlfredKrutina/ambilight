import 'package:ambilight_desktop/application/ambilight_app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fáze 9 — opakovaný start/stop bez výjimky (sanity pro dispose / timer).
void main() {
  test('AmbilightAppController repeated startLoop/stopLoop/dispose', () async {
    for (var i = 0; i < 6; i++) {
      final c = AmbilightAppController();
      c.startLoop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      c.stopLoop();
      c.dispose();
    }
  });
}
