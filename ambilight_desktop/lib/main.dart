import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'application/ambilight_app_controller.dart';
import 'core/models/config_models.dart'
    show normalizeAmbilightUiLanguage, normalizeAmbilightUiTheme;
import 'application/app_error_safety.dart';
import 'application/build_environment.dart';
import 'application/desktop_chrome_stub.dart'
    if (dart.library.io) 'application/desktop_chrome_io.dart' as desktop_chrome;
import 'features/screen_overlay/scan_overlay_controller.dart';
import 'features/screen_overlay/scan_overlay_painter.dart';
import 'features/spotify/spotify_service.dart';
import 'features/system_media/system_media_now_playing_service.dart';
import 'services/autostart_service.dart';
import 'ui/ambi_shell.dart';
import 'ui/app_navigator.dart';
import 'ui/app_theme.dart';
import 'ui/tray/tray_menu_host.dart';
import 'l10n/app_locale_bridge.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_resolution.dart';
import 'ui/onboarding/ambilight_onboarding_flow.dart';

/// Zóna z okamžiku [WidgetsFlutterBinding.ensureInitialized]. Po `await` v bootstrapu může být
/// [Zone.current] jiná (window_manager apod.) — [runApp] musí běžet v této zóně,
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
        reportAppFault(
          AppLocaleBridge.strings
              .bootstrapFailed(e.toString().split('\n').first),
        );
      }),
    );
  }, (Object error, StackTrace stack) {
    logZoneError(error, stack);
    reportAppFault(error.toString().split('\n').first);
  });
}

Future<void> _bootstrapApp() async {
  final bootLog = Logger('AppBoot');
  Logger.root.level = ambilightDetailedLogsEnabled ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((r) {
    debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}');
  });

  try {
    await desktop_chrome.initWindowManagerEarly();
  } catch (e, st) {
    bootLog.warning('initWindowManagerEarly: $e', e, st);
  }

  final controller = AmbilightAppController();
  controller.onAfterConfigApplied = () async {
    try {
      await AutostartService.syncFromConfig(
          controller.config.globalSettings.autostart);
    } catch (e, st) {
      bootLog.warning('onAfterConfigApplied: $e', e, st);
    }
  };

  try {
    await controller.load();
  } catch (e, st) {
    bootLog.warning('controller.load: $e', e, st);
    reportAppFault(
      AppLocaleBridge.strings.configLoadFailed(e.toString().split('\n').first),
    );
  }

  switch (normalizeAmbilightUiLanguage(
      controller.config.globalSettings.uiLanguage)) {
    case 'cs':
      AppLocaleBridge.locale = const Locale('cs');
      break;
    case 'en':
      AppLocaleBridge.locale = const Locale('en');
      break;
    default:
      AppLocaleBridge.syncFromPlatform();
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
      ChangeNotifierProvider<SpotifyService>.value(value: controller.spotify),
      ChangeNotifierProvider<SystemMediaNowPlayingService>.value(
        value: controller.systemMediaNowPlaying,
      ),
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
    return Selector<AmbilightAppController,
        ({String uiTheme, bool uiAnimations, String uiLang})>(
      selector: (_, c) => (
        uiTheme: normalizeAmbilightUiTheme(c.config.globalSettings.theme),
        uiAnimations: c.config.globalSettings.uiAnimationsEnabled,
        uiLang: c.config.globalSettings.uiLanguage,
      ),
      builder: (context, shell, _) {
        final appPalette = AmbiLightTheme.themeForKey(shell.uiTheme);
        return Consumer<ScanOverlayController>(
          builder: (context, scan, _) {
            return TrayMenuHost(
              child: MaterialApp(
                navigatorKey: ambiNavigatorKey,
                title: 'AmbiLight',
                locale: ambilightLocaleOverride(shell.uiLang),
                localeListResolutionCallback: (locales, supported) {
                  final o = ambilightLocaleOverride(shell.uiLang);
                  if (o != null) return o;
                  return ambilightResolvePlatformLocale(locales);
                },
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: appPalette,
                darkTheme: appPalette,
                themeMode: ThemeMode.light,
                builder: (context, child) {
                  AppLocaleBridge.syncFrom(context);
                  final mq = MediaQuery.of(context);
                  final userAnimOff = !shell.uiAnimations;
                  final mqMerged = mq.copyWith(
                      disableAnimations: mq.disableAnimations || userAnimOff);

                  Widget inner = child ?? const SizedBox.shrink();
                  if (scan.visualizeEnabled) {
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
                                    painter:
                                        ScanOverlayPainter(regions: regions),
                                    child: const SizedBox.expand(),
                                  );
                                } catch (e, st) {
                                  Logger('UI')
                                      .warning('scan overlay: $e', e, st);
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
                              label: AppLocalizations.of(context)
                                  .semanticsCloseScanOverlay,
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.grid_on_rounded,
                                          size: 18,
                                          color:
                                              Colors.lightBlueAccent.shade100,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          AppLocalizations.of(context)
                                              .scanZonesChip,
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
                  }
                  inner = Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      inner,
                      Selector<AmbilightAppController, bool>(
                        selector: (_, c) =>
                            !c.config.globalSettings.onboardingCompleted,
                        builder: (context, showOnboarding, _) {
                          if (!showOnboarding) return const SizedBox.shrink();
                          return const Positioned.fill(
                              child: AmbilightOnboardingLayer());
                        },
                      ),
                    ],
                  );
                  final mqChild = MediaQuery(data: mqMerged, child: inner);
                  return Selector<AmbilightAppController, bool>(
                    selector: (_, c) =>
                        c.config.globalSettings.onboardingCompleted,
                    builder: (context, onboardingDone, _) {
                      if (!onboardingDone) return mqChild;
                      return wrapWithAppFaultBanner(mqChild);
                    },
                  );
                },
                home: const AmbiShell(),
              ),
            );
          },
        );
      },
    );
  }
}
