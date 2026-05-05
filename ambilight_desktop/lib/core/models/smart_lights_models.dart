import '../json/json_utils.dart';

/// Kde se fyzicky ovládá světlo (REST / nativní HomeKit).
enum SmartLightBackend {
  homeAssistant,
  appleHomeKit,
  ;

  static SmartLightBackend fromJson(String? s) {
    switch (s) {
      case 'apple_homekit':
        return SmartLightBackend.appleHomeKit;
      case 'home_assistant':
      default:
        return SmartLightBackend.homeAssistant;
    }
  }

  String toJsonValue() => switch (this) {
        SmartLightBackend.homeAssistant => 'home_assistant',
        SmartLightBackend.appleHomeKit => 'apple_homekit',
      };
}

/// `ambient` = barvy z engine; `manual` = uživatel drží barvu v UI (engine neposílá).
enum SmartFixtureMode {
  ambient,
  manual,
  ;

  static SmartFixtureMode from(String? s) =>
      s == 'manual' ? SmartFixtureMode.manual : SmartFixtureMode.ambient;

  String toJsonValue() => name;
}

/// `global_mean` — průměr všech LED všech zařízení.
/// `virtual_led_range` — výřez indexů na jednom `device_id`.
/// `screen_edge` — průměr z RGBA snímku podle hrany monitoru (stejná logika jako segmenty).
enum SmartBindingKind {
  globalMean,
  virtualLedRange,
  screenEdge,
  ;

  static SmartBindingKind from(String? s) {
    switch (s) {
      case 'virtual_led_range':
        return SmartBindingKind.virtualLedRange;
      case 'screen_edge':
        return SmartBindingKind.screenEdge;
      case 'global_mean':
      default:
        return SmartBindingKind.globalMean;
    }
  }

  String toJsonValue() => switch (this) {
        SmartBindingKind.globalMean => 'global_mean',
        SmartBindingKind.virtualLedRange => 'virtual_led_range',
        SmartBindingKind.screenEdge => 'screen_edge',
      };
}

/// Vazba barvy na zdroj (viz [SmartBindingKind]).
class SmartLightBinding {
  const SmartLightBinding({
    this.kind = SmartBindingKind.globalMean,
    this.deviceId,
    this.ledStart = 0,
    this.ledEnd = 0,
    this.monitorIndex = 1,
    this.edge = 'left',
    this.t0 = 0.0,
    this.t1 = 1.0,
    this.depthPercent = 12.0,
  });

  final SmartBindingKind kind;
  final String? deviceId;
  final int ledStart;
  final int ledEnd;
  final int monitorIndex;
  final String edge;
  final double t0;
  final double t1;
  final double depthPercent;

  Map<String, dynamic> toJson() => {
        'kind': kind.toJsonValue(),
        if (deviceId != null) 'device_id': deviceId,
        'led_start': ledStart,
        'led_end': ledEnd,
        'monitor_index': monitorIndex,
        'edge': edge,
        't0': t0,
        't1': t1,
        'depth_percent': depthPercent,
      };

  factory SmartLightBinding.fromJson(Map<String, dynamic> j) {
    return SmartLightBinding(
      kind: SmartBindingKind.from(asString(j['kind'], 'global_mean')),
      deviceId: j['device_id']?.toString(),
      ledStart: asInt(j['led_start'], 0),
      ledEnd: asInt(j['led_end'], 0),
      monitorIndex: asInt(j['monitor_index'], 1),
      edge: asString(j['edge'], 'left'),
      t0: (j['t0'] as num?)?.toDouble() ?? 0.0,
      t1: (j['t1'] as num?)?.toDouble() ?? 1.0,
      depthPercent: (j['depth_percent'] as num?)?.toDouble() ?? 12.0,
    );
  }

  SmartLightBinding copyWith({
    SmartBindingKind? kind,
    String? deviceId,
    bool clearDeviceId = false,
    int? ledStart,
    int? ledEnd,
    int? monitorIndex,
    String? edge,
    double? t0,
    double? t1,
    double? depthPercent,
  }) {
    return SmartLightBinding(
      kind: kind ?? this.kind,
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      ledStart: ledStart ?? this.ledStart,
      ledEnd: ledEnd ?? this.ledEnd,
      monitorIndex: monitorIndex ?? this.monitorIndex,
      edge: edge ?? this.edge,
      t0: t0 ?? this.t0,
      t1: t1 ?? this.t1,
      depthPercent: depthPercent ?? this.depthPercent,
    );
  }
}

/// Jedno mapovatelné světlo (HA entita nebo HomeKit accessory UUID).
class SmartFixture {
  const SmartFixture({
    required this.id,
    required this.displayName,
    this.backend = SmartLightBackend.homeAssistant,
    this.haEntityId = '',
    this.homeKitAccessoryUuid = '',
    this.enabled = true,
    this.mode = SmartFixtureMode.ambient,
    this.binding = const SmartLightBinding(),
    this.brightnessPctCap = 100,
    /// Pozice ve virtuální místnosti 0–1 (osa X vlevo–vpravo, Y „dál od uživatele“ = směr k TV nahoře).
    this.roomX = 0.5,
    this.roomY = 0.42,
  });

  final String id;
  final String displayName;
  final SmartLightBackend backend;
  /// Např. `light.obyvak` pro Home Assistant.
  final String haEntityId;
  /// `HMAccessory.uniqueIdentifier.uuidString` na macOS.
  final String homeKitAccessoryUuid;
  final bool enabled;
  final SmartFixtureMode mode;
  final SmartLightBinding binding;
  final int brightnessPctCap;
  final double roomX;
  final double roomY;

  SmartFixture copyWith({
    String? id,
    String? displayName,
    SmartLightBackend? backend,
    String? haEntityId,
    String? homeKitAccessoryUuid,
    bool? enabled,
    SmartFixtureMode? mode,
    SmartLightBinding? binding,
    int? brightnessPctCap,
    double? roomX,
    double? roomY,
  }) {
    return SmartFixture(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      backend: backend ?? this.backend,
      haEntityId: haEntityId ?? this.haEntityId,
      homeKitAccessoryUuid: homeKitAccessoryUuid ?? this.homeKitAccessoryUuid,
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      binding: binding ?? this.binding,
      brightnessPctCap: brightnessPctCap ?? this.brightnessPctCap,
      roomX: roomX ?? this.roomX,
      roomY: roomY ?? this.roomY,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'backend': backend.toJsonValue(),
        'ha_entity_id': haEntityId,
        'homekit_accessory_uuid': homeKitAccessoryUuid,
        'enabled': enabled,
        'mode': mode.toJsonValue(),
        'binding': binding.toJson(),
        'brightness_pct_cap': brightnessPctCap.clamp(1, 100),
        'room_x': roomX.clamp(0.0, 1.0),
        'room_y': roomY.clamp(0.0, 1.0),
      };

  factory SmartFixture.fromJson(Map<String, dynamic> j) {
    return SmartFixture(
      id: asString(j['id'], 'fx1'),
      displayName: asString(j['display_name'], 'Light'),
      backend: SmartLightBackend.fromJson(j['backend']?.toString()),
      haEntityId: asString(j['ha_entity_id'], ''),
      homeKitAccessoryUuid: asString(j['homekit_accessory_uuid'], ''),
      enabled: asBool(j['enabled'], true),
      mode: SmartFixtureMode.from(j['mode']?.toString()),
      binding: j['binding'] is Map
          ? SmartLightBinding.fromJson(asMap(j['binding']))
          : const SmartLightBinding(),
      brightnessPctCap: asInt(j['brightness_pct_cap'], 100).clamp(1, 100),
      roomX: (j['room_x'] as num?)?.toDouble() ?? 0.5,
      roomY: (j['room_y'] as num?)?.toDouble() ?? 0.42,
    );
  }
}

/// Efekt virtuální místnosti pro smart světla (HA / HomeKit).
enum SmartRoomEffectKind {
  none,
  wave,
  breath,
  chase,
  sparkle,
  ;

  static SmartRoomEffectKind fromJson(String? s) {
    switch (s) {
      case 'wave':
        return SmartRoomEffectKind.wave;
      case 'breath':
        return SmartRoomEffectKind.breath;
      case 'chase':
        return SmartRoomEffectKind.chase;
      case 'sparkle':
        return SmartRoomEffectKind.sparkle;
      case 'none':
        return SmartRoomEffectKind.none;
      default:
        return SmartRoomEffectKind.wave;
    }
  }

  String toJsonValue() => switch (this) {
        SmartRoomEffectKind.none => 'none',
        SmartRoomEffectKind.wave => 'wave',
        SmartRoomEffectKind.breath => 'breath',
        SmartRoomEffectKind.chase => 'chase',
        SmartRoomEffectKind.sparkle => 'sparkle',
      };
}

/// Geometrie prostorové fáze vlny / chase (řazení podle projekce).
enum SmartRoomWaveGeometry {
  /// Kulová vlna od pozice TV (legacy).
  radialFromTv,
  /// Fáze podle projekce kolmo na pohled uživatele (uživatel–TV + [userFacingDeg]).
  alongUserView,
  /// Projektovat na vodorovnou osu místnosti (relativně k TV).
  horizontalRoom,
  /// Projektovat na svislou osu místnosti (relativně k TV).
  verticalRoom,
  /// Osa pod úhlem [VirtualRoomLayout.waveExtraAngleDeg] od vodorovné osi (0° = vpravo).
  customAngle,
  ;

  static SmartRoomWaveGeometry fromJson(String? s) {
    switch (s) {
      case 'along_user_view':
        return SmartRoomWaveGeometry.alongUserView;
      case 'horizontal_room':
        return SmartRoomWaveGeometry.horizontalRoom;
      case 'vertical_room':
        return SmartRoomWaveGeometry.verticalRoom;
      case 'custom_angle':
        return SmartRoomWaveGeometry.customAngle;
      case 'radial_from_tv':
      default:
        return SmartRoomWaveGeometry.radialFromTv;
    }
  }

  String toJsonValue() => switch (this) {
        SmartRoomWaveGeometry.radialFromTv => 'radial_from_tv',
        SmartRoomWaveGeometry.alongUserView => 'along_user_view',
        SmartRoomWaveGeometry.horizontalRoom => 'horizontal_room',
        SmartRoomWaveGeometry.verticalRoom => 'vertical_room',
        SmartRoomWaveGeometry.customAngle => 'custom_angle',
      };
}

/// Jak efekt mění výstup: jen barva, jen jas HA, nebo obojí.
enum SmartRoomBrightnessModulate {
  rgbOnly,
  brightnessOnly,
  both,
  ;

  static SmartRoomBrightnessModulate fromJson(String? s) {
    switch (s) {
      case 'rgb_only':
        return SmartRoomBrightnessModulate.rgbOnly;
      case 'brightness_only':
        return SmartRoomBrightnessModulate.brightnessOnly;
      case 'both':
      default:
        return SmartRoomBrightnessModulate.both;
    }
  }

  String toJsonValue() => switch (this) {
        SmartRoomBrightnessModulate.rgbOnly => 'rgb_only',
        SmartRoomBrightnessModulate.brightnessOnly => 'brightness_only',
        SmartRoomBrightnessModulate.both => 'both',
      };
}

/// Virtuální půdorys: TV, pozice uživatele, směr pohledu, parametry vlnění přes světla.
class VirtualRoomLayout {
  const VirtualRoomLayout({
    this.tvX = 0.5,
    this.tvY = 0.14,
    this.userX = 0.5,
    this.userY = 0.72,
    /// Odchylka od pohledu „přímo na TV“ (°): 0 = čelem k obrazovce, + = otočení doprava.
    this.userFacingDeg = 0,
    this.roomEffect = SmartRoomEffectKind.wave,
    this.waveGeometry = SmartRoomWaveGeometry.radialFromTv,
    /// Pro [SmartRoomWaveGeometry.customAngle]: úhel osy vlnění ve ° (0 = vodorovně vpravo).
    this.waveExtraAngleDeg = 0,
    this.brightnessModulation = SmartRoomBrightnessModulate.both,
    /// Násobič [animationTick] — vyšší = rychlejší vlna.
    this.waveSpeed = 0.07,
    /// 0 = žádný efekt, 1 = plná modulace podle průběhu.
    this.waveStrength = 0.38,
    /// Jak moc prostorová souřadnice posouvá fázi (větší = ostřejší fronta).
    this.waveDistanceScale = 5.5,
  });

  final double tvX;
  final double tvY;
  final double userX;
  final double userY;
  final double userFacingDeg;
  final SmartRoomEffectKind roomEffect;
  final SmartRoomWaveGeometry waveGeometry;
  final double waveExtraAngleDeg;
  final SmartRoomBrightnessModulate brightnessModulation;
  final double waveSpeed;
  final double waveStrength;
  final double waveDistanceScale;

  /// Zpětná kompatibilita: `true` když [roomEffect] není [SmartRoomEffectKind.none].
  bool get waveEnabled => roomEffect != SmartRoomEffectKind.none;

  VirtualRoomLayout copyWith({
    double? tvX,
    double? tvY,
    double? userX,
    double? userY,
    double? userFacingDeg,
    SmartRoomEffectKind? roomEffect,
    SmartRoomWaveGeometry? waveGeometry,
    double? waveExtraAngleDeg,
    SmartRoomBrightnessModulate? brightnessModulation,
    double? waveSpeed,
    double? waveStrength,
    double? waveDistanceScale,
  }) {
    return VirtualRoomLayout(
      tvX: tvX ?? this.tvX,
      tvY: tvY ?? this.tvY,
      userX: userX ?? this.userX,
      userY: userY ?? this.userY,
      userFacingDeg: userFacingDeg ?? this.userFacingDeg,
      roomEffect: roomEffect ?? this.roomEffect,
      waveGeometry: waveGeometry ?? this.waveGeometry,
      waveExtraAngleDeg: waveExtraAngleDeg ?? this.waveExtraAngleDeg,
      brightnessModulation: brightnessModulation ?? this.brightnessModulation,
      waveSpeed: waveSpeed ?? this.waveSpeed,
      waveStrength: waveStrength ?? this.waveStrength,
      waveDistanceScale: waveDistanceScale ?? this.waveDistanceScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'tv_x': tvX.clamp(0.0, 1.0),
        'tv_y': tvY.clamp(0.0, 1.0),
        'user_x': userX.clamp(0.0, 1.0),
        'user_y': userY.clamp(0.0, 1.0),
        'user_facing_deg': userFacingDeg,
        'room_effect': roomEffect.toJsonValue(),
        'wave_geometry': waveGeometry.toJsonValue(),
        'wave_extra_angle_deg': waveExtraAngleDeg,
        'brightness_modulation': brightnessModulation.toJsonValue(),
        'wave_enabled': waveEnabled,
        'wave_speed': waveSpeed.clamp(0.01, 0.5),
        'wave_strength': waveStrength.clamp(0.0, 1.0),
        'wave_distance_scale': waveDistanceScale.clamp(0.5, 20.0),
      };

  factory VirtualRoomLayout.fromJson(Map<String, dynamic>? j) {
    if (j == null || j.isEmpty) return const VirtualRoomLayout();
    SmartRoomEffectKind effect;
    if (j.containsKey('room_effect')) {
      effect = SmartRoomEffectKind.fromJson(j['room_effect']?.toString());
    } else {
      effect = asBool(j['wave_enabled'], true) ? SmartRoomEffectKind.wave : SmartRoomEffectKind.none;
    }
    return VirtualRoomLayout(
      tvX: (j['tv_x'] as num?)?.toDouble() ?? 0.5,
      tvY: (j['tv_y'] as num?)?.toDouble() ?? 0.14,
      userX: (j['user_x'] as num?)?.toDouble() ?? 0.5,
      userY: (j['user_y'] as num?)?.toDouble() ?? 0.72,
      userFacingDeg: (j['user_facing_deg'] as num?)?.toDouble() ?? 0.0,
      roomEffect: effect,
      waveGeometry: SmartRoomWaveGeometry.fromJson(j['wave_geometry']?.toString()),
      waveExtraAngleDeg: (j['wave_extra_angle_deg'] as num?)?.toDouble() ?? 0.0,
      brightnessModulation: SmartRoomBrightnessModulate.fromJson(j['brightness_modulation']?.toString()),
      waveSpeed: (j['wave_speed'] as num?)?.toDouble() ?? 0.07,
      waveStrength: (j['wave_strength'] as num?)?.toDouble() ?? 0.38,
      waveDistanceScale: (j['wave_distance_scale'] as num?)?.toDouble() ?? 5.5,
    );
  }
}

/// Integrace Home Assistant + volitelně Apple HomeKit (macOS) + návod na Google Home přes HA.
class SmartLightsSettings {
  const SmartLightsSettings({
    this.enabled = false,
    this.haBaseUrl = '',
    this.haLongLivedToken = '',
    this.haAllowInsecureCert = false,
    this.haTimeoutSeconds = 12,
    this.maxUpdateHzPerFixture = 8,
    this.globalBrightnessCapPct = 100,
    /// 0–200 % saturace barvy před `light.turn_on` (100 = beze změny).
    this.haColorSaturationPercent = 100,
    /// V režimu Hudba zrychlit odesílání do HA podle beatu (i bez prostorového efektu).
    this.haMusicReactiveThrottle = true,
    /// Při náběžné hraně beatu přičíst k jasu světel v HA (0 = vypnuto).
    this.haMusicBeatBrightnessBoost = 0,
    this.fixtures = const [],
    this.virtualRoom = const VirtualRoomLayout(),
  });

  final bool enabled;
  final String haBaseUrl;
  /// Runtime hodnota; v `default.json` se maže v [AppConfig.sanitizedForPersistence].
  /// Trvalý token na disku drží aplikace v souboru `ha_long_lived_token.txt` (viz controller load/save).
  final String haLongLivedToken;
  final bool haAllowInsecureCert;
  final int haTimeoutSeconds;
  final int maxUpdateHzPerFixture;
  final int globalBrightnessCapPct;
  final int haColorSaturationPercent;
  final bool haMusicReactiveThrottle;
  final int haMusicBeatBrightnessBoost;
  final List<SmartFixture> fixtures;
  final VirtualRoomLayout virtualRoom;

  static const SmartLightsSettings disabled = SmartLightsSettings();

  SmartLightsSettings copyWith({
    bool? enabled,
    String? haBaseUrl,
    String? haLongLivedToken,
    bool clearHaToken = false,
    bool? haAllowInsecureCert,
    int? haTimeoutSeconds,
    int? maxUpdateHzPerFixture,
    int? globalBrightnessCapPct,
    int? haColorSaturationPercent,
    bool? haMusicReactiveThrottle,
    int? haMusicBeatBrightnessBoost,
    List<SmartFixture>? fixtures,
    VirtualRoomLayout? virtualRoom,
  }) {
    return SmartLightsSettings(
      enabled: enabled ?? this.enabled,
      haBaseUrl: haBaseUrl ?? this.haBaseUrl,
      haLongLivedToken: clearHaToken ? '' : (haLongLivedToken ?? this.haLongLivedToken),
      haAllowInsecureCert: haAllowInsecureCert ?? this.haAllowInsecureCert,
      haTimeoutSeconds: haTimeoutSeconds ?? this.haTimeoutSeconds,
      maxUpdateHzPerFixture: maxUpdateHzPerFixture ?? this.maxUpdateHzPerFixture,
      globalBrightnessCapPct: globalBrightnessCapPct ?? this.globalBrightnessCapPct,
      haColorSaturationPercent: haColorSaturationPercent ?? this.haColorSaturationPercent,
      haMusicReactiveThrottle: haMusicReactiveThrottle ?? this.haMusicReactiveThrottle,
      haMusicBeatBrightnessBoost: haMusicBeatBrightnessBoost ?? this.haMusicBeatBrightnessBoost,
      fixtures: fixtures ?? this.fixtures,
      virtualRoom: virtualRoom ?? this.virtualRoom,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'ha_base_url': haBaseUrl,
        'ha_long_lived_token': haLongLivedToken,
        'ha_allow_insecure_cert': haAllowInsecureCert,
        'ha_timeout_seconds': haTimeoutSeconds.clamp(3, 120),
        'max_update_hz_per_fixture': maxUpdateHzPerFixture.clamp(1, 30),
        'global_brightness_cap_pct': globalBrightnessCapPct.clamp(1, 100),
        'ha_color_saturation_pct': haColorSaturationPercent.clamp(0, 200),
        'ha_music_reactive_throttle': haMusicReactiveThrottle,
        'ha_music_beat_brightness_boost': haMusicBeatBrightnessBoost.clamp(0, 35),
        'fixtures': fixtures.map((e) => e.toJson()).toList(),
        'virtual_room': virtualRoom.toJson(),
      };

  factory SmartLightsSettings.fromJson(Map<String, dynamic>? j) {
    if (j == null || j.isEmpty) return SmartLightsSettings.disabled;
    List<SmartFixture> fx = const [];
    if (j['fixtures'] is List) {
      fx = (j['fixtures'] as List).map((e) => SmartFixture.fromJson(asMap(e))).toList();
    }
    return SmartLightsSettings(
      enabled: asBool(j['enabled'], false),
      haBaseUrl: asString(j['ha_base_url'], ''),
      haLongLivedToken: asString(j['ha_long_lived_token'], ''),
      haAllowInsecureCert: asBool(j['ha_allow_insecure_cert'], false),
      haTimeoutSeconds: asInt(j['ha_timeout_seconds'], 12).clamp(3, 120),
      maxUpdateHzPerFixture: asInt(j['max_update_hz_per_fixture'], 8).clamp(1, 30),
      globalBrightnessCapPct: asInt(j['global_brightness_cap_pct'], 100).clamp(1, 100),
      haColorSaturationPercent: asInt(j['ha_color_saturation_pct'], 100).clamp(0, 200),
      haMusicReactiveThrottle: j['ha_music_reactive_throttle'] is bool
          ? j['ha_music_reactive_throttle'] as bool
          : asBool(j['ha_music_reactive_throttle'], true),
      haMusicBeatBrightnessBoost: asInt(j['ha_music_beat_brightness_boost'], 0).clamp(0, 35),
      fixtures: fx,
      virtualRoom: VirtualRoomLayout.fromJson(j['virtual_room'] is Map ? asMap(j['virtual_room']) : null),
    );
  }
}
