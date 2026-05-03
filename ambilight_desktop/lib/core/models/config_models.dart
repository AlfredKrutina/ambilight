import 'dart:convert';

import '../json/json_utils.dart';
import 'custom_hotkey_models.dart';
import 'pc_health_defaults.dart';
import 'smart_lights_models.dart';

/// --- Device ---

class DeviceSettings {
  const DeviceSettings({
    required this.id,
    required this.name,
    required this.type,
    this.port = 'COM5',
    this.ipAddress = '',
    this.udpPort = 4210,
    this.ledCount = 66,
    this.ledOffset = 0,
    this.defaultMonitor = 1,
    this.controlViaHa = false,
    this.firmwareVersion = '',
  });

  final String id;
  final String name;
  /// `serial` | `wifi`
  final String type;
  final String port;
  final String ipAddress;
  final int udpPort;
  final int ledCount;
  final int ledOffset;
  final int defaultMonitor;
  final bool controlViaHa;
  /// Z `ESP32_PONG` (poslední pole), pokud známe.
  final String firmwareVersion;

  DeviceSettings copyWith({
    String? id,
    String? name,
    String? type,
    String? port,
    String? ipAddress,
    int? udpPort,
    int? ledCount,
    int? ledOffset,
    int? defaultMonitor,
    bool? controlViaHa,
    String? firmwareVersion,
  }) {
    return DeviceSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      port: port ?? this.port,
      ipAddress: ipAddress ?? this.ipAddress,
      udpPort: (udpPort ?? this.udpPort).clamp(1, 65535),
      ledCount: ledCount ?? this.ledCount,
      ledOffset: ledOffset ?? this.ledOffset,
      defaultMonitor: defaultMonitor ?? this.defaultMonitor,
      controlViaHa: controlViaHa ?? this.controlViaHa,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'port': port,
        'ip_address': ipAddress,
        'udp_port': udpPort,
        'led_count': ledCount,
        'led_offset': ledOffset,
        'default_monitor': defaultMonitor,
        'control_via_ha': controlViaHa,
        'firmware_version': firmwareVersion,
      };

  factory DeviceSettings.fromJson(Map<String, dynamic> j) {
    return DeviceSettings(
      id: asString(j['id'], 'primary'),
      name: asString(j['name'], 'Controller'),
      type: asString(j['type'], 'serial'),
      port: asString(j['port'], 'COM5'),
      ipAddress: asString(j['ip_address'], ''),
      udpPort: asInt(j['udp_port'], 4210).clamp(1, 65535),
      ledCount: asInt(j['led_count'], 66),
      ledOffset: asInt(j['led_offset'], 0),
      defaultMonitor: asInt(j['default_monitor'], 1),
      controlViaHa: asBool(j['control_via_ha'], false),
      firmwareVersion: asString(j['firmware_version'], ''),
    );
  }
}

/// --- Global ---

class GlobalSettings {
  const GlobalSettings({
    this.serialPort = 'COM5',
    this.baudRate = 115200,
    this.ledCount = 66,
    this.devices = const [],
    this.startMode = 'screen',
    this.startMinimized = false,
    this.autostart = false,
    this.theme = 'dark',
    this.captureMethod = 'mss',
    this.hotkeysEnabled = true,
    this.hotkeyToggle = 'ctrl+shift+l',
    this.hotkeyModeLight = '',
    this.hotkeyModeScreen = '',
    this.hotkeyModeMusic = '',
    this.customHotkeys = const [],
    this.uiAnimationsEnabled = true,
    this.performanceMode = false,
  });

  final String serialPort;
  final int baudRate;
  final int ledCount;
  final List<DeviceSettings> devices;
  final String startMode;
  final bool startMinimized;
  final bool autostart;
  final String theme;
  final String captureMethod;
  final bool hotkeysEnabled;
  final String hotkeyToggle;
  final String hotkeyModeLight;
  final String hotkeyModeScreen;
  final String hotkeyModeMusic;
  final List<CustomHotkeyEntry> customHotkeys;
  /// Krátké UI přechody; vypnuto = `MediaQuery.disableAnimations` pro celou aplikaci.
  final bool uiAnimationsEnabled;
  /// Nižší frekvence smyčky, řidší snímání obrazovky a pozadí — bez vypínání UI animací.
  final bool performanceMode;

  GlobalSettings copyWith({
    String? serialPort,
    int? baudRate,
    int? ledCount,
    List<DeviceSettings>? devices,
    String? startMode,
    bool? startMinimized,
    bool? autostart,
    String? theme,
    String? captureMethod,
    bool? hotkeysEnabled,
    String? hotkeyToggle,
    String? hotkeyModeLight,
    String? hotkeyModeScreen,
    String? hotkeyModeMusic,
    List<CustomHotkeyEntry>? customHotkeys,
    bool? uiAnimationsEnabled,
    bool? performanceMode,
  }) {
    return GlobalSettings(
      serialPort: serialPort ?? this.serialPort,
      baudRate: baudRate ?? this.baudRate,
      ledCount: ledCount ?? this.ledCount,
      devices: devices ?? this.devices,
      startMode: startMode ?? this.startMode,
      startMinimized: startMinimized ?? this.startMinimized,
      autostart: autostart ?? this.autostart,
      theme: theme ?? this.theme,
      captureMethod: captureMethod ?? this.captureMethod,
      hotkeysEnabled: hotkeysEnabled ?? this.hotkeysEnabled,
      hotkeyToggle: hotkeyToggle ?? this.hotkeyToggle,
      hotkeyModeLight: hotkeyModeLight ?? this.hotkeyModeLight,
      hotkeyModeScreen: hotkeyModeScreen ?? this.hotkeyModeScreen,
      hotkeyModeMusic: hotkeyModeMusic ?? this.hotkeyModeMusic,
      customHotkeys: customHotkeys ?? this.customHotkeys,
      uiAnimationsEnabled: uiAnimationsEnabled ?? this.uiAnimationsEnabled,
      performanceMode: performanceMode ?? this.performanceMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'serial_port': serialPort,
        'baud_rate': baudRate,
        'led_count': ledCount,
        'devices': devices.map((e) => e.toJson()).toList(),
        'start_mode': startMode,
        'start_minimized': startMinimized,
        'autostart': autostart,
        'theme': theme,
        'capture_method': captureMethod,
        'hotkeys_enabled': hotkeysEnabled,
        'hotkey_toggle': hotkeyToggle,
        'hotkey_mode_light': hotkeyModeLight,
        'hotkey_mode_screen': hotkeyModeScreen,
        'hotkey_mode_music': hotkeyModeMusic,
        'custom_hotkeys': customHotkeys.map((e) => e.toJson()).toList(),
        'ui_animations_enabled': uiAnimationsEnabled,
        'performance_mode': performanceMode,
      };

  factory GlobalSettings.fromJson(Map<String, dynamic> j) {
    final List<DeviceSettings> devs;
    if (j['devices'] is List) {
      devs = (j['devices'] as List).map((e) => DeviceSettings.fromJson(asMap(e))).toList();
    } else if (!j.containsKey('devices')) {
      // Staré JSON bez pole `devices` — zachovat chování jako dřív (jeden řádek z serial_port).
      devs = [
        DeviceSettings(
          id: 'primary',
          name: 'Primary Controller',
          type: 'serial',
          port: asString(j['serial_port'], 'COM5'),
          ledCount: asInt(j['led_count'], 66),
        ),
      ];
    } else {
      devs = const [];
    }
    return GlobalSettings(
      serialPort: asString(j['serial_port'], 'COM5'),
      baudRate: asInt(j['baud_rate'], 115200),
      ledCount: asInt(j['led_count'], 66),
      devices: devs,
      startMode: asString(j['start_mode'], 'screen'),
      startMinimized: asBool(j['start_minimized'], false),
      autostart: asBool(j['autostart'], false),
      theme: asString(j['theme'], 'dark'),
      captureMethod: asString(j['capture_method'], 'mss'),
      hotkeysEnabled: asBool(j['hotkeys_enabled'], true),
      hotkeyToggle: asString(j['hotkey_toggle'], 'ctrl+shift+l'),
      hotkeyModeLight: asString(j['hotkey_mode_light'], ''),
      hotkeyModeScreen: asString(j['hotkey_mode_screen'], ''),
      hotkeyModeMusic: asString(j['hotkey_mode_music'], ''),
      customHotkeys: asMapList(j['custom_hotkeys']).map((e) => CustomHotkeyEntry.fromJson(Map<String, dynamic>.from(e))).toList(),
      uiAnimationsEnabled: asBool(j['ui_animations_enabled'], true),
      performanceMode: asBool(j['performance_mode'], false),
    );
  }
}

/// --- Light ---

class CustomZone {
  const CustomZone({
    required this.name,
    required this.start,
    required this.end,
    required this.color,
    this.effect = 'static',
    this.speed = 50,
    this.brightness = 255,
  });

  final String name;
  final double start;
  final double end;
  final List<int> color;
  final String effect;
  final int speed;
  final int brightness;

  Map<String, dynamic> toJson() => {
        'name': name,
        'start': start,
        'end': end,
        'color': color,
        'effect': effect,
        'speed': speed,
        'brightness': brightness,
      };

  factory CustomZone.fromJson(Map<String, dynamic> j) {
    return CustomZone(
      name: asString(j['name'], 'Zone'),
      start: asDouble(j['start']),
      end: asDouble(j['end']),
      color: asRgb(j['color']),
      effect: asString(j['effect'], 'static'),
      speed: asInt(j['speed'], 50),
      brightness: asInt(j['brightness'], 255),
    );
  }

  CustomZone copyWith({
    String? name,
    double? start,
    double? end,
    List<int>? color,
    String? effect,
    int? speed,
    int? brightness,
  }) {
    return CustomZone(
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
      effect: effect ?? this.effect,
      speed: speed ?? this.speed,
      brightness: brightness ?? this.brightness,
    );
  }
}

class LightModeSettings {
  const LightModeSettings({
    this.color = const [255, 200, 100],
    this.brightness = 200,
    this.effect = 'static',
    this.speed = 50,
    this.extra = 50,
    this.customZones = const [],
    this.homekitEnabled = false,
  });

  final List<int> color;
  final int brightness;
  final String effect;
  final int speed;
  final int extra;
  final List<CustomZone> customZones;
  final bool homekitEnabled;

  Map<String, dynamic> toJson() => {
        'color': color,
        'brightness': brightness,
        'effect': effect,
        'speed': speed,
        'extra': extra,
        'custom_zones': customZones.map((e) => e.toJson()).toList(),
        'homekit_enabled': homekitEnabled,
      };

  factory LightModeSettings.fromJson(Map<String, dynamic> j) {
    var effect = asString(j['effect'], 'static');
    if (j.containsKey('animation_type') && effect == 'static') {
      effect = asString(j['animation_type'], effect);
    }
    var speed = asInt(j['speed'], 50);
    if (j.containsKey('animation_speed')) {
      speed = asInt(j['animation_speed'], speed);
    }
    return LightModeSettings(
      color: asRgb(j['color'], const [255, 200, 100]),
      brightness: asInt(j['brightness'], 200),
      effect: effect,
      speed: speed,
      extra: asInt(j['extra'], 50),
      customZones: asMapList(j['custom_zones']).map(CustomZone.fromJson).toList(),
      homekitEnabled: asBool(j['homekit_enabled'], false),
    );
  }

  LightModeSettings copyWith({
    List<int>? color,
    int? brightness,
    String? effect,
    int? speed,
    int? extra,
    List<CustomZone>? customZones,
    bool? homekitEnabled,
  }) {
    return LightModeSettings(
      color: color ?? this.color,
      brightness: brightness ?? this.brightness,
      effect: effect ?? this.effect,
      speed: speed ?? this.speed,
      extra: extra ?? this.extra,
      customZones: customZones ?? this.customZones,
      homekitEnabled: homekitEnabled ?? this.homekitEnabled,
    );
  }
}

/// --- LED segment (screen) ---

class LedSegment {
  const LedSegment({
    this.ledStart = 0,
    this.ledEnd = 0,
    this.monitorIdx = 0,
    this.edge = 'top',
    this.depth = 10,
    this.reverse = false,
    this.deviceId,
    this.pixelStart = 0,
    this.pixelEnd = 0,
    this.refWidth = 0,
    this.refHeight = 0,
    this.musicEffect = 'default',
    this.role = 'auto',
  });

  final int ledStart;
  final int ledEnd;
  final int monitorIdx;
  final String edge;
  final int depth;
  final bool reverse;
  final String? deviceId;
  final int pixelStart;
  final int pixelEnd;
  final int refWidth;
  final int refHeight;
  final String musicEffect;
  final String role;

  Map<String, dynamic> toJson() => {
        'led_start': ledStart,
        'led_end': ledEnd,
        'monitor_idx': monitorIdx,
        'edge': edge,
        'depth': depth,
        'reverse': reverse,
        'device_id': deviceId,
        'pixel_start': pixelStart,
        'pixel_end': pixelEnd,
        'ref_width': refWidth,
        'ref_height': refHeight,
        'music_effect': musicEffect,
        'role': role,
      };

  factory LedSegment.fromJson(Map<String, dynamic> j) {
    return LedSegment(
      ledStart: asInt(j['led_start']),
      ledEnd: asInt(j['led_end']),
      monitorIdx: asInt(j['monitor_idx']),
      edge: asString(j['edge'], 'top'),
      depth: asInt(j['depth'], 10),
      reverse: asBool(j['reverse'], false),
      deviceId: j['device_id']?.toString(),
      pixelStart: asInt(j['pixel_start']),
      pixelEnd: asInt(j['pixel_end']),
      refWidth: asInt(j['ref_width']),
      refHeight: asInt(j['ref_height']),
      musicEffect: asString(j['music_effect'], 'default'),
      role: asString(j['role'], 'auto'),
    );
  }

  LedSegment copyWith({
    int? ledStart,
    int? ledEnd,
    int? monitorIdx,
    String? edge,
    int? depth,
    bool? reverse,
    String? deviceId,
    bool nullifyDeviceId = false,
    int? pixelStart,
    int? pixelEnd,
    int? refWidth,
    int? refHeight,
    String? musicEffect,
    String? role,
  }) {
    return LedSegment(
      ledStart: ledStart ?? this.ledStart,
      ledEnd: ledEnd ?? this.ledEnd,
      monitorIdx: monitorIdx ?? this.monitorIdx,
      edge: edge ?? this.edge,
      depth: depth ?? this.depth,
      reverse: reverse ?? this.reverse,
      deviceId: nullifyDeviceId ? null : (deviceId ?? this.deviceId),
      pixelStart: pixelStart ?? this.pixelStart,
      pixelEnd: pixelEnd ?? this.pixelEnd,
      refWidth: refWidth ?? this.refWidth,
      refHeight: refHeight ?? this.refHeight,
      musicEffect: musicEffect ?? this.musicEffect,
      role: role ?? this.role,
    );
  }
}

class ScreenModeSettings {
  const ScreenModeSettings({
    this.monitorIndex = 1,
    this.scanDepthPercent = 10,
    this.paddingPercent = 5,
    this.saturationBoost = 1.2,
    this.ultraSaturation = false,
    this.ultraSaturationAmount = 2.5,
    this.minBrightness = 10,
    this.interpolationMs = 100,
    this.gamma = 2.2,
    this.activePreset = 'Balanced',
    this.calibrationPoints,
    this.brightness = 200,
    this.colorCalibration,
    this.calibrationProfiles = const {},
    this.activeCalibrationProfile = 'Default',
    this.scanMode = 'simple',
    this.paddingTop = 0,
    this.paddingBottom = 0,
    this.paddingLeft = 0,
    this.paddingRight = 0,
    this.scanDepthTop = 10,
    this.scanDepthBottom = 10,
    this.scanDepthLeft = 10,
    this.scanDepthRight = 10,
    this.segments = const [],
  });

  final int monitorIndex;
  final int scanDepthPercent;
  final int paddingPercent;
  final double saturationBoost;
  final bool ultraSaturation;
  final double ultraSaturationAmount;
  final int minBrightness;
  final int interpolationMs;
  final double gamma;
  final String activePreset;
  final List<dynamic>? calibrationPoints;
  final int brightness;
  final Map<String, dynamic>? colorCalibration;
  final Map<String, Map<String, dynamic>> calibrationProfiles;
  final String activeCalibrationProfile;
  final String scanMode;
  final int paddingTop;
  final int paddingBottom;
  final int paddingLeft;
  final int paddingRight;
  final int scanDepthTop;
  final int scanDepthBottom;
  final int scanDepthLeft;
  final int scanDepthRight;
  final List<LedSegment> segments;

  Map<String, dynamic> toJson() => {
        'monitor_index': monitorIndex,
        'scan_depth_percent': scanDepthPercent,
        'padding_percent': paddingPercent,
        'saturation_boost': saturationBoost,
        'ultra_saturation': ultraSaturation,
        'ultra_saturation_amount': ultraSaturationAmount,
        'min_brightness': minBrightness,
        'interpolation_ms': interpolationMs,
        'gamma': gamma,
        'active_preset': activePreset,
        'calibration_points': calibrationPoints,
        'brightness': brightness,
        'color_calibration': colorCalibration,
        'calibration_profiles': calibrationProfiles,
        'active_calibration_profile': activeCalibrationProfile,
        'scan_mode': scanMode,
        'padding_top': paddingTop,
        'padding_bottom': paddingBottom,
        'padding_left': paddingLeft,
        'padding_right': paddingRight,
        'scan_depth_top': scanDepthTop,
        'scan_depth_bottom': scanDepthBottom,
        'scan_depth_left': scanDepthLeft,
        'scan_depth_right': scanDepthRight,
        'segments': segments.map((e) => e.toJson()).toList(),
      };

  factory ScreenModeSettings.fromJson(Map<String, dynamic> j) {
    final segList = <LedSegment>[];
    if (j['segments'] is List) {
      for (final e in j['segments'] as List) {
        segList.add(LedSegment.fromJson(asMap(e)));
      }
    }
    final profiles = <String, Map<String, dynamic>>{};
    final rawProf = j['calibration_profiles'];
    if (rawProf is Map) {
      rawProf.forEach((k, v) {
        profiles[k.toString()] = asMap(v);
      });
    }
    return ScreenModeSettings(
      monitorIndex: asInt(j['monitor_index'], 1),
      scanDepthPercent: asInt(j['scan_depth_percent'], 10),
      paddingPercent: asInt(j['padding_percent'], 5),
      saturationBoost: asDouble(j['saturation_boost'], 1.2),
      ultraSaturation: asBool(j['ultra_saturation'], false),
      ultraSaturationAmount: asDouble(j['ultra_saturation_amount'], 2.5),
      minBrightness: asInt(j['min_brightness'], 10),
      interpolationMs: asInt(j['interpolation_ms'], 100),
      gamma: asDouble(j['gamma'], 2.2),
      activePreset: asString(j['active_preset'], 'Balanced'),
      calibrationPoints:
          j['calibration_points'] is List ? List<dynamic>.from(j['calibration_points'] as List) : null,
      brightness: asInt(j['brightness'], 200),
      colorCalibration: j['color_calibration'] != null ? asMap(j['color_calibration']) : null,
      calibrationProfiles: profiles,
      activeCalibrationProfile: asString(j['active_calibration_profile'], 'Default'),
      scanMode: asString(j['scan_mode'], 'simple'),
      paddingTop: asInt(j['padding_top'], 0),
      paddingBottom: asInt(j['padding_bottom'], 0),
      paddingLeft: asInt(j['padding_left'], 0),
      paddingRight: asInt(j['padding_right'], 0),
      scanDepthTop: asInt(j['scan_depth_top'], 10),
      scanDepthBottom: asInt(j['scan_depth_bottom'], 10),
      scanDepthLeft: asInt(j['scan_depth_left'], 10),
      scanDepthRight: asInt(j['scan_depth_right'], 10),
      segments: segList,
    );
  }

  ScreenModeSettings withBrightness(int b) => ScreenModeSettings(
        monitorIndex: monitorIndex,
        scanDepthPercent: scanDepthPercent,
        paddingPercent: paddingPercent,
        saturationBoost: saturationBoost,
        ultraSaturation: ultraSaturation,
        ultraSaturationAmount: ultraSaturationAmount,
        minBrightness: minBrightness,
        interpolationMs: interpolationMs,
        gamma: gamma,
        activePreset: activePreset,
        calibrationPoints: calibrationPoints,
        brightness: b.clamp(0, 255),
        colorCalibration: colorCalibration,
        calibrationProfiles: calibrationProfiles,
        activeCalibrationProfile: activeCalibrationProfile,
        scanMode: scanMode,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        scanDepthTop: scanDepthTop,
        scanDepthBottom: scanDepthBottom,
        scanDepthLeft: scanDepthLeft,
        scanDepthRight: scanDepthRight,
        segments: segments,
      );

  /// Python `calib_auto`: vymaže uložené kalibrační body.
  ScreenModeSettings withClearedCalibration() => ScreenModeSettings(
        monitorIndex: monitorIndex,
        scanDepthPercent: scanDepthPercent,
        paddingPercent: paddingPercent,
        saturationBoost: saturationBoost,
        ultraSaturation: ultraSaturation,
        ultraSaturationAmount: ultraSaturationAmount,
        minBrightness: minBrightness,
        interpolationMs: interpolationMs,
        gamma: gamma,
        activePreset: activePreset,
        calibrationPoints: null,
        brightness: brightness,
        colorCalibration: colorCalibration,
        calibrationProfiles: calibrationProfiles,
        activeCalibrationProfile: activeCalibrationProfile,
        scanMode: scanMode,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        scanDepthTop: scanDepthTop,
        scanDepthBottom: scanDepthBottom,
        scanDepthLeft: scanDepthLeft,
        scanDepthRight: scanDepthRight,
        segments: segments,
      );

  /// Tray / rychlé presety — mění jen vybrané parametry obrazovky.
  ScreenModeSettings withQuickTuning({
    double? saturationBoost,
    int? minBrightness,
    int? interpolationMs,
    double? gamma,
    String? activePreset,
  }) =>
      ScreenModeSettings(
        monitorIndex: monitorIndex,
        scanDepthPercent: scanDepthPercent,
        paddingPercent: paddingPercent,
        saturationBoost: saturationBoost ?? this.saturationBoost,
        ultraSaturation: ultraSaturation,
        ultraSaturationAmount: ultraSaturationAmount,
        minBrightness: minBrightness ?? this.minBrightness,
        interpolationMs: interpolationMs ?? this.interpolationMs,
        gamma: gamma ?? this.gamma,
        activePreset: activePreset ?? this.activePreset,
        calibrationPoints: calibrationPoints,
        brightness: brightness,
        colorCalibration: colorCalibration,
        calibrationProfiles: calibrationProfiles,
        activeCalibrationProfile: activeCalibrationProfile,
        scanMode: scanMode,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        scanDepthTop: scanDepthTop,
        scanDepthBottom: scanDepthBottom,
        scanDepthLeft: scanDepthLeft,
        scanDepthRight: scanDepthRight,
        segments: segments,
      );

  ScreenModeSettings copyWith({
    int? monitorIndex,
    int? scanDepthPercent,
    int? paddingPercent,
    double? saturationBoost,
    bool? ultraSaturation,
    double? ultraSaturationAmount,
    int? minBrightness,
    int? interpolationMs,
    double? gamma,
    String? activePreset,
    List<dynamic>? calibrationPoints,
    int? brightness,
    Map<String, dynamic>? colorCalibration,
    Map<String, Map<String, dynamic>>? calibrationProfiles,
    String? activeCalibrationProfile,
    String? scanMode,
    int? paddingTop,
    int? paddingBottom,
    int? paddingLeft,
    int? paddingRight,
    int? scanDepthTop,
    int? scanDepthBottom,
    int? scanDepthLeft,
    int? scanDepthRight,
    List<LedSegment>? segments,
  }) =>
      ScreenModeSettings(
        monitorIndex: monitorIndex ?? this.monitorIndex,
        scanDepthPercent: scanDepthPercent ?? this.scanDepthPercent,
        paddingPercent: paddingPercent ?? this.paddingPercent,
        saturationBoost: saturationBoost ?? this.saturationBoost,
        ultraSaturation: ultraSaturation ?? this.ultraSaturation,
        ultraSaturationAmount: ultraSaturationAmount ?? this.ultraSaturationAmount,
        minBrightness: minBrightness ?? this.minBrightness,
        interpolationMs: interpolationMs ?? this.interpolationMs,
        gamma: gamma ?? this.gamma,
        activePreset: activePreset ?? this.activePreset,
        calibrationPoints: calibrationPoints ?? this.calibrationPoints,
        brightness: brightness ?? this.brightness,
        colorCalibration: colorCalibration ?? this.colorCalibration,
        calibrationProfiles: calibrationProfiles ?? this.calibrationProfiles,
        activeCalibrationProfile: activeCalibrationProfile ?? this.activeCalibrationProfile,
        scanMode: scanMode ?? this.scanMode,
        paddingTop: paddingTop ?? this.paddingTop,
        paddingBottom: paddingBottom ?? this.paddingBottom,
        paddingLeft: paddingLeft ?? this.paddingLeft,
        paddingRight: paddingRight ?? this.paddingRight,
        scanDepthTop: scanDepthTop ?? this.scanDepthTop,
        scanDepthBottom: scanDepthBottom ?? this.scanDepthBottom,
        scanDepthLeft: scanDepthLeft ?? this.scanDepthLeft,
        scanDepthRight: scanDepthRight ?? this.scanDepthRight,
        segments: segments ?? this.segments,
      );
}

/// --- Music ---

class MusicModeSettings {
  const MusicModeSettings({
    this.audioDeviceIndex,
    this.micEnabled = false,
    this.colorSource = 'fixed',
    this.fixedColor = const [255, 0, 255],
    this.brightness = 200,
    this.beatDetectionEnabled = true,
    this.beatThreshold = 1.5,
    this.effect = 'energy',
    this.sensitivity = 50,
    this.bassSensitivity = 50,
    this.midSensitivity = 50,
    this.highSensitivity = 50,
    this.globalSensitivity = 50,
    this.subBassColor = const [255, 0, 0],
    this.bassColor = const [255, 50, 0],
    this.lowMidColor = const [255, 100, 0],
    this.midColor = const [0, 255, 0],
    this.highMidColor = const [0, 255, 255],
    this.presenceColor = const [0, 0, 255],
    this.brillianceColor = const [255, 0, 255],
    this.autoGain = false,
    this.autoMid = false,
    this.autoHigh = false,
    this.smoothingMs = 70,
    this.minBrightness = 0,
    this.rotationSpeed = 20,
    this.activePreset = 'Custom',
  });

  final int? audioDeviceIndex;
  final bool micEnabled;
  final String colorSource;
  final List<int> fixedColor;
  final int brightness;
  final bool beatDetectionEnabled;
  final double beatThreshold;
  final String effect;
  final int sensitivity;
  final int bassSensitivity;
  final int midSensitivity;
  final int highSensitivity;
  final int globalSensitivity;
  final List<int> subBassColor;
  final List<int> bassColor;
  final List<int> lowMidColor;
  final List<int> midColor;
  final List<int> highMidColor;
  final List<int> presenceColor;
  final List<int> brillianceColor;
  final bool autoGain;
  final bool autoMid;
  final bool autoHigh;
  final int smoothingMs;
  final int minBrightness;
  final int rotationSpeed;
  final String activePreset;

  Map<String, dynamic> toJson() => {
        'audio_device_index': audioDeviceIndex,
        'mic_enabled': micEnabled,
        'color_source': colorSource,
        'fixed_color': fixedColor,
        'brightness': brightness,
        'beat_detection_enabled': beatDetectionEnabled,
        'beat_threshold': beatThreshold,
        'effect': effect,
        'sensitivity': sensitivity,
        'bass_sensitivity': bassSensitivity,
        'mid_sensitivity': midSensitivity,
        'high_sensitivity': highSensitivity,
        'global_sensitivity': globalSensitivity,
        'sub_bass_color': subBassColor,
        'bass_color': bassColor,
        'low_mid_color': lowMidColor,
        'mid_color': midColor,
        'high_mid_color': highMidColor,
        'presence_color': presenceColor,
        'brilliance_color': brillianceColor,
        'auto_gain': autoGain,
        'auto_mid': autoMid,
        'auto_high': autoHigh,
        'smoothing_ms': smoothingMs,
        'min_brightness': minBrightness,
        'rotation_speed': rotationSpeed,
        'active_preset': activePreset,
      };

  factory MusicModeSettings.fromJson(Map<String, dynamic> j) {
    var effect = asString(j['effect'], 'energy');
    if (j.containsKey('visualization_type') && !j.containsKey('effect')) {
      effect = asString(j['visualization_type'], effect);
    }
    var m = MusicModeSettings(
      audioDeviceIndex: j['audio_device_index'] == null ? null : asInt(j['audio_device_index']),
      micEnabled: asBool(j['mic_enabled'], false),
      colorSource: asString(j['color_source'], 'fixed'),
      fixedColor: asRgb(j['fixed_color'], const [255, 0, 255]),
      brightness: asInt(j['brightness'], 200),
      beatDetectionEnabled: asBool(j['beat_detection_enabled'], true),
      beatThreshold: asDouble(j['beat_threshold'], 1.5),
      effect: effect,
      sensitivity: asInt(j['sensitivity'], 50),
      bassSensitivity: asInt(j['bass_sensitivity'], 50),
      midSensitivity: asInt(j['mid_sensitivity'], 50),
      highSensitivity: asInt(j['high_sensitivity'], 50),
      globalSensitivity: asInt(j['global_sensitivity'], 50),
      subBassColor: asRgb(j['sub_bass_color'], const [255, 0, 0]),
      bassColor: asRgb(j['bass_color'], const [255, 50, 0]),
      lowMidColor: asRgb(j['low_mid_color'], const [255, 100, 0]),
      midColor: asRgb(j['mid_color'], const [0, 255, 0]),
      highMidColor: asRgb(j['high_mid_color'], const [0, 255, 255]),
      presenceColor: asRgb(j['presence_color'], const [0, 0, 255]),
      brillianceColor: asRgb(j['brilliance_color'], const [255, 0, 255]),
      autoGain: asBool(j['auto_gain'], false),
      autoMid: asBool(j['auto_mid'], false),
      autoHigh: asBool(j['auto_high'], false),
      smoothingMs: asInt(j['smoothing_ms'], 70),
      minBrightness: asInt(j['min_brightness'], 0),
      rotationSpeed: asInt(j['rotation_speed'], 20),
      activePreset: asString(j['active_preset'], 'Custom'),
    );
    if (!j.containsKey('sub_bass_color') && j.containsKey('bass_color')) {
      final bass = asRgb(j['bass_color']);
      final mid = asRgb(j['mid_color'], const [0, 255, 0]);
      final high = asRgb(j['high_color'], const [0, 0, 255]);
      m = MusicModeSettings(
        audioDeviceIndex: m.audioDeviceIndex,
        micEnabled: m.micEnabled,
        colorSource: m.colorSource,
        fixedColor: m.fixedColor,
        brightness: m.brightness,
        beatDetectionEnabled: m.beatDetectionEnabled,
        beatThreshold: m.beatThreshold,
        effect: m.effect,
        sensitivity: m.sensitivity,
        bassSensitivity: m.bassSensitivity,
        midSensitivity: m.midSensitivity,
        highSensitivity: m.highSensitivity,
        globalSensitivity: m.globalSensitivity,
        subBassColor: bass,
        bassColor: bass,
        lowMidColor: [for (var i = 0; i < 3; i++) ((bass[i] + mid[i]) / 2).round()],
        midColor: mid,
        highMidColor: [for (var i = 0; i < 3; i++) ((mid[i] + high[i]) / 2).round()],
        presenceColor: high,
        brillianceColor: high,
        autoGain: m.autoGain,
        autoMid: m.autoMid,
        autoHigh: m.autoHigh,
        smoothingMs: m.smoothingMs,
        minBrightness: m.minBrightness,
        rotationSpeed: m.rotationSpeed,
        activePreset: m.activePreset,
      );
    }
    return m;
  }

  MusicModeSettings withBrightness(int b) => MusicModeSettings(
        audioDeviceIndex: audioDeviceIndex,
        micEnabled: micEnabled,
        colorSource: colorSource,
        fixedColor: fixedColor,
        brightness: b.clamp(0, 255),
        beatDetectionEnabled: beatDetectionEnabled,
        beatThreshold: beatThreshold,
        effect: effect,
        sensitivity: sensitivity,
        bassSensitivity: bassSensitivity,
        midSensitivity: midSensitivity,
        highSensitivity: highSensitivity,
        globalSensitivity: globalSensitivity,
        subBassColor: subBassColor,
        bassColor: bassColor,
        lowMidColor: lowMidColor,
        midColor: midColor,
        highMidColor: highMidColor,
        presenceColor: presenceColor,
        brillianceColor: brillianceColor,
        autoGain: autoGain,
        autoMid: autoMid,
        autoHigh: autoHigh,
        smoothingMs: smoothingMs,
        minBrightness: minBrightness,
        rotationSpeed: rotationSpeed,
        activePreset: activePreset,
      );

  MusicModeSettings withEffect(String e) => MusicModeSettings(
        audioDeviceIndex: audioDeviceIndex,
        micEnabled: micEnabled,
        colorSource: colorSource,
        fixedColor: fixedColor,
        brightness: brightness,
        beatDetectionEnabled: beatDetectionEnabled,
        beatThreshold: beatThreshold,
        effect: e,
        sensitivity: sensitivity,
        bassSensitivity: bassSensitivity,
        midSensitivity: midSensitivity,
        highSensitivity: highSensitivity,
        globalSensitivity: globalSensitivity,
        subBassColor: subBassColor,
        bassColor: bassColor,
        lowMidColor: lowMidColor,
        midColor: midColor,
        highMidColor: highMidColor,
        presenceColor: presenceColor,
        brillianceColor: brillianceColor,
        autoGain: autoGain,
        autoMid: autoMid,
        autoHigh: autoHigh,
        smoothingMs: smoothingMs,
        minBrightness: minBrightness,
        rotationSpeed: rotationSpeed,
        activePreset: activePreset,
      );

  MusicModeSettings withBandSensitivity({
    required int bass,
    required int mid,
    required int high,
    String? activePreset,
  }) =>
      MusicModeSettings(
        audioDeviceIndex: audioDeviceIndex,
        micEnabled: micEnabled,
        colorSource: colorSource,
        fixedColor: fixedColor,
        brightness: brightness,
        beatDetectionEnabled: beatDetectionEnabled,
        beatThreshold: beatThreshold,
        effect: effect,
        sensitivity: sensitivity,
        bassSensitivity: bass.clamp(0, 100),
        midSensitivity: mid.clamp(0, 100),
        highSensitivity: high.clamp(0, 100),
        globalSensitivity: globalSensitivity,
        subBassColor: subBassColor,
        bassColor: bassColor,
        lowMidColor: lowMidColor,
        midColor: midColor,
        highMidColor: highMidColor,
        presenceColor: presenceColor,
        brillianceColor: brillianceColor,
        autoGain: autoGain,
        autoMid: autoMid,
        autoHigh: autoHigh,
        smoothingMs: smoothingMs,
        minBrightness: minBrightness,
        rotationSpeed: rotationSpeed,
        activePreset: activePreset ?? this.activePreset,
      );

  MusicModeSettings copyWith({
    int? audioDeviceIndex,
    bool clearAudioDeviceIndex = false,
    bool? micEnabled,
    String? colorSource,
    List<int>? fixedColor,
    int? brightness,
    bool? beatDetectionEnabled,
    double? beatThreshold,
    String? effect,
    int? sensitivity,
    int? bassSensitivity,
    int? midSensitivity,
    int? highSensitivity,
    int? globalSensitivity,
    List<int>? subBassColor,
    List<int>? bassColor,
    List<int>? lowMidColor,
    List<int>? midColor,
    List<int>? highMidColor,
    List<int>? presenceColor,
    List<int>? brillianceColor,
    bool? autoGain,
    bool? autoMid,
    bool? autoHigh,
    int? smoothingMs,
    int? minBrightness,
    int? rotationSpeed,
    String? activePreset,
  }) =>
      MusicModeSettings(
        audioDeviceIndex: clearAudioDeviceIndex ? null : (audioDeviceIndex ?? this.audioDeviceIndex),
        micEnabled: micEnabled ?? this.micEnabled,
        colorSource: colorSource ?? this.colorSource,
        fixedColor: fixedColor ?? this.fixedColor,
        brightness: brightness ?? this.brightness,
        beatDetectionEnabled: beatDetectionEnabled ?? this.beatDetectionEnabled,
        beatThreshold: beatThreshold ?? this.beatThreshold,
        effect: effect ?? this.effect,
        sensitivity: sensitivity ?? this.sensitivity,
        bassSensitivity: bassSensitivity ?? this.bassSensitivity,
        midSensitivity: midSensitivity ?? this.midSensitivity,
        highSensitivity: highSensitivity ?? this.highSensitivity,
        globalSensitivity: globalSensitivity ?? this.globalSensitivity,
        subBassColor: subBassColor ?? this.subBassColor,
        bassColor: bassColor ?? this.bassColor,
        lowMidColor: lowMidColor ?? this.lowMidColor,
        midColor: midColor ?? this.midColor,
        highMidColor: highMidColor ?? this.highMidColor,
        presenceColor: presenceColor ?? this.presenceColor,
        brillianceColor: brillianceColor ?? this.brillianceColor,
        autoGain: autoGain ?? this.autoGain,
        autoMid: autoMid ?? this.autoMid,
        autoHigh: autoHigh ?? this.autoHigh,
        smoothingMs: smoothingMs ?? this.smoothingMs,
        minBrightness: minBrightness ?? this.minBrightness,
        rotationSpeed: rotationSpeed ?? this.rotationSpeed,
        activePreset: activePreset ?? this.activePreset,
      );
}

/// --- Spotify ---

class SpotifySettings {
  const SpotifySettings({
    this.enabled = false,
    this.accessToken,
    this.refreshToken,
    this.useAlbumColors = true,
    this.clientId,
    this.clientSecret,
  });

  final bool enabled;
  final String? accessToken;
  final String? refreshToken;
  final bool useAlbumColors;
  final String? clientId;
  final String? clientSecret;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'use_album_colors': useAlbumColors,
        'client_id': clientId,
        'client_secret': clientSecret,
      };

  factory SpotifySettings.fromJson(Map<String, dynamic> j) {
    return SpotifySettings(
      enabled: asBool(j['enabled'], false),
      accessToken: j['access_token']?.toString(),
      refreshToken: j['refresh_token']?.toString(),
      useAlbumColors: asBool(j['use_album_colors'], true),
      clientId: j['client_id']?.toString(),
      clientSecret: j['client_secret']?.toString(),
    );
  }

  SpotifySettings copyWith({
    bool? enabled,
    String? accessToken,
    String? refreshToken,
    bool? useAlbumColors,
    String? clientId,
    String? clientSecret,
    bool clearAccessToken = false,
    bool clearRefreshToken = false,
    bool clearClientSecret = false,
  }) {
    return SpotifySettings(
      enabled: enabled ?? this.enabled,
      accessToken: clearAccessToken ? null : (accessToken ?? this.accessToken),
      refreshToken: clearRefreshToken ? null : (refreshToken ?? this.refreshToken),
      useAlbumColors: useAlbumColors ?? this.useAlbumColors,
      clientId: clientId ?? this.clientId,
      clientSecret: clearClientSecret ? null : (clientSecret ?? this.clientSecret),
    );
  }
}

/// Dominantní barva z náhledu obalu u **aktuálně přehrávaného média v OS** (Windows GSMTC).
///
/// Funguje pro Apple Music (aplikace), často pro YouTube Music v prohlížeči / Edge — záleží,
/// zda přehrávač hlásí miniaturu do systému. Není náhrada oficiálního API YouTube Music.
class SystemMediaAlbumSettings {
  const SystemMediaAlbumSettings({
    this.enabled = false,
    this.useAlbumColors = true,
  });

  final bool enabled;
  final bool useAlbumColors;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'use_album_colors': useAlbumColors,
      };

  factory SystemMediaAlbumSettings.fromJson(Map<String, dynamic> j) {
    return SystemMediaAlbumSettings(
      enabled: asBool(j['enabled'], false),
      useAlbumColors: asBool(j['use_album_colors'], true),
    );
  }

  SystemMediaAlbumSettings copyWith({
    bool? enabled,
    bool? useAlbumColors,
  }) =>
      SystemMediaAlbumSettings(
        enabled: enabled ?? this.enabled,
        useAlbumColors: useAlbumColors ?? this.useAlbumColors,
      );
}

/// --- PC Health ---

class PcHealthSettings {
  const PcHealthSettings({
    this.enabled = false,
    this.updateRate = 500,
    this.brightness = 200,
    this.metrics = const [],
  });

  final bool enabled;
  final int updateRate;
  final int brightness;
  final List<Map<String, dynamic>> metrics;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'update_rate': updateRate,
        'brightness': brightness,
        'metrics': metrics,
      };

  factory PcHealthSettings.fromJson(Map<String, dynamic> j) {
    var metrics = asMapList(j['metrics']).map((e) => Map<String, dynamic>.from(e)).toList();
    if (metrics.isEmpty) {
      metrics = builtinPcHealthMetrics().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return PcHealthSettings(
      enabled: asBool(j['enabled'], false),
      updateRate: asInt(j['update_rate'], 500),
      brightness: asInt(j['brightness'], 200),
      metrics: metrics,
    );
  }

  PcHealthSettings copyWith({
    bool? enabled,
    int? updateRate,
    int? brightness,
    List<Map<String, dynamic>>? metrics,
  }) =>
      PcHealthSettings(
        enabled: enabled ?? this.enabled,
        updateRate: updateRate ?? this.updateRate,
        brightness: brightness ?? this.brightness,
        metrics: metrics ?? this.metrics,
      );

  PcHealthSettings withBrightness(int b) => PcHealthSettings(
        enabled: enabled,
        updateRate: updateRate,
        brightness: b.clamp(0, 255),
        metrics: metrics,
      );
}

/// --- Root ---

class AppConfig {
  const AppConfig({
    required this.globalSettings,
    required this.lightMode,
    required this.screenMode,
    required this.musicMode,
    required this.spotify,
    required this.systemMediaAlbum,
    required this.pcHealth,
    this.smartLights = SmartLightsSettings.disabled,
    this.userScreenPresets = const {},
    this.userMusicPresets = const {},
  });

  final GlobalSettings globalSettings;
  final LightModeSettings lightMode;
  final ScreenModeSettings screenMode;
  final MusicModeSettings musicMode;
  final SpotifySettings spotify;
  final SystemMediaAlbumSettings systemMediaAlbum;
  final PcHealthSettings pcHealth;
  /// Chytrá světla: Home Assistant (REST), Apple HomeKit (macOS), Google Home přes HA (návod v UI).
  final SmartLightsSettings smartLights;
  final Map<String, Map<String, dynamic>> userScreenPresets;
  final Map<String, Map<String, dynamic>> userMusicPresets;

  AppConfig copyWith({
    GlobalSettings? globalSettings,
    LightModeSettings? lightMode,
    ScreenModeSettings? screenMode,
    MusicModeSettings? musicMode,
    SpotifySettings? spotify,
    SystemMediaAlbumSettings? systemMediaAlbum,
    PcHealthSettings? pcHealth,
    SmartLightsSettings? smartLights,
    Map<String, Map<String, dynamic>>? userScreenPresets,
    Map<String, Map<String, dynamic>>? userMusicPresets,
  }) {
    return AppConfig(
      globalSettings: globalSettings ?? this.globalSettings,
      lightMode: lightMode ?? this.lightMode,
      screenMode: screenMode ?? this.screenMode,
      musicMode: musicMode ?? this.musicMode,
      spotify: spotify ?? this.spotify,
      systemMediaAlbum: systemMediaAlbum ?? this.systemMediaAlbum,
      pcHealth: pcHealth ?? this.pcHealth,
      smartLights: smartLights ?? this.smartLights,
      userScreenPresets: userScreenPresets ?? this.userScreenPresets,
      userMusicPresets: userMusicPresets ?? this.userMusicPresets,
    );
  }

  static AppConfig defaults() => AppConfig(
        globalSettings: GlobalSettings(
          devices: const [],
        ),
        lightMode: const LightModeSettings(),
        screenMode: const ScreenModeSettings(),
        musicMode: const MusicModeSettings(),
        spotify: const SpotifySettings(),
        systemMediaAlbum: const SystemMediaAlbumSettings(),
        pcHealth: PcHealthSettings(
          enabled: true,
          updateRate: 500,
          brightness: 200,
          metrics: builtinPcHealthMetrics().map((e) => Map<String, dynamic>.from(e)).toList(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'global_settings': globalSettings.toJson(),
        'light_mode': lightMode.toJson(),
        'screen_mode': screenMode.toJson(),
        'music_mode': musicMode.toJson(),
        'spotify': spotify.toJson(),
        'system_media_album': systemMediaAlbum.toJson(),
        'pc_health': pcHealth.toJson(),
        'smart_lights': smartLights.toJson(),
        'user_screen_presets': Map<String, dynamic>.from(userScreenPresets),
        'user_music_presets': Map<String, dynamic>.from(userMusicPresets),
      };

  String toJsonString() {
    final raw = jsonSanitizeForEncode(toJson());
    return const JsonEncoder.withIndent('    ').convert(raw);
  }

  /// Hluboká kopie pro lokální draft (např. nastavení před Apply).
  AppConfig clone() => AppConfig.fromJson(Map<String, dynamic>.from(toJson()));

  /// JSON na disk bez tokenů a `client_secret` (viz [ConfigRepository.save]).
  AppConfig sanitizedForPersistence() {
    return copyWith(
      spotify: spotify.copyWith(
        clearAccessToken: true,
        clearRefreshToken: true,
        clearClientSecret: true,
      ),
      smartLights: smartLights.copyWith(clearHaToken: true),
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> data) {
    if (!data.containsKey('global_settings')) {
      return AppConfig.defaults();
    }
    final usp = <String, Map<String, dynamic>>{};
    final rawUsp = data['user_screen_presets'];
    if (rawUsp is Map) {
      rawUsp.forEach((k, v) {
        usp[k.toString()] = asMap(v);
      });
    }
    final ump = <String, Map<String, dynamic>>{};
    final rawUmp = data['user_music_presets'];
    if (rawUmp is Map) {
      rawUmp.forEach((k, v) {
        ump[k.toString()] = asMap(v);
      });
    }
    return AppConfig(
      globalSettings: GlobalSettings.fromJson(asMap(data['global_settings'])),
      lightMode: LightModeSettings.fromJson(asMap(data['light_mode'])),
      screenMode: data['screen_mode'] != null
          ? ScreenModeSettings.fromJson(asMap(data['screen_mode']))
          : const ScreenModeSettings(),
      musicMode: data['music_mode'] != null
          ? MusicModeSettings.fromJson(asMap(data['music_mode']))
          : const MusicModeSettings(),
      spotify: data['spotify'] != null
          ? SpotifySettings.fromJson(asMap(data['spotify']))
          : const SpotifySettings(),
      systemMediaAlbum: data['system_media_album'] != null
          ? SystemMediaAlbumSettings.fromJson(asMap(data['system_media_album']))
          : const SystemMediaAlbumSettings(),
      pcHealth: data['pc_health'] != null
          ? PcHealthSettings.fromJson(asMap(data['pc_health']))
          : const PcHealthSettings(),
      smartLights: SmartLightsSettings.fromJson(
        data['smart_lights'] is Map ? asMap(data['smart_lights']) : null,
      ),
      userScreenPresets: usp,
      userMusicPresets: ump,
    );
  }

  factory AppConfig.parse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return AppConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppConfig.fromJson(decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {}
    return AppConfig.defaults();
  }
}
