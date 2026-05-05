import 'dart:async';

import '../core/models/config_models.dart';

/// Sends RGB frames to one ESP32 controller.
abstract class DeviceTransport {
  DeviceTransport(this.device);

  /// Aktuální snapshot zařízení; může se měnit po [syncDeviceSnapshot] bez nového transportu.
  DeviceSettings device;

  bool get isConnected;

  /// Opens port / validates UDP target. Non-throwing; sets [isConnected].
  Future<void> connect();

  void disconnect();

  /// Engine brightness 0–255 (viz [brightnessForMode]); UDP bere jako bajt jasu, USB sériové mapuje na škálu rámu /100.
  void sendColors(List<(int r, int g, int b)> colors, int brightnessPercent);

  /// Stejný obsah jako [sendColors], ale bez UDP 16ms bulk časovače — průvodce (full blackout před [sendPixel]).
  Future<void> sendColorsNow(List<(int r, int g, int b)> colors, int brightnessPercent) async {
    sendColors(colors, brightnessPercent);
  }

  /// Optional: single pixel (Wi‑Fi calibration).
  void sendPixel(int index, int r, int g, int b);

  /// USB sériové ESP: `0xA5 0x5A` + počet LED (logická délka pásku). Wi‑Fi / jiné: výchozí no-op.
  void announceLogicalStripLength(int ledCount) {}

  /// Po debouncované změně [DeviceSettings] bez přebudování transportu (např. `led_count`).
  void syncDeviceSnapshot(DeviceSettings next) {}

  /// Globální výkonový režim (perioda COM drain apod.) — bez zavírání portu.
  void applyPerformanceMode(bool performanceMode) {}

  void dispose();

  /// Po [dispose] může ještě dobíhat nativní uvolnění (např. COM na Windows) — [AmbilightAppController]
  /// pošle všechny dispose a pak na tomto počká, aby se nekrývalo s ukládáním konfigurace.
  Future<void> flushPendingDispose() async {}
}
