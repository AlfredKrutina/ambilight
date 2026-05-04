import 'package:ambilight_desktop/application/ambilight_app_controller.dart';
import 'package:ambilight_desktop/ui/ambi_shell.dart';
import 'package:ambilight_desktop/ui/layout_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ambi_provider_scope.dart';
import 'support/l10n_test_app.dart';

void main() {
  testWidgets('AmbiShell zobrazí AppBar', (WidgetTester tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ambiProviderScope(
        controller,
        ambilightTestMaterialApp(home: const AmbiShell()),
      ),
    );
    await tester.pump();
    expect(find.text('AmbiLight'), findsOneWidget);
  });

  testWidgets('úzké okno: spodní NavigationBar (D15)', (WidgetTester tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(480, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ambiProviderScope(
        controller,
        ambilightTestMaterialApp(home: const AmbiShell()),
      ),
    );
    await tester.pump();
    expect(AppBreakpoints.useShellSideRail(480), isFalse);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('ambi-main-sidebar')), findsNothing);
  });

  testWidgets('široké okno: NavigationRail (D15)', (WidgetTester tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ambiProviderScope(
        controller,
        ambilightTestMaterialApp(home: const AmbiShell()),
      ),
    );
    await tester.pump();
    expect(AppBreakpoints.useShellSideRail(900), isTrue);
    expect(find.byKey(const Key('ambi-main-sidebar')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
