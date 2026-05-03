import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'application/ambilight_app_controller.dart';
import 'application/app_error_safety.dart';
import 'application/desktop_chrome_stub.dart'
    if (dart.library.io) 'application/desktop_chrome_io.dart' as desktop_chrome;
import 'features/screen_overlay/scan_overlay_controller.dart';
import 'features/screen_overlay/scan_overlay_painter.dart';
import 'services/ambilight_hotkey_service.dart';
import 'services/autostart_service.dart';
import 'ui/ambi_shell.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installAppErrorHandling();

  final bootLog = Logger('AppBoot');
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}');
  });

  try {
    await hotKeyManager.unregisterAll();
  } catch (e, st) {
    bootLog.warning('hotKeyManager.unregisterAll: $e', e, st);
  }

  final controller = AmbilightAppController();
  final hotkeys = AmbilightHotkeyService(controller);
  controller.onAfterConfigApplied = () async {
    try {
      await AutostartService.syncFromConfig(controller.config.globalSettings.autostart);
      await hotkeys.syncFromController();
    } catch (e, st) {
      bootLog.warning('onAfterConfigApplied: $e', e, st);
    }
  };

  try {
    await controller.load();
  } catch (e, st) {
    bootLog.warning('controller.load: $e', e, st);
  }

  try {
    await desktop_chrome.initDesktopShell(controller);
  } catch (e, st) {
    bootLog.warning('initDesktopShell: $e', e, st);
  }

  controller.startLoop();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider(create: (_) => ScanOverlayController()),
      ],
      child: const AmbiLightRoot(),
    ),
  );
}

class AmbiLightRoot extends StatelessWidget {
  const AmbiLightRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AmbilightAppController, ({String themeLow, bool uiAnimations})>(
      selector: (_, c) => (
        themeLow: c.config.globalSettings.theme.toLowerCase(),
        uiAnimations: c.config.globalSettings.uiAnimationsEnabled,
      ),
      builder: (context, shell, _) {
        final themeMode = shell.themeLow == 'light' ? ThemeMode.light : ThemeMode.dark;
        return Consumer<ScanOverlayController>(
          builder: (context, scan, _) {
            return MaterialApp(
              title: 'AmbiLight',
              themeMode: themeMode,
              theme: AmbiLightTheme.light(),
              darkTheme: AmbiLightTheme.dark(),
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                final userAnimOff = !shell.uiAnimations;
                final mqMerged = mq.copyWith(disableAnimations: mq.disableAnimations || userAnimOff);

                Widget inner = child ?? const SizedBox.shrink();
                if (!scan.visualizeEnabled) {
                  return MediaQuery(data: mqMerged, child: inner);
                }
                inner = Stack(
                  fit: StackFit.expand,
                  children: [
                    inner,
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final sz = Size(c.maxWidth, c.maxHeight);
                          final regions = scan.regionsForLayoutSize(sz);
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: ScanOverlayPainter(regions: regions),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              SafeArea(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Material(
                                    elevation: 6,
                                    color: const Color(0xE600162A),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 8),
                                          Icon(Icons.monitor_heart_outlined, color: Colors.cyanAccent.shade100, size: 22),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Náhled v měřítku monitoru · zavři až po doladění',
                                            style: TextStyle(
                                              color: Colors.blue.shade50,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Zavřít náhled',
                                            color: Colors.white,
                                            onPressed: () => unawaited(scan.hide()),
                                            icon: const Icon(Icons.close),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
                return MediaQuery(data: mqMerged, child: inner);
              },
              home: const AmbiShell(),
            );
          },
        );
      },
    );
  }
}
