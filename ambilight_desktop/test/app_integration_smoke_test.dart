import 'package:ambilight_desktop/application/ambilight_app_controller.dart';
import 'package:ambilight_desktop/ui/ambi_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ambi_provider_scope.dart';
import 'support/l10n_test_app.dart';

/// Fáze 8.3 — minimální integrační kouř: shell + krátký běh smyčky controlleru (bez nativního tray).
void main() {
  testWidgets('AmbiShell + controller loop smoke', (tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    controller.startLoop();

    await tester.pumpWidget(
      ambiProviderScope(
        controller,
        ambilightTestMaterialApp(home: const AmbiShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('AmbiLight'), findsWidgets);

    controller.stopLoop();
  });

  testWidgets('Top chrome výstup toggles controller.enabled', (tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ambiProviderScope(
        controller,
        ambilightTestMaterialApp(home: const AmbiShell()),
      ),
    );
    await tester.pump();

    expect(controller.enabled, true);
    await tester.tap(find.widgetWithText(FilledButton, 'Výstup zapnutý'));
    await tester.pump();

    expect(controller.enabled, false);
    expect(find.text('Výstup vypnutý'), findsOneWidget);
  });

  testWidgets('Home mode tile calls setStartMode', (tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ambiProviderScope(
        controller,
        ambilightTestMaterialApp(home: const AmbiShell()),
      ),
    );
    await tester.pump();

    expect(controller.config.globalSettings.startMode, 'screen');

    // První výskyt = dlaždice režimu (druhý je karta v sekci Integrace).
    await tester.tap(find.text('Hudba').at(0));
    await tester.pump();

    expect(controller.config.globalSettings.startMode, 'music');
  });
}
