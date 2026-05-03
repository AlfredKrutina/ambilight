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

/// Zóna z okamžiku [WidgetsFlutterBinding.ensureInitialized]. Po `await` v bootstrapu může být
/// [Zone.current] jiná (window_manager / hotkey apod.) — [runApp] musí běžet v této zóně,
/// jinak Flutter v debug režimu hlásí [BindingBase.debugCheckZone].
Zone? _ambiBindingZone;

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    _ambiBindingZone = Zone.current;
    installAppErrorHandling();
    unawaited(
      _bootstrapApp().catchError((Object e, StackTrace st) {
        final bootLog = Logger('AppBoot');
        bootLog.severe('Bootstrap fatální chyba: $e', e, st);
        reportAppFault('Aplikace se nespustila: ${e.toString().split('\n').first}');
      }),
    );
  }, (Object error, StackTrace stack) {
    logZoneError(error, stack);
    reportAppFault(error.toString().split('\n').first);
  });
}

Future<void> _bootstrapApp() async {
  final bootLog = Logger('AppBoot');
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}');
  });

  try {
    await desktop_chrome.initWindowManagerEarly();
  } catch (e, st) {
    bootLog.warning('initWindowManagerEarly: $e', e, st);
  }

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
    reportAppFault('Načtení konfigurace selhalo, používám výchozí: ${e.toString().split('\n').first}');
  }

  try {
    await desktop_chrome.initDesktopShell(controller);
  } catch (e, st) {
    bootLog.warning('initDesktopShell: $e', e, st);
  }

  controller.startLoop();

  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      ChangeNotifierProvider(create: (_) => ScanOverlayController()),
    ],
    child: const AmbiLightRoot(),
  );
  final z = _ambiBindingZone;
  if (z != null) {
    z.run(() => runApp(app));
  } else {
    runApp(app);
  }
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
                  return wrapWithAppFaultBanner(MediaQuery(data: mqMerged, child: inner));
                }
                // Hit-test: Stack testuje od posledního childa — chip musí zůstat poslední,
                // aby šel zavřít; před ním jen IgnorePointer přes celou plochu.
                inner = Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    inner,
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        ignoringSemantics: true,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            try {
                              final sz = Size(c.maxWidth, c.maxHeight);
                              final regions = scan.regionsForLayoutSize(sz);
                              return CustomPaint(
                                painter: ScanOverlayPainter(regions: regions),
                                child: const SizedBox.expand(),
                              );
                            } catch (e, st) {
                              Logger('UI').warning('scan overlay: $e', e, st);
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: SafeArea(
                        minimum: const EdgeInsets.all(6),
                        child: Semantics(
                          label: 'Zavřít náhled oblasti snímání',
                          button: true,
                          child: Material(
                            elevation: 10,
                            color: const Color(0xE6161820),
                            shadowColor: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => unawaited(scan.hide()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.grid_on_rounded,
                                      size: 18,
                                      color: Colors.lightBlueAccent.shade100,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Náhled zón',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade50,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.close_rounded,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
                return wrapWithAppFaultBanner(MediaQuery(data: mqMerged, child: inner));
              },
              home: const AmbiShell(),
            );
          },
        );
      },
    );
  }
}
