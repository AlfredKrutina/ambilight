import '../core/models/config_models.dart';

/// Sends RGB frames to one ESP32 controller.
abstract class DeviceTransport {
  DeviceTransport(this.device);

  final DeviceSettings device;

  bool get isConnected;

  /// Opens port / validates UDP target. Non-throwing; sets [isConnected].
  Future<void> connect();

  void disconnect();

  /// [brightnessPercent] 0–100 for serial scaling; UDP uses 0–255 in packet (caller maps).
  void sendColors(List<(int r, int g, int b)> colors, int brightnessPercent);

  /// Optional: single pixel (Wi‑Fi calibration).
  void sendPixel(int index, int r, int g, int b);

  void dispose();
}
