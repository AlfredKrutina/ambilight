import 'ambilight_app_controller.dart';

/// Web / platformy bez `dart:io` — no-op.
Future<void> initWindowManagerEarly() async {}

/// Web / platformy bez `dart:io` — no-op.
Future<void> initDesktopShell(AmbilightAppController controller) async {}

Future<void> disposeDesktopShell() async {}

/// Po návratu aplikace z pozadí / probuzení OS — no-op na webu.
Future<void> onDesktopAppResumed() async {}

/// Tray menu ve stylu tématu — na webu se nevolá.
void registerTrayThemedPopup(void Function()? fn) {}

Future<void> trayQuitFromMenu() async {}

Future<void> trayOpenSettingsFromMenu(AmbilightAppController c) async {}

Future<void> trayPopNativeContextMenu() async {}
