import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AmbiLight'**
  String get appTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageCzech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get languageCzech;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @measuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get measuring;

  /// No description provided for @findingCom.
  ///
  /// In en, this message translates to:
  /// **'Finding COM…'**
  String get findingCom;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @navOverviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Home — modes and device preview'**
  String get navOverviewTooltip;

  /// No description provided for @navDevicesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discovery, strips and calibration'**
  String get navDevicesTooltip;

  /// No description provided for @navSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Modes, integrations and config backup'**
  String get navSettingsTooltip;

  /// No description provided for @navAboutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Version and basics'**
  String get navAboutTooltip;

  /// No description provided for @navigationSection.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigationSection;

  /// No description provided for @outputOn.
  ///
  /// In en, this message translates to:
  /// **'Output on'**
  String get outputOn;

  /// No description provided for @outputOff.
  ///
  /// In en, this message translates to:
  /// **'Output off'**
  String get outputOff;

  /// No description provided for @tooltipColorsOn.
  ///
  /// In en, this message translates to:
  /// **'Stop sending colors to strips'**
  String get tooltipColorsOn;

  /// No description provided for @tooltipColorsOff.
  ///
  /// In en, this message translates to:
  /// **'Start sending colors to strips'**
  String get tooltipColorsOff;

  /// No description provided for @allOutputsOnline.
  ///
  /// In en, this message translates to:
  /// **'All output devices connected ({online}/{total}).'**
  String allOutputsOnline(Object online, Object total);

  /// No description provided for @someOutputsOffline.
  ///
  /// In en, this message translates to:
  /// **'Some outputs offline ({online}/{total}) — check USB or Wi‑Fi.'**
  String someOutputsOffline(Object online, Object total);

  /// No description provided for @footerNoOutputs.
  ///
  /// In en, this message translates to:
  /// **'No output devices (optional)'**
  String get footerNoOutputs;

  /// No description provided for @footerUsbOne.
  ///
  /// In en, this message translates to:
  /// **'USB'**
  String get footerUsbOne;

  /// No description provided for @footerUsbMany.
  ///
  /// In en, this message translates to:
  /// **'{count}× USB'**
  String footerUsbMany(Object count);

  /// No description provided for @footerWifiOne.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get footerWifiOne;

  /// No description provided for @footerWifiMany.
  ///
  /// In en, this message translates to:
  /// **'{count}× Wi‑Fi'**
  String footerWifiMany(Object count);

  /// No description provided for @pathCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get pathCopiedSnackbar;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AmbiLight Desktop — LED strips from Windows (USB and Wi‑Fi).'**
  String get aboutSubtitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Desktop Flutter client aligned with ESP32 firmware. In-app wizards cover strips, screen segments and calibration.'**
  String get aboutBody;

  /// No description provided for @aboutAppName.
  ///
  /// In en, this message translates to:
  /// **'AmbiLight Desktop'**
  String get aboutAppName;

  /// No description provided for @showOnboardingAgain.
  ///
  /// In en, this message translates to:
  /// **'Show onboarding again'**
  String get showOnboardingAgain;

  /// No description provided for @crashLogFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Crash / diagnostic log file:'**
  String get crashLogFileLabel;

  /// No description provided for @copyLogPath.
  ///
  /// In en, this message translates to:
  /// **'Copy log path'**
  String get copyLogPath;

  /// No description provided for @debugSection.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugSection;

  /// No description provided for @engineTickDebug.
  ///
  /// In en, this message translates to:
  /// **'Engine frame counter: {tick}\n(Updates on device connection changes, new screen frame, or ~4 s interval.)'**
  String engineTickDebug(Object tick);

  /// No description provided for @versionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load version: {error}'**
  String versionLoadError(Object error);

  /// No description provided for @versionLine.
  ///
  /// In en, this message translates to:
  /// **'Version: {version} ({build})'**
  String versionLine(Object version, Object build);

  /// No description provided for @buildLine.
  ///
  /// In en, this message translates to:
  /// **'Build: {mode} · channel: {channel}'**
  String buildLine(Object mode, Object channel);

  /// No description provided for @gitLine.
  ///
  /// In en, this message translates to:
  /// **'Git: {sha}'**
  String gitLine(Object sha);

  /// No description provided for @semanticsCloseScanOverlay.
  ///
  /// In en, this message translates to:
  /// **'Close capture region preview'**
  String get semanticsCloseScanOverlay;

  /// No description provided for @scanZonesChip.
  ///
  /// In en, this message translates to:
  /// **'Zone preview'**
  String get scanZonesChip;

  /// No description provided for @bootstrapFailed.
  ///
  /// In en, this message translates to:
  /// **'App failed to start: {detail}'**
  String bootstrapFailed(Object detail);

  /// No description provided for @configLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load settings, using defaults: {detail}'**
  String configLoadFailed(Object detail);

  /// No description provided for @faultUiError.
  ///
  /// In en, this message translates to:
  /// **'UI error: {detail}'**
  String faultUiError(Object detail);

  /// No description provided for @faultUncaughtAsync.
  ///
  /// In en, this message translates to:
  /// **'Uncaught error in async code.'**
  String get faultUncaughtAsync;

  /// No description provided for @errorWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Error rendering a widget. The app keeps running.\n\n'**
  String get errorWidgetTitle;

  /// No description provided for @closeBannerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get closeBannerTooltip;

  /// No description provided for @settingsDevicesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving device list failed: {detail}'**
  String settingsDevicesSaveFailed(Object detail);

  /// No description provided for @semanticsSelected.
  ///
  /// In en, this message translates to:
  /// **', selected'**
  String get semanticsSelected;

  /// No description provided for @homeOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get homeOverviewTitle;

  /// No description provided for @homeOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on output, pick a mode and check connectivity. Details live under Devices and Settings.'**
  String get homeOverviewSubtitle;

  /// No description provided for @homeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get homeModeTitle;

  /// No description provided for @homeModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a tile to change the active mode. The pencil opens Settings for that mode.'**
  String get homeModeSubtitle;

  /// No description provided for @homeIntegrationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get homeIntegrationsTitle;

  /// No description provided for @homeIntegrationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Music (Spotify OAuth plus optional OS player colors), Home Assistant and ESP firmware — edit each under Settings.'**
  String get homeIntegrationsSubtitle;

  /// No description provided for @homeDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get homeDevicesTitle;

  /// No description provided for @homeDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick status. Strip setup, discovery and networking are under Devices in the sidebar.'**
  String get homeDevicesSubtitle;

  /// No description provided for @homeDevicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No output devices yet — normal until you connect a strip.\n\nYou can still tune modes, presets and backups. To send colors, add a device under Devices (Discovery or manual).'**
  String get homeDevicesEmpty;

  /// No description provided for @modeLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get modeLightTitle;

  /// No description provided for @modeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Static effects, zones, breathing'**
  String get modeLightSubtitle;

  /// No description provided for @modeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get modeScreenTitle;

  /// No description provided for @modeScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ambilight from monitor capture'**
  String get modeScreenSubtitle;

  /// No description provided for @modeMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get modeMusicTitle;

  /// No description provided for @modeMusicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FFT, melody, colors'**
  String get modeMusicSubtitle;

  /// No description provided for @modePcHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'PC Health'**
  String get modePcHealthTitle;

  /// No description provided for @modePcHealthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Temps, load, visualization'**
  String get modePcHealthSubtitle;

  /// No description provided for @modeSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings for mode \"{mode}\"'**
  String modeSettingsTooltip(Object mode);

  /// No description provided for @homeLedOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'LED output'**
  String get homeLedOutputTitle;

  /// No description provided for @homeLedOutputOnBody.
  ///
  /// In en, this message translates to:
  /// **'Colors are sent to all active devices.'**
  String get homeLedOutputOnBody;

  /// No description provided for @homeLedOutputOffBody.
  ///
  /// In en, this message translates to:
  /// **'Off — strips receive black.'**
  String get homeLedOutputOffBody;

  /// No description provided for @homeServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get homeServiceTitle;

  /// No description provided for @homeBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Runs in background'**
  String get homeBackgroundTitle;

  /// No description provided for @homeBackgroundBody.
  ///
  /// In en, this message translates to:
  /// **'The app continuously prepares colors for strips. Status changes when you switch modes or connect devices.'**
  String get homeBackgroundBody;

  /// No description provided for @integrationSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get integrationSettingsButton;

  /// No description provided for @musicCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get musicCardTitle;

  /// No description provided for @spotifyConnected.
  ///
  /// In en, this message translates to:
  /// **'Spotify: connected'**
  String get spotifyConnected;

  /// No description provided for @spotifyDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Spotify: not connected'**
  String get spotifyDisconnected;

  /// No description provided for @spotifyHintNeedClientId.
  ///
  /// In en, this message translates to:
  /// **'Add Client ID under Settings → Spotify.'**
  String get spotifyHintNeedClientId;

  /// No description provided for @spotifyHintLogin.
  ///
  /// In en, this message translates to:
  /// **'“Sign in” opens the browser; on Windows you can also take colors from the OS media player (see help).'**
  String get spotifyHintLogin;

  /// No description provided for @spotifyOAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Spotify integration (OAuth)'**
  String get spotifyOAuthTitle;

  /// No description provided for @spotifyOAuthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enables account polling; disable to stop polling.'**
  String get spotifyOAuthSubtitle;

  /// No description provided for @spotifyAlbumColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Album colors via Spotify'**
  String get spotifyAlbumColorsTitle;

  /// No description provided for @spotifyAlbumColorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In Music mode, preferred over FFT when the API returns artwork.'**
  String get spotifyAlbumColorsSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @haCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant'**
  String get haCardTitle;

  /// No description provided for @haStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Integration disabled.'**
  String get haStatusOff;

  /// No description provided for @haStatusOnOk.
  ///
  /// In en, this message translates to:
  /// **'On · {count} lights in map.'**
  String haStatusOnOk(Object count);

  /// No description provided for @haStatusOnNeedUrl.
  ///
  /// In en, this message translates to:
  /// **'On — add URL and token in Settings.'**
  String get haStatusOnNeedUrl;

  /// No description provided for @haDetailOk.
  ///
  /// In en, this message translates to:
  /// **'REST API to Home Assistant; map engine colors to light.* entities.'**
  String get haDetailOk;

  /// No description provided for @haDetailNeedUrl.
  ///
  /// In en, this message translates to:
  /// **'First add your instance URL and long-lived token (HA user profile).'**
  String get haDetailNeedUrl;

  /// No description provided for @fwCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get fwCardTitle;

  /// No description provided for @fwManifestLabel.
  ///
  /// In en, this message translates to:
  /// **'Manifest (OTA)'**
  String get fwManifestLabel;

  /// No description provided for @fwManifestHint.
  ///
  /// In en, this message translates to:
  /// **'Download binaries, OTA command via UDP or flash via USB (esptool).'**
  String get fwManifestHint;

  /// No description provided for @kindUsb.
  ///
  /// In en, this message translates to:
  /// **'USB'**
  String get kindUsb;

  /// No description provided for @kindWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get kindWifi;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get deviceConnected;

  /// No description provided for @deviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'not connected'**
  String get deviceDisconnected;

  /// No description provided for @deviceLedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {count} LED'**
  String deviceLedSubtitle(Object kind, Object count);

  /// No description provided for @deviceStripStateLine.
  ///
  /// In en, this message translates to:
  /// **'{info} · {state}'**
  String deviceStripStateLine(Object info, Object state);

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @settingsRailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a topic on the left — no Apply button needed.'**
  String get settingsRailSubtitle;

  /// No description provided for @settingsPersistHint.
  ///
  /// In en, this message translates to:
  /// **'The engine updates immediately; disk save follows shortly after your last change. Screen/music presets are not changed.'**
  String get settingsPersistHint;

  /// No description provided for @settingsSidebarBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get settingsSidebarBasics;

  /// No description provided for @settingsSidebarModes.
  ///
  /// In en, this message translates to:
  /// **'Modes'**
  String get settingsSidebarModes;

  /// No description provided for @settingsSidebarIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get settingsSidebarIntegrations;

  /// No description provided for @tabGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get tabGlobal;

  /// No description provided for @tabDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get tabDevices;

  /// No description provided for @tabLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get tabLight;

  /// No description provided for @tabScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get tabScreen;

  /// No description provided for @tabMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get tabMusic;

  /// No description provided for @tabPcHealth.
  ///
  /// In en, this message translates to:
  /// **'PC Health'**
  String get tabPcHealth;

  /// No description provided for @tabSpotify.
  ///
  /// In en, this message translates to:
  /// **'Spotify'**
  String get tabSpotify;

  /// No description provided for @tabSmartHome.
  ///
  /// In en, this message translates to:
  /// **'Smart Home'**
  String get tabSmartHome;

  /// No description provided for @tabFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get tabFirmware;

  /// No description provided for @globalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get globalSectionTitle;

  /// No description provided for @globalSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Startup behavior, appearance and performance. Import/export below.'**
  String get globalSectionSubtitle;

  /// No description provided for @startModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Default mode on startup'**
  String get startModeLabel;

  /// No description provided for @startModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get startModeLight;

  /// No description provided for @startModeScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen (Ambilight)'**
  String get startModeScreen;

  /// No description provided for @startModeMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get startModeMusic;

  /// No description provided for @startModePcHealth.
  ///
  /// In en, this message translates to:
  /// **'PC Health'**
  String get startModePcHealth;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'App appearance'**
  String get themeLabel;

  /// No description provided for @themeHelper.
  ///
  /// In en, this message translates to:
  /// **'Dark blue = legacy default look. SnowRunner = neutral dark gray.'**
  String get themeHelper;

  /// No description provided for @themeSnowrunner.
  ///
  /// In en, this message translates to:
  /// **'Dark (SnowRunner)'**
  String get themeSnowrunner;

  /// No description provided for @themeDarkBlue.
  ///
  /// In en, this message translates to:
  /// **'Dark blue'**
  String get themeDarkBlue;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get themeCoffee;

  /// No description provided for @uiAnimationsTitle.
  ///
  /// In en, this message translates to:
  /// **'UI animations'**
  String get uiAnimationsTitle;

  /// No description provided for @uiAnimationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short transitions between sections. Disable when tweaking repeatedly; also respects system reduced motion.'**
  String get uiAnimationsSubtitle;

  /// No description provided for @performanceModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance mode'**
  String get performanceModeTitle;

  /// No description provided for @performanceModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When the app captures the monitor (Screen mode or Music with “monitor” colors), the main loop runs at 25 FPS; Spotify / PC Health intervals are longer and the USB queue is gentler. Light-only mode stays faster (~62 Hz). When performance mode is off, set the refresh rate below (60 / 120 / 240 FPS). “UI animations” only affects Material transitions.'**
  String get performanceModeSubtitle;

  /// No description provided for @screenRefreshRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Ambilight refresh rate'**
  String get screenRefreshRateTitle;

  /// No description provided for @screenRefreshRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Main loop when performance mode is off — applies to capture and LED output.'**
  String get screenRefreshRateSubtitle;

  /// No description provided for @screenRefreshRateDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off performance mode to change this (capture is fixed at 25 FPS while performance is on).'**
  String get screenRefreshRateDisabledHint;

  /// No description provided for @screenRefreshRateHz60.
  ///
  /// In en, this message translates to:
  /// **'60 FPS'**
  String get screenRefreshRateHz60;

  /// No description provided for @screenRefreshRateHz120.
  ///
  /// In en, this message translates to:
  /// **'120 FPS'**
  String get screenRefreshRateHz120;

  /// No description provided for @screenRefreshRateHz240.
  ///
  /// In en, this message translates to:
  /// **'240 FPS'**
  String get screenRefreshRateHz240;

  /// No description provided for @autostartTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch with Windows'**
  String get autostartTitle;

  /// No description provided for @autostartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the app after signing in.'**
  String get autostartSubtitle;

  /// No description provided for @trayDisableOutput.
  ///
  /// In en, this message translates to:
  /// **'Disable output'**
  String get trayDisableOutput;

  /// No description provided for @trayEnableOutput.
  ///
  /// In en, this message translates to:
  /// **'Enable output'**
  String get trayEnableOutput;

  /// No description provided for @trayModeLine.
  ///
  /// In en, this message translates to:
  /// **'Mode: {mode}'**
  String trayModeLine(Object mode);

  /// No description provided for @trayScreenPresetsSection.
  ///
  /// In en, this message translates to:
  /// **'Screen — presets'**
  String get trayScreenPresetsSection;

  /// No description provided for @trayMusicPresetsSection.
  ///
  /// In en, this message translates to:
  /// **'Music — presets'**
  String get trayMusicPresetsSection;

  /// No description provided for @trayMusicUnlockColors.
  ///
  /// In en, this message translates to:
  /// **'Unlock colors (music)'**
  String get trayMusicUnlockColors;

  /// No description provided for @trayMusicCancelLockPending.
  ///
  /// In en, this message translates to:
  /// **'Cancel color lock (waiting for frame)'**
  String get trayMusicCancelLockPending;

  /// No description provided for @trayMusicLockColorsShort.
  ///
  /// In en, this message translates to:
  /// **'Lock colors (music)'**
  String get trayMusicLockColorsShort;

  /// No description provided for @traySettingsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get traySettingsEllipsis;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @startMinimizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Start minimized'**
  String get startMinimizedTitle;

  /// No description provided for @captureMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen capture method (advanced)'**
  String get captureMethodLabel;

  /// No description provided for @captureMethodHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. mss, dxcam'**
  String get captureMethodHint;

  /// No description provided for @captureMethodHelper.
  ///
  /// In en, this message translates to:
  /// **'The desktop app uses the native capture plugin. On Windows, choose GDI vs DXGI under Settings → Screen.'**
  String get captureMethodHelper;

  /// No description provided for @captureMethodNativeMss.
  ///
  /// In en, this message translates to:
  /// **'Native capture (default · mss)'**
  String get captureMethodNativeMss;

  /// No description provided for @captureMethodCustomSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {name}'**
  String captureMethodCustomSaved(Object name);

  /// No description provided for @screenMonitorVirtualDesktopChoice.
  ///
  /// In en, this message translates to:
  /// **'0 · Virtual desktop (all monitors)'**
  String get screenMonitorVirtualDesktopChoice;

  /// No description provided for @screenMonitorRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh monitor list'**
  String get screenMonitorRefreshTooltip;

  /// No description provided for @screenMonitorListFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'Monitor list unavailable — values below are manual MSS indices. Tap refresh.'**
  String get screenMonitorListFallbackHint;

  /// No description provided for @onboardWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AmbiLight'**
  String get onboardWelcomeTitle;

  /// No description provided for @onboardWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'This app drives your LED strips from Windows — USB (serial) or network (UDP). ESP32 firmware stays compatible with older clients; this UI is clearer.'**
  String get onboardWelcomeBody;

  /// No description provided for @onboardHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get onboardHowTitle;

  /// No description provided for @onboardHowBody.
  ///
  /// In en, this message translates to:
  /// **'AmbiLight takes colors from the screen, microphone, PC sensors or static effects and sends RGB data to the controller. The top bar toggles output — when off, strips stop receiving new commands.'**
  String get onboardHowBody;

  /// No description provided for @onboardOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Output on / off'**
  String get onboardOutputTitle;

  /// No description provided for @onboardOutputBody.
  ///
  /// In en, this message translates to:
  /// **'The “Output on” button in the header is the main switch: turn it off to leave strips idle or while troubleshooting. Turn it on once devices and mode are set.'**
  String get onboardOutputBody;

  /// No description provided for @onboardModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Modes'**
  String get onboardModesTitle;

  /// No description provided for @onboardModesBody.
  ///
  /// In en, this message translates to:
  /// **'Light — static colors and effects. Screen — ambilight from monitor capture (segments and edge depth in Settings). Music — FFT and melody from mic or system. PC Health — temps and load visualization.'**
  String get onboardModesBody;

  /// No description provided for @onboardDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get onboardDevicesTitle;

  /// No description provided for @onboardDevicesBody.
  ///
  /// In en, this message translates to:
  /// **'On Devices you add strips, run discovery and set LED count, offset and default monitor. USB uses COM and baud; Wi‑Fi needs IP and UDP port (same as firmware).'**
  String get onboardDevicesBody;

  /// No description provided for @onboardScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen and zones'**
  String get onboardScreenTitle;

  /// No description provided for @onboardScreenBody.
  ///
  /// In en, this message translates to:
  /// **'Under Settings → Screen set edge depth, padding and per-strip segments. The capture-region preview overlay helps verify geometry.'**
  String get onboardScreenBody;

  /// No description provided for @onboardMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Music and Spotify'**
  String get onboardMusicTitle;

  /// No description provided for @onboardMusicBody.
  ///
  /// In en, this message translates to:
  /// **'Music can use microphone or sound card output. Spotify is optional — get Client ID from Spotify Developer; detailed steps are next to Spotify settings.'**
  String get onboardMusicBody;

  /// No description provided for @onboardSmartTitle.
  ///
  /// In en, this message translates to:
  /// **'PC Health and smart lights'**
  String get onboardSmartTitle;

  /// No description provided for @onboardSmartBody.
  ///
  /// In en, this message translates to:
  /// **'PC Health reads sensors (temps, load) and maps them to colors. Smart lights supports Home Assistant: after URL and token you can mirror colors to other lamps.'**
  String get onboardSmartBody;

  /// No description provided for @onboardFirmwareTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings and firmware'**
  String get onboardFirmwareTitle;

  /// No description provided for @onboardFirmwareBody.
  ///
  /// In en, this message translates to:
  /// **'Global settings include theme, performance mode, capture method and firmware manifest (OTA links). Export/import JSON — back up before experiments.'**
  String get onboardFirmwareBody;

  /// No description provided for @onboardReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'You are ready'**
  String get onboardReadyTitle;

  /// No description provided for @onboardReadyBody.
  ///
  /// In en, this message translates to:
  /// **'You can reopen this guide under About. Suggested flow: add device → verify output → pick Screen or Light → tune brightness in Settings.'**
  String get onboardReadyBody;

  /// No description provided for @onboardStartUsing.
  ///
  /// In en, this message translates to:
  /// **'Start using'**
  String get onboardStartUsing;

  /// No description provided for @onboardProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String onboardProgress(Object current, Object total);

  /// No description provided for @devicesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesPageTitle;

  /// No description provided for @devicesActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get devicesActionsTitle;

  /// No description provided for @discoveryWizardLabel.
  ///
  /// In en, this message translates to:
  /// **'Discovery — wizard'**
  String get discoveryWizardLabel;

  /// No description provided for @segmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get segmentsLabel;

  /// No description provided for @calibrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibrationLabel;

  /// No description provided for @screenPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen preset'**
  String get screenPresetLabel;

  /// No description provided for @addWifiManual.
  ///
  /// In en, this message translates to:
  /// **'Add Wi‑Fi manually'**
  String get addWifiManual;

  /// No description provided for @findAmbilightCom.
  ///
  /// In en, this message translates to:
  /// **'Find Ambilight (COM)'**
  String get findAmbilightCom;

  /// No description provided for @devicesIntro.
  ///
  /// In en, this message translates to:
  /// **'Manage strips: discovery, Wi‑Fi setup and calibration. Saving writes config and reconnects transports.'**
  String get devicesIntro;

  /// No description provided for @saveDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Save device'**
  String get saveDeviceTitle;

  /// No description provided for @invalidIp.
  ///
  /// In en, this message translates to:
  /// **'Invalid IP address.'**
  String get invalidIp;

  /// No description provided for @pongTimeout.
  ///
  /// In en, this message translates to:
  /// **'PONG timed out.'**
  String get pongTimeout;

  /// No description provided for @pongResult.
  ///
  /// In en, this message translates to:
  /// **'PONG: FW {version}, LED {leds}'**
  String pongResult(Object version, Object leds);

  /// No description provided for @verifyPong.
  ///
  /// In en, this message translates to:
  /// **'Verify PONG'**
  String get verifyPong;

  /// No description provided for @enterValidIpv4.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IPv4 address.'**
  String get enterValidIpv4;

  /// No description provided for @deviceSaved.
  ///
  /// In en, this message translates to:
  /// **'Device saved.'**
  String get deviceSaved;

  /// No description provided for @resetWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Wi‑Fi?'**
  String get resetWifiTitle;

  /// No description provided for @resetWifiBody.
  ///
  /// In en, this message translates to:
  /// **'Sends RESET_WIFI over UDP to the device. Use only when you know what you are doing.'**
  String get resetWifiBody;

  /// No description provided for @sendResetWifi.
  ///
  /// In en, this message translates to:
  /// **'Send RESET_WIFI'**
  String get sendResetWifi;

  /// No description provided for @resetWifiSent.
  ///
  /// In en, this message translates to:
  /// **'RESET_WIFI sent.'**
  String get resetWifiSent;

  /// No description provided for @resetWifiFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed.'**
  String get resetWifiFailed;

  /// No description provided for @removeFailed.
  ///
  /// In en, this message translates to:
  /// **'Remove failed: {error}'**
  String removeFailed(Object error);

  /// No description provided for @deviceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Device “{name}” removed.'**
  String deviceRemoved(Object name);

  /// No description provided for @pongMissing.
  ///
  /// In en, this message translates to:
  /// **'PONG did not arrive.'**
  String get pongMissing;

  /// No description provided for @firmwareFromPong.
  ///
  /// In en, this message translates to:
  /// **'Firmware (from PONG): {version}'**
  String firmwareFromPong(Object version);

  /// No description provided for @comScanHandshake.
  ///
  /// In en, this message translates to:
  /// **'Scanning COM with handshake 0xAA / 0xBB…'**
  String get comScanHandshake;

  /// No description provided for @comScanNoReply.
  ///
  /// In en, this message translates to:
  /// **'No port replied (Ambilight handshake).'**
  String get comScanNoReply;

  /// No description provided for @serialPortSet.
  ///
  /// In en, this message translates to:
  /// **'Serial port set: {port}'**
  String serialPortSet(Object port);

  /// No description provided for @firmwareLabel.
  ///
  /// In en, this message translates to:
  /// **'Firmware: {version}'**
  String firmwareLabel(Object version);

  /// No description provided for @discoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery (D9)'**
  String get discoveryTitle;

  /// No description provided for @discoveryRescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get discoveryRescan;

  /// No description provided for @discoveryScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get discoveryScanning;

  /// No description provided for @discoveryNoReply.
  ///
  /// In en, this message translates to:
  /// **'No device replied (UDP 4210).'**
  String get discoveryNoReply;

  /// No description provided for @discoveryAdded.
  ///
  /// In en, this message translates to:
  /// **'Added: {name}'**
  String discoveryAdded(Object name);

  /// No description provided for @discoveryAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get discoveryAdd;

  /// No description provided for @discoverySelectHint.
  ///
  /// In en, this message translates to:
  /// **'Scan the LAN on UDP 4210; identified devices appear below.'**
  String get discoverySelectHint;

  /// No description provided for @zoneEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Zone / segment editor'**
  String get zoneEditorTitle;

  /// No description provided for @zoneEditorAddSegment.
  ///
  /// In en, this message translates to:
  /// **'Add segment'**
  String get zoneEditorAddSegment;

  /// No description provided for @zoneEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} segments.'**
  String zoneEditorSaved(Object count);

  /// No description provided for @zoneEditorIntro.
  ///
  /// In en, this message translates to:
  /// **'Max LED index: {max}. Each segment: LED range, edge, monitor, scan depth, reverse, pixel mapping and music role.'**
  String zoneEditorIntro(Object max);

  /// No description provided for @zoneEditorSegmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Segment {index} · {edge} · LED {ledStart}–{ledEnd} · mon {monitor}'**
  String zoneEditorSegmentTitle(Object index, Object edge, Object ledStart,
      Object ledEnd, Object monitor);

  /// No description provided for @refDimsFromCapture.
  ///
  /// In en, this message translates to:
  /// **'Ref. dimensions from last capture'**
  String get refDimsFromCapture;

  /// No description provided for @dropdownAllDefault.
  ///
  /// In en, this message translates to:
  /// **'— all / default —'**
  String get dropdownAllDefault;

  /// No description provided for @guideMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Music & Spotify'**
  String get guideMusicTitle;

  /// No description provided for @guideBrowserFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser.'**
  String get guideBrowserFailed;

  /// No description provided for @guideNeedClientIdFirst.
  ///
  /// In en, this message translates to:
  /// **'First enter Client ID under Settings → Spotify (see button above).'**
  String get guideNeedClientIdFirst;

  /// No description provided for @guideClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get guideClose;

  /// No description provided for @guideOpenSpotifyDev.
  ///
  /// In en, this message translates to:
  /// **'Open Spotify Developer'**
  String get guideOpenSpotifyDev;

  /// No description provided for @guideSpotifyBrowserLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Spotify in browser'**
  String get guideSpotifyBrowserLogin;

  /// No description provided for @guideSectionSound.
  ///
  /// In en, this message translates to:
  /// **'1 · Mode and audio'**
  String get guideSectionSound;

  /// No description provided for @guideSectionAlbum.
  ///
  /// In en, this message translates to:
  /// **'2 · Album color'**
  String get guideSectionAlbum;

  /// No description provided for @guideSectionSpotify.
  ///
  /// In en, this message translates to:
  /// **'3 · Spotify'**
  String get guideSectionSpotify;

  /// No description provided for @guideSectionApple.
  ///
  /// In en, this message translates to:
  /// **'4 · Apple Music'**
  String get guideSectionApple;

  /// No description provided for @guideSectionTrouble.
  ///
  /// In en, this message translates to:
  /// **'When something fails'**
  String get guideSectionTrouble;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration backup'**
  String get backupTitle;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export JSON…'**
  String get backupExport;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import JSON…'**
  String get backupImport;

  /// No description provided for @backupExported.
  ///
  /// In en, this message translates to:
  /// **'Configuration exported.'**
  String get backupExported;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Configuration imported.'**
  String get backupImported;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid configuration file.'**
  String get backupInvalid;

  /// No description provided for @spotifyTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Spotify'**
  String get spotifyTabTitle;

  /// No description provided for @spotifyTabIntro.
  ///
  /// In en, this message translates to:
  /// **'OAuth tokens and album artwork colors. Help explains audio routing and artwork.'**
  String get spotifyTabIntro;

  /// No description provided for @spotifyHelpAlbum.
  ///
  /// In en, this message translates to:
  /// **'Help: music & artwork'**
  String get spotifyHelpAlbum;

  /// No description provided for @spotifyIntegrationEnabled.
  ///
  /// In en, this message translates to:
  /// **'Spotify integration enabled'**
  String get spotifyIntegrationEnabled;

  /// No description provided for @spotifyAlbumColors.
  ///
  /// In en, this message translates to:
  /// **'Album colors (Spotify API)'**
  String get spotifyAlbumColors;

  /// No description provided for @spotifyDeleteSecretDraft.
  ///
  /// In en, this message translates to:
  /// **'Remove client secret from draft'**
  String get spotifyDeleteSecretDraft;

  /// No description provided for @spotifyAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get spotifyAccessToken;

  /// No description provided for @spotifyRefreshToken.
  ///
  /// In en, this message translates to:
  /// **'Refresh token'**
  String get spotifyRefreshToken;

  /// No description provided for @spotifyTokenSetHidden.
  ///
  /// In en, this message translates to:
  /// **'Set (hidden)'**
  String get spotifyTokenSetHidden;

  /// No description provided for @spotifyTokenMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get spotifyTokenMissing;

  /// No description provided for @spotifyAppleOsTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Music / YouTube Music (OS)'**
  String get spotifyAppleOsTitle;

  /// No description provided for @spotifyAppleOsBody.
  ///
  /// In en, this message translates to:
  /// **'Uses dominant color from OS media thumbnails when Spotify does not provide a color.'**
  String get spotifyAppleOsBody;

  /// No description provided for @spotifyGsmtcOn.
  ///
  /// In en, this message translates to:
  /// **'Album color via OS media (GSMTC)'**
  String get spotifyGsmtcOn;

  /// No description provided for @spotifyGsmtcOff.
  ///
  /// In en, this message translates to:
  /// **'Album color via OS media (unavailable)'**
  String get spotifyGsmtcOff;

  /// No description provided for @spotifyGsmtcSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used in music mode when Spotify has no color or it is disabled.'**
  String get spotifyGsmtcSubtitle;

  /// No description provided for @spotifyDominantThumb.
  ///
  /// In en, this message translates to:
  /// **'Use dominant color from OS thumbnail'**
  String get spotifyDominantThumb;

  /// No description provided for @firmwareEspTitle.
  ///
  /// In en, this message translates to:
  /// **'ESP firmware'**
  String get firmwareEspTitle;

  /// No description provided for @firmwareEspIntro.
  ///
  /// In en, this message translates to:
  /// **'Manifest URL, downloads and flash/OTA actions. Requires compatible controller.'**
  String get firmwareEspIntro;

  /// No description provided for @firmwareManifestUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Manifest URL (GitHub Pages)'**
  String get firmwareManifestUrlLabel;

  /// No description provided for @firmwareManifestUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://alfredkrutina.github.io/ambilight/firmware/latest/'**
  String get firmwareManifestUrlHint;

  /// No description provided for @firmwareManifestHelper.
  ///
  /// In en, this message translates to:
  /// **'Inherited from global settings; without a file we append /manifest.json'**
  String get firmwareManifestHelper;

  /// No description provided for @firmwareLoadManifest.
  ///
  /// In en, this message translates to:
  /// **'Load manifest'**
  String get firmwareLoadManifest;

  /// No description provided for @firmwareDownloadBins.
  ///
  /// In en, this message translates to:
  /// **'Download binaries'**
  String get firmwareDownloadBins;

  /// No description provided for @firmwareVersionChip.
  ///
  /// In en, this message translates to:
  /// **'Version: {version} · chip: {chip}'**
  String firmwareVersionChip(Object version, Object chip);

  /// No description provided for @firmwarePartLine.
  ///
  /// In en, this message translates to:
  /// **'• {file} @ {offset}'**
  String firmwarePartLine(Object file, Object offset);

  /// No description provided for @firmwareOtaUrlLine.
  ///
  /// In en, this message translates to:
  /// **'OTA URL: {url}'**
  String firmwareOtaUrlLine(Object url);

  /// No description provided for @firmwareUsbFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'USB flash (COM)'**
  String get firmwareUsbFlashTitle;

  /// No description provided for @firmwareRefreshPorts.
  ///
  /// In en, this message translates to:
  /// **'Refresh port list'**
  String get firmwareRefreshPorts;

  /// No description provided for @firmwareSelectPortFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a serial port.'**
  String get firmwareSelectPortFirst;

  /// No description provided for @firmwarePickFirmwareFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick a firmware folder with manifest.json.'**
  String get firmwarePickFirmwareFolder;

  /// No description provided for @firmwareFlashEsptool.
  ///
  /// In en, this message translates to:
  /// **'Flash via esptool'**
  String get firmwareFlashEsptool;

  /// No description provided for @firmwareOtaUdpTitle.
  ///
  /// In en, this message translates to:
  /// **'OTA over Wi‑Fi (UDP)'**
  String get firmwareOtaUdpTitle;

  /// No description provided for @firmwareDeviceIp.
  ///
  /// In en, this message translates to:
  /// **'Device IP'**
  String get firmwareDeviceIp;

  /// No description provided for @firmwareUdpPort.
  ///
  /// In en, this message translates to:
  /// **'UDP port'**
  String get firmwareUdpPort;

  /// No description provided for @firmwareVerifyReachability.
  ///
  /// In en, this message translates to:
  /// **'Verify reachability (UDP PONG)'**
  String get firmwareVerifyReachability;

  /// No description provided for @firmwareSendOtaHttp.
  ///
  /// In en, this message translates to:
  /// **'Send OTA_HTTP'**
  String get firmwareSendOtaHttp;

  /// No description provided for @smartHaUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL (https://…:8123)'**
  String get smartHaUrlLabel;

  /// No description provided for @smartHaTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Long-lived access token'**
  String get smartHaTokenLabel;

  /// No description provided for @smartHaConfigureFirst.
  ///
  /// In en, this message translates to:
  /// **'First set Home Assistant URL and token.'**
  String get smartHaConfigureFirst;

  /// No description provided for @smartHaError.
  ///
  /// In en, this message translates to:
  /// **'HA: {error}'**
  String smartHaError(Object error);

  /// No description provided for @smartHaNoLights.
  ///
  /// In en, this message translates to:
  /// **'No light.* entities in HA.'**
  String get smartHaNoLights;

  /// No description provided for @smartAddLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Add light from Home Assistant'**
  String get smartAddLightTitle;

  /// No description provided for @smartIntegrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Home'**
  String get smartIntegrationTitle;

  /// No description provided for @smartIntegrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant and virtual room wave.'**
  String get smartIntegrationSubtitle;

  /// No description provided for @virtualRoomWaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Room wave'**
  String get virtualRoomWaveTitle;

  /// No description provided for @virtualRoomWaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Brightness modulation by distance from TV and capture time.'**
  String get virtualRoomWaveSubtitle;

  /// No description provided for @virtualRoomWaveStrength.
  ///
  /// In en, this message translates to:
  /// **'Wave strength: {pct} %'**
  String virtualRoomWaveStrength(Object pct);

  /// No description provided for @virtualRoomWaveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wave speed'**
  String get virtualRoomWaveSpeed;

  /// No description provided for @virtualRoomDistanceSens.
  ///
  /// In en, this message translates to:
  /// **'Distance sensitivity'**
  String get virtualRoomDistanceSens;

  /// No description provided for @virtualRoomFacing.
  ///
  /// In en, this message translates to:
  /// **'View angle offset toward TV: {deg}°'**
  String virtualRoomFacing(Object deg);

  /// No description provided for @scanOverlaySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan overlay (detail)'**
  String get scanOverlaySettingsTitle;

  /// No description provided for @scanOverlaySettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Preview capture zones on the monitor while tuning screen mode.'**
  String get scanOverlaySettingsIntro;

  /// No description provided for @scanOverlayPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Show zone preview while tuning'**
  String get scanOverlayPreviewTitle;

  /// No description provided for @scanOverlayPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short fullscreen overlay; does not affect capture.'**
  String get scanOverlayPreviewSubtitle;

  /// No description provided for @scanOverlayMonitorLabel.
  ///
  /// In en, this message translates to:
  /// **'Monitor (MSS index, same as capture)'**
  String get scanOverlayMonitorLabel;

  /// No description provided for @scanOverlayShowNow.
  ///
  /// In en, this message translates to:
  /// **'Show zone preview now (~1 s)'**
  String get scanOverlayShowNow;

  /// No description provided for @scanDepthPercentTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan depth % (per edge)'**
  String get scanDepthPercentTitle;

  /// No description provided for @scanPaddingPercentTitle.
  ///
  /// In en, this message translates to:
  /// **'Padding % (per edge)'**
  String get scanPaddingPercentTitle;

  /// No description provided for @scanRegionSchemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Region scheme (ratio of selected monitor)'**
  String get scanRegionSchemeTitle;

  /// No description provided for @scanLastFrameTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest frame (screen mode)'**
  String get scanLastFrameTitle;

  /// No description provided for @pcHealthSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'PC Health'**
  String get pcHealthSectionTitle;

  /// No description provided for @pcHealthSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sensors to colors. Add metrics and map them to zones.'**
  String get pcHealthSectionSubtitle;

  /// No description provided for @pcHealthEnabledTitle.
  ///
  /// In en, this message translates to:
  /// **'PC Health enabled'**
  String get pcHealthEnabledTitle;

  /// No description provided for @pcHealthEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disabled = black output in this mode.'**
  String get pcHealthEnabledSubtitle;

  /// No description provided for @pcHealthMetricNew.
  ///
  /// In en, this message translates to:
  /// **'New metric'**
  String get pcHealthMetricNew;

  /// No description provided for @pcHealthMetricEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit metric'**
  String get pcHealthMetricEdit;

  /// No description provided for @pcHealthMetricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get pcHealthMetricEnabled;

  /// No description provided for @pcHealthMetricName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pcHealthMetricName;

  /// No description provided for @pcHealthMetricKey.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get pcHealthMetricKey;

  /// No description provided for @pcHealthMetricMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get pcHealthMetricMin;

  /// No description provided for @pcHealthMetricMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get pcHealthMetricMax;

  /// No description provided for @pcHealthColorScale.
  ///
  /// In en, this message translates to:
  /// **'Color scale'**
  String get pcHealthColorScale;

  /// No description provided for @pcHealthBrightnessMode.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get pcHealthBrightnessMode;

  /// No description provided for @pcHealthBrightnessStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get pcHealthBrightnessStatic;

  /// No description provided for @pcHealthBrightnessDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic (by value)'**
  String get pcHealthBrightnessDynamic;

  /// No description provided for @pcHealthZonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Zones'**
  String get pcHealthZonesTitle;

  /// No description provided for @pcHealthLivePreview.
  ///
  /// In en, this message translates to:
  /// **'Live value preview'**
  String get pcHealthLivePreview;

  /// No description provided for @pcHealthMeasureNow.
  ///
  /// In en, this message translates to:
  /// **'Measure now'**
  String get pcHealthMeasureNow;

  /// No description provided for @pcHealthMetricsHeader.
  ///
  /// In en, this message translates to:
  /// **'Metrics ({count})'**
  String pcHealthMetricsHeader(Object count);

  /// No description provided for @pcHealthNoMetrics.
  ///
  /// In en, this message translates to:
  /// **'No metrics.'**
  String get pcHealthNoMetrics;

  /// No description provided for @pcHealthDefaultMetrics.
  ///
  /// In en, this message translates to:
  /// **'Defaults'**
  String get pcHealthDefaultMetrics;

  /// No description provided for @pcHealthColorStripPreview.
  ///
  /// In en, this message translates to:
  /// **'Color strip (preview)'**
  String get pcHealthColorStripPreview;

  /// No description provided for @pcHealthStagingHint.
  ///
  /// In en, this message translates to:
  /// **'[staging] PC Health: preview + metric editor'**
  String get pcHealthStagingHint;

  /// No description provided for @lightSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightSectionTitle;

  /// No description provided for @lightSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Static color, effects, zones and brightness.'**
  String get lightSectionSubtitle;

  /// No description provided for @screenSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get screenSectionTitle;

  /// No description provided for @screenSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Screen mode: colors from monitor edges. Calibration and segments can also be adjusted in Devices. The zone preview while tuning is only an in-app overlay (highlighted scan bands; the window is not moved).'**
  String get screenSectionSubtitle;

  /// No description provided for @musicSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Music mode'**
  String get musicSectionTitle;

  /// No description provided for @musicSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone, effects and Spotify integration.'**
  String get musicSectionSubtitle;

  /// No description provided for @devicesTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTabTitle;

  /// No description provided for @devicesTabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'USB and Wi‑Fi controllers, LED counts and default monitor.'**
  String get devicesTabSubtitle;

  /// No description provided for @usbSerialLabel.
  ///
  /// In en, this message translates to:
  /// **'USB / serial'**
  String get usbSerialLabel;

  /// No description provided for @udpWifiLabel.
  ///
  /// In en, this message translates to:
  /// **'UDP / Wi‑Fi'**
  String get udpWifiLabel;

  /// No description provided for @onboardingModesDemoLabel.
  ///
  /// In en, this message translates to:
  /// **'Modes'**
  String get onboardingModesDemoLabel;

  /// No description provided for @onboardingOutputDemoOn.
  ///
  /// In en, this message translates to:
  /// **'Output on'**
  String get onboardingOutputDemoOn;

  /// No description provided for @onboardingOutputDemoOff.
  ///
  /// In en, this message translates to:
  /// **'Output off'**
  String get onboardingOutputDemoOff;

  /// No description provided for @calibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibrationTitle;

  /// No description provided for @ledStripWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'LED strip wizard'**
  String get ledStripWizardTitle;

  /// No description provided for @configProfileWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Save screen preset'**
  String get configProfileWizardTitle;

  /// No description provided for @colorPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick color'**
  String get colorPickerTitle;

  /// No description provided for @colorPickerHex.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get colorPickerHex;

  /// No description provided for @devicesTabPlaceholder.
  ///
  /// In en, this message translates to:
  /// **''**
  String get devicesTabPlaceholder;

  /// No description provided for @onboardingReplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboardingReplayTitle;

  /// No description provided for @onboardingReplayBody.
  ///
  /// In en, this message translates to:
  /// **'Same guide as first launch — output, modes, devices and settings.'**
  String get onboardingReplayBody;

  /// No description provided for @replayOnboardingButton.
  ///
  /// In en, this message translates to:
  /// **'Run onboarding again'**
  String get replayOnboardingButton;

  /// No description provided for @devicesPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Network discovery, segment editing and calibration. Tap a device row for LED mapping.'**
  String get devicesPageSubtitle;

  /// No description provided for @fieldDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldDeviceName;

  /// No description provided for @fieldIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get fieldIpAddress;

  /// No description provided for @fieldUdpPort.
  ///
  /// In en, this message translates to:
  /// **'UDP port'**
  String get fieldUdpPort;

  /// No description provided for @fieldLedCount.
  ///
  /// In en, this message translates to:
  /// **'LED count'**
  String get fieldLedCount;

  /// No description provided for @removeDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Removing device failed: {detail}'**
  String removeDeviceFailed(Object detail);

  /// No description provided for @exportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String exportSavedTo(Object path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @importReadError.
  ///
  /// In en, this message translates to:
  /// **'Cannot read file (missing path).'**
  String get importReadError;

  /// No description provided for @importLoaded.
  ///
  /// In en, this message translates to:
  /// **'Configuration loaded and saved.'**
  String get importLoaded;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @backupIntroBody.
  ///
  /// In en, this message translates to:
  /// **'JSON compatible with the Python client (`config/default.json`). Import replaces current settings and persists them.'**
  String get backupIntroBody;

  /// No description provided for @exportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export AmbiLight configuration'**
  String get exportDialogTitle;

  /// No description provided for @devicesConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Configured devices'**
  String get devicesConfiguredTitle;

  /// No description provided for @devicesEmptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'None yet — you can set up modes and presets first. Add USB or Wi‑Fi above to drive a strip.'**
  String get devicesEmptyStateBody;

  /// No description provided for @diagnosticsComPorts.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics (COM ports)'**
  String get diagnosticsComPorts;

  /// No description provided for @noSerialPortsDetected.
  ///
  /// In en, this message translates to:
  /// **'No serial ports detected.'**
  String get noSerialPortsDetected;

  /// No description provided for @resetWifiContent.
  ///
  /// In en, this message translates to:
  /// **'Device \"{name}\" clears saved Wi‑Fi credentials on the controller and restarts. You must reconnect it to the network.'**
  String resetWifiContent(Object name);

  /// No description provided for @screenSettingsLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings layout'**
  String get screenSettingsLayoutTitle;

  /// No description provided for @screenModeSimpleLabel.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get screenModeSimpleLabel;

  /// No description provided for @screenModeAdvancedLabel.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get screenModeAdvancedLabel;

  /// No description provided for @screenModeHintAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Shows all fields including color curves, technical monitor index and per-edge controls in the preview section.'**
  String get screenModeHintAdvanced;

  /// No description provided for @screenModeHintSimple.
  ///
  /// In en, this message translates to:
  /// **'Monitor, brightness, smoothing and uniform scan depth / padding are enough. Detailed zones appear in the preview below.'**
  String get screenModeHintSimple;

  /// No description provided for @fieldMonitorIndexLabel.
  ///
  /// In en, this message translates to:
  /// **'Monitor (index)'**
  String get fieldMonitorIndexLabel;

  /// No description provided for @fieldMonitorSameAsCaptureLabel.
  ///
  /// In en, this message translates to:
  /// **'Monitor (same as capture)'**
  String get fieldMonitorSameAsCaptureLabel;

  /// No description provided for @screenScanDepthUniformPct.
  ///
  /// In en, this message translates to:
  /// **'Scan depth (uniform): {pct} %'**
  String screenScanDepthUniformPct(Object pct);

  /// No description provided for @screenPaddingUniformPct.
  ///
  /// In en, this message translates to:
  /// **'Padding (uniform): {pct} %'**
  String screenPaddingUniformPct(Object pct);

  /// No description provided for @screenCaptureCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen capture'**
  String get screenCaptureCardTitle;

  /// No description provided for @refreshDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Refresh diagnostics'**
  String get refreshDiagnostics;

  /// No description provided for @screenCapturePermissionOk.
  ///
  /// In en, this message translates to:
  /// **'Screen permission: OK â€” check Privacy settings if needed.'**
  String get screenCapturePermissionOk;

  /// No description provided for @screenCapturePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied or unavailable.'**
  String get screenCapturePermissionDenied;

  /// No description provided for @macosRequestScreenCapture.
  ///
  /// In en, this message translates to:
  /// **'macOS: request screen capture'**
  String get macosRequestScreenCapture;

  /// No description provided for @screenImageOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'Image and output'**
  String get screenImageOutputTitle;

  /// No description provided for @screenWindowsCaptureBackendLabel.
  ///
  /// In en, this message translates to:
  /// **'Windows capture'**
  String get screenWindowsCaptureBackendLabel;

  /// No description provided for @screenWindowsCaptureBackendHint.
  ///
  /// In en, this message translates to:
  /// **'CPU (GDI) often reduces cursor flicker; GPU (DXGI) uses Desktop Duplication on a specific monitor (not virtual desktop 0).'**
  String get screenWindowsCaptureBackendHint;

  /// No description provided for @screenWindowsCaptureBackendCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU (GDI)'**
  String get screenWindowsCaptureBackendCpu;

  /// No description provided for @screenWindowsCaptureBackendGpu.
  ///
  /// In en, this message translates to:
  /// **'GPU (DXGI)'**
  String get screenWindowsCaptureBackendGpu;

  /// No description provided for @screenBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'Brightness (screen): {v}'**
  String screenBrightnessValue(Object v);

  /// No description provided for @screenInterpolationMs.
  ///
  /// In en, this message translates to:
  /// **'Interpolation (ms): {v}'**
  String screenInterpolationMs(Object v);

  /// No description provided for @screenUniformRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Uniform capture region'**
  String get screenUniformRegionTitle;

  /// No description provided for @screenTechMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Technical monitor and uniform region'**
  String get screenTechMonitorTitle;

  /// No description provided for @fieldMonitorIndexMssLabel.
  ///
  /// In en, this message translates to:
  /// **'monitor_index (MSS, 0â€“32)'**
  String get fieldMonitorIndexMssLabel;

  /// No description provided for @screenColorsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Colors and scan (detail)'**
  String get screenColorsDetailTitle;

  /// No description provided for @screenGammaValue.
  ///
  /// In en, this message translates to:
  /// **'Gamma: {v}'**
  String screenGammaValue(Object v);

  /// No description provided for @screenSaturationBoostValue.
  ///
  /// In en, this message translates to:
  /// **'Saturation boost: {v}'**
  String screenSaturationBoostValue(Object v);

  /// No description provided for @screenUltraSaturation.
  ///
  /// In en, this message translates to:
  /// **'Ultra saturation'**
  String get screenUltraSaturation;

  /// No description provided for @screenUltraAmountValue.
  ///
  /// In en, this message translates to:
  /// **'Ultra amount: {v}'**
  String screenUltraAmountValue(Object v);

  /// No description provided for @screenMinBrightnessLed.
  ///
  /// In en, this message translates to:
  /// **'Min. brightness (LED): {v}'**
  String screenMinBrightnessLed(Object v);

  /// No description provided for @fieldScreenColorPreset.
  ///
  /// In en, this message translates to:
  /// **'Screen color preset'**
  String get fieldScreenColorPreset;

  /// No description provided for @helperScreenColorPreset.
  ///
  /// In en, this message translates to:
  /// **'Quick presets, built-in names and saved user_screen_presets'**
  String get helperScreenColorPreset;

  /// No description provided for @fieldActiveCalibrationProfile.
  ///
  /// In en, this message translates to:
  /// **'Active calibration profile'**
  String get fieldActiveCalibrationProfile;

  /// No description provided for @helperCalibrationProfileKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys from calibration_profiles in config'**
  String get helperCalibrationProfileKeys;

  /// No description provided for @stripMarkersTitle.
  ///
  /// In en, this message translates to:
  /// **'LED markers on strip'**
  String get stripMarkersTitle;

  /// No description provided for @stripMarkersBody.
  ///
  /// In en, this message translates to:
  /// **'Green LEDs at corners (like PyQt calibration). When indicating, max strip length is used for transport (USB up to 2000 LEDs with wide 0xFC framing, Wiâ€‘Fi per UDP), not the LED count from device settings â€” so high indices can light up. Turn off before saving or switching tabs.'**
  String get stripMarkersBody;

  /// No description provided for @markerTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get markerTopLeft;

  /// No description provided for @markerTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get markerTopRight;

  /// No description provided for @markerBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get markerBottomRight;

  /// No description provided for @markerBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get markerBottomLeft;

  /// No description provided for @markerOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off markers'**
  String get markerOff;

  /// No description provided for @segmentsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get segmentsTileTitle;

  /// No description provided for @segmentsZoneEditorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Count: {count} (zone editor A7)'**
  String segmentsZoneEditorSubtitle(Object count);

  /// No description provided for @lightZoneColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Zone color'**
  String get lightZoneColorTitle;

  /// No description provided for @lightPrimaryColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get lightPrimaryColorTitle;

  /// No description provided for @lightSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightSettingsHeader;

  /// No description provided for @lightSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Static colors and effects on the strip without screen capture. Picking a color may briefly preview on the strip.'**
  String get lightSettingsSubtitle;

  /// No description provided for @lightPrimaryColorTile.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get lightPrimaryColorTile;

  /// No description provided for @lightPrimaryColorRgbHint.
  ///
  /// In en, this message translates to:
  /// **'RGB({rgb}) · tap to pick like Home / Hue'**
  String lightPrimaryColorRgbHint(Object rgb);

  /// No description provided for @fieldEffect.
  ///
  /// In en, this message translates to:
  /// **'Effect'**
  String get fieldEffect;

  /// No description provided for @lightSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'Speed: {v}'**
  String lightSpeedValue(Object v);

  /// No description provided for @lightExtraValue.
  ///
  /// In en, this message translates to:
  /// **'Extra: {v}'**
  String lightExtraValue(Object v);

  /// No description provided for @lightBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'Brightness: {v}'**
  String lightBrightnessValue(Object v);

  /// No description provided for @lightHomekitTile.
  ///
  /// In en, this message translates to:
  /// **'HomeKit (FW / MQTT â€” do not send colors from PC)'**
  String get lightHomekitTile;

  /// No description provided for @lightHomekitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'homekit_enabled'**
  String get lightHomekitSubtitle;

  /// No description provided for @lightCustomZonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom zones'**
  String get lightCustomZonesTitle;

  /// No description provided for @lightAddZone.
  ///
  /// In en, this message translates to:
  /// **'Add zone'**
  String get lightAddZone;

  /// No description provided for @lightZoneDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Zone {n}'**
  String lightZoneDefaultName(Object n);

  /// No description provided for @fieldZoneName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldZoneName;

  /// No description provided for @fieldStartPercent.
  ///
  /// In en, this message translates to:
  /// **'Start %'**
  String get fieldStartPercent;

  /// No description provided for @fieldEndPercent.
  ///
  /// In en, this message translates to:
  /// **'End %'**
  String get fieldEndPercent;

  /// No description provided for @fieldZoneEffect.
  ///
  /// In en, this message translates to:
  /// **'Zone effect'**
  String get fieldZoneEffect;

  /// No description provided for @lightZoneSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'Zone speed: {v}'**
  String lightZoneSpeedValue(Object v);

  /// No description provided for @lightRemoveZone.
  ///
  /// In en, this message translates to:
  /// **'Remove zone'**
  String get lightRemoveZone;

  /// No description provided for @lightEffectStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get lightEffectStatic;

  /// No description provided for @lightEffectBreathing.
  ///
  /// In en, this message translates to:
  /// **'Breathing'**
  String get lightEffectBreathing;

  /// No description provided for @lightEffectRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get lightEffectRainbow;

  /// No description provided for @lightEffectChase.
  ///
  /// In en, this message translates to:
  /// **'Chase'**
  String get lightEffectChase;

  /// No description provided for @lightEffectCustomZones.
  ///
  /// In en, this message translates to:
  /// **'Custom zones'**
  String get lightEffectCustomZones;

  /// No description provided for @musicDeviceError.
  ///
  /// In en, this message translates to:
  /// **'Device: {error}'**
  String musicDeviceError(Object error);

  /// No description provided for @musicInputDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio input device'**
  String get musicInputDeviceLabel;

  /// No description provided for @musicDefaultInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Default (first suitable)'**
  String get musicDefaultInputDevice;

  /// No description provided for @musicRefreshDeviceListTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh device list'**
  String get musicRefreshDeviceListTooltip;

  /// No description provided for @musicSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get musicSettingsHeader;

  /// No description provided for @musicSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Audio source, effects and color preview. Music mode must be active on the overview for output to reach strips.'**
  String get musicSettingsSubtitle;

  /// No description provided for @musicGuideMusicArtwork.
  ///
  /// In en, this message translates to:
  /// **'Guide: music & artwork'**
  String get musicGuideMusicArtwork;

  /// No description provided for @musicLockPaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock color output to strip (music)'**
  String get musicLockPaletteTitle;

  /// No description provided for @musicLockPaletteFrozen.
  ///
  /// In en, this message translates to:
  /// **'Sending frozen palette (same as tray item).'**
  String get musicLockPaletteFrozen;

  /// No description provided for @musicLockPalettePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for next frame, then palette freezes.'**
  String get musicLockPalettePending;

  /// No description provided for @musicLockPaletteIdle.
  ///
  /// In en, this message translates to:
  /// **'Only meaningful in music mode; switching modes clears the lock.'**
  String get musicLockPaletteIdle;

  /// No description provided for @musicPreferMicTitle.
  ///
  /// In en, this message translates to:
  /// **'Prefer microphone'**
  String get musicPreferMicTitle;

  /// No description provided for @musicPreferMicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If no device is selected, a suitable input outside the speaker loop is preferred.'**
  String get musicPreferMicSubtitle;

  /// No description provided for @musicColorSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Color source'**
  String get musicColorSourceLabel;

  /// No description provided for @musicColorSourceFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed color'**
  String get musicColorSourceFixed;

  /// No description provided for @musicColorSourceSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum from audio'**
  String get musicColorSourceSpectrum;

  /// No description provided for @musicColorSourceMonitor.
  ///
  /// In en, this message translates to:
  /// **'Colors from monitor (Ambilight)'**
  String get musicColorSourceMonitor;

  /// No description provided for @musicFixedColorHeader.
  ///
  /// In en, this message translates to:
  /// **'Fixed color'**
  String get musicFixedColorHeader;

  /// No description provided for @musicFixedColorHint.
  ///
  /// In en, this message translates to:
  /// **'Pick color like Home / Hue â€” strip preview while adjusting.'**
  String get musicFixedColorHint;

  /// No description provided for @musicVisualEffectLabel.
  ///
  /// In en, this message translates to:
  /// **'Visual effect'**
  String get musicVisualEffectLabel;

  /// No description provided for @musicSmartMusicHint.
  ///
  /// In en, this message translates to:
  /// **'Smart Music: spectrum, beat and melody map to the strip in real time (local, no cloud).'**
  String get musicSmartMusicHint;

  /// No description provided for @musicBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'Brightness (music): {v}'**
  String musicBrightnessValue(Object v);

  /// No description provided for @musicBeatDetection.
  ///
  /// In en, this message translates to:
  /// **'Beat detection'**
  String get musicBeatDetection;

  /// No description provided for @musicBeatThreshold.
  ///
  /// In en, this message translates to:
  /// **'Beat threshold: {v}'**
  String musicBeatThreshold(Object v);

  /// No description provided for @musicOverallSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Overall sensitivity: {v}'**
  String musicOverallSensitivity(Object v);

  /// No description provided for @musicBandSensitivityCaption.
  ///
  /// In en, this message translates to:
  /// **'Band sensitivity (bass / mids / highs / overall)'**
  String get musicBandSensitivityCaption;

  /// No description provided for @musicBassValue.
  ///
  /// In en, this message translates to:
  /// **'Bass: {v}'**
  String musicBassValue(Object v);

  /// No description provided for @musicMidValue.
  ///
  /// In en, this message translates to:
  /// **'Mid: {v}'**
  String musicMidValue(Object v);

  /// No description provided for @musicHighValue.
  ///
  /// In en, this message translates to:
  /// **'High: {v}'**
  String musicHighValue(Object v);

  /// No description provided for @musicGlobalValue.
  ///
  /// In en, this message translates to:
  /// **'Global: {v}'**
  String musicGlobalValue(Object v);

  /// No description provided for @musicAutoGainTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic gain'**
  String get musicAutoGainTitle;

  /// No description provided for @musicAutoGainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Normalizes input volume to track dynamics.'**
  String get musicAutoGainSubtitle;

  /// No description provided for @musicAutoMidTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto mids'**
  String get musicAutoMidTitle;

  /// No description provided for @musicAutoHighTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto highs'**
  String get musicAutoHighTitle;

  /// No description provided for @musicSmoothingMs.
  ///
  /// In en, this message translates to:
  /// **'Temporal smoothing: {v} ms'**
  String musicSmoothingMs(Object v);

  /// No description provided for @musicMinBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'min_brightness (music): {v}'**
  String musicMinBrightnessValue(Object v);

  /// No description provided for @musicRotationSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'rotation_speed: {v}'**
  String musicRotationSpeedValue(Object v);

  /// No description provided for @musicActivePresetField.
  ///
  /// In en, this message translates to:
  /// **'active_preset'**
  String get musicActivePresetField;

  /// No description provided for @musicFixedColorPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixed color (music)'**
  String get musicFixedColorPickerTitle;

  /// No description provided for @musicEditColorButton.
  ///
  /// In en, this message translates to:
  /// **'Edit color'**
  String get musicEditColorButton;

  /// No description provided for @musicRgbTriple.
  ///
  /// In en, this message translates to:
  /// **'RGB {r} · {g} · {b}'**
  String musicRgbTriple(Object r, Object g, Object b);

  /// No description provided for @musicEffectSmartMusic.
  ///
  /// In en, this message translates to:
  /// **'Smart Music'**
  String get musicEffectSmartMusic;

  /// No description provided for @musicEffectEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get musicEffectEnergy;

  /// No description provided for @musicEffectSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get musicEffectSpectrum;

  /// No description provided for @musicEffectSpectrumRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotating spectrum'**
  String get musicEffectSpectrumRotate;

  /// No description provided for @musicEffectSpectrumPunchy.
  ///
  /// In en, this message translates to:
  /// **'Spectrum (punchy)'**
  String get musicEffectSpectrumPunchy;

  /// No description provided for @musicEffectStrobe.
  ///
  /// In en, this message translates to:
  /// **'Strobe'**
  String get musicEffectStrobe;

  /// No description provided for @musicEffectVuMeter.
  ///
  /// In en, this message translates to:
  /// **'VU meter'**
  String get musicEffectVuMeter;

  /// No description provided for @musicEffectVuSpectrum.
  ///
  /// In en, this message translates to:
  /// **'VU + spectrum'**
  String get musicEffectVuSpectrum;

  /// No description provided for @musicEffectPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get musicEffectPulse;

  /// No description provided for @musicEffectReactiveBass.
  ///
  /// In en, this message translates to:
  /// **'Reactive bass'**
  String get musicEffectReactiveBass;

  /// No description provided for @devicesTabHeader.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTabHeader;

  /// No description provided for @devicesTabIntro.
  ///
  /// In en, this message translates to:
  /// **'Name and LED count matter for control. IP and port are under Connection.'**
  String get devicesTabIntro;

  /// No description provided for @devicesTabEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'The list may stay empty â€” useful for preparing profiles only. Add at least one device to drive a strip.'**
  String get devicesTabEmptyHint;

  /// No description provided for @devicesAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get devicesAddDevice;

  /// No description provided for @devicesNewDeviceName.
  ///
  /// In en, this message translates to:
  /// **'New device'**
  String get devicesNewDeviceName;

  /// No description provided for @devicesUnnamedDevice.
  ///
  /// In en, this message translates to:
  /// **'Device {index}'**
  String devicesUnnamedDevice(Object index);

  /// No description provided for @devicesRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get devicesRemoveTooltip;

  /// No description provided for @fieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get fieldDisplayName;

  /// No description provided for @fieldConnectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get fieldConnectionType;

  /// No description provided for @devicesTypeUsb.
  ///
  /// In en, this message translates to:
  /// **'USB (serial)'**
  String get devicesTypeUsb;

  /// No description provided for @devicesTypeWifi.
  ///
  /// In en, this message translates to:
  /// **'Wiâ€‘Fi (UDP)'**
  String get devicesTypeWifi;

  /// No description provided for @devicesControlViaHa.
  ///
  /// In en, this message translates to:
  /// **'Control via Home Assistant'**
  String get devicesControlViaHa;

  /// No description provided for @devicesControlViaHaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PC will not send colors to this device.'**
  String get devicesControlViaHaSubtitle;

  /// No description provided for @devicesConnectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection and internal fields'**
  String get devicesConnectionSection;

  /// No description provided for @devicesWifiIpMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter controller IP address'**
  String get devicesWifiIpMissing;

  /// No description provided for @devicesWifiSaved.
  ///
  /// In en, this message translates to:
  /// **'Network details saved (edit in expansion)'**
  String get devicesWifiSaved;

  /// No description provided for @devicesSerialPortMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter COM port or pick from detected'**
  String get devicesSerialPortMissing;

  /// No description provided for @devicesPortSummary.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String devicesPortSummary(Object port);

  /// No description provided for @fieldComPort.
  ///
  /// In en, this message translates to:
  /// **'COM port'**
  String get fieldComPort;

  /// No description provided for @devicesComHintExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. {example}'**
  String devicesComHintExample(Object example);

  /// No description provided for @devicesComDetectedHelper.
  ///
  /// In en, this message translates to:
  /// **'Detected: {ports} â€” tap chips below to fill quickly'**
  String devicesComDetectedHelper(Object ports);

  /// No description provided for @fieldControllerIp.
  ///
  /// In en, this message translates to:
  /// **'Controller IP address'**
  String get fieldControllerIp;

  /// No description provided for @fieldInternalId.
  ///
  /// In en, this message translates to:
  /// **'Internal ID (links in config)'**
  String get fieldInternalId;

  /// No description provided for @helperInternalId.
  ///
  /// In en, this message translates to:
  /// **'Change only if JSON segments reference it.'**
  String get helperInternalId;

  /// No description provided for @scanOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan overlay (detail)'**
  String get scanOverlayTitle;

  /// No description provided for @scanOverlayIntro.
  ///
  /// In en, this message translates to:
  /// **'Highlighted bands show the actual capture region (center stays clear). Ratio matches the selected monitor; the app window does not go fullscreen. After releasing a slider the preview hides in {seconds} s. The button below shows a brief preview without moving sliders. The chip top-right or Escape closes it.'**
  String scanOverlayIntro(Object seconds);

  /// No description provided for @scanPreviewMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor preview while tuning'**
  String get scanPreviewMonitorTitle;

  /// No description provided for @scanPreviewOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get scanPreviewOff;

  /// No description provided for @scanPreviewVisible.
  ///
  /// In en, this message translates to:
  /// **'Preview visible; hides {seconds} s after release'**
  String scanPreviewVisible(Object seconds);

  /// No description provided for @scanPreviewOnDragging.
  ///
  /// In en, this message translates to:
  /// **'On â€” preview while dragging sliders (capture region)'**
  String get scanPreviewOnDragging;

  /// No description provided for @fieldMonitorMssSameAsCapture.
  ///
  /// In en, this message translates to:
  /// **'Monitor (MSS index, same as capture)'**
  String get fieldMonitorMssSameAsCapture;

  /// No description provided for @scanMonitorNoEnum.
  ///
  /// In en, this message translates to:
  /// **'Monitor {index} (OS enumeration unavailable)'**
  String scanMonitorNoEnum(Object index);

  /// No description provided for @scanPreviewNowButton.
  ///
  /// In en, this message translates to:
  /// **'Show zone preview now (~1 s)'**
  String get scanPreviewNowButton;

  /// No description provided for @scanDepthPerEdge.
  ///
  /// In en, this message translates to:
  /// **'Scan depth % (per-edge)'**
  String get scanDepthPerEdge;

  /// No description provided for @scanPaddingPerEdge.
  ///
  /// In en, this message translates to:
  /// **'Padding % (per-edge)'**
  String get scanPaddingPerEdge;

  /// No description provided for @scanEdgeTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get scanEdgeTop;

  /// No description provided for @scanEdgeBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get scanEdgeBottom;

  /// No description provided for @scanEdgeLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get scanEdgeLeft;

  /// No description provided for @scanEdgeRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get scanEdgeRight;

  /// No description provided for @scanPadLeft.
  ///
  /// In en, this message translates to:
  /// **'Left (padding)'**
  String get scanPadLeft;

  /// No description provided for @scanPadRight.
  ///
  /// In en, this message translates to:
  /// **'Right (padding)'**
  String get scanPadRight;

  /// No description provided for @scanPctLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}: {pct} %'**
  String scanPctLabel(Object label, Object pct);

  /// No description provided for @scanSimpleModeHint.
  ///
  /// In en, this message translates to:
  /// **'Set uniform depth and padding above under Capture region. Enable advanced screen mode for independent edges.'**
  String get scanSimpleModeHint;

  /// No description provided for @scanDiagramTitle.
  ///
  /// In en, this message translates to:
  /// **'Region diagram (selected monitor aspect)'**
  String get scanDiagramTitle;

  /// No description provided for @scanThumbNeedScreenMode.
  ///
  /// In en, this message translates to:
  /// **'Turn on screen mode for a live preview.'**
  String get scanThumbNeedScreenMode;

  /// No description provided for @scanThumbWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for frameâ€¦'**
  String get scanThumbWaiting;

  /// No description provided for @removeDeviceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove device?'**
  String get removeDeviceDialogTitle;

  /// No description provided for @removeDeviceDialogLastBody.
  ///
  /// In en, this message translates to:
  /// **'The device list may stay empty â€” that is fine. Without a device you cannot send colors to strips; you can still configure modes and presets. When hardware is connected, add it again here or via Discovery.'**
  String get removeDeviceDialogLastBody;

  /// No description provided for @removeDeviceDialogNamedBody.
  ///
  /// In en, this message translates to:
  /// **'Device \"{name}\" will be removed from configuration.'**
  String removeDeviceDialogNamedBody(Object name);

  /// No description provided for @deviceDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get deviceDetailsTitle;

  /// No description provided for @detailLineInternalId.
  ///
  /// In en, this message translates to:
  /// **'Internal ID: {id}'**
  String detailLineInternalId(Object id);

  /// No description provided for @detailLineType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String detailLineType(Object type);

  /// No description provided for @detailLineLedCount.
  ///
  /// In en, this message translates to:
  /// **'LED count: {count}'**
  String detailLineLedCount(Object count);

  /// No description provided for @detailLineIp.
  ///
  /// In en, this message translates to:
  /// **'IP: {ip}'**
  String detailLineIp(Object ip);

  /// No description provided for @detailLineUdpPort.
  ///
  /// In en, this message translates to:
  /// **'UDP port: {port}'**
  String detailLineUdpPort(Object port);

  /// No description provided for @detailLineSerialPort.
  ///
  /// In en, this message translates to:
  /// **'Port: {port}'**
  String detailLineSerialPort(Object port);

  /// No description provided for @detailLineFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware: {version}'**
  String detailLineFirmware(Object version);

  /// No description provided for @deviceConnectionOkLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get deviceConnectionOkLabel;

  /// No description provided for @deviceConnectionOfflineLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get deviceConnectionOfflineLabel;

  /// No description provided for @deviceHaControlledNote.
  ///
  /// In en, this message translates to:
  /// **'Controlled via Home Assistant â€” PC colors are not sent to this device.'**
  String get deviceHaControlledNote;

  /// No description provided for @menuMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get menuMoreActions;

  /// No description provided for @menuEditLedMapping.
  ///
  /// In en, this message translates to:
  /// **'Edit LED mapping'**
  String get menuEditLedMapping;

  /// No description provided for @menuTechnicalDetailsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Technical detailsâ€¦'**
  String get menuTechnicalDetailsEllipsis;

  /// No description provided for @menuIdentifyBlink.
  ///
  /// In en, this message translates to:
  /// **'Brief identify (blink)'**
  String get menuIdentifyBlink;

  /// No description provided for @menuRefreshFirmwareInfo.
  ///
  /// In en, this message translates to:
  /// **'Refresh firmware info'**
  String get menuRefreshFirmwareInfo;

  /// No description provided for @menuResetSavedWifi.
  ///
  /// In en, this message translates to:
  /// **'Reset saved Wi‑Fi on controller'**
  String get menuResetSavedWifi;

  /// No description provided for @menuRemoveDeviceEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Remove deviceâ€¦'**
  String get menuRemoveDeviceEllipsis;

  /// No description provided for @deviceSubtitleUsbLed.
  ///
  /// In en, this message translates to:
  /// **'USB · {count} LED'**
  String deviceSubtitleUsbLed(Object count);

  /// No description provided for @deviceSubtitleWifiLed.
  ///
  /// In en, this message translates to:
  /// **'Wiâ€‘Fi Â· {count} LED'**
  String deviceSubtitleWifiLed(Object count);

  /// No description provided for @onboardingUsbSerialLabel.
  ///
  /// In en, this message translates to:
  /// **'USB / serial'**
  String get onboardingUsbSerialLabel;

  /// No description provided for @onboardingUdpWifiLabel.
  ///
  /// In en, this message translates to:
  /// **'UDP / Wi‑Fi'**
  String get onboardingUdpWifiLabel;

  /// No description provided for @colorPickerHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get colorPickerHue;

  /// No description provided for @colorPickerSaturationValue.
  ///
  /// In en, this message translates to:
  /// **'Saturation & brightness'**
  String get colorPickerSaturationValue;

  /// No description provided for @colorPickerPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get colorPickerPresets;

  /// No description provided for @colorPickerDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorPickerDefaultTitle;

  /// No description provided for @guideMusicColorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Music & artwork colors'**
  String get guideMusicColorsTitle;

  /// No description provided for @guideCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get guideCloseTooltip;

  /// No description provided for @guideBrowserOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser.'**
  String get guideBrowserOpenFailed;

  /// No description provided for @guideNeedSpotifyClientId.
  ///
  /// In en, this message translates to:
  /// **'Enter Spotify Client ID in Settings → Spotify first (see button above).'**
  String get guideNeedSpotifyClientId;

  /// No description provided for @guideOpenSpotifyDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Open Spotify Developer'**
  String get guideOpenSpotifyDeveloper;

  /// No description provided for @guideSignInSpotifyBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Spotify in browser'**
  String get guideSignInSpotifyBrowser;

  /// No description provided for @guideIntroBlurb.
  ///
  /// In en, this message translates to:
  /// **'Briefly: in Music mode you get PC audio (effects) and optionally one color from track artwork.'**
  String get guideIntroBlurb;

  /// No description provided for @guideCard1Title.
  ///
  /// In en, this message translates to:
  /// **'1 · Mode and audio'**
  String get guideCard1Title;

  /// No description provided for @guideCard1Body.
  ///
  /// In en, this message translates to:
  /// **'On the overview enable the Music tile. In Settings → Music pick an input (Stereo Mix, microphone, …) and allow audio capture for AmbiLight in the OS.'**
  String get guideCard1Body;

  /// No description provided for @guideCard2Title.
  ///
  /// In en, this message translates to:
  /// **'2 · Artwork color'**
  String get guideCard2Title;

  /// No description provided for @guideCard2Body.
  ///
  /// In en, this message translates to:
  /// **'Either Spotify (below) or on Windows the “OS media” section in Settings → Spotify (Apple Music etc. via the OS). When artwork is enabled it takes priority over FFT effects.'**
  String get guideCard2Body;

  /// No description provided for @guideCard3Title.
  ///
  /// In en, this message translates to:
  /// **'3 · Spotify'**
  String get guideCard3Title;

  /// No description provided for @guideCard3Body.
  ///
  /// In en, this message translates to:
  /// **'You need a Client ID from the developer console and redirect http://127.0.0.1:8767/callback in the console. The button below opens the web — signing in then launches the browser like “Sign in” on the overview.'**
  String get guideCard3Body;

  /// No description provided for @guideCard4Title.
  ///
  /// In en, this message translates to:
  /// **'4 · Apple Music'**
  String get guideCard4Title;

  /// No description provided for @guideCard4Body.
  ///
  /// In en, this message translates to:
  /// **'There is no “sign in to Apple Music on the web” button here: Apple does not offer the same open OAuth as Spotify for this desktop app. On Windows enable OS media, play Apple Music (app) — color comes from the thumbnail the system shares when available.'**
  String get guideCard4Body;

  /// No description provided for @guideCard5Title.
  ///
  /// In en, this message translates to:
  /// **'When something fails'**
  String get guideCard5Title;

  /// No description provided for @guideCard5Body.
  ///
  /// In en, this message translates to:
  /// **'Spotify error after login → try Sign in again. No sound in effects → wrong input or permissions. Still only FFT → artwork integration off or nothing playing / no thumbnail.'**
  String get guideCard5Body;

  /// No description provided for @spotifySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Spotify'**
  String get spotifySectionTitle;

  /// No description provided for @spotifyOAuthNote.
  ///
  /// In en, this message translates to:
  /// **'OAuth tokens are stored on disk via ConfigRepository (sanitized); full token flow and Sign-in buttons are wired separately.'**
  String get spotifyOAuthNote;

  /// No description provided for @spotifyIntegrationEnabledTile.
  ///
  /// In en, this message translates to:
  /// **'Spotify integration enabled'**
  String get spotifyIntegrationEnabledTile;

  /// No description provided for @spotifyAlbumColorsApi.
  ///
  /// In en, this message translates to:
  /// **'Album colors (Spotify API)'**
  String get spotifyAlbumColorsApi;

  /// No description provided for @spotifyClientSecretHintStored.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep current; clear in settings or enter a new secret'**
  String get spotifyClientSecretHintStored;

  /// No description provided for @spotifyClientSecretHintOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get spotifyClientSecretHintOptional;

  /// No description provided for @spotifyClearSecretButton.
  ///
  /// In en, this message translates to:
  /// **'Clear client secret from draft'**
  String get spotifyClearSecretButton;

  /// No description provided for @spotifyAccessTokenTile.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get spotifyAccessTokenTile;

  /// No description provided for @spotifyRefreshTokenTile.
  ///
  /// In en, this message translates to:
  /// **'Refresh token'**
  String get spotifyRefreshTokenTile;

  /// No description provided for @spotifyTokenSet.
  ///
  /// In en, this message translates to:
  /// **'Set (hidden)'**
  String get spotifyTokenSet;

  /// No description provided for @spotifyOsMediaSection.
  ///
  /// In en, this message translates to:
  /// **'Apple Music / YouTube Music (OS)'**
  String get spotifyOsMediaSection;

  /// No description provided for @spotifyOsMediaBodyWin.
  ///
  /// In en, this message translates to:
  /// **'On Windows we read artwork from the current system player (GSMTC). It usually works for Apple Music and often YouTube Music in Edge or Chrome — depends on whether the player publishes a thumbnail. Official YouTube Music API is not used here.'**
  String get spotifyOsMediaBodyWin;

  /// No description provided for @spotifyOsMediaBodyOther.
  ///
  /// In en, this message translates to:
  /// **'On this OS only Spotify (OAuth) for now. GSMTC / system thumbnail is implemented for Windows.'**
  String get spotifyOsMediaBodyOther;

  /// No description provided for @spotifyOsAlbumColorGsmtc.
  ///
  /// In en, this message translates to:
  /// **'Album color via OS media (GSMTC)'**
  String get spotifyOsAlbumColorGsmtc;

  /// No description provided for @spotifyOsAlbumColorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Album color via OS media (unavailable)'**
  String get spotifyOsAlbumColorUnavailable;

  /// No description provided for @spotifyOsAlbumColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used in Music mode when Spotify does not provide a color or it is disabled.'**
  String get spotifyOsAlbumColorSubtitle;

  /// No description provided for @spotifyOsDominantThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Use dominant color from OS thumbnail'**
  String get spotifyOsDominantThumbnail;

  /// No description provided for @discWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery (Wi‑Fi)'**
  String get discWizardTitle;

  /// No description provided for @discDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get discDone;

  /// No description provided for @discScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get discScanning;

  /// No description provided for @discScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get discScanAgain;

  /// No description provided for @discIntro.
  ///
  /// In en, this message translates to:
  /// **'Broadcast DISCOVER_ESP32 on port 4210. Identify sends a short highlight on the strip.'**
  String get discIntro;

  /// No description provided for @discNoDevicesSnack.
  ///
  /// In en, this message translates to:
  /// **'No devices replied (UDP 4210).'**
  String get discNoDevicesSnack;

  /// No description provided for @discEmptyAfterScan.
  ///
  /// In en, this message translates to:
  /// **'No devices. Check network and firmware.'**
  String get discEmptyAfterScan;

  /// No description provided for @discAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Added: {name}'**
  String discAddedSnack(Object name);

  /// No description provided for @discResetWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Wi‑Fi?'**
  String get discResetWifiTitle;

  /// No description provided for @discResetWifiBody.
  ///
  /// In en, this message translates to:
  /// **'Device „{name}“ ({ip}) clears saved Wi‑Fi credentials and restarts. You must configure it again.'**
  String discResetWifiBody(Object name, Object ip);

  /// No description provided for @discSendResetWifi.
  ///
  /// In en, this message translates to:
  /// **'Send RESET_WIFI'**
  String get discSendResetWifi;

  /// No description provided for @discResetWifiSnackOk.
  ///
  /// In en, this message translates to:
  /// **'RESET_WIFI sent.'**
  String get discResetWifiSnackOk;

  /// No description provided for @discResetWifiSnackFail.
  ///
  /// In en, this message translates to:
  /// **'Send failed.'**
  String get discResetWifiSnackFail;

  /// No description provided for @discAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get discAddButton;

  /// No description provided for @discResetWifiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Wi‑Fi (clears saved credentials)'**
  String get discResetWifiTooltip;

  /// No description provided for @discIdentifyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Identify'**
  String get discIdentifyTooltip;

  /// No description provided for @zoneEditorSavedSegments.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} segments.'**
  String zoneEditorSavedSegments(Object count);

  /// No description provided for @zoneEditorEmpty.
  ///
  /// In en, this message translates to:
  /// **'No segments — use the LED wizard or “Add segment”.'**
  String get zoneEditorEmpty;

  /// No description provided for @zoneEditorSegmentLine.
  ///
  /// In en, this message translates to:
  /// **'Segment {index} · {edge} · LED {start}–{end} · mon {mon}'**
  String zoneEditorSegmentLine(
      Object index, Object edge, Object start, Object end, Object mon);

  /// No description provided for @zoneEditorDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get zoneEditorDeleteTooltip;

  /// No description provided for @zoneDeviceAllDefault.
  ///
  /// In en, this message translates to:
  /// **'— All / default —'**
  String get zoneDeviceAllDefault;

  /// No description provided for @zoneRefFromCapture.
  ///
  /// In en, this message translates to:
  /// **'Reference size from last frame'**
  String get zoneRefFromCapture;

  /// No description provided for @calibWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen calibration'**
  String get calibWizardTitle;

  /// No description provided for @calibWizardIntro.
  ///
  /// In en, this message translates to:
  /// **'Profiles live in `screen_mode.calibration_profiles` (JSON). Full curve wizard — future detail.'**
  String get calibWizardIntro;

  /// No description provided for @calibNoProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profiles in config.'**
  String get calibNoProfiles;

  /// No description provided for @calibActiveProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Active calibration profile'**
  String get calibActiveProfileLabel;

  /// No description provided for @calibSaveChoice.
  ///
  /// In en, this message translates to:
  /// **'Save selection'**
  String get calibSaveChoice;

  /// No description provided for @calibActiveProfileSnack.
  ///
  /// In en, this message translates to:
  /// **'Active profile: {name}'**
  String calibActiveProfileSnack(Object name);

  /// No description provided for @configProfileIntro.
  ///
  /// In en, this message translates to:
  /// **'Config file is handled by ConfigRepository; this stores the current screen mode snapshot into user_screen_presets.'**
  String get configProfileIntro;

  /// No description provided for @configProfileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get configProfileNameLabel;

  /// No description provided for @configProfileExistingTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing presets:'**
  String get configProfileExistingTitle;

  /// No description provided for @configProfileSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Preset „{name}“ saved to user_screen_presets.'**
  String configProfileSavedSnack(Object name);

  /// No description provided for @defaultPresetNameDraft.
  ///
  /// In en, this message translates to:
  /// **'My preset'**
  String get defaultPresetNameDraft;

  /// No description provided for @ledWizTitle.
  ///
  /// In en, this message translates to:
  /// **'LED wizard'**
  String get ledWizTitle;

  /// No description provided for @ledWizTitleWithDevice.
  ///
  /// In en, this message translates to:
  /// **'LED wizard — {name}'**
  String ledWizTitleWithDevice(Object name);

  /// No description provided for @ledWizMonitorLocked.
  ///
  /// In en, this message translates to:
  /// **'Monitor: {idx} (locked)'**
  String ledWizMonitorLocked(Object idx);

  /// No description provided for @ledWizAppendBadge.
  ///
  /// In en, this message translates to:
  /// **'Mode: append segments'**
  String get ledWizAppendBadge;

  /// No description provided for @ledWizStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} / {total}'**
  String ledWizStepProgress(Object current, Object total);

  /// No description provided for @ledWizAddDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a device first (Discovery or manually).'**
  String get ledWizAddDeviceFirst;

  /// No description provided for @ledWizDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get ledWizDeviceLabel;

  /// No description provided for @ledWizStripSides.
  ///
  /// In en, this message translates to:
  /// **'Strip sides'**
  String get ledWizStripSides;

  /// No description provided for @ledWizRefMonitorLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference monitor (native list)'**
  String get ledWizRefMonitorLabel;

  /// No description provided for @ledWizMonitorLine.
  ///
  /// In en, this message translates to:
  /// **'Monitor {idx} — {w}×{h}{suffix}'**
  String ledWizMonitorLine(Object idx, Object w, Object h, Object suffix);

  /// No description provided for @ledWizPrimarySuffix.
  ///
  /// In en, this message translates to:
  /// **' · primary'**
  String get ledWizPrimarySuffix;

  /// No description provided for @ledWizMonitorManualLabel.
  ///
  /// In en, this message translates to:
  /// **'Monitor index (MSS, manual — list unavailable)'**
  String get ledWizMonitorManualLabel;

  /// No description provided for @ledWizAppendSegmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Append to existing segments (multi-monitor)'**
  String get ledWizAppendSegmentsTitle;

  /// No description provided for @ledWizAppendSegmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Otherwise only this device’s segments are cleared.'**
  String get ledWizAppendSegmentsSubtitle;

  /// No description provided for @ledWizLedIndexSlider.
  ///
  /// In en, this message translates to:
  /// **'LED index {n}'**
  String ledWizLedIndexSlider(Object n);

  /// No description provided for @ledWizLedIndexRow.
  ///
  /// In en, this message translates to:
  /// **'LED index: {n}'**
  String ledWizLedIndexRow(Object n);

  /// No description provided for @ledWizFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Segments are computed from stored indices.'**
  String get ledWizFinishBody;

  /// No description provided for @ledWizStartCalibration.
  ///
  /// In en, this message translates to:
  /// **'Start calibration'**
  String get ledWizStartCalibration;

  /// No description provided for @ledWizPickOneSideSnack.
  ///
  /// In en, this message translates to:
  /// **'Select at least one side.'**
  String get ledWizPickOneSideSnack;

  /// No description provided for @ledWizSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get ledWizSummary;

  /// No description provided for @ledWizNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get ledWizNext;

  /// No description provided for @ledWizSaveClose.
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get ledWizSaveClose;

  /// No description provided for @ledWizSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Saved {segments} segments, LED {led}, monitor {mon}.'**
  String ledWizSavedSnack(Object segments, Object led, Object mon);

  /// No description provided for @ledWizConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get ledWizConfigTitle;

  /// No description provided for @ledWizConfigBody.
  ///
  /// In en, this message translates to:
  /// **'In Settings → Devices set LED count to at least an upper estimate (max 2000). Before calibration the app sends this count on USB. Then pick sides and monitor — move the green LED to each physical corner.'**
  String get ledWizConfigBody;

  /// No description provided for @ledWizFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get ledWizFinishTitle;

  /// No description provided for @ledWizLeftStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Left side — start'**
  String get ledWizLeftStartTitle;

  /// No description provided for @ledWizLeftStartBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the start of the left side (usually bottom).'**
  String get ledWizLeftStartBody;

  /// No description provided for @ledWizLeftEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Left side — end'**
  String get ledWizLeftEndTitle;

  /// No description provided for @ledWizLeftEndBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the end of the left side (usually top).'**
  String get ledWizLeftEndBody;

  /// No description provided for @ledWizTopStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Top side — start'**
  String get ledWizTopStartTitle;

  /// No description provided for @ledWizTopStartBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the start of the top edge (left).'**
  String get ledWizTopStartBody;

  /// No description provided for @ledWizTopEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Top side — end'**
  String get ledWizTopEndTitle;

  /// No description provided for @ledWizTopEndBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the end of the top edge (right).'**
  String get ledWizTopEndBody;

  /// No description provided for @ledWizRightStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Right side — start'**
  String get ledWizRightStartTitle;

  /// No description provided for @ledWizRightStartBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the start of the right side (usually top).'**
  String get ledWizRightStartBody;

  /// No description provided for @ledWizRightEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Right side — end'**
  String get ledWizRightEndTitle;

  /// No description provided for @ledWizRightEndBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the end of the right side (usually bottom).'**
  String get ledWizRightEndBody;

  /// No description provided for @ledWizBottomStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Bottom side — start'**
  String get ledWizBottomStartTitle;

  /// No description provided for @ledWizBottomStartBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the start of the bottom edge (right).'**
  String get ledWizBottomStartBody;

  /// No description provided for @ledWizBottomEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Bottom side — end'**
  String get ledWizBottomEndTitle;

  /// No description provided for @ledWizBottomEndBody.
  ///
  /// In en, this message translates to:
  /// **'Move the slider so the green LED is at the end of the bottom edge (left).'**
  String get ledWizBottomEndBody;

  /// No description provided for @fwTitle.
  ///
  /// In en, this message translates to:
  /// **'ESP firmware'**
  String get fwTitle;

  /// No description provided for @fwIntro.
  ///
  /// In en, this message translates to:
  /// **'CI can publish a manifest on GitHub Pages. Load the manifest, download .bin files and flash via USB (esptool in PATH) or run OTA over Wi‑Fi (UDP command). Switching to dual OTA layout needs one full USB flash first.'**
  String get fwIntro;

  /// No description provided for @fwManifestUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Manifest URL (GitHub Pages)'**
  String get fwManifestUrlLabel;

  /// No description provided for @fwManifestUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.github.io/ambilight/firmware/latest/'**
  String get fwManifestUrlHint;

  /// No description provided for @fwManifestHelper.
  ///
  /// In en, this message translates to:
  /// **'Default from global settings; /manifest.json is appended if missing.'**
  String get fwManifestHelper;

  /// No description provided for @fwLoadManifest.
  ///
  /// In en, this message translates to:
  /// **'Load manifest'**
  String get fwLoadManifest;

  /// No description provided for @fwDownloadBins.
  ///
  /// In en, this message translates to:
  /// **'Download binaries'**
  String get fwDownloadBins;

  /// No description provided for @fwVersionChipLine.
  ///
  /// In en, this message translates to:
  /// **'Version: {version} · chip: {chip}'**
  String fwVersionChipLine(Object version, Object chip);

  /// No description provided for @fwPartBullet.
  ///
  /// In en, this message translates to:
  /// **'• {file} @ {offset}'**
  String fwPartBullet(Object file, Object offset);

  /// No description provided for @fwOtaUrlLine.
  ///
  /// In en, this message translates to:
  /// **'OTA URL: {url}'**
  String fwOtaUrlLine(Object url);

  /// No description provided for @fwFlashUsbTitle.
  ///
  /// In en, this message translates to:
  /// **'Flash via USB (COM)'**
  String get fwFlashUsbTitle;

  /// No description provided for @fwRefreshPortsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh port list'**
  String get fwRefreshPortsTooltip;

  /// No description provided for @fwSerialPortsError.
  ///
  /// In en, this message translates to:
  /// **'Cannot load serial ports: {error}'**
  String fwSerialPortsError(Object error);

  /// No description provided for @fwSerialPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Serial port'**
  String get fwSerialPortLabel;

  /// No description provided for @fwNoComHintDriver.
  ///
  /// In en, this message translates to:
  /// **'Try Refresh or check permissions / driver.'**
  String get fwNoComHintDriver;

  /// No description provided for @fwNoComEmpty.
  ///
  /// In en, this message translates to:
  /// **'No COM — connect ESP USB'**
  String get fwNoComEmpty;

  /// No description provided for @fwFlashEsptool.
  ///
  /// In en, this message translates to:
  /// **'Flash with esptool'**
  String get fwFlashEsptool;

  /// No description provided for @fwOtaUdpTitle.
  ///
  /// In en, this message translates to:
  /// **'OTA over Wi‑Fi (UDP)'**
  String get fwOtaUdpTitle;

  /// No description provided for @fwDeviceIpLabel.
  ///
  /// In en, this message translates to:
  /// **'Device IP'**
  String get fwDeviceIpLabel;

  /// No description provided for @fwOtaHintNeedManifest.
  ///
  /// In en, this message translates to:
  /// **'Load the manifest first — OTA HTTPS URL is unknown without it.'**
  String get fwOtaHintNeedManifest;

  /// No description provided for @fwOtaHintMissingUrl.
  ///
  /// In en, this message translates to:
  /// **'Manifest has no OTA URL — add root ota_http_url or parts with app .bin URLs.'**
  String get fwOtaHintMissingUrl;

  /// No description provided for @fwOtaHintWillUse.
  ///
  /// In en, this message translates to:
  /// **'OTA will use: {url}'**
  String fwOtaHintWillUse(Object url);

  /// No description provided for @fwVerifyUdpPong.
  ///
  /// In en, this message translates to:
  /// **'Verify reachability (UDP PONG)'**
  String get fwVerifyUdpPong;

  /// No description provided for @fwSendOtaHttp.
  ///
  /// In en, this message translates to:
  /// **'Send OTA_HTTP'**
  String get fwSendOtaHttp;

  /// No description provided for @fwStatusCacheFail.
  ///
  /// In en, this message translates to:
  /// **'Cannot create cache (path_provider).'**
  String get fwStatusCacheFail;

  /// No description provided for @fwStatusEnterManifestUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter manifest URL (e.g. …/firmware/latest/).'**
  String get fwStatusEnterManifestUrl;

  /// No description provided for @fwStatusLoadingManifest.
  ///
  /// In en, this message translates to:
  /// **'Loading manifest…'**
  String get fwStatusLoadingManifest;

  /// No description provided for @fwStatusManifestOk.
  ///
  /// In en, this message translates to:
  /// **'Manifest OK — version {version}, chip {chip}, {count} files.'**
  String fwStatusManifestOk(Object version, Object chip, Object count);

  /// No description provided for @fwStatusManifestError.
  ///
  /// In en, this message translates to:
  /// **'Manifest error: {error}'**
  String fwStatusManifestError(Object error);

  /// No description provided for @fwStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get fwStatusDownloading;

  /// No description provided for @fwStatusDownloadedTo.
  ///
  /// In en, this message translates to:
  /// **'Downloaded to: {path}'**
  String fwStatusDownloadedTo(Object path);

  /// No description provided for @fwStatusDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String fwStatusDownloadFailed(Object error);

  /// No description provided for @fwStatusPickCom.
  ///
  /// In en, this message translates to:
  /// **'Pick a COM / serial port.'**
  String get fwStatusPickCom;

  /// No description provided for @fwStatusDownloadBinsFirst.
  ///
  /// In en, this message translates to:
  /// **'Download binaries first (button above).'**
  String get fwStatusDownloadBinsFirst;

  /// No description provided for @fwStatusFlashing.
  ///
  /// In en, this message translates to:
  /// **'Flashing via esptool… (stop app stream on the same COM)'**
  String get fwStatusFlashing;

  /// No description provided for @fwStatusFlashOk.
  ///
  /// In en, this message translates to:
  /// **'Flash OK.\\n{log}'**
  String fwStatusFlashOk(Object log);

  /// No description provided for @fwStatusFlashFail.
  ///
  /// In en, this message translates to:
  /// **'Flash failed.\\n{log}'**
  String fwStatusFlashFail(Object log);

  /// No description provided for @fwStatusException.
  ///
  /// In en, this message translates to:
  /// **'Exception: {error}'**
  String fwStatusException(Object error);

  /// No description provided for @fwStatusEnterIpProbe.
  ///
  /// In en, this message translates to:
  /// **'Enter device IP for probe (UDP PONG).'**
  String get fwStatusEnterIpProbe;

  /// No description provided for @fwStatusProbing.
  ///
  /// In en, this message translates to:
  /// **'Probing device (UDP, max 2 s)…'**
  String get fwStatusProbing;

  /// No description provided for @fwStatusProbeTimeout.
  ///
  /// In en, this message translates to:
  /// **'No reply in time — offline, wrong IP/port/firewall, or firmware without DISCOVER reply.'**
  String get fwStatusProbeTimeout;

  /// No description provided for @fwStatusProbeOnline.
  ///
  /// In en, this message translates to:
  /// **'Online: {name} · LED {led} · version {version} (ESP32_PONG).'**
  String fwStatusProbeOnline(Object name, Object led, Object version);

  /// No description provided for @fwStatusNoOtaUrl.
  ///
  /// In en, this message translates to:
  /// **'Manifest has no usable OTA URL (ota_http_url or derived parts[].url).'**
  String get fwStatusNoOtaUrl;

  /// No description provided for @fwStatusEnterIpEsp.
  ///
  /// In en, this message translates to:
  /// **'Enter ESP IP (Wi‑Fi).'**
  String get fwStatusEnterIpEsp;

  /// No description provided for @fwStatusSendingOta.
  ///
  /// In en, this message translates to:
  /// **'Sending OTA_HTTP to {ip}:{port}…'**
  String fwStatusSendingOta(Object ip, Object port);

  /// No description provided for @fwStatusOtaSent.
  ///
  /// In en, this message translates to:
  /// **'Command sent. ESP downloads firmware and reboots (check log / LEDs).'**
  String get fwStatusOtaSent;

  /// No description provided for @fwStatusUdpFailed.
  ///
  /// In en, this message translates to:
  /// **'UDP send failed.'**
  String get fwStatusUdpFailed;

  /// No description provided for @pcHealthHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'PC Health'**
  String get pcHealthHeaderTitle;

  /// No description provided for @pcHealthHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Strip edge colors from system metrics. Pick PC Health on the overview to drive outputs.'**
  String get pcHealthHeaderSubtitle;

  /// No description provided for @pcHealthHintWeb.
  ///
  /// In en, this message translates to:
  /// **'System metrics are not read on the web.'**
  String get pcHealthHintWeb;

  /// No description provided for @pcHealthHintMac.
  ///
  /// In en, this message translates to:
  /// **'macOS: CPU usage is estimated from load average / cores; disk from df; network from netstat byte totals. CPU temperature without tools like powermetrics may stay 0. NVIDIA GPU only if nvidia-smi is in PATH.'**
  String get pcHealthHintMac;

  /// No description provided for @pcHealthHintLinux.
  ///
  /// In en, this message translates to:
  /// **'Linux: disk_usage metric is not filled yet in the collector (0). Other values from /proc and thermal zones.'**
  String get pcHealthHintLinux;

  /// No description provided for @pcHealthHintWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows: disk uses first fixed disk; CPU temperature from ACPI WMI when available.'**
  String get pcHealthHintWindows;

  /// No description provided for @pcHealthEnabledTile.
  ///
  /// In en, this message translates to:
  /// **'PC Health enabled'**
  String get pcHealthEnabledTile;

  /// No description provided for @pcHealthUpdateInterval.
  ///
  /// In en, this message translates to:
  /// **'Update interval: {ms} ms'**
  String pcHealthUpdateInterval(Object ms);

  /// No description provided for @pcHealthGlobalBrightness.
  ///
  /// In en, this message translates to:
  /// **'Global brightness: {v}'**
  String pcHealthGlobalBrightness(Object v);

  /// No description provided for @pcHealthLivePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Live value preview'**
  String get pcHealthLivePreviewTitle;

  /// No description provided for @pcHealthNotTrackingHint.
  ///
  /// In en, this message translates to:
  /// **'Active mode is not PC Health — showing last sample or manual measurement.'**
  String get pcHealthNotTrackingHint;

  /// No description provided for @pcHealthMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get pcHealthMeasuring;

  /// No description provided for @pcHealthMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics ({count})'**
  String pcHealthMetricsTitle(Object count);

  /// No description provided for @pcHealthRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get pcHealthRestoreDefaults;

  /// No description provided for @pcHealthStagingDebug.
  ///
  /// In en, this message translates to:
  /// **'[staging] PC Health preview + metric editor'**
  String get pcHealthStagingDebug;

  /// No description provided for @pcHealthDialogNew.
  ///
  /// In en, this message translates to:
  /// **'New metric'**
  String get pcHealthDialogNew;

  /// No description provided for @pcHealthDialogEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit metric'**
  String get pcHealthDialogEdit;

  /// No description provided for @pcHealthTileEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get pcHealthTileEnabled;

  /// No description provided for @pcHealthFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pcHealthFieldName;

  /// No description provided for @pcHealthFieldMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get pcHealthFieldMetric;

  /// No description provided for @pcHealthFieldMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get pcHealthFieldMin;

  /// No description provided for @pcHealthFieldMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get pcHealthFieldMax;

  /// No description provided for @pcHealthFieldColorScale.
  ///
  /// In en, this message translates to:
  /// **'Color scale'**
  String get pcHealthFieldColorScale;

  /// No description provided for @pcHealthFieldBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get pcHealthFieldBrightness;

  /// No description provided for @pcHealthBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'Brightness: {v}'**
  String pcHealthBrightnessValue(Object v);

  /// No description provided for @pcHealthBrightnessMin.
  ///
  /// In en, this message translates to:
  /// **'Brightness min: {v}'**
  String pcHealthBrightnessMin(Object v);

  /// No description provided for @pcHealthBrightnessMax.
  ///
  /// In en, this message translates to:
  /// **'Brightness max: {v}'**
  String pcHealthBrightnessMax(Object v);

  /// No description provided for @pcHealthMetricFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get pcHealthMetricFallbackName;

  /// No description provided for @pcHealthEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get pcHealthEditTooltip;

  /// No description provided for @pcHealthDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pcHealthDeleteTooltip;

  /// No description provided for @pcMetricCpuUsage.
  ///
  /// In en, this message translates to:
  /// **'CPU usage'**
  String get pcMetricCpuUsage;

  /// No description provided for @pcMetricRamUsage.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get pcMetricRamUsage;

  /// No description provided for @pcMetricNetUsage.
  ///
  /// In en, this message translates to:
  /// **'Network (estimate)'**
  String get pcMetricNetUsage;

  /// No description provided for @pcMetricCpuTemp.
  ///
  /// In en, this message translates to:
  /// **'CPU temperature'**
  String get pcMetricCpuTemp;

  /// No description provided for @pcMetricGpuUsage.
  ///
  /// In en, this message translates to:
  /// **'GPU usage'**
  String get pcMetricGpuUsage;

  /// No description provided for @pcMetricGpuTemp.
  ///
  /// In en, this message translates to:
  /// **'GPU temperature'**
  String get pcMetricGpuTemp;

  /// No description provided for @pcMetricDiskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get pcMetricDiskUsage;

  /// No description provided for @smartHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart home'**
  String get smartHomeTitle;

  /// No description provided for @smartHomeIntro.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant: direct light.* control via REST. Apple Home (HomeKit): native on macOS. Google Home: no local public API — link via Home Assistant (below).'**
  String get smartHomeIntro;

  /// No description provided for @smartPushColorsTile.
  ///
  /// In en, this message translates to:
  /// **'Push colors to smart lights'**
  String get smartPushColorsTile;

  /// No description provided for @smartPushColorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable after configuring HA / HomeKit fixtures below.'**
  String get smartPushColorsSubtitle;

  /// No description provided for @smartHaSection.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant'**
  String get smartHaSection;

  /// No description provided for @smartHaTokenHelper.
  ///
  /// In en, this message translates to:
  /// **'Stored outside default.json (application support / ha_long_lived_token.txt).'**
  String get smartHaTokenHelper;

  /// No description provided for @smartHaTrustCertTile.
  ///
  /// In en, this message translates to:
  /// **'Trust custom HTTPS certificate'**
  String get smartHaTrustCertTile;

  /// No description provided for @smartHaTrustCertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only for local HA with self-signed certs.'**
  String get smartHaTrustCertSubtitle;

  /// No description provided for @smartTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get smartTestConnection;

  /// No description provided for @smartAddHaLight.
  ///
  /// In en, this message translates to:
  /// **'Add light from HA'**
  String get smartAddHaLight;

  /// No description provided for @smartHaFillUrlToken.
  ///
  /// In en, this message translates to:
  /// **'Fill URL and Home Assistant token first.'**
  String get smartHaFillUrlToken;

  /// No description provided for @smartHaPickLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Add light from Home Assistant'**
  String get smartHaPickLightTitle;

  /// No description provided for @smartMaxHzLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Hz per light'**
  String get smartMaxHzLabel;

  /// No description provided for @smartBrightnessCapLabel.
  ///
  /// In en, this message translates to:
  /// **'Brightness cap %'**
  String get smartBrightnessCapLabel;

  /// No description provided for @smartHomeKitSection.
  ///
  /// In en, this message translates to:
  /// **'Apple Home (HomeKit)'**
  String get smartHomeKitSection;

  /// No description provided for @smartHomeKitNonMac.
  ///
  /// In en, this message translates to:
  /// **'Native HomeKit is macOS-only. On Windows/Linux add lights to Home Assistant (HomeKit Device / Matter bridge) and control via HA above.'**
  String get smartHomeKitNonMac;

  /// No description provided for @smartHomeKitLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading HomeKit…'**
  String get smartHomeKitLoading;

  /// No description provided for @smartHomeKitEmpty.
  ///
  /// In en, this message translates to:
  /// **'No HomeKit lights (or missing permission).'**
  String get smartHomeKitEmpty;

  /// No description provided for @smartHomeKitCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lights.'**
  String smartHomeKitCount(Object count);

  /// No description provided for @smartRefreshHomeKit.
  ///
  /// In en, this message translates to:
  /// **'Refresh HomeKit light list'**
  String get smartRefreshHomeKit;

  /// No description provided for @smartGoogleSection.
  ///
  /// In en, this message translates to:
  /// **'Google Home'**
  String get smartGoogleSection;

  /// No description provided for @smartGoogleBody.
  ///
  /// In en, this message translates to:
  /// **'Google does not let desktop apps control Google Home lights directly. Reliable path: install Home Assistant, add Hue / Nest / … there and link HA with Google Assistant.'**
  String get smartGoogleBody;

  /// No description provided for @smartGoogleDocButton.
  ///
  /// In en, this message translates to:
  /// **'Docs: Google Assistant + HA'**
  String get smartGoogleDocButton;

  /// No description provided for @smartMyHaButton.
  ///
  /// In en, this message translates to:
  /// **'My Home Assistant'**
  String get smartMyHaButton;

  /// No description provided for @smartVirtualRoomSection.
  ///
  /// In en, this message translates to:
  /// **'Virtual room'**
  String get smartVirtualRoomSection;

  /// No description provided for @smartVirtualRoomIntro.
  ///
  /// In en, this message translates to:
  /// **'Place the TV, yourself and lights on the plan. The cone shows viewing direction (relative to the TV axis). Wave modulates brightness by distance from TV and time; HA/HomeKit still receive mapped colors each frame.'**
  String get smartVirtualRoomIntro;

  /// No description provided for @smartFixturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Configured lights ({count})'**
  String smartFixturesTitle(Object count);

  /// No description provided for @smartFixturesEmpty.
  ///
  /// In en, this message translates to:
  /// **'None yet — add from HA or HomeKit.'**
  String get smartFixturesEmpty;

  /// No description provided for @smartFixtureRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get smartFixtureRemoveTooltip;

  /// No description provided for @smartFixtureHaLine.
  ///
  /// In en, this message translates to:
  /// **'HA: {id}'**
  String smartFixtureHaLine(Object id);

  /// No description provided for @smartFixtureHkLine.
  ///
  /// In en, this message translates to:
  /// **'HomeKit: {id}'**
  String smartFixtureHkLine(Object id);

  /// No description provided for @smartBindingLabel.
  ///
  /// In en, this message translates to:
  /// **'Color mapping'**
  String get smartBindingLabel;

  /// No description provided for @smartBindingGlobalMean.
  ///
  /// In en, this message translates to:
  /// **'Average of all LEDs'**
  String get smartBindingGlobalMean;

  /// No description provided for @smartBindingLedRange.
  ///
  /// In en, this message translates to:
  /// **'LED range on device'**
  String get smartBindingLedRange;

  /// No description provided for @smartBindingScreenEdge.
  ///
  /// In en, this message translates to:
  /// **'Screen edge'**
  String get smartBindingScreenEdge;

  /// No description provided for @smartDeviceIdOptional.
  ///
  /// In en, this message translates to:
  /// **'device_id (empty = first device)'**
  String get smartDeviceIdOptional;

  /// No description provided for @smartEdgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get smartEdgeLabel;

  /// No description provided for @smartMonitorIndexBinding.
  ///
  /// In en, this message translates to:
  /// **'monitor_index (0=desktop, 1…)'**
  String get smartMonitorIndexBinding;

  /// No description provided for @smartHaStatusTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get smartHaStatusTesting;

  /// No description provided for @smartHaStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK: {msg}'**
  String smartHaStatusOk(Object msg);

  /// No description provided for @smartHaStatusErr.
  ///
  /// In en, this message translates to:
  /// **'Error: {msg}'**
  String smartHaStatusErr(Object msg);

  /// No description provided for @vrWaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Room wave'**
  String get vrWaveTitle;

  /// No description provided for @vrWaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Brightness modulation by distance from TV and frame time'**
  String get vrWaveSubtitle;

  /// No description provided for @vrWaveStrength.
  ///
  /// In en, this message translates to:
  /// **'Wave strength: {pct} %'**
  String vrWaveStrength(Object pct);

  /// No description provided for @vrWaveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wave speed'**
  String get vrWaveSpeed;

  /// No description provided for @vrDistanceSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Distance sensitivity'**
  String get vrDistanceSensitivity;

  /// No description provided for @vrViewingAngle.
  ///
  /// In en, this message translates to:
  /// **'Viewing angle offset toward TV: {deg}°'**
  String vrViewingAngle(Object deg);

  /// No description provided for @vrTooltipTv.
  ///
  /// In en, this message translates to:
  /// **'TV (drag)'**
  String get vrTooltipTv;

  /// No description provided for @vrTooltipYou.
  ///
  /// In en, this message translates to:
  /// **'You (drag)'**
  String get vrTooltipYou;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
