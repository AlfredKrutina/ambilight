import 'package:ambilight_desktop/application/ambilight_app_controller.dart';
import 'package:ambilight_desktop/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/l10n_test_app.dart';

void main() {
  testWidgets('SettingsPage — záložka Globální a struktura TabBar', (tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    // Šířka pod 600 px → spodní TabBar místo postranního railu (viz AppBreakpoints.useSettingsSideRail).
    await tester.binding.setSurfaceSize(const Size(520, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: ambilightTestMaterialApp(
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Globální'), findsWidgets);
    expect(find.byType(TabBar), findsOneWidget);
  });
}
