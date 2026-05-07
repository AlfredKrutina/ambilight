import 'dart:io';

import 'package:flutter/foundation.dart';

/// Na macOS bez testů je PC Health skrytý a nepoužitelný jako startovací režim.
bool get ambilightPcHealthUiAvailable {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return true;
  if (Platform.isMacOS) return false;
  // Pojistka (embed / hybrid): hostitel macOS i když `Platform` selže výjimečně.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) return false;
  return true;
}

/// Po [normalizeAmbilightStartMode]: na macOS přemapuje `pchealth` → `light`.
String coerceStartModeIfPcHealthUnavailable(String normalizedMode) {
  if (ambilightPcHealthUiAvailable) return normalizedMode;
  final m = normalizedMode.trim().toLowerCase().replaceAll('-', '_');
  if (m == 'pchealth' || m == 'pc_health') return 'light';
  return normalizedMode;
}
