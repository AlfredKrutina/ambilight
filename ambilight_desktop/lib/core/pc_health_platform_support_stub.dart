import 'package:flutter/foundation.dart';

/// Web / prostředí bez `dart:io` — na cíli macOS stejná politika jako v desktopové aplikaci.
bool get ambilightPcHealthUiAvailable =>
    defaultTargetPlatform != TargetPlatform.macOS;

/// Po [normalizeAmbilightStartMode]: na macOS přemapuje `pchealth` → `light`.
String coerceStartModeIfPcHealthUnavailable(String normalizedMode) {
  if (ambilightPcHealthUiAvailable) return normalizedMode;
  final m = normalizedMode.trim().toLowerCase().replaceAll('-', '_');
  if (m == 'pchealth' || m == 'pc_health') return 'light';
  return normalizedMode;
}
