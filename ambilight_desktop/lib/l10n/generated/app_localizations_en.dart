// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AmbiLight';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageCzech => 'Czech';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get settings => 'Settings';

  @override
  String get help => 'Help';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get verify => 'Verify';

  @override
  String get refresh => 'Refresh';

  @override
  String get send => 'Send';

  @override
  String get remove => 'Remove';

  @override
  String get scanning => 'Scanning…';

  @override
  String get measuring => 'Measuring…';

  @override
  String get findingCom => 'Finding COM…';

  @override
  String get navOverview => 'Overview';

  @override
  String get navDevices => 'Devices';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAbout => 'About';

  @override
  String get navOverviewTooltip => 'Home — modes and device preview';

  @override
  String get navDevicesTooltip => 'Discovery, strips and calibration';

  @override
  String get navSettingsTooltip => 'Modes, integrations and config backup';

  @override
  String get navAboutTooltip => 'Version and basics';

  @override
  String get navigationSection => 'Navigation';

  @override
  String get outputOn => 'Output on';

  @override
  String get outputOff => 'Output off';

  @override
  String get tooltipColorsOn => 'Stop sending colors to strips';

  @override
  String get tooltipColorsOff => 'Start sending colors to strips';

  @override
  String allOutputsOnline(Object online, Object total) {
    return 'All output devices connected ($online/$total).';
  }

  @override
  String someOutputsOffline(Object online, Object total) {
    return 'Some outputs offline ($online/$total) — check USB or Wi‑Fi.';
  }

  @override
  String get footerNoOutputs => 'No output devices (optional)';

  @override
  String get footerUsbOne => 'USB';

  @override
  String footerUsbMany(Object count) {
    return '$count× USB';
  }

  @override
  String get footerWifiOne => 'Wi‑Fi';

  @override
  String footerWifiMany(Object count) {
    return '$count× Wi‑Fi';
  }

  @override
  String get pathCopiedSnackbar => 'Path copied to clipboard';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle =>
      'AmbiLight Desktop — LED strips from Windows (USB and Wi‑Fi).';

  @override
  String get aboutBody =>
      'Desktop Flutter client aligned with ESP32 firmware. In-app wizards cover strips, screen segments and calibration.';

  @override
  String get aboutAppName => 'AmbiLight Desktop';

  @override
  String get showOnboardingAgain => 'Show onboarding again';

  @override
  String get crashLogFileLabel => 'Crash / diagnostic log file:';

  @override
  String get copyLogPath => 'Copy log path';

  @override
  String get debugSection => 'Debug';

  @override
  String engineTickDebug(Object tick) {
    return 'Engine frame counter: $tick\n(Updates on device connection changes, new screen frame, or ~4 s interval.)';
  }

  @override
  String versionLoadError(Object error) {
    return 'Could not load version: $error';
  }

  @override
  String versionLine(Object version, Object build) {
    return 'Version: $version ($build)';
  }

  @override
  String buildLine(Object mode, Object channel) {
    return 'Build: $mode · channel: $channel';
  }

  @override
  String gitLine(Object sha) {
    return 'Git: $sha';
  }

  @override
  String get desktopUpdateSectionTitle => 'App updates';

  @override
  String get desktopUpdateSectionHint =>
      'Uses the release manifest over HTTPS. Downloaded packages are verified with SHA-256 before install.';

  @override
  String get desktopUpdateManifestUrlLabel => 'Manifest URL';

  @override
  String get desktopUpdateCheckButton => 'Check for updates';

  @override
  String get desktopUpdateUpToDate =>
      'You are on the latest version for this update channel.';

  @override
  String desktopUpdateCheckFailed(Object detail) {
    return 'Could not check for updates: $detail';
  }

  @override
  String desktopUpdateChannelMismatch(
      Object manifestChannel, Object appChannel) {
    return 'Release channel mismatch (manifest: $manifestChannel, this app: $appChannel).';
  }

  @override
  String desktopUpdateAvailable(Object remote, Object current) {
    return 'Update available: $remote (installed: $current).';
  }

  @override
  String get desktopUpdateReleaseNotesLink => 'Release notes';

  @override
  String get desktopUpdateDownloadAndInstall =>
      'Download and install (restart)';

  @override
  String get desktopUpdateOpenDownloadPage => 'Open download page';

  @override
  String get desktopUpdateConfirmTitle => 'Install update?';

  @override
  String get desktopUpdateConfirmBody =>
      'The app will quit; a short script will unpack the update, replace files in this install folder, and restart AmbiLight. Save other work first.';

  @override
  String get desktopUpdateConfirmInstall => 'Install';

  @override
  String get desktopUpdateDownloadFailed =>
      'Download or integrity check failed.';

  @override
  String get desktopUpdateUpdaterStartFailed => 'Could not start the updater.';

  @override
  String get desktopUpdateRestarting =>
      'Saving and exiting… the updater will restart the app.';

  @override
  String desktopUpdateErrorDetail(Object detail) {
    return '$detail';
  }

  @override
  String get semanticsCloseScanOverlay => 'Close capture region preview';

  @override
  String get scanZonesChip => 'Zone preview';

  @override
  String bootstrapFailed(Object detail) {
    return 'App failed to start: $detail';
  }

  @override
  String configLoadFailed(Object detail) {
    return 'Could not load settings, using defaults: $detail';
  }

  @override
  String get configFileUnusableBanner =>
      'The configuration file is damaged or incompatible — default settings are in use. Restore a backup under Import / export.';

  @override
  String configSaveFailed(Object detail) {
    return 'Could not save configuration: $detail';
  }

  @override
  String configInvalidJsonImport(Object detail) {
    return 'Invalid configuration JSON: $detail';
  }

  @override
  String configApplyFailed(Object detail) {
    return 'Could not apply settings: $detail';
  }

  @override
  String configAutosaveFailed(Object detail) {
    return 'Background save failed: $detail';
  }

  @override
  String get screenCaptureRepeatedFailureBanner =>
      'Screen capture keeps failing. Check privacy permissions (Windows: Privacy settings) and the monitor selection.';

  @override
  String faultUiError(Object detail) {
    return 'UI error: $detail';
  }

  @override
  String get faultUncaughtAsync => 'Uncaught error in async code.';

  @override
  String get errorWidgetTitle =>
      'Error rendering a widget. The app keeps running.\n\n';

  @override
  String get closeBannerTooltip => 'Dismiss';

  @override
  String settingsDevicesSaveFailed(Object detail) {
    return 'Saving device list failed: $detail';
  }

  @override
  String get semanticsSelected => ', selected';

  @override
  String get homeOverviewTitle => 'Overview';

  @override
  String get homeOverviewSubtitle =>
      'Turn on output, pick a mode and check connectivity. Details live under Devices and Settings.';

  @override
  String get homeModeTitle => 'Mode';

  @override
  String get homeModeSubtitle =>
      'Tap a tile to change the active mode. The pencil opens Settings for that mode.';

  @override
  String get homeIntegrationsTitle => 'Integrations';

  @override
  String get homeIntegrationsSubtitle =>
      'Music (Spotify OAuth plus optional OS player colors), Home Assistant and ESP firmware — edit each under Settings.';

  @override
  String get homeDevicesTitle => 'Devices';

  @override
  String get homeDevicesSubtitle =>
      'Quick status. Strip setup, discovery and networking are under Devices in the sidebar.';

  @override
  String get homeDevicesEmpty =>
      'No output devices yet — normal until you connect a strip.\n\nYou can still tune modes, presets and backups. To send colors, add a device under Devices (Discovery or manual).';

  @override
  String get modeLightTitle => 'Light';

  @override
  String get modeLightSubtitle => 'Static effects, zones, breathing';

  @override
  String get modeScreenTitle => 'Screen';

  @override
  String get modeScreenSubtitle => 'Ambilight from monitor capture';

  @override
  String get modeMusicTitle => 'Music';

  @override
  String get modeMusicSubtitle => 'FFT, melody, colors';

  @override
  String get modePcHealthTitle => 'PC Health';

  @override
  String get modePcHealthSubtitle => 'Temps, load, visualization';

  @override
  String modeSettingsTooltip(Object mode) {
    return 'Settings for mode \"$mode\"';
  }

  @override
  String get homeLedOutputTitle => 'LED output';

  @override
  String get homeLedOutputOnBody => 'Colors are sent to all active devices.';

  @override
  String get homeLedOutputOffBody => 'Off — strips receive black.';

  @override
  String get homeServiceTitle => 'Service';

  @override
  String get homeBackgroundTitle => 'Runs in background';

  @override
  String get homeBackgroundBody =>
      'The app continuously prepares colors for strips. Status changes when you switch modes or connect devices.';

  @override
  String get integrationSettingsButton => 'Settings';

  @override
  String get musicCardTitle => 'Music';

  @override
  String get spotifyConnected => 'Spotify: connected';

  @override
  String get spotifyDisconnected => 'Spotify: not connected';

  @override
  String get spotifyHintNeedClientId =>
      'Add Client ID under Settings → Spotify.';

  @override
  String get spotifyHintLogin =>
      '“Sign in” opens the browser; on Windows you can also take colors from the OS media player (see help).';

  @override
  String get spotifyOAuthTitle => 'Spotify integration (OAuth)';

  @override
  String get spotifyOAuthSubtitle =>
      'Enables account polling; disable to stop polling.';

  @override
  String get spotifyAlbumColorsTitle => 'Album colors via Spotify';

  @override
  String get spotifyAlbumColorsSubtitle =>
      'In Music mode, preferred over FFT when the API returns artwork.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get haCardTitle => 'Home Assistant';

  @override
  String get haStatusOff => 'Integration disabled.';

  @override
  String haStatusOnOk(Object count) {
    return 'On · $count lights in map.';
  }

  @override
  String get haStatusOnNeedUrl => 'On — add URL and token in Settings.';

  @override
  String get haDetailOk =>
      'REST API to Home Assistant; map engine colors to light.* entities.';

  @override
  String get haDetailNeedUrl =>
      'First add your instance URL and long-lived token (HA user profile).';

  @override
  String get fwCardTitle => 'Firmware';

  @override
  String get fwManifestLabel => 'Manifest (OTA)';

  @override
  String get fwManifestHint =>
      'Download binaries, OTA command via UDP or flash via USB (esptool).';

  @override
  String get kindUsb => 'USB';

  @override
  String get kindWifi => 'Wi‑Fi';

  @override
  String get deviceConnected => 'connected';

  @override
  String get deviceDisconnected => 'not connected';

  @override
  String deviceLedSubtitle(Object kind, Object count) {
    return '$kind · $count LED';
  }

  @override
  String deviceStripStateLine(Object info, Object state) {
    return '$info · $state';
  }

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsRailSubtitle =>
      'Pick a topic on the left — no Apply button needed.';

  @override
  String get settingsPersistHint =>
      'The engine updates immediately; disk save follows shortly after your last change. Screen/music presets are not changed.';

  @override
  String get settingsSidebarBasics => 'Basics';

  @override
  String get settingsSidebarModes => 'Modes';

  @override
  String get settingsSidebarIntegrations => 'Integrations';

  @override
  String get tabGlobal => 'Global';

  @override
  String get tabDevices => 'Devices';

  @override
  String get tabLight => 'Light';

  @override
  String get tabScreen => 'Screen';

  @override
  String get tabMusic => 'Music';

  @override
  String get tabPcHealth => 'PC Health';

  @override
  String get tabSpotify => 'Spotify';

  @override
  String get tabSmartHome => 'Smart Home';

  @override
  String get tabFirmware => 'Firmware';

  @override
  String get settingsTabGlobalTooltip =>
      'Language, theme, performance, default mode and JSON backup/import.';

  @override
  String get settingsTabLightTooltip =>
      'Static colors, effects, zones and timing for Light mode.';

  @override
  String get settingsTabScreenTooltip =>
      'Monitor capture, segments, gamma, interpolation and calibration.';

  @override
  String get settingsTabMusicTooltip =>
      'Audio input, FFT, melody, presets and mapping colors to the strip.';

  @override
  String get settingsTabPcHealthTooltip =>
      'PC sensors (CPU, GPU, …) mapped to output colors.';

  @override
  String get settingsTabSpotifyTooltip =>
      'Spotify OAuth and artwork colors — complements Music mode.';

  @override
  String get settingsTabSmartHomeTooltip =>
      'Home Assistant, HomeKit and virtual room for extra lamps.';

  @override
  String get settingsTabFirmwareTooltip =>
      'OTA manifest, USB flashing (esptool) and UDP commands.';

  @override
  String get settingsPageHelpTooltip =>
      'On wide windows use the left grouped menu; on narrow layouts tabs scroll horizontally. Changes save shortly after edits (see the banner hint above).';

  @override
  String get settingsPerformanceHelpTooltip =>
      'Caps monitor capture and related loops to reduce CPU. Light mode without capture stays faster.';

  @override
  String get musicLockPaletteHelpTooltip =>
      'Captures current strip colors and holds them — handy while tuning without continuous output.';

  @override
  String get screenUltraSatHelpTooltip =>
      'Aggressively boosts extremely saturated colors from capture — use with the sliders below.';

  @override
  String get smartPushColorsHelpTooltip =>
      'When on, the app sends the same mapped colors as the strip to HA / HomeKit fixtures per each lamp’s binding.';

  @override
  String get homeSectionModeHelpTooltip =>
      'The active mode chooses where colors come from (static effects / monitor / audio / sensors).';

  @override
  String get homeSectionIntegrationsHelpTooltip =>
      'Quick Spotify, Home Assistant and firmware manifest status — full controls live in Settings tabs.';

  @override
  String get homeSectionDevicesHelpTooltip =>
      'Connection status for known strips; add or edit devices on the Devices page.';

  @override
  String get modeLightTooltip =>
      'Colors and effects without monitor capture — zones from Settings.';

  @override
  String get modeScreenTooltip =>
      'Ambilight from the edges of the chosen monitor using segments and geometry.';

  @override
  String get modeMusicTooltip =>
      'FFT / melody from microphone or loopback; Spotify and OS media optional.';

  @override
  String get modePcHealthTooltip =>
      'PC temperatures and load mapped to colors via configured metrics.';

  @override
  String get integrationMusicCardTooltip =>
      'Spotify OAuth and overview settings affecting Music mode.';

  @override
  String get integrationHaCardTooltip =>
      'Mirror strip colors to Home Assistant or HomeKit (macOS) entities.';

  @override
  String get integrationFirmwareCardTooltip =>
      'Manifest URL for OTA and downloading binaries — does not flash by itself.';

  @override
  String get devicesActionDiscoverTooltip =>
      'UDP discovery finds ESP devices on the network and adds them.';

  @override
  String get devicesActionZonesTooltip =>
      'LED segment editor tied to monitor edges and LED order.';

  @override
  String get devicesActionSegGeomTooltip =>
      'Strip orientation around the screen before calibration.';

  @override
  String get devicesActionCalibrationTooltip =>
      'Wizard mapping physical corners to captured geometry.';

  @override
  String get devicesActionPresetTooltip =>
      'Save current screen settings as a named preset.';

  @override
  String get devicesActionAddWifiTooltip =>
      'Manually add a Wi‑Fi device by IP and UDP port.';

  @override
  String get devicesActionFindComTooltip =>
      'Scans serial ports for firmware handshake over USB.';

  @override
  String get globalSectionTitle => 'Global';

  @override
  String get globalSectionSubtitle =>
      'Startup behavior, appearance and performance. Import/export below.';

  @override
  String get startModeLabel => 'Default mode on startup';

  @override
  String get startModeLight => 'Light';

  @override
  String get startModeScreen => 'Screen (Ambilight)';

  @override
  String get startModeMusic => 'Music';

  @override
  String get startModePcHealth => 'PC Health';

  @override
  String get themeLabel => 'App appearance';

  @override
  String get themeHelper =>
      'Dark blue = legacy default look. SnowRunner = neutral dark gray.';

  @override
  String get themeSnowrunner => 'Dark (SnowRunner)';

  @override
  String get themeDarkBlue => 'Dark blue';

  @override
  String get themeLight => 'Light';

  @override
  String get themeCoffee => 'Coffee';

  @override
  String get uiAnimationsTitle => 'UI animations';

  @override
  String get uiAnimationsSubtitle =>
      'Short transitions between sections. Disable when tweaking repeatedly; also respects system reduced motion.';

  @override
  String get performanceModeTitle => 'Performance mode';

  @override
  String get performanceModeSubtitle =>
      'When the app captures the monitor (Screen mode or Music with “monitor” colors), the main loop is capped (default ~25 FPS); use “Performance screen tick” below to trade CPU for smoother LEDs. Spotify / PC Health intervals are longer and the USB queue is gentler. Light-only mode stays faster (~62 Hz). When performance mode is off, set the refresh rate below (60 / 120 / 240 FPS). “UI animations” only affects Material transitions.';

  @override
  String performanceScreenLoopPeriodLabel(Object ms) {
    return 'Performance screen tick (ms): $ms';
  }

  @override
  String get performanceScreenLoopPeriodHint =>
      'Lower ms = higher FPS to the strip and higher CPU use (16–40 ms). Applies only when performance mode is on and the app captures the monitor.';

  @override
  String get screenRefreshRateTitle => 'Ambilight refresh rate';

  @override
  String get screenRefreshRateSubtitle =>
      'Main loop when performance mode is off — applies to capture and LED output.';

  @override
  String get screenRefreshRateDisabledHint =>
      'Turn off performance mode to change this (while performance is on, tune “Performance screen tick” above instead).';

  @override
  String get screenRefreshRateHz60 => '60 FPS';

  @override
  String get screenRefreshRateHz120 => '120 FPS';

  @override
  String get screenRefreshRateHz240 => '240 FPS';

  @override
  String get autostartTitle => 'Launch with Windows';

  @override
  String get autostartSubtitle => 'Start the app after signing in.';

  @override
  String get trayDisableOutput => 'Disable output';

  @override
  String get trayEnableOutput => 'Enable output';

  @override
  String trayModeLine(Object mode) {
    return 'Mode: $mode';
  }

  @override
  String get trayScreenPresetsSection => 'Screen — presets';

  @override
  String get trayMusicPresetsSection => 'Music — presets';

  @override
  String get trayMusicUnlockColors => 'Unfreeze strip (music)';

  @override
  String get trayMusicCancelLockPending => 'Cancel freeze (waiting for frame)';

  @override
  String get trayMusicLockColorsShort => 'Freeze strip output (music)';

  @override
  String get traySettingsEllipsis => 'Settings…';

  @override
  String get trayQuit => 'Quit';

  @override
  String get startMinimizedTitle => 'Start minimized';

  @override
  String get captureMethodLabel => 'Screen capture method (advanced)';

  @override
  String get captureMethodHint => 'e.g. mss, dxcam';

  @override
  String get captureMethodHelper =>
      'The desktop app uses the native capture plugin. On Windows, choose GDI vs DXGI under Settings → Screen.';

  @override
  String get captureMethodNativeMss => 'Native capture (default · mss)';

  @override
  String captureMethodCustomSaved(Object name) {
    return 'Saved: $name';
  }

  @override
  String get screenMonitorVirtualDesktopChoice =>
      '0 · Virtual desktop (all monitors)';

  @override
  String get screenMonitorRefreshTooltip => 'Refresh monitor list';

  @override
  String get screenMonitorListFallbackHint =>
      'Monitor list unavailable — values below are manual MSS indices. Tap refresh.';

  @override
  String get onboardWelcomeTitle => 'Welcome to AmbiLight';

  @override
  String get onboardWelcomeBody =>
      'This app drives your LED strips from Windows — USB (serial) or network (UDP). ESP32 firmware stays compatible with older clients; this UI is clearer.';

  @override
  String get onboardHowTitle => 'How it works';

  @override
  String get onboardHowBody =>
      'AmbiLight takes colors from the screen, microphone, PC sensors or static effects and sends RGB data to the controller. The top bar toggles output — when off, strips stop receiving new commands.';

  @override
  String get onboardOutputTitle => 'Output on / off';

  @override
  String get onboardOutputBody =>
      'The “Output on” button in the header is the main switch: turn it off to leave strips idle or while troubleshooting. Turn it on once devices and mode are set.';

  @override
  String get onboardModesTitle => 'Modes';

  @override
  String get onboardModesBody =>
      'Light — static colors and effects. Screen — ambilight from monitor capture (segments and edge depth in Settings). Music — FFT and melody from mic or system. PC Health — temps and load visualization.';

  @override
  String get onboardDevicesTitle => 'Devices';

  @override
  String get onboardDevicesBody =>
      'On Devices you add strips, run discovery and set LED count, offset and default monitor. USB uses COM and baud; Wi‑Fi needs IP and UDP port (same as firmware).';

  @override
  String get onboardScreenTitle => 'Screen and zones';

  @override
  String get onboardScreenBody =>
      'Under Settings → Screen set edge depth, padding and per-strip segments. The capture-region preview overlay helps verify geometry.';

  @override
  String get onboardMusicTitle => 'Music and Spotify';

  @override
  String get onboardMusicBody =>
      'Music can use microphone or sound card output. Spotify is optional — get Client ID from Spotify Developer; detailed steps are next to Spotify settings.';

  @override
  String get onboardSmartTitle => 'PC Health and smart lights';

  @override
  String get onboardSmartBody =>
      'PC Health reads sensors (temps, load) and maps them to colors. Smart lights supports Home Assistant: after URL and token you can mirror colors to other lamps.';

  @override
  String get onboardFirmwareTitle => 'Settings and firmware';

  @override
  String get onboardFirmwareBody =>
      'Global settings include theme, performance mode, capture method and firmware manifest (OTA links). Export/import JSON — back up before experiments.';

  @override
  String get onboardReadyTitle => 'You are ready';

  @override
  String get onboardReadyBody =>
      'You can reopen this guide under About. Suggested flow: add device → verify output → pick Screen or Light → tune brightness in Settings.';

  @override
  String get onboardStartUsing => 'Start using';

  @override
  String onboardProgress(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get onboardIllustColorsToStrip => 'Colors flow to the strip';

  @override
  String get onboardIllustMiniBackup => 'JSON backup';

  @override
  String get onboardIllustCpuLabel => 'CPU';

  @override
  String get onboardIllustGpuLabel => 'GPU';

  @override
  String get onboardOutputTourOnlyHint =>
      'Preview only — the real Output switch lives in the app header.';

  @override
  String onboardSlideDotA11y(int n, int total) {
    return 'Go to step $n of $total';
  }

  @override
  String get onboardScreenHuePreview => 'Preview hue';

  @override
  String get onboardSettingsSnackModes =>
      'Pick the active mode on the overview (tiles at the top).';

  @override
  String get onboardSettingsSnackFirmware =>
      'Firmware downloads and OTA: Settings → Firmware.';

  @override
  String get onboardSettingsSnackBackup =>
      'Back up JSON: Settings → Global → Export.';

  @override
  String get onboardConnectivityUsbTap =>
      'USB: choose the COM port under Devices.';

  @override
  String get onboardConnectivityWifiTap =>
      'Wi‑Fi: set IP and UDP port under Devices (same as firmware).';

  @override
  String get onboardKeysHint => 'Keyboard: arrow keys for steps, Esc to skip.';

  @override
  String get devicesPageTitle => 'Devices';

  @override
  String get devicesActionsTitle => 'Actions';

  @override
  String get discoveryWizardLabel => 'Discovery — wizard';

  @override
  String get segmentsLabel => 'Segments';

  @override
  String get calibrationLabel => 'Calibration';

  @override
  String get screenPresetLabel => 'Screen preset';

  @override
  String get addWifiManual => 'Add Wi‑Fi manually';

  @override
  String get findAmbilightCom => 'Find Ambilight (COM)';

  @override
  String get devicesIntro =>
      'Manage strips: discovery, Wi‑Fi setup and calibration. Saving writes config and reconnects transports.';

  @override
  String get saveDeviceTitle => 'Save device';

  @override
  String get invalidIp => 'Invalid IP address.';

  @override
  String get pongTimeout => 'PONG timed out.';

  @override
  String pongResult(Object version, Object leds) {
    return 'PONG: FW $version, LED $leds';
  }

  @override
  String get verifyPong => 'Verify PONG';

  @override
  String get enterValidIpv4 => 'Enter a valid IPv4 address.';

  @override
  String get deviceSaved => 'Device saved.';

  @override
  String get resetWifiTitle => 'Reset Wi‑Fi?';

  @override
  String get resetWifiBody =>
      'Sends RESET_WIFI over UDP to the device. Use only when you know what you are doing.';

  @override
  String get sendResetWifi => 'Send RESET_WIFI';

  @override
  String get resetWifiSent => 'RESET_WIFI sent.';

  @override
  String get resetWifiFailed => 'Send failed.';

  @override
  String removeFailed(Object error) {
    return 'Remove failed: $error';
  }

  @override
  String deviceRemoved(Object name) {
    return 'Device “$name” removed.';
  }

  @override
  String get pongMissing => 'PONG did not arrive.';

  @override
  String firmwareFromPong(Object version) {
    return 'Firmware (from PONG): $version';
  }

  @override
  String get comScanHandshake => 'Scanning COM with handshake 0xAA / 0xBB…';

  @override
  String get comScanNoReply => 'No port replied (Ambilight handshake).';

  @override
  String serialPortSet(Object port) {
    return 'Serial port set: $port';
  }

  @override
  String comScanUsbDeviceDefaultName(Object port) {
    return 'USB ($port)';
  }

  @override
  String comScanUsbDeviceAdded(Object port) {
    return 'USB device added on $port. You can rename it in the list.';
  }

  @override
  String firmwareLabel(Object version) {
    return 'Firmware: $version';
  }

  @override
  String get discoveryTitle => 'Discovery (D9)';

  @override
  String get discoveryRescan => 'Scan again';

  @override
  String get discoveryScanning => 'Scanning…';

  @override
  String get discoveryNoReply => 'No device replied (UDP 4210).';

  @override
  String discoveryAdded(Object name) {
    return 'Added: $name';
  }

  @override
  String get discoveryAdd => 'Add';

  @override
  String get discoverySelectHint =>
      'Scan the LAN on UDP 4210; identified devices appear below.';

  @override
  String get zoneEditorTitle => 'Zone / segment editor';

  @override
  String get zoneEditorAddSegment => 'Add segment';

  @override
  String zoneEditorSaved(Object count) {
    return 'Saved $count segments.';
  }

  @override
  String zoneEditorIntro(Object max) {
    return 'Max LED index: $max. Each segment: LED range, edge, monitor, scan depth, reverse, pixel mapping and music role.';
  }

  @override
  String zoneEditorSegmentTitle(Object index, Object edge, Object ledStart,
      Object ledEnd, Object monitor) {
    return 'Segment $index · $edge · LED $ledStart–$ledEnd · mon $monitor';
  }

  @override
  String get segGeomWizardTitle => 'Segment placement wizard';

  @override
  String get segGeomWizardIntro =>
      'Choose a segment, rotate which screen edge it samples, slide the band along that edge, or flip LED order. Rotating the edge resets the capture band to the full edge (LED indices stay the same).';

  @override
  String get segGeomWizardEmpty =>
      'No segments are configured yet. Run the LED mapping wizard first, then fine‑tune placement here.';

  @override
  String get segGeomWizardSegmentPicker => 'Segment';

  @override
  String segGeomWizardSegmentLabel(int index) {
    return 'Segment $index';
  }

  @override
  String segGeomWizardLedRange(int start, int end) {
    return 'LEDs $start–$end';
  }

  @override
  String get segGeomWizardRotateCwTooltip =>
      'Rotate edge clockwise (top → right → bottom → left)';

  @override
  String get segGeomWizardRotateCcwTooltip => 'Rotate edge counter‑clockwise';

  @override
  String get segGeomWizardReverse => 'Reverse LED order along strip';

  @override
  String get segGeomWizardWholeEdge => 'Sample the entire edge';

  @override
  String get segGeomWizardWholeEdgeSubtitle =>
      'Turn off to limit sampling to part of the edge with the sliders below.';

  @override
  String get segGeomWizardBandTitle => 'Band along edge (reference pixels)';

  @override
  String get segGeomWizardPresetFull => 'Full edge';

  @override
  String get segGeomWizardPresetStartHalf => 'First half';

  @override
  String get segGeomWizardPresetEndHalf => 'Second half';

  @override
  String get segGeomWizardPresetCenterThird => 'Center third';

  @override
  String get segGeomWizardRefFromCapture =>
      'Match reference size to last capture';

  @override
  String get segGeomWizardPreviewCaption => 'Sampling region (approximation)';

  @override
  String get segGeomWizardGradientSubtitle =>
      'Live gradient matches colors sent along this edge (screen left→right on top/bottom; top→bottom on left/right). Align it with your strip using Reverse or edge rotation.';

  @override
  String get segGeomWizardGradientUnavailable =>
      'No live preview — check segment monitor index, turn output on, and use Screen mode so captures reach this dialog.';

  @override
  String get segGeomWizardPreviewLive => 'Preview uses live capture dimensions';

  @override
  String get segGeomWizardPreviewRef => 'Preview uses segment reference size';

  @override
  String get segGeomWizardOpenMapping => 'LED mapping wizard…';

  @override
  String get segGeomWizardSaved => 'Segment geometry saved.';

  @override
  String get segGeomWizardMonitorTitle => 'Monitor index';

  @override
  String get segGeomWizardLaunchButton => 'Segment placement';

  @override
  String get refDimsFromCapture => 'Ref. dimensions from last capture';

  @override
  String get dropdownAllDefault => '— all / default —';

  @override
  String get guideMusicTitle => 'Music & Spotify';

  @override
  String get guideBrowserFailed => 'Could not open the browser.';

  @override
  String get guideNeedClientIdFirst =>
      'First enter Client ID under Settings → Spotify (see button above).';

  @override
  String get guideClose => 'Close';

  @override
  String get guideOpenSpotifyDev => 'Open Spotify Developer';

  @override
  String get guideSpotifyBrowserLogin => 'Sign in to Spotify in browser';

  @override
  String get guideSectionSound => '1 · Mode and audio';

  @override
  String get guideSectionAlbum => '2 · Album color';

  @override
  String get guideSectionSpotify => '3 · Spotify';

  @override
  String get guideSectionApple => '4 · Apple Music';

  @override
  String get guideSectionTrouble => 'When something fails';

  @override
  String get backupTitle => 'Configuration backup';

  @override
  String get backupExport => 'Export JSON…';

  @override
  String get backupImport => 'Import JSON…';

  @override
  String get backupExported => 'Configuration exported.';

  @override
  String get backupImported => 'Configuration imported.';

  @override
  String get backupInvalid => 'Invalid configuration file.';

  @override
  String get factoryResetTitle => 'Restore defaults';

  @override
  String get factoryResetButton => 'Restore factory defaults…';

  @override
  String get factoryResetDialogTitle => 'Restore factory defaults?';

  @override
  String get factoryResetDialogBody =>
      'All settings will revert to built-in defaults, devices and zones will be cleared, and saved Home Assistant and Spotify tokens will be removed. This cannot be undone — export a JSON backup first if you need a copy.';

  @override
  String get factoryResetConfirm => 'Restore defaults';

  @override
  String get factoryResetDone => 'Settings restored to defaults.';

  @override
  String factoryResetFailed(String error) {
    return 'Factory reset failed: $error';
  }

  @override
  String get spotifyTabTitle => 'Spotify';

  @override
  String get spotifyTabIntro =>
      'OAuth tokens and album artwork colors. Help explains audio routing and artwork.';

  @override
  String get spotifyHelpAlbum => 'Help: music & artwork';

  @override
  String get spotifyIntegrationEnabled => 'Spotify integration enabled';

  @override
  String get spotifyAlbumColors => 'Album colors (Spotify API)';

  @override
  String get spotifyDeleteSecretDraft => 'Remove client secret from draft';

  @override
  String get spotifyAccessToken => 'Access token';

  @override
  String get spotifyRefreshToken => 'Refresh token';

  @override
  String get spotifyTokenSetHidden => 'Set (hidden)';

  @override
  String get spotifyTokenMissing => 'Missing';

  @override
  String get spotifyAppleOsTitle => 'Apple Music / YouTube Music (OS)';

  @override
  String get spotifyAppleOsBody =>
      'Uses dominant color from OS media thumbnails when Spotify does not provide a color.';

  @override
  String get spotifyGsmtcOn => 'Album color via OS media (GSMTC)';

  @override
  String get spotifyGsmtcOff => 'Album color via OS media (unavailable)';

  @override
  String get spotifyGsmtcSubtitle =>
      'Used in music mode when Spotify has no color or it is disabled.';

  @override
  String get spotifyDominantThumb => 'Use dominant color from OS thumbnail';

  @override
  String get firmwareEspTitle => 'ESP firmware';

  @override
  String get firmwareEspIntro =>
      'Manifest URL, downloads and flash/OTA actions. Requires compatible controller.';

  @override
  String get firmwareManifestUrlLabel => 'Manifest URL (GitHub Pages)';

  @override
  String get firmwareManifestUrlHint =>
      'https://alfredkrutina.github.io/ambilight/firmware/latest/';

  @override
  String get firmwareManifestHelper =>
      'Inherited from global settings; without a file we append /manifest.json';

  @override
  String get firmwareLoadManifest => 'Load manifest';

  @override
  String get firmwareDownloadBins => 'Download binaries';

  @override
  String firmwareVersionChip(Object version, Object chip) {
    return 'Version: $version · chip: $chip';
  }

  @override
  String firmwarePartLine(Object file, Object offset) {
    return '• $file @ $offset';
  }

  @override
  String firmwareOtaUrlLine(Object url) {
    return 'OTA URL: $url';
  }

  @override
  String get firmwareUsbFlashTitle => 'USB flash (COM)';

  @override
  String get firmwareRefreshPorts => 'Refresh port list';

  @override
  String get firmwareSelectPortFirst => 'Select a serial port.';

  @override
  String get firmwarePickFirmwareFolder =>
      'Pick a firmware folder with manifest.json.';

  @override
  String get firmwareFlashEsptool => 'Flash via esptool';

  @override
  String get firmwareOtaUdpTitle => 'OTA over Wi‑Fi (UDP)';

  @override
  String get firmwareDeviceIp => 'Device IP';

  @override
  String get firmwareUdpPort => 'UDP port';

  @override
  String get firmwareVerifyReachability => 'Verify reachability (UDP PONG)';

  @override
  String get firmwareSendOtaHttp => 'Send OTA_HTTP';

  @override
  String get smartHaUrlLabel => 'URL (https://…:8123)';

  @override
  String get smartHaTokenLabel => 'Long-lived access token';

  @override
  String get smartHaConfigureFirst => 'First set Home Assistant URL and token.';

  @override
  String smartHaError(Object error) {
    return 'HA: $error';
  }

  @override
  String get smartHaNoLights => 'No light.* entities in HA.';

  @override
  String get smartAddLightTitle => 'Add light from Home Assistant';

  @override
  String get smartIntegrationTitle => 'Smart Home';

  @override
  String get smartIntegrationSubtitle =>
      'Home Assistant and virtual room wave.';

  @override
  String get virtualRoomWaveTitle => 'Room wave';

  @override
  String get virtualRoomWaveSubtitle =>
      'Brightness modulation by distance from TV and capture time.';

  @override
  String virtualRoomWaveStrength(Object pct) {
    return 'Wave strength: $pct %';
  }

  @override
  String get virtualRoomWaveSpeed => 'Wave speed';

  @override
  String get virtualRoomDistanceSens => 'Distance sensitivity';

  @override
  String virtualRoomFacing(Object deg) {
    return 'View angle offset toward TV: $deg°';
  }

  @override
  String get virtualRoomEffectLabel => 'Effect on smart lights';

  @override
  String get virtualRoomEffectNone => 'Off';

  @override
  String get virtualRoomEffectWave => 'Wave';

  @override
  String get virtualRoomEffectBreath => 'Breath';

  @override
  String get virtualRoomEffectChase => 'Chase';

  @override
  String get virtualRoomEffectSparkle => 'Sparkle';

  @override
  String get virtualRoomEffectHintNone =>
      'Colors and brightness from the engine only — no extra modulation.';

  @override
  String get virtualRoomEffectHintWave =>
      'Smooth wave through the room; geometry sets how distance affects phase.';

  @override
  String get virtualRoomEffectHintBreath =>
      'All lights pulse together — good when you do not want a spatial pattern.';

  @override
  String get virtualRoomEffectHintChase =>
      'Lights brighten in order along the chosen axis (sorted left-to-right on that axis).';

  @override
  String get virtualRoomEffectHintSparkle =>
      'Each light drifts with a slightly different phase for a lively shimmer.';

  @override
  String get virtualRoomGeometryLabel => 'Wave / chase axis';

  @override
  String get virtualRoomGeometryRadial => 'Radial from TV';

  @override
  String get virtualRoomGeometryAlongView =>
      'Across your view (perpendicular to gaze)';

  @override
  String get virtualRoomGeometryHorizontal => 'Horizontal (toward TV on X)';

  @override
  String get virtualRoomGeometryVertical => 'Vertical (toward TV on Y)';

  @override
  String get virtualRoomGeometryCustom => 'Custom angle from TV';

  @override
  String virtualRoomCustomAngle(Object deg) {
    return 'Axis angle: $deg°';
  }

  @override
  String get virtualRoomBrightnessModLabel => 'Apply modulation to';

  @override
  String get virtualRoomBrightnessBoth => 'Color and brightness';

  @override
  String get virtualRoomBrightnessRgb => 'Color only';

  @override
  String get virtualRoomBrightnessBri => 'Brightness only';

  @override
  String get virtualRoomPreviewToggle => 'Animated preview';

  @override
  String get virtualRoomPreviewSubtitle =>
      'Bulb icons use the same math as Home Assistant / HomeKit output.';

  @override
  String get virtualRoomDragTv => 'TV (drag)';

  @override
  String get virtualRoomDragUser => 'You (drag)';

  @override
  String get scanOverlaySettingsTitle => 'Scan overlay (detail)';

  @override
  String get scanOverlaySettingsIntro =>
      'Preview capture zones on the monitor while tuning screen mode.';

  @override
  String get scanOverlayPreviewTitle => 'Show zone preview while tuning';

  @override
  String get scanOverlayPreviewSubtitle =>
      'Short fullscreen overlay; does not affect capture.';

  @override
  String get scanOverlayMonitorLabel => 'Monitor (MSS index, same as capture)';

  @override
  String get scanOverlayShowNow => 'Show zone preview now (~1 s)';

  @override
  String get scanDepthPercentTitle => 'Scan depth % (per edge)';

  @override
  String get scanPaddingPercentTitle => 'Padding % (per edge)';

  @override
  String get scanRegionSchemeTitle =>
      'Region scheme (ratio of selected monitor)';

  @override
  String get scanLastFrameTitle => 'Latest frame (screen mode)';

  @override
  String get pcHealthSectionTitle => 'PC Health';

  @override
  String get pcHealthSectionSubtitle =>
      'Sensors to colors. Add metrics and map them to zones.';

  @override
  String get pcHealthEnabledTitle => 'PC Health enabled';

  @override
  String get pcHealthEnabledSubtitle => 'Disabled = black output in this mode.';

  @override
  String get pcHealthMetricNew => 'New metric';

  @override
  String get pcHealthMetricEdit => 'Edit metric';

  @override
  String get pcHealthMetricEnabled => 'Enabled';

  @override
  String get pcHealthMetricName => 'Name';

  @override
  String get pcHealthMetricKey => 'Metric';

  @override
  String get pcHealthMetricMin => 'Min';

  @override
  String get pcHealthMetricMax => 'Max';

  @override
  String get pcHealthColorScale => 'Color scale';

  @override
  String get pcHealthBrightnessMode => 'Brightness';

  @override
  String get pcHealthBrightnessStatic => 'Static';

  @override
  String get pcHealthBrightnessDynamic => 'Dynamic (by value)';

  @override
  String get pcHealthZonesTitle => 'Zones';

  @override
  String get pcHealthLivePreview => 'Live value preview';

  @override
  String get pcHealthMeasureNow => 'Measure now';

  @override
  String pcHealthMetricsHeader(Object count) {
    return 'Metrics ($count)';
  }

  @override
  String get pcHealthNoMetrics => 'No metrics.';

  @override
  String get pcHealthDefaultMetrics => 'Defaults';

  @override
  String get pcHealthColorStripPreview => 'Color strip (preview)';

  @override
  String get pcHealthStagingHint =>
      '[staging] PC Health: preview + metric editor';

  @override
  String get lightSectionTitle => 'Light mode';

  @override
  String get lightSectionSubtitle =>
      'Static color, effects, zones and brightness.';

  @override
  String get screenSectionTitle => 'Screen';

  @override
  String get screenSectionSubtitle =>
      'Screen mode: colors from monitor edges. Calibration and segments can also be adjusted in Devices. The zone preview while tuning is only an in-app overlay (highlighted scan bands; the window is not moved).';

  @override
  String get musicSectionTitle => 'Music mode';

  @override
  String get musicSectionSubtitle =>
      'Microphone, effects and Spotify integration.';

  @override
  String get devicesTabTitle => 'Devices';

  @override
  String get devicesTabSubtitle =>
      'USB and Wi‑Fi controllers, LED counts and default monitor.';

  @override
  String get usbSerialLabel => 'USB / serial';

  @override
  String get udpWifiLabel => 'UDP / Wi‑Fi';

  @override
  String get onboardingModesDemoLabel => 'Modes';

  @override
  String get onboardingOutputDemoOn => 'Output on';

  @override
  String get onboardingOutputDemoOff => 'Output off';

  @override
  String get calibrationTitle => 'Calibration';

  @override
  String get ledStripWizardTitle => 'LED strip wizard';

  @override
  String get configProfileWizardTitle => 'Save screen preset';

  @override
  String get colorPickerTitle => 'Pick color';

  @override
  String get colorPickerHex => 'Hex';

  @override
  String get devicesTabPlaceholder => '';

  @override
  String get onboardingReplayTitle => 'Onboarding';

  @override
  String get onboardingReplayBody =>
      'Same guide as first launch — output, modes, devices and settings.';

  @override
  String get replayOnboardingButton => 'Run onboarding again';

  @override
  String get uiControlLevelLabel => 'Control level';

  @override
  String get uiControlLevelHelper =>
      'Simple hides advanced screen tuning (gamma, calibration shortcuts, capture diagnostics). You can change this anytime.';

  @override
  String get uiControlLevelSimple => 'Simple';

  @override
  String get uiControlLevelAdvanced => 'Advanced';

  @override
  String get onboardWizardStepThemeTitle => 'Choose appearance';

  @override
  String get onboardWizardStepThemeSubtitle =>
      'You can change this later under Settings → Global.';

  @override
  String get onboardWizardThemeLightTitle => 'Light';

  @override
  String get onboardWizardThemeLightSubtitle =>
      'Bright surfaces and high contrast controls.';

  @override
  String get onboardWizardThemeDarkTitle => 'Dark';

  @override
  String get onboardWizardThemeDarkSubtitle =>
      'Easier on the eyes in dim rooms.';

  @override
  String get onboardWizardStepComplexityTitle =>
      'How detailed should settings be?';

  @override
  String get onboardWizardStepComplexitySubtitle =>
      'Simple keeps everyday sliders only. Advanced exposes gamma, offsets and diagnostics.';

  @override
  String get onboardWizardComplexitySimpleTitle => 'Simple';

  @override
  String get onboardWizardComplexitySimpleSubtitle =>
      'Recommended — fewer knobs, faster setup.';

  @override
  String get onboardWizardComplexityAdvancedTitle => 'Advanced';

  @override
  String get onboardWizardComplexityAdvancedSubtitle =>
      'Full control over capture, color math and calibration tools.';

  @override
  String get onboardWizardStepDeviceTitle => 'Connect your controller';

  @override
  String get onboardWizardStepDeviceSubtitle =>
      'Pick how your PC talks to the LEDs. You can add more devices later on the Devices page.';

  @override
  String get onboardWizardScanWifi => 'Scan for Wi‑Fi devices';

  @override
  String get onboardWizardSetupUsb => 'Set up USB / Serial';

  @override
  String get onboardWizardStepMappingTitle => 'Map LEDs to your screen';

  @override
  String get onboardWizardStepMappingSubtitle =>
      'Walk the strip once so corners match your monitor. Skip if you want to do this later.';

  @override
  String get onboardWizardOpenMapping => 'Open mapping wizard';

  @override
  String get onboardWizardMappingSkip => 'SKIP FOR NOW';

  @override
  String get onboardWizardStepIntegrationsTitle => 'Integrations';

  @override
  String get onboardWizardStepIntegrationsSubtitle =>
      'Optional extras — enable them when you need them.';

  @override
  String get onboardWizardHaCardTitle => 'Home Assistant';

  @override
  String get onboardWizardHaCardBody =>
      'Mirror colors to lamps and automations with a long‑lived token and your HA URL.';

  @override
  String get onboardWizardSpotifyCardTitle => 'Spotify';

  @override
  String get onboardWizardSpotifyCardBody =>
      'Richer music visuals when you link a Spotify Developer app (Client ID in Settings).';

  @override
  String get onboardWizardPcHealthCardTitle => 'PC Health';

  @override
  String get onboardWizardPcHealthCardBody =>
      'Temperatures and load drive ambient colors — great for idle dashboards.';

  @override
  String get onboardWizardPreviewHint =>
      'Rainbow preview uses the same test path as Settings → Screen (synthetic colors).';

  @override
  String get onboardWizardFinish => 'Get started';

  @override
  String get setupWizardLanguageHeader => 'Choose your language / Zvolte jazyk';

  @override
  String get setupWizardLanguageSubtitle =>
      'Applied immediately — change anytime under Settings → Global.';

  @override
  String get setupWizardLanguageEnglishTitle => 'English';

  @override
  String get setupWizardLanguageEnglishSubtitle =>
      'Default language for the UI.';

  @override
  String get setupWizardLanguageCzechTitle => 'Čeština';

  @override
  String get setupWizardLanguageCzechSubtitle => 'Czech interface.';

  @override
  String get setupWizardAppearanceHeader => 'How should we look?';

  @override
  String get setupWizardAppearanceSubtitle =>
      'Pick a palette — it is saved to your profile right away.';

  @override
  String get setupWizardThemeOptionLightSubtitle =>
      'Bright surfaces with teal accents.';

  @override
  String get setupWizardThemeOptionDarkBlueSubtitle =>
      'Cyan and violet highlights on a deep blue base — classic AmbiLight look.';

  @override
  String get setupWizardThemeOptionSnowrunnerSubtitle =>
      'Neutral dark gray UI with a warm orange accent.';

  @override
  String get setupWizardThemeOptionCoffeeSubtitle =>
      'Warm cream and brown tones.';

  @override
  String get setupWizardExpertiseSimpleExplain =>
      'Advanced settings (Gamma, smoothing, and fine IP/offset fields) stay hidden for a cleaner experience. You can switch to Advanced anytime in Global settings.';

  @override
  String get setupWizardUsbListTitle => 'USB — serial ports';

  @override
  String get setupWizardUsbEmpty =>
      'No COM ports detected. Plug in the controller and tap refresh.';

  @override
  String get setupWizardUsbConnect => 'Connect';

  @override
  String get setupWizardUsbWebHint =>
      'Serial/USB setup is available in the Windows desktop build.';

  @override
  String get setupWizardComDtrRtsHint =>
      'Test uses the same DTR/RTS line setup as a normal connect (ESP32‑C3 USB‑JTAG or classic USB‑UART bridge).';

  @override
  String get setupWizardDeviceWifiSection => 'Wi‑Fi / network';

  @override
  String get setupWizardDeviceSerialSection => 'USB / serial';

  @override
  String get setupWizardDeviceWifiIntro =>
      'We broadcast on your LAN (UDP 4210). Controllers that answer appear below — tap Add to save one to your profile.';

  @override
  String get setupWizardDeviceSerialIntro =>
      'Choose the COM port your ESP32 or USB‑serial adapter uses (for example COM3). Test verifies an AmbiLight controller before you add it.';

  @override
  String get setupWizardDeviceWifiDesktopOnly =>
      'Wi‑Fi discovery is available in the Windows desktop build.';

  @override
  String get setupWizardDeviceTestConnection => 'Test';

  @override
  String get setupWizardDeviceAdd => 'Add';

  @override
  String get setupWizardDeviceScanningLabel => 'Scanning your network…';

  @override
  String get setupWizardDeviceIdentifiedShort =>
      'AmbiLight controller detected.';

  @override
  String get setupWizardDeviceTestFailedShort =>
      'Not an AmbiLight controller on this port.';

  @override
  String setupWizardDeviceControllerId(Object macSuffix) {
    return 'ID: $macSuffix';
  }

  @override
  String setupWizardDeviceWifiScanFailed(Object message) {
    return 'Scan failed: $message';
  }

  @override
  String get setupWizardMappingEdgesTitle =>
      'LEDs per screen edge (current mapping)';

  @override
  String get setupWizardMappingRainbowHint =>
      'Rainbow uses the synthetic screen-output path so you can see the strip respond.';

  @override
  String get setupWizardWhatsNextTitle => 'What\'s next?';

  @override
  String get setupWizardWhatsNextSubtitle =>
      'Optional features when you want more than ambient screen colors.';

  @override
  String get setupWizardCardSpotifyTitle => 'Spotify integration';

  @override
  String get setupWizardCardSpotifyBody => 'Sync lights with your music.';

  @override
  String get setupWizardCardHaTitle => 'Home Assistant';

  @override
  String get setupWizardCardHaBody =>
      'Control via your smart home dashboard (URL + long‑lived token).';

  @override
  String get setupWizardCardPcHealthTitle => 'PC Health';

  @override
  String get setupWizardCardPcHealthBody => 'Monitor CPU/GPU temps via colors.';

  @override
  String get setupWizardFinalHeadline => 'You\'re set.';

  @override
  String get setupWizardFinalSubtitle =>
      'Turn on Output in the app header when your hardware is ready.';

  @override
  String get setupWizardLetsGlow => 'LET\'S GLOW';

  @override
  String setupWizardStepCounter(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get devicesPageSubtitle =>
      'Network discovery, segment editing and calibration. Tap a device row for LED mapping.';

  @override
  String get fieldDeviceName => 'Name';

  @override
  String get fieldIpAddress => 'IP address';

  @override
  String get fieldUdpPort => 'UDP port';

  @override
  String get fieldLedCount => 'LED count';

  @override
  String removeDeviceFailed(Object detail) {
    return 'Removing device failed: $detail';
  }

  @override
  String exportSavedTo(Object path) {
    return 'Saved: $path';
  }

  @override
  String exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get importReadError => 'Cannot read file (missing path).';

  @override
  String get importLoaded => 'Configuration loaded and saved.';

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get backupIntroBody =>
      'JSON compatible with the Python client (`config/default.json`). Safe export omits Home Assistant and Spotify secrets (same as the app’s on-disk profile). Use “Export with secrets” for a full clone including tokens.';

  @override
  String get backupExportWithSecrets => 'Export with secrets…';

  @override
  String get backupExportWithSecretsConfirm => 'Export anyway';

  @override
  String get backupSecretsExportTitle => 'Include secrets in the backup?';

  @override
  String get backupSecretsExportBody =>
      'The file will contain your Home Assistant long-lived token (if set), Spotify OAuth access/refresh tokens from this PC, Spotify client secret if entered, and the same fields as in Settings. Anyone with the file can control your HA or Spotify session — store it only in a safe place and never share it.';

  @override
  String get backupSecretsSaveDialogTitle =>
      'Save configuration including secrets';

  @override
  String get backupImportRestoresTokensHint =>
      'Import applies `ha_long_lived_token` and Spotify tokens from the file when present (written to the same sidecar storage as a normal login).';

  @override
  String get exportDialogTitle => 'Export AmbiLight configuration';

  @override
  String get devicesConfiguredTitle => 'Configured devices';

  @override
  String get devicesEmptyStateBody =>
      'None yet — you can set up modes and presets first. Add USB or Wi‑Fi above to drive a strip.';

  @override
  String get diagnosticsComPorts => 'Diagnostics (COM ports)';

  @override
  String get noSerialPortsDetected => 'No serial ports detected.';

  @override
  String resetWifiContent(Object name) {
    return 'Device \"$name\" clears saved Wi‑Fi credentials on the controller and restarts. You must reconnect it to the network.';
  }

  @override
  String get screenSettingsLayoutTitle => 'Settings layout';

  @override
  String get screenModeSimpleLabel => 'Simple';

  @override
  String get screenModeAdvancedLabel => 'Advanced';

  @override
  String get screenModeHintAdvanced =>
      'Shows all fields including color curves, technical monitor index and per-edge controls in the preview section.';

  @override
  String get screenModeHintSimple =>
      'Monitor, brightness, smoothing and uniform scan depth / padding are enough. Detailed zones appear in the preview below.';

  @override
  String get fieldMonitorIndexLabel => 'Monitor (index)';

  @override
  String get fieldMonitorSameAsCaptureLabel => 'Monitor (same as capture)';

  @override
  String screenScanDepthUniformPct(Object pct) {
    return 'Scan depth (uniform): $pct %';
  }

  @override
  String screenPaddingUniformPct(Object pct) {
    return 'Padding (uniform): $pct %';
  }

  @override
  String get screenColorSamplingLabel => 'LED color from scan region';

  @override
  String get screenColorSamplingMedian => 'Median (PyQt default)';

  @override
  String get screenColorSamplingAverage => 'Average (mean)';

  @override
  String get screenColorSamplingHint =>
      'Each LED maps to a rectangle along the segment edge (same geometry at any capture resolution). Median reduces bright outliers (e.g. white UI on colored backgrounds). Average matches smoother pooling similar to PyQt cv2.resize INTER_AREA.';

  @override
  String get screenCaptureCardTitle => 'Screen capture';

  @override
  String get refreshDiagnostics => 'Refresh diagnostics';

  @override
  String get screenCapturePermissionOk =>
      'Screen permission: OK — check Privacy settings if needed.';

  @override
  String get screenCapturePermissionDenied =>
      'Permission denied or unavailable.';

  @override
  String get macosRequestScreenCapture => 'macOS: request screen capture';

  @override
  String get screenImageOutputTitle => 'Image and output';

  @override
  String get screenWindowsCaptureBackendLabel => 'Windows capture';

  @override
  String get screenWindowsCaptureBackendHint =>
      'CPU (GDI) often reduces cursor flicker; GPU (DXGI) uses Desktop Duplication on a specific monitor (not virtual desktop 0).';

  @override
  String get screenWindowsCaptureBackendCpu => 'CPU (GDI)';

  @override
  String get screenWindowsCaptureBackendGpu => 'GPU (DXGI)';

  @override
  String screenBrightnessValue(Object v) {
    return 'Brightness (screen): $v';
  }

  @override
  String screenInterpolationMs(Object v) {
    return 'Interpolation (ms): $v';
  }

  @override
  String get screenUniformRegionTitle => 'Uniform capture region';

  @override
  String get screenTechMonitorTitle => 'Technical monitor and uniform region';

  @override
  String get fieldMonitorIndexMssLabel => 'monitor_index (MSS, 0-32)';

  @override
  String get screenColorsDetailTitle => 'Colors and scan (detail)';

  @override
  String screenGammaValue(Object v) {
    return 'Gamma: $v';
  }

  @override
  String screenSaturationBoostValue(Object v) {
    return 'Saturation boost: $v';
  }

  @override
  String get screenUltraSaturation => 'Ultra saturation';

  @override
  String screenUltraAmountValue(Object v) {
    return 'Ultra amount: $v';
  }

  @override
  String screenMinBrightnessLed(Object v) {
    return 'Min. brightness (LED): $v';
  }

  @override
  String get fieldScreenColorPreset => 'Screen color preset';

  @override
  String get helperScreenColorPreset =>
      'Quick presets, built-in names and saved user_screen_presets';

  @override
  String get fieldActiveCalibrationProfile => 'Active calibration profile';

  @override
  String get helperCalibrationProfileKeys =>
      'Keys from calibration_profiles in config';

  @override
  String get stripMarkersTitle => 'LED markers on strip';

  @override
  String get stripMarkersBody =>
      'Green LEDs at corners (like PyQt calibration). When indicating, max strip length is used for transport (USB up to 2000 LEDs with wide 0xFC framing, Wi-Fi per UDP), not the LED count from device settings — so high indices can light up. Turn off before saving or switching tabs.';

  @override
  String get markerTopLeft => 'Top left';

  @override
  String get markerTopRight => 'Top right';

  @override
  String get markerBottomRight => 'Bottom right';

  @override
  String get markerBottomLeft => 'Bottom left';

  @override
  String get markerOff => 'Turn off markers';

  @override
  String get screenRainbowSynthSectionTitle => 'Pipeline diagnostics';

  @override
  String get screenRainbowSynthSwitchTitle =>
      'Synthetic rainbow (ignore screen pixels)';

  @override
  String get screenRainbowSynthSwitchSubtitle =>
      'The screen worker skips ROI and sends a moving test pattern through the same pack/UDP path. Off by default — use to separate capture lag from downstream lag.';

  @override
  String get segmentsTileTitle => 'Segments';

  @override
  String segmentsZoneEditorSubtitle(Object count) {
    return 'Count: $count (zone editor A7)';
  }

  @override
  String screenSegmentMonitorMismatchBanner(Object capture) {
    return 'Some LED segments sample a different monitor than the selected capture source (index $capture). Adjust segment monitor indices or change the capture monitor.';
  }

  @override
  String get lightZoneColorTitle => 'Zone color';

  @override
  String get lightPrimaryColorTitle => 'Primary color';

  @override
  String get lightSettingsHeader => 'Light';

  @override
  String get lightSettingsSubtitle =>
      'Static colors and effects on the strip without screen capture. Picking a color may briefly preview on the strip.';

  @override
  String get lightPrimaryColorTile => 'Primary color';

  @override
  String lightPrimaryColorRgbHint(Object rgb) {
    return 'RGB($rgb) · tap to pick like Home / Hue';
  }

  @override
  String get fieldEffect => 'Effect';

  @override
  String lightSpeedValue(Object v) {
    return 'Speed: $v';
  }

  @override
  String lightExtraValue(Object v) {
    return 'Extra: $v';
  }

  @override
  String lightBrightnessValue(Object v) {
    return 'Brightness: $v';
  }

  @override
  String lightSmoothingMs(Object v) {
    return 'Color smoothing (ms): $v';
  }

  @override
  String get lightSmoothingHint =>
      'Blends light-mode colors between frames (0 = instant). Same idea as screen interpolation.';

  @override
  String get lightHomekitTile =>
      'HomeKit (FW / MQTT — do not send colors from PC)';

  @override
  String get lightHomekitSubtitle => 'homekit_enabled';

  @override
  String get lightCustomZonesTitle => 'Custom zones';

  @override
  String get lightAddZone => 'Add zone';

  @override
  String lightZoneDefaultName(Object n) {
    return 'Zone $n';
  }

  @override
  String get fieldZoneName => 'Name';

  @override
  String get fieldStartPercent => 'Start %';

  @override
  String get fieldEndPercent => 'End %';

  @override
  String get fieldZoneEffect => 'Zone effect';

  @override
  String lightZoneSpeedValue(Object v) {
    return 'Zone speed: $v';
  }

  @override
  String get lightRemoveZone => 'Remove zone';

  @override
  String get lightEffectStatic => 'Static';

  @override
  String get lightEffectBreathing => 'Breathing';

  @override
  String get lightEffectRainbow => 'Rainbow';

  @override
  String get lightEffectChase => 'Chase';

  @override
  String get lightEffectCustomZones => 'Custom zones';

  @override
  String get lightZoneEffectPulse => 'Pulse';

  @override
  String get lightZoneEffectBlink => 'Blink';

  @override
  String musicDeviceError(Object error) {
    return 'Device: $error';
  }

  @override
  String get musicInputDeviceLabel => 'Audio input device';

  @override
  String get musicDefaultInputDevice => 'Automatic: system mix (loopback)';

  @override
  String get musicSystemLoopbackHint =>
      'With no device selected and “Prefer microphone” off, AmbiLight drives the visualizer from system-side audio. On Windows 10+, the app uses WASAPI loopback on the default playback device (browser, games, Spotify — not just a physical mic). You can still pick Stereo Mix, VB-Audio Cable, etc. from the list. macOS: install BlackHole from existential.audio/blackhole, create a Multi-Output Device in Audio MIDI Setup, then pick “BlackHole” (or Aggregate) here.';

  @override
  String get musicRefreshDeviceListTooltip => 'Refresh device list';

  @override
  String get musicSettingsHeader => 'Music';

  @override
  String get musicSettingsSubtitle =>
      'Audio source, effects and color preview. Music mode must be active on the overview for output to reach strips.';

  @override
  String get musicGuideMusicArtwork => 'Guide: music & artwork';

  @override
  String get musicLockPaletteTitle => 'Freeze strip lights (music)';

  @override
  String get musicLockPaletteFrozen =>
      'Frozen: the last captured LED pattern is resent every tick — lights stay still while audio keeps updating internally.';

  @override
  String get musicLockPalettePending =>
      'Next tick captures the current strip output, then LEDs hold that pattern.';

  @override
  String get musicLockPaletteIdle =>
      'Freezes the physical LED output (whole-strip RGB snapshot), not just color-source logic. Cleared when leaving music mode.';

  @override
  String get musicPreferMicTitle => 'Prefer microphone';

  @override
  String get musicPreferMicSubtitle =>
      'If no device is selected, a suitable input outside the speaker loop is preferred.';

  @override
  String get musicColorSourceLabel => 'Color source';

  @override
  String get musicColorSourceFixed => 'Fixed color';

  @override
  String get musicColorSourceSpectrum => 'Spectrum from audio';

  @override
  String get musicColorSourceMonitor => 'Colors from monitor (Ambilight)';

  @override
  String get musicFixedColorHeader => 'Fixed color';

  @override
  String get musicFixedColorHint =>
      'Pick color like Home / Hue — strip preview while adjusting.';

  @override
  String get musicVisualEffectLabel => 'Visual effect';

  @override
  String get musicSmartMusicHint =>
      'Smart Music: spectrum, beat and melody map to the strip in real time (local, no cloud).';

  @override
  String musicBrightnessValue(Object v) {
    return 'Brightness (music): $v';
  }

  @override
  String get musicBeatDetection => 'Beat detection';

  @override
  String musicBeatThreshold(Object v) {
    return 'Beat threshold: $v';
  }

  @override
  String musicOverallSensitivity(Object v) {
    return 'Overall sensitivity: $v';
  }

  @override
  String get musicBandSensitivityCaption =>
      'Band sensitivity (bass / mids / highs / overall)';

  @override
  String musicBassValue(Object v) {
    return 'Bass: $v';
  }

  @override
  String musicMidValue(Object v) {
    return 'Mid: $v';
  }

  @override
  String musicHighValue(Object v) {
    return 'High: $v';
  }

  @override
  String musicGlobalValue(Object v) {
    return 'Global: $v';
  }

  @override
  String get musicAutoGainTitle => 'Automatic gain';

  @override
  String get musicAutoGainSubtitle =>
      'Normalizes input volume to track dynamics.';

  @override
  String get musicAutoMidTitle => 'Auto mids';

  @override
  String get musicAutoHighTitle => 'Auto highs';

  @override
  String musicSmoothingMs(Object v) {
    return 'Temporal smoothing: $v ms';
  }

  @override
  String musicMinBrightnessValue(Object v) {
    return 'min_brightness (music): $v';
  }

  @override
  String musicRotationSpeedValue(Object v) {
    return 'rotation_speed: $v';
  }

  @override
  String get musicSpectrumRotationTitle => 'Spectrum rotation (time)';

  @override
  String get musicSpectrumRotationSubtitle =>
      'When off, “Rotating spectrum” stays fixed like plain spectrum; beat-sync gradient step still applies if enabled.';

  @override
  String get musicActivePresetField => 'Music preset';

  @override
  String get helperMusicActivePreset =>
      'Quick presets, built-in names, and entries from saved user_music_presets.';

  @override
  String get musicFixedColorPickerTitle => 'Fixed color (music)';

  @override
  String get musicEditColorButton => 'Edit color';

  @override
  String musicRgbTriple(Object r, Object g, Object b) {
    return 'RGB $r · $g · $b';
  }

  @override
  String get musicSpectrumPaletteHeader => 'Spectrum band colors';

  @override
  String get musicSpectrumPaletteHint =>
      'Seven stops from sub-bass to brilliance. Spectrum, VU+spectrum and Smart Music blend along this path when \"Spectrum from audio\" is selected.';

  @override
  String get musicSpectrumBandSubBass => 'Sub-bass';

  @override
  String get musicSpectrumBandBass => 'Bass';

  @override
  String get musicSpectrumBandLowMid => 'Low-mid';

  @override
  String get musicSpectrumBandMid => 'Mid';

  @override
  String get musicSpectrumBandHighMid => 'High-mid';

  @override
  String get musicSpectrumBandPresence => 'Presence';

  @override
  String get musicSpectrumBandBrilliance => 'Brilliance';

  @override
  String get musicSpectrumResetBands => 'Reset spectrum colors';

  @override
  String musicSpectrumPickerTitle(String band) {
    return 'Spectrum: $band';
  }

  @override
  String get musicBeatSyncLabel => 'Beat sync (visual)';

  @override
  String get musicBeatSyncHint =>
      'Uses beat flags from the analyzer. Gradient step shifts spectrum; color pulse briefly boosts brightness.';

  @override
  String get musicBeatSyncOff => 'Off';

  @override
  String get musicBeatSyncGradientStep => 'Gradient step on beat';

  @override
  String get musicBeatSyncColorPulse => 'Color pulse on beat';

  @override
  String get musicMelodySpectrumTintTitle => 'Melody + spectrum palette';

  @override
  String get musicMelodySpectrumTintSubtitle =>
      'When the color source is spectrum, blend melody HSV toward the band palette (tint strength below).';

  @override
  String musicMelodySpectrumTintAmount(int p) {
    return 'Tint strength: $p%';
  }

  @override
  String get musicPerBandSensitivityTitle => 'Per-band sensitivity (advanced)';

  @override
  String get musicPerBandSensitivitySubtitle =>
      'When enabled, each FFT band has its own 0–100 gain; otherwise bass / mid / high groups apply as before.';

  @override
  String get musicUserPresetsTitle => 'Saved music presets (JSON)';

  @override
  String get musicUserPresetsHint =>
      'Save the current music settings under a name, export all user presets, or merge from a JSON file. Selecting a name in “Music preset” loads it.';

  @override
  String get musicUserPresetsNameLabel => 'Preset name';

  @override
  String get musicUserPresetsSave => 'Save current as preset';

  @override
  String get musicUserPresetsSavedOk => 'Preset saved.';

  @override
  String get musicUserPresetsDelete => 'Remove';

  @override
  String get musicUserPresetsExport => 'Copy presets JSON';

  @override
  String get musicUserPresetsImport => 'Import JSON…';

  @override
  String get musicUserPresetsCopied => 'Presets JSON copied to clipboard.';

  @override
  String get musicUserPresetsMerged =>
      'Imported presets merged into user list.';

  @override
  String get musicUserPresetsBadJson => 'Could not read presets JSON.';

  @override
  String get musicAgcMeterTitle => 'AGC (auto gain)';

  @override
  String musicAgcMeterPeak(String v) {
    return 'Tracked peak: $v';
  }

  @override
  String musicAgcMeterGain(String v) {
    return 'Applied gain: $v';
  }

  @override
  String get musicGuideMacosAudio => 'Guide: macOS loopback';

  @override
  String get musicMacosLoopbackGuideTitle =>
      'macOS — system audio to Ambilight';

  @override
  String get musicMacosLoopbackGuideIntro =>
      'Unlike Windows WASAPI loopback on the default playback device, macOS does not expose a built-in “what you hear” capture device to all apps.';

  @override
  String get musicMacosLoopbackGuideSteps =>
      '1) Install BlackHole (2ch) from existential.audio/blackhole.\n2) Open Audio MIDI Setup → create a Multi-Output Device that includes your speakers/headphones and BlackHole; set it as the system output for listening while routing a copy to BlackHole.\n3) In Ambilight → Music, pick “BlackHole” (or your aggregate) as the input device.';

  @override
  String get musicMacosLoopbackGuideNote =>
      'Latency and device names depend on your aggregate. For Spotify-only colors you can also use the in-app Spotify integration.';

  @override
  String get musicMacosLoopbackGuideClose => 'Close';

  @override
  String get musicMacosLoopbackGuideBlackHole => 'Open BlackHole page';

  @override
  String get musicMacosLoopbackGuideOpenFailed => 'Could not open the link.';

  @override
  String get musicEffectSmartMusic => 'Smart Music';

  @override
  String get musicEffectEnergy => 'Energy';

  @override
  String get musicEffectSpectrum => 'Spectrum';

  @override
  String get musicEffectSpectrumRotate => 'Rotating spectrum';

  @override
  String get musicEffectSpectrumPunchy => 'Spectrum (punchy)';

  @override
  String get musicEffectStrobe => 'Strobe';

  @override
  String get musicEffectVuMeter => 'VU meter';

  @override
  String get musicEffectVuSpectrum => 'VU + spectrum';

  @override
  String get musicEffectPulse => 'Pulse';

  @override
  String get musicEffectReactiveBass => 'Reactive bass';

  @override
  String get devicesTabHeader => 'Devices';

  @override
  String get devicesTabIntro =>
      'Name and LED count matter for control. IP and port are under Connection.';

  @override
  String get devicesTabEmptyHint =>
      'The list may stay empty — useful for preparing profiles only. Add at least one device to drive a strip.';

  @override
  String get devicesAddDevice => 'Add device';

  @override
  String get devicesNewDeviceName => 'New device';

  @override
  String devicesUnnamedDevice(Object index) {
    return 'Device $index';
  }

  @override
  String get devicesRemoveTooltip => 'Remove device';

  @override
  String get fieldDisplayName => 'Display name';

  @override
  String get fieldConnectionType => 'Connection type';

  @override
  String get devicesTypeUsb => 'USB (serial)';

  @override
  String get devicesTypeWifi => 'Wi-Fi (UDP)';

  @override
  String get devicesControlViaHa => 'Control via Home Assistant';

  @override
  String get devicesControlViaHaSubtitle =>
      'PC will not send colors to this device.';

  @override
  String get devicesConnectionSection => 'Connection and internal fields';

  @override
  String get devicesWifiIpMissing => 'Enter controller IP address';

  @override
  String get devicesWifiSaved => 'Network details saved (edit in expansion)';

  @override
  String get devicesSerialPortMissing => 'Enter COM port or pick from detected';

  @override
  String devicesPortSummary(Object port) {
    return 'Port $port';
  }

  @override
  String get fieldComPort => 'COM port';

  @override
  String devicesComHintExample(Object example) {
    return 'e.g. $example';
  }

  @override
  String devicesComDetectedHelper(Object ports) {
    return 'Detected: $ports — tap chips below to fill quickly';
  }

  @override
  String get fieldControllerIp => 'Controller IP address';

  @override
  String get fieldInternalId => 'Internal ID (links in config)';

  @override
  String get helperInternalId => 'Change only if JSON segments reference it.';

  @override
  String get scanOverlayTitle => 'Scan overlay (detail)';

  @override
  String scanOverlayIntro(Object seconds) {
    return 'Highlighted bands show the actual capture region (center stays clear). Ratio matches the selected monitor; the app window does not go fullscreen. After releasing a slider the preview hides in $seconds s. The button below shows a brief preview without moving sliders. The chip top-right or Escape closes it.';
  }

  @override
  String get scanPreviewMonitorTitle => 'Monitor preview while tuning';

  @override
  String get scanPreviewOff => 'Off';

  @override
  String scanPreviewVisible(Object seconds) {
    return 'Preview visible; hides $seconds s after release';
  }

  @override
  String get scanPreviewOnDragging =>
      'On — preview while dragging sliders (capture region)';

  @override
  String get fieldMonitorMssSameAsCapture =>
      'Monitor (MSS index, same as capture)';

  @override
  String scanMonitorNoEnum(Object index) {
    return 'Monitor $index (OS enumeration unavailable)';
  }

  @override
  String get scanPreviewNowButton => 'Show zone preview now (~1 s)';

  @override
  String get scanDepthPerEdge => 'Scan depth % (per-edge)';

  @override
  String get scanPaddingPerEdge => 'Padding % (per-edge)';

  @override
  String get scanEdgeTop => 'Top';

  @override
  String get scanEdgeBottom => 'Bottom';

  @override
  String get scanEdgeLeft => 'Left';

  @override
  String get scanEdgeRight => 'Right';

  @override
  String get scanPadLeft => 'Left (padding)';

  @override
  String get scanPadRight => 'Right (padding)';

  @override
  String scanPctLabel(Object label, Object pct) {
    return '$label: $pct %';
  }

  @override
  String get scanSimpleModeHint =>
      'Set uniform depth and padding above under Capture region. Enable advanced screen mode for independent edges.';

  @override
  String get scanDiagramTitle => 'Region diagram (selected monitor aspect)';

  @override
  String get scanThumbNeedScreenMode =>
      'Turn on screen mode for a live preview.';

  @override
  String get scanThumbWaiting => 'Waiting for frame…';

  @override
  String get removeDeviceDialogTitle => 'Remove device?';

  @override
  String get removeDeviceDialogLastBody =>
      'The device list may stay empty — that is fine. Without a device you cannot send colors to strips; you can still configure modes and presets. When hardware is connected, add it again here or via Discovery.';

  @override
  String removeDeviceDialogNamedBody(Object name) {
    return 'Device \"$name\" will be removed from configuration.';
  }

  @override
  String get deviceDetailsTitle => 'Technical details';

  @override
  String detailLineInternalId(Object id) {
    return 'Internal ID: $id';
  }

  @override
  String detailLineType(Object type) {
    return 'Type: $type';
  }

  @override
  String detailLineLedCount(Object count) {
    return 'LED count: $count';
  }

  @override
  String detailLineIp(Object ip) {
    return 'IP: $ip';
  }

  @override
  String detailLineUdpPort(Object port) {
    return 'UDP port: $port';
  }

  @override
  String detailLineSerialPort(Object port) {
    return 'Port: $port';
  }

  @override
  String detailLineFirmware(Object version) {
    return 'Firmware: $version';
  }

  @override
  String get deviceConnectionOkLabel => 'Connected';

  @override
  String get deviceConnectionOfflineLabel => 'Disconnected';

  @override
  String get deviceHaControlledNote =>
      'Controlled via Home Assistant — PC colors are not sent to this device.';

  @override
  String get menuMoreActions => 'More actions';

  @override
  String get menuEditLedMapping => 'Edit LED mapping';

  @override
  String get menuTechnicalDetailsEllipsis => 'Technical details…';

  @override
  String get menuIdentifyBlink => 'Brief identify (blink)';

  @override
  String get menuRefreshFirmwareInfo => 'Refresh firmware info';

  @override
  String get menuResetSavedWifi => 'Reset saved Wi‑Fi on controller';

  @override
  String get menuRemoveDeviceEllipsis => 'Remove device…';

  @override
  String deviceSubtitleUsbLed(Object count) {
    return 'USB · $count LED';
  }

  @override
  String deviceSubtitleWifiLed(Object count) {
    return 'Wi-Fi · $count LED';
  }

  @override
  String get onboardingUsbSerialLabel => 'USB / serial';

  @override
  String get onboardingUdpWifiLabel => 'UDP / Wi‑Fi';

  @override
  String get colorPickerHue => 'Hue';

  @override
  String get colorPickerSaturationValue => 'Saturation & brightness';

  @override
  String get colorPickerPresets => 'Presets';

  @override
  String get colorPickerDefaultTitle => 'Color';

  @override
  String get guideMusicColorsTitle => 'Music & artwork colors';

  @override
  String get guideCloseTooltip => 'Close';

  @override
  String get guideBrowserOpenFailed => 'Could not open the browser.';

  @override
  String get guideNeedSpotifyClientId =>
      'Enter Spotify Client ID in Settings → Spotify first (see button above).';

  @override
  String get guideOpenSpotifyDeveloper => 'Open Spotify Developer';

  @override
  String get guideSignInSpotifyBrowser => 'Sign in to Spotify in browser';

  @override
  String get guideIntroBlurb =>
      'Briefly: in Music mode you get PC audio (effects) and optionally one color from track artwork.';

  @override
  String get guideCard1Title => '1 · Mode and audio';

  @override
  String get guideCard1Body =>
      'On the overview enable the Music tile. In Settings → Music pick an input (Stereo Mix, microphone, …) and allow audio capture for AmbiLight in the OS.';

  @override
  String get guideCard2Title => '2 · Artwork color';

  @override
  String get guideCard2Body =>
      'Either Spotify (below) or on Windows the “OS media” section in Settings → Spotify (Apple Music etc. via the OS). When artwork is enabled it takes priority over FFT effects.';

  @override
  String get guideCard3Title => '3 · Spotify';

  @override
  String get guideCard3Body =>
      'You need a Client ID from the developer console and redirect http://127.0.0.1:8767/callback in the console. The button below opens the web — signing in then launches the browser like “Sign in” on the overview.';

  @override
  String get guideCard4Title => '4 · Apple Music';

  @override
  String get guideCard4Body =>
      'There is no “sign in to Apple Music on the web” button here: Apple does not offer the same open OAuth as Spotify for this desktop app. On Windows enable OS media, play Apple Music (app) — color comes from the thumbnail the system shares when available.';

  @override
  String get guideCard5Title => 'When something fails';

  @override
  String get guideCard5Body =>
      'Spotify error after login → try Sign in again. No sound in effects → wrong input or permissions. Still only FFT → artwork integration off or nothing playing / no thumbnail.';

  @override
  String get spotifySectionTitle => 'Spotify';

  @override
  String get spotifyOAuthNote =>
      'OAuth tokens are stored on disk via ConfigRepository (sanitized); full token flow and Sign-in buttons are wired separately.';

  @override
  String get spotifyIntegrationEnabledTile => 'Spotify integration enabled';

  @override
  String get spotifyAlbumColorsApi => 'Album colors (Spotify API)';

  @override
  String get spotifyClientSecretHintStored =>
      'Leave empty to keep current; clear in settings or enter a new secret';

  @override
  String get spotifyClientSecretHintOptional => 'Optional';

  @override
  String get spotifyClearSecretButton => 'Clear client secret from draft';

  @override
  String get spotifyAccessTokenTile => 'Access token';

  @override
  String get spotifyRefreshTokenTile => 'Refresh token';

  @override
  String get spotifyTokenSet => 'Set (hidden)';

  @override
  String get spotifyOsMediaSection => 'Apple Music / YouTube Music (OS)';

  @override
  String get spotifyOsMediaBodyWin =>
      'On Windows we read artwork from the current system player (GSMTC). It usually works for Apple Music and often YouTube Music in Edge or Chrome — depends on whether the player publishes a thumbnail. Official YouTube Music API is not used here.';

  @override
  String get spotifyOsMediaBodyOther =>
      'On this OS only Spotify (OAuth) for now. GSMTC / system thumbnail is implemented for Windows.';

  @override
  String get spotifyOsAlbumColorGsmtc => 'Album color via OS media (GSMTC)';

  @override
  String get spotifyOsAlbumColorUnavailable =>
      'Album color via OS media (unavailable)';

  @override
  String get spotifyOsAlbumColorSubtitle =>
      'Used in Music mode when Spotify does not provide a color or it is disabled.';

  @override
  String get spotifyOsDominantThumbnail =>
      'Use dominant color from OS thumbnail';

  @override
  String get discWizardTitle => 'Discovery (Wi‑Fi)';

  @override
  String get discDone => 'Done';

  @override
  String get discScanning => 'Scanning…';

  @override
  String get discScanAgain => 'Scan again';

  @override
  String get discIntro =>
      'Broadcast DISCOVER_ESP32 on port 4210. Identify sends a short highlight on the strip.';

  @override
  String get discNoDevicesSnack => 'No devices replied (UDP 4210).';

  @override
  String get discEmptyAfterScan => 'No devices. Check network and firmware.';

  @override
  String discAddedSnack(Object name) {
    return 'Added: $name';
  }

  @override
  String get discResetWifiTitle => 'Reset Wi‑Fi?';

  @override
  String discResetWifiBody(Object name, Object ip) {
    return 'Device \"$name\" ($ip) clears saved Wi-Fi credentials and restarts. You must configure it again.';
  }

  @override
  String get discSendResetWifi => 'Send RESET_WIFI';

  @override
  String get discResetWifiSnackOk => 'RESET_WIFI sent.';

  @override
  String get discResetWifiSnackFail => 'Send failed.';

  @override
  String get discAddButton => 'Add';

  @override
  String get discResetWifiTooltip => 'Reset Wi‑Fi (clears saved credentials)';

  @override
  String get discIdentifyTooltip => 'Identify';

  @override
  String discListItemSubtitle(Object ip, int ledCount, Object version) {
    return '$ip · $ledCount LED · FW $version';
  }

  @override
  String zoneEditorSavedSegments(Object count) {
    return 'Saved $count segments.';
  }

  @override
  String get zoneEditorEmpty =>
      'No segments — use the LED wizard or “Add segment”.';

  @override
  String zoneEditorSegmentLine(
      Object index, Object edge, Object start, Object end, Object mon) {
    return 'Segment $index · $edge · LED $start–$end · mon $mon';
  }

  @override
  String get zoneEditorDeleteTooltip => 'Delete';

  @override
  String zoneFieldLedStart(int value) {
    return 'LED start: $value';
  }

  @override
  String zoneFieldLedEnd(int value) {
    return 'LED end: $value';
  }

  @override
  String zoneFieldMonitorIndex(int value) {
    return 'Monitor index: $value';
  }

  @override
  String get zoneFieldEdge => 'Edge';

  @override
  String zoneFieldDepthScan(int value) {
    return 'Scan depth: $value';
  }

  @override
  String get zoneFieldReverse => 'Reverse direction';

  @override
  String get zoneFieldDeviceId => 'Device';

  @override
  String zoneFieldPixelStart(int value) {
    return 'Pixel start: $value';
  }

  @override
  String zoneFieldPixelEnd(int value) {
    return 'Pixel end: $value';
  }

  @override
  String zoneFieldRefWidth(int value) {
    return 'Reference width: $value';
  }

  @override
  String zoneFieldRefHeight(int value) {
    return 'Reference height: $value';
  }

  @override
  String get zoneFieldMusicEffect => 'Music effect';

  @override
  String get zoneFieldRole => 'Frequency band';

  @override
  String get zoneEdgeTop => 'Top';

  @override
  String get zoneEdgeBottom => 'Bottom';

  @override
  String get zoneEdgeLeft => 'Left';

  @override
  String get zoneEdgeRight => 'Right';

  @override
  String get zoneMusicEffectDefault => 'Default';

  @override
  String get zoneMusicEffectSmartMusic => 'Smart music';

  @override
  String get zoneMusicEffectEnergy => 'Energy';

  @override
  String get zoneMusicEffectSpectrum => 'Spectrum';

  @override
  String get zoneMusicEffectSpectrumRotate => 'Spectrum rotate';

  @override
  String get zoneMusicEffectSpectrumPunchy => 'Spectrum punchy';

  @override
  String get zoneMusicEffectStrobe => 'Strobe';

  @override
  String get zoneMusicEffectVumeter => 'VU meter';

  @override
  String get zoneMusicEffectVumeterSpectrum => 'VU + spectrum';

  @override
  String get zoneMusicEffectPulse => 'Pulse';

  @override
  String get zoneMusicEffectReactiveBass => 'Reactive bass';

  @override
  String get zoneRoleAuto => 'Auto';

  @override
  String get zoneRoleBass => 'Bass';

  @override
  String get zoneRoleMids => 'Mids';

  @override
  String get zoneRoleHighs => 'Highs';

  @override
  String get zoneRoleAmbience => 'Ambience';

  @override
  String get zoneDeviceAllDefault => '— All / default —';

  @override
  String get zoneRefFromCapture => 'Reference size from last frame';

  @override
  String get calibWizardTitle => 'Screen calibration';

  @override
  String get calibWizardIntro =>
      'Profiles live in `screen_mode.calibration_profiles` (JSON). Full curve wizard — future detail.';

  @override
  String get calibNoProfiles => 'No profiles in config.';

  @override
  String get calibActiveProfileLabel => 'Active calibration profile';

  @override
  String get calibSaveChoice => 'Save selection';

  @override
  String calibActiveProfileSnack(Object name) {
    return 'Active profile: $name';
  }

  @override
  String get configProfileIntro =>
      'Config file is handled by ConfigRepository; this stores the current screen mode snapshot into user_screen_presets.';

  @override
  String get configProfileNameLabel => 'Preset name';

  @override
  String get configProfileExistingTitle => 'Existing presets:';

  @override
  String configProfileSavedSnack(Object name) {
    return 'Preset \"$name\" saved to user_screen_presets.';
  }

  @override
  String get defaultPresetNameDraft => 'My preset';

  @override
  String get ledWizTitle => 'LED wizard';

  @override
  String ledWizTitleWithDevice(Object name) {
    return 'LED wizard — $name';
  }

  @override
  String ledWizMonitorLocked(Object idx) {
    return 'Monitor: $idx (locked)';
  }

  @override
  String get ledWizAppendBadge => 'Mode: append segments';

  @override
  String ledWizStepProgress(Object current, Object total) {
    return 'Step $current / $total';
  }

  @override
  String get ledWizAddDeviceFirst =>
      'Add a device first (Discovery or manually).';

  @override
  String get ledWizDeviceLabel => 'Device';

  @override
  String get ledWizStripSides => 'Strip sides';

  @override
  String get ledWizRefMonitorLabel => 'Reference monitor (native list)';

  @override
  String ledWizMonitorLine(Object idx, Object w, Object h, Object suffix) {
    return 'Monitor $idx — $w×$h$suffix';
  }

  @override
  String get ledWizPrimarySuffix => ' · primary';

  @override
  String get ledWizMonitorManualLabel =>
      'Monitor index (MSS, manual — list unavailable)';

  @override
  String get ledWizAppendSegmentsTitle =>
      'Append to existing segments (multi-monitor)';

  @override
  String get ledWizAppendSegmentsSubtitle =>
      'Otherwise only this device’s segments are cleared.';

  @override
  String ledWizLedIndexSlider(Object n) {
    return 'LED index $n';
  }

  @override
  String ledWizLedIndexRow(Object n) {
    return 'LED index: $n';
  }

  @override
  String get ledWizFinishBody => 'Segments are computed from stored indices.';

  @override
  String get ledWizStartCalibration => 'Start calibration';

  @override
  String get ledWizPickOneSideSnack => 'Select at least one side.';

  @override
  String get ledWizSummary => 'Summary';

  @override
  String get ledWizNext => 'Next';

  @override
  String get ledWizSaveClose => 'Save and close';

  @override
  String ledWizSavedSnack(Object segments, Object led, Object mon) {
    return 'Saved $segments segments, LED $led, monitor $mon.';
  }

  @override
  String get ledWizConfigTitle => 'Configuration';

  @override
  String get ledWizConfigBody =>
      'In Settings → Devices set LED count to at least an upper estimate (max 2000). Before calibration the app sends this count on USB. Then pick sides and monitor — move the green LED to each physical corner.';

  @override
  String get ledWizFinishTitle => 'Done';

  @override
  String get ledWizLeftStartTitle => 'Left side — start';

  @override
  String get ledWizLeftStartBody =>
      'Move the slider so the green LED is at the start of the left side (usually bottom).';

  @override
  String get ledWizLeftEndTitle => 'Left side — end';

  @override
  String get ledWizLeftEndBody =>
      'Move the slider so the green LED is at the end of the left side (usually top).';

  @override
  String get ledWizTopStartTitle => 'Top side — start';

  @override
  String get ledWizTopStartBody =>
      'Move the slider so the green LED is at the start of the top edge (left).';

  @override
  String get ledWizTopEndTitle => 'Top side — end';

  @override
  String get ledWizTopEndBody =>
      'Move the slider so the green LED is at the end of the top edge (right).';

  @override
  String get ledWizRightStartTitle => 'Right side — start';

  @override
  String get ledWizRightStartBody =>
      'Move the slider so the green LED is at the start of the right side (usually top).';

  @override
  String get ledWizRightEndTitle => 'Right side — end';

  @override
  String get ledWizRightEndBody =>
      'Move the slider so the green LED is at the end of the right side (usually bottom).';

  @override
  String get ledWizBottomStartTitle => 'Bottom side — start';

  @override
  String get ledWizBottomStartBody =>
      'Move the slider so the green LED is at the start of the bottom edge (right).';

  @override
  String get ledWizBottomEndTitle => 'Bottom side — end';

  @override
  String get ledWizBottomEndBody =>
      'Move the slider so the green LED is at the end of the bottom edge (left).';

  @override
  String get fwTitle => 'ESP firmware';

  @override
  String get fwIntro =>
      'CI can publish a manifest on GitHub Pages. Load the manifest, download .bin files and flash via USB (esptool in PATH) or run OTA over Wi‑Fi (UDP command). Switching to dual OTA layout needs one full USB flash first.';

  @override
  String get fwManifestUrlLabel => 'Manifest URL (GitHub Pages)';

  @override
  String get fwManifestUrlHint =>
      'https://example.github.io/ambilight/firmware/latest/';

  @override
  String get fwManifestHelper =>
      'Default from global settings; /manifest.json is appended if missing.';

  @override
  String get fwLoadManifest => 'Load manifest';

  @override
  String get fwDownloadBins => 'Download binaries';

  @override
  String fwVersionChipLine(Object version, Object chip) {
    return 'Version: $version · chip: $chip';
  }

  @override
  String fwPartBullet(Object file, Object offset) {
    return '• $file @ $offset';
  }

  @override
  String fwOtaUrlLine(Object url) {
    return 'OTA URL: $url';
  }

  @override
  String get fwFlashUsbTitle => 'Flash via USB (COM)';

  @override
  String get fwRefreshPortsTooltip => 'Refresh port list';

  @override
  String fwSerialPortsError(Object error) {
    return 'Cannot load serial ports: $error';
  }

  @override
  String get fwSerialPortLabel => 'Serial port';

  @override
  String get fwNoComHintDriver => 'Try Refresh or check permissions / driver.';

  @override
  String get fwNoComEmpty => 'No COM — connect ESP USB';

  @override
  String get fwFlashEsptool => 'Flash with esptool';

  @override
  String get fwOtaUdpTitle => 'OTA over Wi‑Fi (UDP)';

  @override
  String get fwDeviceIpLabel => 'Device IP';

  @override
  String get fwOtaHintNeedManifest =>
      'Load the manifest first — OTA HTTPS URL is unknown without it.';

  @override
  String get fwOtaHintMissingUrl =>
      'Manifest has no OTA URL — add root ota_http_url or parts with app .bin URLs.';

  @override
  String fwOtaHintWillUse(Object url) {
    return 'OTA will use: $url';
  }

  @override
  String get fwVerifyUdpPong => 'Verify reachability (UDP PONG)';

  @override
  String get fwSendOtaHttp => 'Send OTA_HTTP';

  @override
  String get fwStatusCacheFail => 'Cannot create cache (path_provider).';

  @override
  String get fwStatusEnterManifestUrl =>
      'Enter manifest URL (e.g. …/firmware/latest/).';

  @override
  String get fwStatusLoadingManifest => 'Loading manifest…';

  @override
  String fwStatusManifestOk(Object version, Object chip, Object count) {
    return 'Manifest OK — version $version, chip $chip, $count files.';
  }

  @override
  String fwStatusManifestError(Object error) {
    return 'Manifest error: $error';
  }

  @override
  String get fwStatusDownloading => 'Downloading…';

  @override
  String fwStatusDownloadedTo(Object path) {
    return 'Downloaded to: $path';
  }

  @override
  String fwStatusDownloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get fwStatusPickCom => 'Pick a COM / serial port.';

  @override
  String get fwStatusDownloadBinsFirst =>
      'Download binaries first (button above).';

  @override
  String get fwStatusFlashing =>
      'Flashing via esptool… (stop app stream on the same COM)';

  @override
  String fwStatusFlashOk(Object log) {
    return 'Flash OK.\\n$log';
  }

  @override
  String fwStatusFlashFail(Object log) {
    return 'Flash failed.\\n$log';
  }

  @override
  String fwStatusException(Object error) {
    return 'Exception: $error';
  }

  @override
  String get fwStatusEnterIpProbe => 'Enter device IP for probe (UDP PONG).';

  @override
  String get fwStatusProbing => 'Probing device (UDP, max 2 s)…';

  @override
  String get fwStatusProbeTimeout =>
      'No reply in time — offline, wrong IP/port/firewall, or firmware without DISCOVER reply.';

  @override
  String fwStatusProbeOnline(Object name, Object led, Object version) {
    return 'Online: $name · LED $led · version $version (ESP32_PONG).';
  }

  @override
  String get fwStatusNoOtaUrl =>
      'Manifest has no usable OTA URL (ota_http_url or derived parts[].url).';

  @override
  String get fwStatusEnterIpEsp => 'Enter ESP IP (Wi‑Fi).';

  @override
  String fwStatusSendingOta(Object ip, Object port) {
    return 'Sending OTA_HTTP to $ip:$port…';
  }

  @override
  String get fwStatusOtaSent =>
      'Command sent. ESP downloads firmware and reboots (check log / LEDs).';

  @override
  String get fwStatusUdpFailed => 'UDP send failed.';

  @override
  String get fwStatusOtaInvalidTarget => 'Invalid device IP address.';

  @override
  String get fwStatusOtaUrlTooShort =>
      'OTA URL is too short (firmware requires at least 12 characters).';

  @override
  String get fwStatusOtaUrlTooLong =>
      'OTA URL is too long for the device (max 1300 characters).';

  @override
  String get fwStatusOtaInvalidChars =>
      'OTA URL contains characters the device rejects (control codes, etc.).';

  @override
  String get fwStatusOtaBadScheme =>
      'OTA URL must start with https:// or http:// (same rule as the device).';

  @override
  String get fwStatusOtaPayloadInvalid =>
      'OTA command does not pass device-side checks.';

  @override
  String get fwProgressUsbTitle => 'USB flash';

  @override
  String get fwProgressUsbSubtitle =>
      'Writing via esptool — stop the app stream on the same COM port while flashing.';

  @override
  String get fwProgressOtaTitle => 'OTA update';

  @override
  String get fwProgressOtaSending => 'Sending OTA_HTTP to the device…';

  @override
  String get fwProgressOtaAwaitNotify => 'Waiting for lamp confirmation…';

  @override
  String fwProgressOtaSuccessNotify(String version) {
    return 'Update complete — firmware $version. The strip should briefly pulse purple.';
  }

  @override
  String get fwProgressOtaDevicePhase =>
      'The device is downloading and installing firmware — watch the strip LEDs. You can close this panel; the lamp keeps updating.';

  @override
  String get fwProgressFlashCancelled =>
      'Flash cancelled (esptool was stopped).';

  @override
  String get fwFillFromDevices => 'Fill from Devices';

  @override
  String get fwFillFromDevicesTooltip =>
      'Copy IP and UDP port from the first Wi-Fi device in your list (Devices tab).';

  @override
  String get fwDebugToolsTitle => 'Debugging tools (lamp)';

  @override
  String get fwDebugReject88Body =>
      'Reject DHCP addresses in 192.168.88.0/24 (third octet .88). Stored on the device (NVS key dbg_rej88). Same toggle exists on the lamp’s SoftAP setup page and via UDP DEBUG_REJ88 0|1|?.';

  @override
  String get fwDebugReject88Query => 'Query lamp';

  @override
  String get fwDebugReject88Enable => 'Enable reject';

  @override
  String get fwDebugReject88Disable => 'Disable reject';

  @override
  String get fwDebugReject88Unknown => 'unknown (no reply or old firmware)';

  @override
  String get fwDebugReject88On => 'on';

  @override
  String get fwDebugReject88Off => 'off';

  @override
  String fwDebugReject88Current(String state) {
    return 'On device: $state';
  }

  @override
  String get fwDebugReject88SetOk => 'Setting applied (NVS on lamp).';

  @override
  String get fwDebugReject88SetFail =>
      'UDP command failed (offline, wrong IP/port, or firmware without DEBUG_REJ88).';

  @override
  String get fwStatusProbeRejectOn => ' · reject 192.168.88.x: on';

  @override
  String get fwStatusProbeRejectOff => ' · reject 192.168.88.x: off';

  @override
  String get fwStatusNoWifiDevice =>
      'No Wi-Fi device with an IP in your list — add one under Devices.';

  @override
  String fwStatusFilledFromDevice(Object name, Object ip, Object port) {
    return 'Filled from “$name”: $ip:$port.';
  }

  @override
  String get pcHealthHeaderTitle => 'PC Health';

  @override
  String get pcHealthHeaderSubtitle =>
      'Strip edge colors from system metrics. Pick PC Health on the overview to drive outputs.';

  @override
  String get pcHealthHintWeb => 'System metrics are not read on the web.';

  @override
  String get pcHealthHintMac =>
      'macOS: CPU usage is estimated from load average / cores; disk from df; network from netstat byte totals. CPU temperature without tools like powermetrics may stay 0. NVIDIA GPU only if nvidia-smi is in PATH.';

  @override
  String get pcHealthHintLinux =>
      'Linux: disk_usage metric is not filled yet in the collector (0). Other values from /proc and thermal zones.';

  @override
  String get pcHealthHintWindows =>
      'Windows: disk uses first fixed disk; CPU temperature from ACPI WMI when available.';

  @override
  String get pcHealthEnabledTile => 'PC Health enabled';

  @override
  String pcHealthUpdateInterval(Object ms) {
    return 'Update interval: $ms ms';
  }

  @override
  String pcHealthGlobalBrightness(Object v) {
    return 'Global brightness: $v';
  }

  @override
  String get pcHealthLivePreviewTitle => 'Live value preview';

  @override
  String get pcHealthNotTrackingHint =>
      'Active mode is not PC Health — showing last sample or manual measurement.';

  @override
  String get pcHealthMeasuring => 'Measuring…';

  @override
  String pcHealthMetricsTitle(Object count) {
    return 'Metrics ($count)';
  }

  @override
  String get pcHealthRestoreDefaults => 'Restore defaults';

  @override
  String get pcHealthStagingDebug =>
      '[staging] PC Health preview + metric editor';

  @override
  String get pcHealthDialogNew => 'New metric';

  @override
  String get pcHealthDialogEdit => 'Edit metric';

  @override
  String get pcHealthTileEnabled => 'Enabled';

  @override
  String get pcHealthFieldName => 'Name';

  @override
  String get pcHealthFieldMetric => 'Metric';

  @override
  String get pcHealthFieldMin => 'Min';

  @override
  String get pcHealthFieldMax => 'Max';

  @override
  String get pcHealthFieldColorScale => 'Color scale';

  @override
  String get pcHealthFieldBrightness => 'Brightness';

  @override
  String pcHealthBrightnessValue(Object v) {
    return 'Brightness: $v';
  }

  @override
  String pcHealthBrightnessMin(Object v) {
    return 'Brightness min: $v';
  }

  @override
  String pcHealthBrightnessMax(Object v) {
    return 'Brightness max: $v';
  }

  @override
  String get pcHealthMetricFallbackName => 'Metric';

  @override
  String get pcHealthEditTooltip => 'Edit';

  @override
  String get pcHealthDeleteTooltip => 'Delete';

  @override
  String get pcMetricCpuUsage => 'CPU usage';

  @override
  String get pcMetricRamUsage => 'RAM';

  @override
  String get pcMetricNetUsage => 'Network (estimate)';

  @override
  String get pcMetricCpuTemp => 'CPU temperature';

  @override
  String get pcMetricGpuUsage => 'GPU usage';

  @override
  String get pcMetricGpuTemp => 'GPU temperature';

  @override
  String get pcMetricDiskUsage => 'Disk';

  @override
  String get smartHomeTitle => 'Smart home';

  @override
  String get smartHomeIntro =>
      'Home Assistant: direct light.* control via REST. Apple Home (HomeKit): native on macOS. Google Home: no local public API — link via Home Assistant (below).';

  @override
  String get smartPushColorsTile => 'Push colors to smart lights';

  @override
  String get smartPushColorsSubtitle =>
      'Enable after configuring HA / HomeKit fixtures below.';

  @override
  String get smartHaSection => 'Home Assistant';

  @override
  String get smartHaTokenHelper =>
      'Stored outside default.json (application support / ha_long_lived_token.txt).';

  @override
  String get smartHaTrustCertTile => 'Trust custom HTTPS certificate';

  @override
  String get smartHaTrustCertSubtitle =>
      'Only for local HA with self-signed certs.';

  @override
  String get smartTestConnection => 'Test connection';

  @override
  String get smartAddHaLight => 'Add light from HA';

  @override
  String get smartHaFillUrlToken => 'Fill URL and Home Assistant token first.';

  @override
  String get smartHaPickLightTitle => 'Add light from Home Assistant';

  @override
  String get smartMaxHzLabel => 'Max Hz per light';

  @override
  String get smartBrightnessCapLabel => 'Brightness cap %';

  @override
  String smartHaSaturationLabel(Object v) {
    return 'Home Assistant color saturation: $v%';
  }

  @override
  String get smartHaSaturationHint =>
      '100% = same as the strip. Lower washes colors toward white; above 100% boosts vividness before light.turn_on (HSV).';

  @override
  String get smartHaMusicReactiveTitle => 'Music: faster HA updates on beat';

  @override
  String get smartHaMusicReactiveSubtitle =>
      'Shortens the per-light throttle on drum hits in Music mode, even if the virtual-room wave does not use music.';

  @override
  String smartHaBeatBoostLabel(Object v) {
    return 'Music: brightness spike on beat (+$v%)';
  }

  @override
  String get smartHaBeatBoostHint =>
      'Adds up to this many percent brightness points on each detected beat edge (0 = off).';

  @override
  String get musicHaIntegrationFootnote =>
      'Home Assistant: tune saturation and beat-linked updates under Settings → Smart Home.';

  @override
  String get smartHomeKitSection => 'Apple Home (HomeKit)';

  @override
  String get smartHomeKitNonMac =>
      'Native HomeKit is macOS-only. On Windows/Linux add lights to Home Assistant (HomeKit Device / Matter bridge) and control via HA above.';

  @override
  String get smartHomeKitLoading => 'Loading HomeKit…';

  @override
  String get smartHomeKitEmpty => 'No HomeKit lights (or missing permission).';

  @override
  String smartHomeKitCount(Object count) {
    return '$count lights.';
  }

  @override
  String get smartRefreshHomeKit => 'Refresh HomeKit light list';

  @override
  String get smartGoogleSection => 'Google Home';

  @override
  String get smartGoogleBody =>
      'Google does not let desktop apps control Google Home lights directly. Reliable path: install Home Assistant, add Hue / Nest / … there and link HA with Google Assistant.';

  @override
  String get smartGoogleDocButton => 'Docs: Google Assistant + HA';

  @override
  String get smartMyHaButton => 'My Home Assistant';

  @override
  String get smartVirtualRoomSection => 'Virtual room';

  @override
  String get smartVirtualRoomIntro =>
      'Place the TV, yourself and lights on the plan. The cone starts at your icon (semi-transparent overlay) and shows viewing direction toward the TV plus the angle slider. Effects modulate brightness using this layout; HA/HomeKit still receive mapped colors each frame.';

  @override
  String smartFixturesTitle(Object count) {
    return 'Configured lights ($count)';
  }

  @override
  String get smartFixturesEmpty => 'None yet — add from HA or HomeKit.';

  @override
  String get smartFixtureRemoveTooltip => 'Remove';

  @override
  String smartFixtureHaLine(Object id) {
    return 'HA: $id';
  }

  @override
  String smartFixtureHkLine(Object id) {
    return 'HomeKit: $id';
  }

  @override
  String get smartBindingLabel => 'Color mapping';

  @override
  String get smartBindingGlobalMean => 'Average of all LEDs';

  @override
  String get smartBindingLedRange => 'LED range on device';

  @override
  String get smartBindingScreenEdge => 'Screen edge';

  @override
  String get smartBindingLedStartField => 'LED start (index)';

  @override
  String get smartBindingLedEndField => 'LED end (index)';

  @override
  String get smartDeviceIdOptional => 'device_id (empty = first device)';

  @override
  String get smartEdgeLabel => 'Edge';

  @override
  String get smartMonitorIndexBinding => 'monitor_index (0=desktop, 1…)';

  @override
  String get smartHaStatusTesting => 'Testing…';

  @override
  String smartHaStatusOk(Object msg) {
    return 'OK: $msg';
  }

  @override
  String smartHaStatusErr(Object msg) {
    return 'Error: $msg';
  }

  @override
  String get vrWaveTitle => 'Room wave';

  @override
  String get vrWaveSubtitle =>
      'Brightness modulation by distance from TV and frame time';

  @override
  String vrWaveStrength(Object pct) {
    return 'Wave strength: $pct %';
  }

  @override
  String get vrWaveSpeed => 'Wave speed';

  @override
  String get vrDistanceSensitivity => 'Distance sensitivity';

  @override
  String vrViewingAngle(Object deg) {
    return 'Viewing angle offset toward TV: $deg°';
  }

  @override
  String get vrTooltipTv => 'TV (drag)';

  @override
  String get vrTooltipYou => 'You (drag)';

  @override
  String get deviceFwTemporalSectionTitle => 'Firmware temporal smoothing';

  @override
  String get deviceFwTemporalOff => 'Off';

  @override
  String get deviceFwTemporalSmooth => 'Smooth';

  @override
  String get deviceFwTemporalSnap => 'Zero-lag snap';

  @override
  String get deviceFwTemporalApply => 'Send to device';

  @override
  String get deviceFwTemporalSnackOk => 'Firmware smoothing mode updated.';

  @override
  String get deviceFwTemporalSnackFail =>
      'Could not confirm the command (timeout or old firmware).';

  @override
  String get deviceFwTemporalHint =>
      'Separate from screen interpolation below. Avoid maxing out both firmware smooth and strong PC interpolation.';

  @override
  String get settingsPcSmoothingFootnote =>
      'Interpolation here runs on the PC before UDP/serial only. For Wi-Fi chunk size at build time see dart-define AMBI_UDP_OPCODE06_CHUNK_PIXELS (UdpAmbilightProtocol).';

  @override
  String get settingsGlobalPcUdpChunkHint =>
      'Optional build-time tuning: --dart-define=AMBI_UDP_OPCODE06_CHUNK_PIXELS=… (32–498) affects UDP packet size when the strip needs 0x06 chunks.';
}
