import 'package:ambilight_desktop/application/ambilight_app_controller.dart';
import 'package:ambilight_desktop/ui/ambi_shell.dart';
import 'package:ambilight_desktop/ui/layout_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('AmbiShell zobrazí AppBar', (WidgetTester tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AmbilightAppController>.value(
        value: controller,
        child: const MaterialApp(
          home: AmbiShell(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('AmbiLight'), findsOneWidget);
  });

  testWidgets('úzké okno: spodní NavigationBar (D15)', (WidgetTester tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AmbilightAppController>.value(
        value: controller,
        child: const MaterialApp(home: AmbiShell()),
      ),
    );
    await tester.pump();
    expect(AppBreakpoints.useShellSideRail(400), isFalse);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('ambi-main-sidebar')), findsNothing);
  });

  testWidgets('široké okno: NavigationRail (D15)', (WidgetTester tester) async {
    final controller = AmbilightAppController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AmbilightAppController>.value(
        value: controller,
        child: const MaterialApp(home: AmbiShell()),
      ),
    );
    await tester.pump();
    expect(AppBreakpoints.useShellSideRail(900), isTrue);
    expect(find.byKey(const Key('ambi-main-sidebar')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
