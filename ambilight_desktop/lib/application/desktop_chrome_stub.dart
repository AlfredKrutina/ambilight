import 'ambilight_app_controller.dart';

/// Web / platformy bez `dart:io` — no-op.
Future<void> initWindowManagerEarly() async {}

/// Web / platformy bez `dart:io` — no-op.
Future<void> initDesktopShell(AmbilightAppController controller) async {}

Future<void> disposeDesktopShell() async {}
