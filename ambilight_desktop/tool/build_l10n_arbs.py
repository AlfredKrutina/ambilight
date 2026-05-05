#!/usr/bin/env python3
"""One-off generator for app_en.arb / app_cs.arb — run from repo: python tool/build_l10n_arbs.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "lib" / "l10n"


def main() -> None:
    en: dict[str, str | dict] = {"@@locale": "en"}

    def e(k: str, v: str, meta: dict | None = None) -> None:
        en[k] = v
        if meta:
            en[f"@{k}"] = meta

    # Core
    e("appTitle", "AmbiLight")
    e("languageLabel", "Language")
    e("languageSystem", "System default")
    e("languageEnglish", "English")
    e("languageCzech", "Czech")
    for k, v in [
        ("cancel", "Cancel"),
        ("save", "Save"),
        ("close", "Close"),
        ("done", "Done"),
        ("next", "Next"),
        ("back", "Back"),
        ("skip", "Skip"),
        ("settings", "Settings"),
        ("help", "Help"),
        ("add", "Add"),
        ("delete", "Delete"),
        ("edit", "Edit"),
        ("verify", "Verify"),
        ("refresh", "Refresh"),
        ("send", "Send"),
        ("remove", "Remove"),
        ("scanning", "Scanning…"),
        ("measuring", "Measuring…"),
        ("findingCom", "Finding COM…"),
    ]:
        e(k, v)

    # Nav / shell
    e("navOverview", "Overview")
    e("navDevices", "Devices")
    e("navSettings", "Settings")
    e("navAbout", "About")
    e("navOverviewTooltip", "Home — modes and device preview")
    e("navDevicesTooltip", "Discovery, strips and calibration")
    e("navSettingsTooltip", "Modes, integrations and config backup")
    e("navAboutTooltip", "Version and basics")
    e("navigationSection", "Navigation")
    e("outputOn", "Output on")
    e("outputOff", "Output off")
    e("tooltipColorsOn", "Stop sending colors to strips")
    e("tooltipColorsOff", "Start sending colors to strips")
    e("allOutputsOnline", "All output devices connected ({online}/{total}).", {"placeholders": {"online": {}, "total": {}}})
    e("someOutputsOffline", "Some outputs offline ({online}/{total}) — check USB or Wi‑Fi.", {"placeholders": {"online": {}, "total": {}}})
    e("footerNoOutputs", "No output devices (optional)")
    e("footerUsbOne", "USB")
    e("footerUsbMany", "{count}× USB", {"placeholders": {"count": {}}})
    e("footerWifiOne", "Wi‑Fi")
    e("footerWifiMany", "{count}× Wi‑Fi", {"placeholders": {"count": {}}})

    e("pathCopiedSnackbar", "Path copied to clipboard")
    e("aboutTitle", "About")
    e("aboutSubtitle", "AmbiLight Desktop — LED strips from Windows (USB and Wi‑Fi).")
    e(
        "aboutBody",
        "Desktop Flutter client aligned with ESP32 firmware. In-app wizards cover strips, screen segments and calibration.",
    )
    e("aboutAppName", "AmbiLight Desktop")
    e("showOnboardingAgain", "Show onboarding again")
    e("crashLogFileLabel", "Crash / diagnostic log file:")
    e("copyLogPath", "Copy log path")
    e("debugSection", "Debug")
    e(
        "engineTickDebug",
        "Engine frame counter: {tick}\n(Updates on device connection changes, new screen frame, or ~4 s interval.)",
        {"placeholders": {"tick": {}}},
    )
    e("versionLoadError", "Could not load version: {error}", {"placeholders": {"error": {}}})
    e("versionLine", "Version: {version} ({build})", {"placeholders": {"version": {}, "build": {}}})
    e("buildLine", "Build: {mode} · channel: {channel}", {"placeholders": {"mode": {}, "channel": {}}})
    e("gitLine", "Git: {sha}", {"placeholders": {"sha": {}}})

    e("semanticsCloseScanOverlay", "Close capture region preview")
    e("scanZonesChip", "Zone preview")
    e("bootstrapFailed", "App failed to start: {detail}", {"placeholders": {"detail": {}}})
    e("configLoadFailed", "Could not load settings, using defaults: {detail}", {"placeholders": {"detail": {}}})
    e("faultUiError", "UI error: {detail}", {"placeholders": {"detail": {}}})
    e("faultUncaughtAsync", "Uncaught error in async code.")
    e("errorWidgetTitle", "Error rendering a widget. The app keeps running.\n\n")
    e("closeBannerTooltip", "Dismiss")
    e("settingsDevicesSaveFailed", "Saving device list failed: {detail}", {"placeholders": {"detail": {}}})
    e("semanticsSelected", ", selected")

    # Home
    e("homeOverviewTitle", "Overview")
    e(
        "homeOverviewSubtitle",
        "Turn on output, pick a mode and check connectivity. Details live under Devices and Settings.",
    )
    e("homeModeTitle", "Mode")
    e("homeModeSubtitle", "Tap a tile to change the active mode. The pencil opens Settings for that mode.")
    e(
        "homeIntegrationsTitle",
        "Integrations",
    )
    e(
        "homeIntegrationsSubtitle",
        "Music (Spotify OAuth plus optional OS player colors), Home Assistant and ESP firmware — edit each under Settings.",
    )
    e("homeDevicesTitle", "Devices")
    e(
        "homeDevicesSubtitle",
        "Quick status. Strip setup, discovery and networking are under Devices in the sidebar.",
    )
    e(
        "homeDevicesEmpty",
        "No output devices yet — normal until you connect a strip.\n\n"
        "You can still tune modes, presets and backups. To send colors, add a device under Devices (Discovery or manual).",
    )
    e("modeLightTitle", "Light")
    e("modeLightSubtitle", "Static effects, zones, breathing")
    e("modeScreenTitle", "Screen")
    e("modeScreenSubtitle", "Ambilight from monitor capture")
    e("modeMusicTitle", "Music")
    e("modeMusicSubtitle", "FFT, melody, colors")
    e("modePcHealthTitle", "PC Health")
    e("modePcHealthSubtitle", "Temps, load, visualization")
    e("modeSettingsTooltip", 'Settings for mode "{mode}"', {"placeholders": {"mode": {}}})
    e("homeLedOutputTitle", "LED output")
    e("homeLedOutputOnBody", "Colors are sent to all active devices.")
    e("homeLedOutputOffBody", "Off — strips receive black.")
    e("homeServiceTitle", "Service")
    e("homeBackgroundTitle", "Runs in background")
    e(
        "homeBackgroundBody",
        "The app continuously prepares colors for strips. Status changes when you switch modes or connect devices.",
    )
    e("integrationSettingsButton", "Settings")
    e("musicCardTitle", "Music")
    e("spotifyConnected", "Spotify: connected")
    e("spotifyDisconnected", "Spotify: not connected")
    e("spotifyHintNeedClientId", "Add Client ID under Settings → Spotify.")
    e(
        "spotifyHintLogin",
        "“Sign in” opens the browser; on Windows you can also take colors from the OS media player (see help).",
    )
    e("spotifyOAuthTitle", "Spotify integration (OAuth)")
    e("spotifyOAuthSubtitle", "Enables account polling; disable to stop polling.")
    e("spotifyAlbumColorsTitle", "Album colors via Spotify")
    e("spotifyAlbumColorsSubtitle", "In Music mode, preferred over FFT when the API returns artwork.")
    e("signIn", "Sign in")
    e("signOut", "Sign out")

    e("haCardTitle", "Home Assistant")
    e("haStatusOff", "Integration disabled.")
    e("haStatusOnOk", "On · {count} lights in map.", {"placeholders": {"count": {}}})
    e("haStatusOnNeedUrl", "On — add URL and token in Settings.")
    e("haDetailOk", "REST API to Home Assistant; map engine colors to light.* entities.")
    e("haDetailNeedUrl", "First add your instance URL and long-lived token (HA user profile).")

    e("fwCardTitle", "Firmware")
    e("fwManifestLabel", "Manifest (OTA)")
    e("fwManifestHint", "Download binaries, OTA command via UDP or flash via USB (esptool).")

    e("kindUsb", "USB")
    e("kindWifi", "Wi‑Fi")
    e("deviceConnected", "connected")
    e("deviceDisconnected", "not connected")
    e("deviceLedSubtitle", "{kind} · {count} LED", {"placeholders": {"kind": {}, "count": {}}})
    e("deviceStripStateLine", "{info} · {state}", {"placeholders": {"info": {}, "state": {}}})

    # Settings chrome
    e("settingsPageTitle", "Settings")
    e("settingsRailSubtitle", "Pick a topic on the left — no Apply button needed.")
    e(
        "settingsPersistHint",
        "The engine updates immediately; disk save follows shortly after your last change. Screen/music presets are not changed.",
    )
    e("settingsSidebarBasics", "Basics")
    e("settingsSidebarModes", "Modes")
    e("settingsSidebarIntegrations", "Integrations")
    for k, v in [
        ("tabGlobal", "Global"),
        ("tabDevices", "Devices"),
        ("tabLight", "Light"),
        ("tabScreen", "Screen"),
        ("tabMusic", "Music"),
        ("tabPcHealth", "PC Health"),
        ("tabSpotify", "Spotify"),
        ("tabSmartHome", "Smart Home"),
        ("tabFirmware", "Firmware"),
    ]:
        e(k, v)

    e("globalSectionTitle", "Global")
    e(
        "globalSectionSubtitle",
        "Startup behavior, appearance and performance. Import/export below.",
    )
    e("startModeLabel", "Default mode on startup")
    e("startModeLight", "Light")
    e("startModeScreen", "Screen (Ambilight)")
    e("startModeMusic", "Music")
    e("startModePcHealth", "PC Health")
    e("themeLabel", "App appearance")
    e("themeHelper", "Dark blue = legacy default look. SnowRunner = neutral dark gray.")
    e("themeSnowrunner", "Dark (SnowRunner)")
    e("themeDarkBlue", "Dark blue")
    e("themeLight", "Light")
    e("themeCoffee", "Coffee")
    e("uiAnimationsTitle", "UI animations")
    e(
        "uiAnimationsSubtitle",
        "Short transitions between sections. Disable when tweaking repeatedly; also respects system reduced motion.",
    )
    e("performanceModeTitle", "Performance mode")
    e(
        "performanceModeSubtitle",
        "Loop ~25 Hz, screen capture every 3rd tick, longer Spotify / PC Health intervals and gentler USB queue. "
        "When performance mode is off, Light mode runs faster (~125 Hz per strip with visible window; Wi‑Fi UDP without queue). "
        "“UI animations” only affects Material transitions.",
    )
    e("autostartTitle", "Launch with Windows")
    e("autostartSubtitle", "Start the app after signing in.")
    e("startMinimizedTitle", "Start minimized")
    e("captureMethodLabel", "Screen capture method (advanced)")
    e("captureMethodHint", "e.g. mss, dxcam")
    e("captureMethodHelper", "Keep default if capture works.")

    # Onboarding
    pages_en = [
        (
            "onboardWelcomeTitle",
            "Welcome to AmbiLight",
            "This app drives your LED strips from Windows — USB (serial) or network (UDP). "
            "ESP32 firmware stays compatible with older clients; this UI is clearer.",
        ),
        (
            "onboardHowTitle",
            "How it works",
            "AmbiLight takes colors from the screen, microphone, PC sensors or static effects and sends RGB data to the controller. "
            "The top bar toggles output — when off, strips stop receiving new commands.",
        ),
        (
            "onboardOutputTitle",
            "Output on / off",
            'The “Output on” button in the header is the main switch: turn it off to leave strips idle or while troubleshooting. '
            "Turn it on once devices and mode are set.",
        ),
        (
            "onboardModesTitle",
            "Modes",
            "Light — static colors and effects. Screen — ambilight from monitor capture (segments and edge depth in Settings). "
            "Music — FFT and melody from mic or system. PC Health — temps and load visualization.",
        ),
        (
            "onboardDevicesTitle",
            "Devices",
            "On Devices you add strips, run discovery and set LED count, offset and default monitor. "
            "USB uses COM and baud; Wi‑Fi needs IP and UDP port (same as firmware).",
        ),
        (
            "onboardScreenTitle",
            "Screen and zones",
            "Under Settings → Screen set edge depth, padding and per-strip segments. "
            "The capture-region preview overlay helps verify geometry.",
        ),
        (
            "onboardMusicTitle",
            "Music and Spotify",
            "Music can use microphone or sound card output. Spotify is optional — get Client ID from Spotify Developer; "
            "detailed steps are next to Spotify settings.",
        ),
        (
            "onboardSmartTitle",
            "PC Health and smart lights",
            "PC Health reads sensors (temps, load) and maps them to colors. Smart lights supports Home Assistant: "
            "after URL and token you can mirror colors to other lamps.",
        ),
        (
            "onboardFirmwareTitle",
            "Settings and firmware",
            "Global settings include theme, performance mode, capture method and firmware manifest (OTA links). "
            "Export/import JSON — back up before experiments.",
        ),
        (
            "onboardReadyTitle",
            "You are ready",
            "You can reopen this guide under About. Suggested flow: add device → verify output → pick Screen or Light → tune brightness in Settings.",
        ),
    ]
    for title_k, _t, body in pages_en:
        body_k = title_k.replace("Title", "Body")
        e(title_k, _t)
        e(body_k, body)

    e("onboardStartUsing", "Start using")
    e("onboardProgress", "{current} / {total}", {"placeholders": {"current": {}, "total": {}}})

    # Devices page & wizards (subset)
    e("devicesPageTitle", "Devices")
    e("devicesActionsTitle", "Actions")
    e("discoveryWizardLabel", "Discovery — wizard")
    e("segmentsLabel", "Segments")
    e("calibrationLabel", "Calibration")
    e("screenPresetLabel", "Screen preset")
    e("addWifiManual", "Add Wi‑Fi manually")
    e("findAmbilightCom", "Find Ambilight (COM)")
    e(
        "devicesIntro",
        "Manage strips: discovery, Wi‑Fi setup and calibration. Saving writes config and reconnects transports.",
    )
    e("saveDeviceTitle", "Save device")
    e("invalidIp", "Invalid IP address.")
    e("pongTimeout", "PONG timed out.")
    e("pongResult", "PONG: FW {version}, LED {leds}", {"placeholders": {"version": {}, "leds": {}}})
    e("verifyPong", "Verify PONG")
    e("enterValidIpv4", "Enter a valid IPv4 address.")
    e("deviceSaved", "Device saved.")
    e("resetWifiTitle", "Reset Wi‑Fi?")
    e(
        "resetWifiBody",
        "Sends RESET_WIFI over UDP to the device. Use only when you know what you are doing.",
    )
    e("sendResetWifi", "Send RESET_WIFI")
    e("resetWifiSent", "RESET_WIFI sent.")
    e("resetWifiFailed", "Send failed.")
    e("removeFailed", "Remove failed: {error}", {"placeholders": {"error": {}}})
    e("deviceRemoved", "Device “{name}” removed.", {"placeholders": {"name": {}}})
    e("pongMissing", "PONG did not arrive.")
    e("firmwareFromPong", "Firmware (from PONG): {version}", {"placeholders": {"version": {}}})
    e("comScanHandshake", "Scanning COM with handshake 0xAA / 0xBB…")
    e("comScanNoReply", "No port replied (Ambilight handshake).")
    e("serialPortSet", "Serial port set: {port}", {"placeholders": {"port": {}}})
    e("firmwareLabel", "Firmware: {version}", {"placeholders": {"version": {}}})

    e("discoveryTitle", "Discovery (D9)")
    e("discoveryRescan", "Scan again")
    e("discoveryScanning", "Scanning…")
    e("discoveryNoReply", "No device replied (UDP 4210).")
    e("discoveryAdded", "Added: {name}", {"placeholders": {"name": {}}})
    e("discoveryAdd", "Add")
    e("discoverySelectHint", "Scan the LAN on UDP 4210; identified devices appear below.")

    # Zone editor
    e("zoneEditorTitle", "Zone / segment editor (D11)")
    e("zoneEditorAddSegment", "Add segment")
    e("zoneEditorSaved", "Saved {count} segments.", {"placeholders": {"count": {}}})
    e("zoneEditorIntro", "Segments map LED ranges to screen edges and monitors.")
    e("zoneEditorSegmentTitle", "Segment {index} · {edge} · LED {ledStart}–{ledEnd} · mon {monitor}", {"placeholders": {"index": {}, "edge": {}, "ledStart": {}, "ledEnd": {}, "monitor": {}}})
    e("refDimsFromCapture", "Ref. dimensions from last capture")
    e("dropdownAllDefault", "— all / default —")

    # Guides — Spotify
    e("guideMusicTitle", "Music & Spotify")
    e("guideBrowserFailed", "Could not open the browser.")
    e("guideNeedClientIdFirst", "First enter Client ID under Settings → Spotify (see button above).")
    e("guideClose", "Close")
    e("guideOpenSpotifyDev", "Open Spotify Developer")
    e("guideSpotifyBrowserLogin", "Sign in to Spotify in browser")
    e("guideSectionSound", "1 · Mode and audio")
    e("guideSectionAlbum", "2 · Album color")
    e("guideSectionSpotify", "3 · Spotify")
    e("guideSectionApple", "4 · Apple Music")
    e("guideSectionTrouble", "When something fails")

    # Config backup
    e("backupTitle", "Configuration backup")
    e("backupExport", "Export JSON…")
    e("backupImport", "Import JSON…")
    e("backupExported", "Configuration exported.")
    e("backupImported", "Configuration imported.")
    e("backupInvalid", "Invalid configuration file.")

    # Spotify tab (extra)
    e("spotifyTabTitle", "Spotify")
    e(
        "spotifyTabIntro",
        "OAuth tokens and album artwork colors. Help explains audio routing and artwork.",
    )
    e("spotifyHelpAlbum", "Help: music & artwork")
    e("spotifyIntegrationEnabled", "Spotify integration enabled")
    e("spotifyAlbumColors", "Album colors (Spotify API)")
    e("spotifyDeleteSecretDraft", "Remove client secret from draft")
    e("spotifyAccessToken", "Access token")
    e("spotifyRefreshToken", "Refresh token")
    e("spotifyTokenSetHidden", "Set (hidden)")
    e("spotifyTokenMissing", "Missing")
    e("spotifyAppleOsTitle", "Apple Music / YouTube Music (OS)")
    e(
        "spotifyAppleOsBody",
        "Uses dominant color from OS media thumbnails when Spotify does not provide a color.",
    )
    e("spotifyGsmtcOn", "Album color via OS media (GSMTC)")
    e("spotifyGsmtcOff", "Album color via OS media (unavailable)")
    e("spotifyGsmtcSubtitle", "Used in music mode when Spotify has no color or it is disabled.")
    e("spotifyDominantThumb", "Use dominant color from OS thumbnail")

    # Firmware tab
    e("firmwareEspTitle", "ESP firmware")
    e(
        "firmwareEspIntro",
        "Manifest URL, downloads and flash/OTA actions. Requires compatible controller.",
    )
    e("firmwareManifestUrlLabel", "Manifest URL (GitHub Pages)")
    e(
        "firmwareManifestUrlHint",
        "https://alfredkrutina.github.io/ambilight/firmware/latest/",
    )
    e(
        "firmwareManifestHelper",
        "Inherited from global settings; without a file we append /manifest.json",
    )
    e("firmwareLoadManifest", "Load manifest")
    e("firmwareDownloadBins", "Download binaries")
    e("firmwareVersionChip", "Version: {version} · chip: {chip}", {"placeholders": {"version": {}, "chip": {}}})
    e("firmwarePartLine", "• {file} @ {offset}", {"placeholders": {"file": {}, "offset": {}}})
    e("firmwareOtaUrlLine", "OTA URL: {url}", {"placeholders": {"url": {}}})
    e("firmwareUsbFlashTitle", "USB flash (COM)")
    e("firmwareRefreshPorts", "Refresh port list")
    e("firmwareSelectPortFirst", "Select a serial port.")
    e("firmwarePickFirmwareFolder", "Pick a firmware folder with manifest.json.")
    e("firmwareFlashEsptool", "Flash via esptool")
    e("firmwareOtaUdpTitle", "OTA over Wi‑Fi (UDP)")
    e("firmwareDeviceIp", "Device IP")
    e("firmwareUdpPort", "UDP port")
    e("firmwareVerifyReachability", "Verify reachability (UDP PONG)")
    e("firmwareSendOtaHttp", "Send OTA_HTTP")

    # Smart integration / HA
    e("smartHaUrlLabel", "Home Assistant URL")
    e("smartHaTokenLabel", "Long-lived access token")
    e("smartHaConfigureFirst", "First set Home Assistant URL and token.")
    e("smartHaError", "HA: {error}", {"placeholders": {"error": {}}})
    e("smartHaNoLights", "No light.* entities in HA.")
    e("smartAddLightTitle", "Add light from Home Assistant")
    e("smartIntegrationTitle", "Smart Home")
    e("smartIntegrationSubtitle", "Home Assistant and virtual room wave.")

    # Virtual room
    e("virtualRoomWaveTitle", "Room wave")
    e(
        "virtualRoomWaveSubtitle",
        "Brightness modulation by distance from TV and capture time.",
    )
    e("virtualRoomWaveStrength", "Wave strength: {pct} %", {"placeholders": {"pct": {}}})
    e("virtualRoomWaveSpeed", "Wave speed")
    e("virtualRoomDistanceSens", "Distance sensitivity")
    e("virtualRoomFacing", "View angle offset toward TV: {deg}°", {"placeholders": {"deg": {}}})
    e("virtualRoomEffectLabel", "Effect on smart lights")
    e("virtualRoomEffectNone", "Off")
    e("virtualRoomEffectWave", "Wave")
    e("virtualRoomEffectBreath", "Breath")
    e("virtualRoomEffectChase", "Chase")
    e("virtualRoomEffectSparkle", "Sparkle")
    e(
        "virtualRoomEffectHintNone",
        "Colors and brightness from the engine only — no extra modulation.",
    )
    e(
        "virtualRoomEffectHintWave",
        "Smooth wave through the room; geometry sets how distance affects phase.",
    )
    e(
        "virtualRoomEffectHintBreath",
        "All lights pulse together — good when you do not want a spatial pattern.",
    )
    e(
        "virtualRoomEffectHintChase",
        "Lights brighten in order along the chosen axis (sorted left-to-right on that axis).",
    )
    e(
        "virtualRoomEffectHintSparkle",
        "Each light drifts with a slightly different phase for a lively shimmer.",
    )
    e("virtualRoomGeometryLabel", "Wave / chase axis")
    e("virtualRoomGeometryRadial", "Radial from TV")
    e("virtualRoomGeometryAlongView", "Across your view (perpendicular to gaze)")
    e("virtualRoomGeometryHorizontal", "Horizontal (toward TV on X)")
    e("virtualRoomGeometryVertical", "Vertical (toward TV on Y)")
    e("virtualRoomGeometryCustom", "Custom angle from TV")
    e("virtualRoomCustomAngle", "Axis angle: {deg}°", {"placeholders": {"deg": {}}})
    e("virtualRoomBrightnessModLabel", "Apply modulation to")
    e("virtualRoomBrightnessBoth", "Color and brightness")
    e("virtualRoomBrightnessRgb", "Color only")
    e("virtualRoomBrightnessBri", "Brightness only")
    e("virtualRoomPreviewToggle", "Animated preview")
    e(
        "virtualRoomPreviewSubtitle",
        "Bulb icons use the same math as Home Assistant / HomeKit output.",
    )
    e("virtualRoomDragTv", "TV (drag)")
    e("virtualRoomDragUser", "You (drag)")

    # Screen overlay / scan tab (short)
    e("scanOverlaySettingsTitle", "Scan overlay (detail)")
    e(
        "scanOverlaySettingsIntro",
        "Preview capture zones on the monitor while tuning screen mode.",
    )
    e("scanOverlayPreviewTitle", "Show zone preview while tuning")
    e(
        "scanOverlayPreviewSubtitle",
        "Short fullscreen overlay; does not affect capture.",
    )
    e("scanOverlayMonitorLabel", "Monitor (MSS index, same as capture)")
    e("scanOverlayShowNow", "Show zone preview now (~1 s)")
    e("scanDepthPercentTitle", "Scan depth % (per edge)")
    e("scanPaddingPercentTitle", "Padding % (per edge)")
    e("scanRegionSchemeTitle", "Region scheme (ratio of selected monitor)")
    e("scanLastFrameTitle", "Last frame (screen mode)")

    # PC Health (common)
    e("pcHealthSectionTitle", "PC Health")
    e(
        "pcHealthSectionSubtitle",
        "Sensors to colors. Add metrics and map them to zones.",
    )
    e("pcHealthEnabledTitle", "PC Health enabled")
    e("pcHealthEnabledSubtitle", "When disabled, output is black in this mode.")
    e("pcHealthMetricNew", "New metric")
    e("pcHealthMetricEdit", "Edit metric")
    e("pcHealthMetricEnabled", "Enabled")
    e("pcHealthMetricName", "Name")
    e("pcHealthMetricKey", "Metric")
    e("pcHealthMetricMin", "Min")
    e("pcHealthMetricMax", "Max")
    e("pcHealthColorScale", "Color scale")
    e("pcHealthBrightnessMode", "Brightness")
    e("pcHealthBrightnessStatic", "Static")
    e("pcHealthBrightnessDynamic", "Dynamic (by value)")
    e("pcHealthZonesTitle", "Zones")
    e("pcHealthLivePreview", "Live value preview")
    e("pcHealthMeasureNow", "Measure now")
    e("pcHealthMetricsHeader", "Metrics ({count})", {"placeholders": {"count": {}}})
    e("pcHealthNoMetrics", "No metrics.")
    e("pcHealthDefaultMetrics", "Defaults")
    e("pcHealthColorStripPreview", "Color strip preview")
    e("pcHealthStagingHint", "[staging] PC Health: preview + metric editor")

    # Light / Screen / Music tabs — high-traffic labels (users see often)
    e("lightSectionTitle", "Light mode")
    e("lightSectionSubtitle", "Static color, effects, zones and brightness.")
    e("screenSectionTitle", "Screen mode")
    e("screenSectionSubtitle", "Capture, scan depth, presets and segments.")
    e("musicSectionTitle", "Music mode")
    e("musicSectionSubtitle", "Microphone, effects and Spotify integration.")

    # Devices tab (settings)
    e("devicesTabTitle", "Devices")
    e("devicesTabSubtitle", "USB and Wi‑Fi controllers, LED counts and default monitor.")

    # Misc UI
    e("usbSerialLabel", "USB / serial")
    e("udpWifiLabel", "UDP / Wi‑Fi")
    e("onboardingModesDemoLabel", "Modes")
    e("onboardingOutputDemoOn", "Output on")
    e("onboardingOutputDemoOff", "Output off")

    # LED / calibration wizards — minimal
    e("calibrationTitle", "Calibration")
    e("ledStripWizardTitle", "LED strip wizard")
    e("configProfileWizardTitle", "Configuration profile")

    # ambilight color picker
    e("colorPickerTitle", "Pick color")
    e("colorPickerHex", "Hex")

    # Controller snackbars / faults used in settings_page
    e("devicesTabPlaceholder", "")

    ROOT.mkdir(parents=True, exist_ok=True)
    # Czech translations keyed same as English (no @@locale in cs — flutter uses file name)
    cs_plain = {k: v for k, v in en.items() if not k.startswith("@")}
    cs_meta = {k: v for k, v in en.items() if k.startswith("@")}

    cs: dict[str, str | dict] = {}
    # Map English string values to Czech for plain keys (same key names)
    cz_map = {
        "AmbiLight": "AmbiLight",
        "Language": "Jazyk",
        "System default": "Podle systému",
        "English": "Angličtina",
        "Czech": "Čeština",
        "Cancel": "Zrušit",
        "Save": "Uložit",
        "Close": "Zavřít",
        "Done": "Hotovo",
        "Next": "Další",
        "Back": "Zpět",
        "Skip": "Přeskočit",
        "Settings": "Nastavení",
        "Help": "Nápověda",
        "Add": "Přidat",
        "Delete": "Smazat",
        "Edit": "Upravit",
        "Verify": "Ověřit",
        "Refresh": "Obnovit",
        "Send": "Odeslat",
        "Remove": "Odebrat",
        "Scanning…": "Skenuji…",
        "Measuring…": "Měřím…",
        "Finding COM…": "Hledám COM…",
        "Overview": "Přehled",
        "Devices": "Zařízení",
        "About": "O aplikaci",
        "Home — modes and device preview": "Domů — režimy a náhled zařízení",
        "Discovery, strips and calibration": "Discovery, pásky a kalibrace",
        "Modes, integrations and config backup": "Režimy, integrace a záloha konfigurace",
        "Version and basics": "Verze a základní informace",
        "Navigation": "Navigace",
        "Output on": "Výstup zapnutý",
        "Output off": "Výstup vypnutý",
        "Stop sending colors to strips": "Vypnout posílání barev na pásky",
        "Start sending colors to strips": "Zapnout posílání barev na pásky",
        "No output devices (optional)": "Žádné výstupní zařízení (volitelné)",
        "USB": "USB",
        "Wi‑Fi": "Wi‑Fi",
        "Path copied to clipboard": "Cesta zkopírována do schránky",
        "AmbiLight Desktop — LED strips from Windows (USB and Wi‑Fi).": "AmbiLight Desktop — ovládání LED pásků z Windows (USB i Wi‑Fi).",
        "Desktop Flutter client aligned with ESP32 firmware. In-app wizards cover strips, screen segments and calibration.": "Desktopový klient ve Flutteru, sladěný s firmware pro ESP32. Průvodce v aplikaci tě provedou páskem, segmenty obrazovky a kalibrací.",
        "AmbiLight Desktop": "AmbiLight Desktop",
        "Show onboarding again": "Znovu zobrazit úvodní průvodce",
        "Crash / diagnostic log file:": "Soubor crash / diagnostického logu:",
        "Copy log path": "Zkopírovat cestu k logu",
        "Debug": "Ladění",
        "Dismiss": "Zavřít",
        ", selected": ", vybráno",
        "Light": "Světlo",
        "Screen (Ambilight)": "Obrazovka (Ambilight)",
        "Music": "Hudba",
        "Music mode": "Hudba",
        "Screen mode": "Obrazovka",
        "Light mode": "Světlo",
        "Global": "Globální",
        "Firmware": "Firmware",
        "Smart Home": "Smart Home",
        "Spotify": "Spotify",
        "Performance mode": "Režim výkonu",
        "Launch with Windows": "Spustit s Windows",
        "Start minimized": "Spustit minimalizovaně",
        "Sign in": "Přihlásit",
        "Sign out": "Odpojit",
        "connected": "připojeno",
        "not connected": "nepřipojeno",
        "Firmware": "Firmware",
        "Manifest (OTA)": "Manifest (OTA)",
        "Basics": "Základ",
        "Modes": "Režimy",
        "Integrations": "Integrace",
        "Global": "Globální",
        "Device saved.": "Zařízení uloženo.",
        "Invalid IP address.": "Neplatná IP adresa.",
        "Verify PONG": "Ověřit PONG",
        "Send RESET_WIFI": "Odeslat RESET_WIFI",
        "Reset Wi‑Fi?": "Reset Wi‑Fi?",
        "Hotovo": "Hotovo",
    }

    def translate(en_val: str) -> str:
        if en_val in cz_map:
            return cz_map[en_val]
        # placeholder-heavy strings: rebuild manually for CS file
        return en_val

    for k, v in cs_plain.items():
        if k == "@@locale":
            cs["@@locale"] = "cs"
            continue
        if isinstance(v, str):
            cs[k] = translate(v)

    for mk, mv in cs_meta.items():
        cs[mk] = mv

    # Manual Czech overrides for parameterized / long strings (must match keys)
    overrides_cs = {
        "allOutputsOnline": "Všechna výstupní zařízení připojená ({online}/{total}).",
        "someOutputsOffline": "Část výstupů offline ({online}/{total}) — zkontroluj USB nebo Wi‑Fi.",
        "footerUsbMany": "{count}× USB",
        "footerWifiMany": "{count}× Wi‑Fi",
        "engineTickDebug": "Čítač snímků engine: {tick}\n(Obnovuje se při změně připojení zařízení, novém snímku obrazovky nebo v intervalu ~4 s.)",
        "versionLoadError": "Verzi nelze načíst: {error}",
        "versionLine": "Verze: {version} ({build})",
        "buildLine": "Build: {mode} · kanál: {channel}",
        "gitLine": "Git: {sha}",
        "bootstrapFailed": "Aplikace se nespustila: {detail}",
        "configLoadFailed": "Načtení konfigurace selhalo, používám výchozí: {detail}",
        "faultUiError": "Chyba rozhraní: {detail}",
        "faultUncaughtAsync": "Neodchycená chyba v asynchronním kódu.",
        "errorWidgetTitle": "Chyba při vykreslení widgetu. Aplikace dál běží.\n\n",
        "settingsDevicesSaveFailed": "Uložení seznamu zařízení selhalo: {detail}",
        "modeSettingsTooltip": "Nastavení režimu „{mode}“",
        "deviceRemoved": "Zařízení „{name}“ bylo odebráno.",
        "removeFailed": "Odebrání se nepodařilo: {error}",
        "pongResult": "PONG: FW {version}, LED {leds}",
        "serialPortSet": "Nastaven sériový port: {port}",
        "firmwareFromPong": "Firmware (z PONG): {version}",
        "firmwareLabel": "Firmware: {version}",
        "discoveryAdded": "Přidáno: {name}",
        "zoneEditorSaved": "Uloženo {count} segmentů.",
        "haStatusOnOk": "Zapnuto · {count} světel v mapě.",
        "deviceLedSubtitle": "{kind} · {count} LED",
        "deviceStripStateLine": "{info} · {state}",
        "onboardProgress": "{current} / {total}",
        "virtualRoomWaveStrength": "Síla vlny: {pct} %",
        "virtualRoomFacing": "Úchyl pohledu od osy k TV: {deg}°",
        "firmwareVersionChip": "Verze: {version} · čip: {chip}",
        "firmwarePartLine": "• {file} @ {offset}",
        "firmwareOtaUrlLine": "OTA URL: {url}",
        "smartHaError": "HA: {error}",
        "pcHealthMetricsHeader": "Metriky ({count})",
        "zoneEditorSegmentTitle": "Segment {index} · {edge} · LED {ledStart}–{ledEnd} · mon {monitor}",
    }
    for k, v in overrides_cs.items():
        cs[k] = v

    # Long Czech paragraphs — copy from original Czech source (not machine placeholder)
    long_cs = {
        "homeOverviewSubtitle": "Zapni výstup, vyber režim a zkontroluj připojení. Podrobná konfigurace je v záložkách Zařízení a Nastavení.",
        "homeModeSubtitle": "Klepnutím na dlaždici změníš aktivní režim. Ikona tužky v rohu otevře Nastavení přímo pro daný režim.",
        "homeIntegrationsSubtitle": "Hudba (Spotify OAuth + volitelně barvy z přehrávače v systému), Home Assistant a firmware ESP — úpravy detailů v příslušných záložkách Nastavení.",
        "homeDevicesSubtitle": "Rychlý náhled stavu. Úpravy pásku, discovery a sítě jsou v hlavní sekci „Zařízení“ v navigaci.",
        "homeDevicesEmpty": "Žádné výstupní zařízení — běžný stav, dokud nepřipojíš pásek.\n\n"
        "Můžeš nastavovat režimy, presety a zálohu. Pro odesílání barev přidej zařízení v „Zařízení“ (Discovery nebo ručně).",
        "modeLightSubtitle": "Statické efekty, zóny, dýchání",
        "modeScreenSubtitle": "Ambilight ze snímku monitoru",
        "modeMusicSubtitle": "FFT, melodie, barvy",
        "modePcHealthSubtitle": "Teploty, zátěž, vizualizace",
        "homeLedOutputTitle": "Výstup na LED",
        "homeLedOutputOnBody": "Barvy se posílají na všechna aktivní zařízení.",
        "homeLedOutputOffBody": "Vypnuto — pásky dostanou černou.",
        "homeServiceTitle": "Služba",
        "homeBackgroundTitle": "Běží na pozadí",
        "homeBackgroundBody": "Aplikace průběžně připravuje barvy pro pásky. Stav se mění při přepnutí režimu nebo připojení zařízení.",
        "spotifyHintNeedClientId": "Client ID doplníš v Nastavení → Spotify.",
        "spotifyHintLogin": "„Přihlásit“ otevře prohlížeč; na Windows lze barvy brát i z přehrávače v systému (viz nápověda).",
        "spotifyOAuthSubtitle": "Zapne dotazování účtu; vypnutím se zastaví polling.",
        "spotifyAlbumColorsSubtitle": "V režimu Hudba má přednost před FFT, pokud API vrátí obal.",
        "haStatusOff": "Integrace vypnutá.",
        "haStatusOnNeedUrl": "Zapnuto — doplň URL a token v Nastavení.",
        "haDetailOk": "REST API do Home Assistant; barvy z engine mapuješ na entity light.*.",
        "haDetailNeedUrl": "Nejdřív URL instance a dlouho žijící token (profil uživatele v HA).",
        "fwManifestHint": "Stažení binárek, příkaz OTA přes UDP nebo flash přes USB (esptool).",
        "settingsRailSubtitle": "Vyber téma vlevo — tlačítko Použít nepotřebuješ.",
        "settingsPersistHint": "Engine a posuvníky reagují hned; na disk se zapíše krátce po poslední změně. Presety obrazovky a hudby se tím nemění.",
        "globalSectionSubtitle": "Chování po startu, vzhled a výkon. Import a export konfigurace najdeš níže.",
        "startModeLabel": "Výchozí režim po startu",
        "themeLabel": "Vzhled aplikace",
        "themeHelper": "Tmavě modrý = dřívější výchozí vzhled. SnowRunner = neutrální šedý tmavý režim.",
        "themeSnowrunner": "Tmavý (SnowRunner)",
        "themeDarkBlue": "Tmavě modrý",
        "themeLight": "Světlý",
        "uiAnimationsTitle": "Animace rozhraní",
        "uiAnimationsSubtitle": "Krátké přechody mezi sekcemi. Vypni při opakované práci — respektuje i systémové snížení animací.",
        "performanceModeSubtitle": "Smyčka ~25 Hz, snímání obrazovky každý 3. tick, delší intervaly Spotify / PC Health a šetrnější fronta USB. "
        "Při vypnutém výkonu běží režim Světlo rychleji (~125 Hz na pásek při viditelném okně; Wi‑Fi UDP bez fronty). "
        "Přepínač „Animace rozhraní“ ovládá jen Material přechody.",
        "autostartSubtitle": "Autostart aplikace po přihlášení k účtu.",
        "captureMethodLabel": "Metoda snímání obrazovky (pokročilé)",
        "captureMethodHint": "např. mss, dxcam",
        "captureMethodHelper": "Ponech výchozí, pokud snímání obrazovky funguje.",
        "onboardWelcomeTitle": "Vítej v AmbiLight",
        "onboardWelcomeBody": "Tato aplikace řídí tvoje LED pásky z Windows — přes USB (sériový port) nebo přes síť (UDP). "
        "Firmware na ESP32 zůstává stejný jako u starších klientů; jen ovládání je tady hezčí a přehlednější.",
        "onboardHowTitle": "Jak to celé funguje",
        "onboardHowBody": "AmbiLight bere barvy z obrazovky, mikrofonu, PC senzorů nebo statických efektů a posílá je jako RGB data na kontrolér. "
        "V horní liště zapínáš a vypínáš samotný výstup — když je vypnutý, pásek nedostává nové příkazy z aplikace.",
        "onboardOutputTitle": "Výstup zapnutý / vypnutý",
        "onboardOutputBody": "Tlačítko „Výstup zapnutý“ v hlavičce je hlavní pojistka: vypni ho, když chceš pásek nechat v klidu, "
        "nebo při řešení problémů s připojením. Zapni ho až máš nastavené zařízení a režim.",
        "onboardModesTitle": "Režimy",
        "onboardModesBody": "Světlo — statické barvy a efekty. Obrazovka — ambilight ze snímku monitoru (segmenty a hloubka okraje v Nastavení). "
        "Hudba — FFT a melodie z mikrofonu nebo systému. PC Health — vizualizace teplot a zátěže.",
        "onboardDevicesTitle": "Zařízení",
        "onboardDevicesBody": "Na stránce Zařízení přidáš pásky, spustíš discovery a nastavíš počet LED, offset a výchozí monitor. "
        "USB používá COM port a baud rate; Wi‑Fi vyžaduje IP a UDP port (stejné jako ve firmware).",
        "onboardScreenTitle": "Obrazovka a zóny",
        "onboardScreenBody": "V Nastavení → obrazovka určíš, jak hluboko se bere okraj, padding a případně jednotlivé segmenty na pásku. "
        "Náhled oblasti snímání (malý překryv) pomůže zkontrolovat geometrii bez hádání.",
        "onboardMusicTitle": "Hudba a Spotify",
        "onboardMusicBody": "Hudba umí barvy z mikrofonu nebo z výstupu zvukové karty. Spotify je volitelná integrace — Client ID získáš v dashboardu vývojáře Spotify; "
        "podrobný návod je v aplikaci u nastavení Spotify.",
        "onboardSmartTitle": "PC Health a chytrá světla",
        "onboardSmartBody": "PC Health čte senzory (teploty, zátěž) a mapuje je na barvy. Chytrá světla umí Home Assistant: "
        "po zadání URL a tokenu můžeš synchronizovat barvy i na další lampy v místnosti.",
        "onboardFirmwareTitle": "Nastavení a firmware",
        "onboardFirmwareBody": "Globální nastavení obsahuje téma vzhledu, výkonový režim, metodu snímání obrazovky a manifest firmware (OTA odkazy). "
        "Konfiguraci můžeš exportovat/importovat jako JSON — před experimenty si ji zálohuj.",
        "onboardReadyTitle": "Jdeš na to",
        "onboardReadyBody": "Průvodce průběžně najdeš znovu v záložce O aplikaci. "
        "Doporučený postup: přidej zařízení → zkontroluj výstup → vyber režim Obrazovka nebo Světlo → doladíš jas v nastavení.",
        "onboardStartUsing": "Začít používat",
        "devicesIntro": "Správa pásků: discovery, Wi‑Fi a kalibrace. Uložením se zapíše konfigurace a znovu se navážou transporty.",
        "saveDeviceTitle": "Uložit zařízení",
        "pongTimeout": "PONG nepřišel (timeout).",
        "resetWifiBody": "Odešle RESET_WIFI přes UDP na zařízení. Používej jen pokud víš, co děláš.",
        "resetWifiSent": "RESET_WIFI odeslán.",
        "resetWifiFailed": "Odeslání se nezdařilo.",
        "pongMissing": "PONG nepřišel.",
        "comScanHandshake": "Hledám COM s handshake 0xAA / 0xBB…",
        "comScanNoReply": "Žádný port neodpověděl (Ambilight handshake).",
        "discoveryNoReply": "Žádné zařízení neodpovědělo (UDP 4210).",
        "discoverySelectHint": "Projdi síť na UDP 4210; nalezená zařízení se zobrazí níže.",
        "zoneEditorIntro": "Segmenty mapují rozsahy LED na hrany obrazovky a monitory.",
        "guideBrowserFailed": "Otevření prohlížeče se nezdařilo.",
        "guideNeedClientIdFirst": "Nejdřív v Nastavení → Spotify zadej Client ID (viz tlačítko výše).",
        "guideSectionSound": "1 · Režim a zvuk",
        "guideSectionAlbum": "2 · Barva z obalu",
        "guideSectionSpotify": "3 · Spotify",
        "guideSectionApple": "4 · Apple Music",
        "guideSectionTrouble": "Když něco nejde",
        "spotifyTabIntro": "OAuth tokeny a barvy z obalů. Nápověda vysvětluje obraz zvuku a obaly.",
        "spotifyHelpAlbum": "Nápověda: hudba a obaly",
        "spotifyIntegrationEnabled": "Spotify integrace zapnutá",
        "spotifyAlbumColors": "Barvy z alba (Spotify API)",
        "spotifyDeleteSecretDraft": "Smazat client secret z draftu",
        "spotifyAccessToken": "Access token",
        "spotifyRefreshToken": "Refresh token",
        "spotifyTokenSetHidden": "Nastaven (skryto)",
        "spotifyTokenMissing": "Chybí",
        "spotifyAppleOsTitle": "Apple Music / YouTube Music (OS)",
        "spotifyAppleOsBody": "Použije se v music módu, pokud Spotify neposkytne barvu nebo je vypnuté.",
        "spotifyGsmtcOn": "Barva z obalu přes OS média (GSMTC)",
        "spotifyGsmtcOff": "Barva z obalu přes OS média (nedostupné)",
        "spotifyGsmtcSubtitle": "Použije se v music módu, pokud Spotify neposkytne barvu nebo je vypnuté.",
        "spotifyDominantThumb": "Použít dominantní barvu z miniatury OS",
        "firmwareEspIntro": "URL manifestu, stažení binárek a flash/OTA. Vyžaduje kompatibilní kontrolér.",
        "firmwareManifestUrlLabel": "URL manifestu (GitHub Pages)",
        "firmwareManifestHelper": "Výchozí z globálního nastavení; bez souboru doplníme /manifest.json",
        "firmwareLoadManifest": "Načíst manifest",
        "firmwareDownloadBins": "Stáhnout binárky",
        "firmwareUsbFlashTitle": "Flash přes USB (COM)",
        "firmwareRefreshPorts": "Obnovit seznam portů",
        "firmwareSelectPortFirst": "Vyber sériový port.",
        "firmwarePickFirmwareFolder": "Vyber složku firmware s manifest.json.",
        "firmwareFlashEsptool": "Flashovat přes esptool",
        "firmwareOtaUdpTitle": "OTA přes Wi‑Fi (UDP)",
        "firmwareDeviceIp": "IP zařízení",
        "firmwareUdpPort": "UDP port",
        "firmwareVerifyReachability": "Ověřit dosah (UDP PONG)",
        "firmwareSendOtaHttp": "Odeslat OTA_HTTP",
        "smartHaConfigureFirst": "Nejdřív nastav URL a token Home Assistant.",
        "smartHaNoLights": "V HA nejsou žádné entity light.*",
        "smartAddLightTitle": "Přidat světlo z Home Assistant",
        "smartIntegrationSubtitle": "Home Assistant a vlna přes místnost.",
        "virtualRoomWaveTitle": "Vlna přes místnost",
        "virtualRoomWaveSubtitle": "Modulace jasu podle vzdálenosti od TV a času snímku",
        "virtualRoomWaveSpeed": "Rychlost vlny",
        "virtualRoomDistanceSens": "Citlivost na vzdálenost",
        "virtualRoomEffectLabel": "Efekt na chytrá světla",
        "virtualRoomEffectNone": "Vypnuto",
        "virtualRoomEffectWave": "Vlna",
        "virtualRoomEffectBreath": "Dýchání",
        "virtualRoomEffectChase": "Běh",
        "virtualRoomEffectSparkle": "Jiskření",
        "virtualRoomEffectHintNone": "Jen barvy a jas z enginu — žádná další modulace.",
        "virtualRoomEffectHintWave": "Plynulá vlna místností; geometrie určuje, jak vzdálenost mění fázi.",
        "virtualRoomEffectHintBreath": "Všechna světla společně pulzují — když nechceš prostorový vzor.",
        "virtualRoomEffectHintChase": "Světla se rozsvěcují v pořadí podle zvolené osy (řazení podle projekce).",
        "virtualRoomEffectHintSparkle": "Každé světlo má mírně jinou fázi pro živý třpyt.",
        "virtualRoomGeometryLabel": "Osa vlny / běhu",
        "virtualRoomGeometryRadial": "Radiálně od TV",
        "virtualRoomGeometryAlongView": "Kolmě na pohled (vlevo–vpravo)",
        "virtualRoomGeometryHorizontal": "Vodorovně (osa X od TV)",
        "virtualRoomGeometryVertical": "Svisle (osa Y od TV)",
        "virtualRoomGeometryCustom": "Vlastní úhel od TV",
        "virtualRoomCustomAngle": "Úhel osy: {deg}°",
        "virtualRoomBrightnessModLabel": "Modulace aplikovat na",
        "virtualRoomBrightnessBoth": "Barvu i jas",
        "virtualRoomBrightnessRgb": "Jen barvu",
        "virtualRoomBrightnessBri": "Jen jas",
        "virtualRoomPreviewToggle": "Animovaný náhled",
        "virtualRoomPreviewSubtitle": "Ikony žárovek používají stejnou matematiku jako výstup do HA / HomeKit.",
        "virtualRoomDragTv": "TV (táhni)",
        "virtualRoomDragUser": "Ty (táhni)",
        "scanOverlaySettingsTitle": "Scan overlay (D-detail)",
        "scanOverlaySettingsIntro": "Náhled zón na monitoru při ladění režimu Obrazovka.",
        "scanOverlayPreviewTitle": "Náhled zón na monitor při ladění",
        "scanOverlayPreviewSubtitle": "Krátký přes celou obrazovku; nesahá na samotný capture.",
        "scanOverlayMonitorLabel": "Monitor (MSS index, shodně s capture)",
        "scanOverlayShowNow": "Ukázat náhled zón teď (~1 s)",
        "scanDepthPercentTitle": "Hloubka snímání % (per-edge)",
        "scanPaddingPercentTitle": "Odsazení % (per-edge)",
        "scanRegionSchemeTitle": "Schéma oblasti (poměr zvoleného monitoru)",
        "scanLastFrameTitle": "Poslední snímek (screen režim)",
        "pcHealthSectionSubtitle": "Senzory do barev. Přidej metriky a mapuj je na zóny.",
        "pcHealthEnabledSubtitle": "Vypnuto = černý výstup v tomto režimu.",
        "pcHealthMetricNew": "Nová metrika",
        "pcHealthMetricEdit": "Upravit metriku",
        "pcHealthMetricEnabled": "Zapnuto",
        "pcHealthMetricName": "Název",
        "pcHealthMetricKey": "Metrika",
        "pcHealthMetricMin": "Min",
        "pcHealthMetricMax": "Max",
        "pcHealthColorScale": "Barevná škála",
        "pcHealthBrightnessMode": "Jas",
        "pcHealthBrightnessStatic": "Statický",
        "pcHealthBrightnessDynamic": "Dynamický (podle hodnoty)",
        "pcHealthZonesTitle": "Zóny",
        "pcHealthLivePreview": "Živý náhled hodnot",
        "pcHealthMeasureNow": "Změřit teď",
        "pcHealthNoMetrics": "Žádné metriky.",
        "pcHealthDefaultMetrics": "Výchozí",
        "pcHealthColorStripPreview": "Barevný pruh (náhled)",
        "pcHealthStagingHint": "[staging] PC Health: náhled + editor metrik",
        "lightSectionSubtitle": "Statická barva, efekty, zóny a jas.",
        "screenSectionSubtitle": "Snímání, hloubka okraje, presety a segmenty.",
        "musicSectionSubtitle": "Mikrofon, efekty a integrace Spotify.",
        "devicesTabSubtitle": "USB a Wi‑Fi kontroléry, počty LED a výchozí monitor.",
        "usbSerialLabel": "USB / sériový",
        "udpWifiLabel": "UDP / Wi‑Fi",
        "integrationSettingsButton": "Nastavení",
        "musicCardTitle": "Hudba",
        "guideMusicTitle": "Hudba a Spotify",
        "backupTitle": "Záloha konfigurace",
        "backupExport": "Exportovat JSON…",
        "backupImport": "Importovat JSON…",
        "backupExported": "Konfigurace exportována.",
        "backupImported": "Konfigurace importována.",
        "backupInvalid": "Neplatný soubor konfigurace.",
    }
    for k, v in long_cs.items():
        cs[k] = v

    (ROOT / "app_en.arb").write_text(json.dumps(en, ensure_ascii=False, indent=2), encoding="utf-8")
    (ROOT / "app_cs.arb").write_text(json.dumps(cs, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(en)} keys to app_en.arb, {len(cs)} keys to app_cs.arb")


if __name__ == "__main__":
    main()
