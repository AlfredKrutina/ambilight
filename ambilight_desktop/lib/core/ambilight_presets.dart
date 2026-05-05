// Rychlé presety zarovnané s Python `led_strip_monitor_pokus - Copy/src/app_config.py`.

class ScreenPresetPatch {
  const ScreenPresetPatch({
    required this.saturationBoost,
    required this.minBrightness,
    required this.interpolationMs,
    required this.gamma,
    required this.activePresetLabel,
  });

  final double saturationBoost;
  final int minBrightness;
  final int interpolationMs;
  final double gamma;
  final String activePresetLabel;
}

class MusicPresetPatch {
  const MusicPresetPatch({
    required this.bass,
    required this.mid,
    required this.high,
    required this.activePresetLabel,
  });

  final int bass;
  final int mid;
  final int high;
  final String activePresetLabel;
}

class AmbilightPresets {
  AmbilightPresets._();

  static const screenNames = ['Movie', 'Gaming', 'Desktop'];
  static const musicNames = ['Party', 'Chill', 'Bass Focus', 'Vocals'];

  /// Krátký popisek jen pro tray UI; [screenPatch] musí dál používat přesný klíč [name].
  static String trayDisplayLabelForScreenPreset(String name) {
    switch (name) {
      case 'Movie':
        return 'Movie (Vivid & Smooth)';
      case 'Gaming':
        return 'Gaming (Fast & Responsive)';
      case 'Desktop':
        return 'Desktop (Balanced)';
      default:
        return name;
    }
  }

  /// Krátký popisek jen pro tray UI; [musicPatch] musí dál používat přesný klíč [name].
  static String trayDisplayLabelForMusicPreset(String name) {
    switch (name) {
      case 'Party':
        return 'Party (Full Spectrum)';
      case 'Chill':
        return 'Chill (Soft)';
      case 'Bass Focus':
        return 'Bass Focus (Low-End)';
      case 'Vocals':
        return 'Vocals (Mid/High)';
      default:
        return name;
    }
  }

  static ScreenPresetPatch? screenPatch(String name) {
    switch (name) {
      case 'Movie':
        return const ScreenPresetPatch(
          saturationBoost: 1.8,
          minBrightness: 10,
          interpolationMs: 150,
          gamma: 1.3,
          activePresetLabel: 'Movie',
        );
      case 'Gaming':
        return const ScreenPresetPatch(
          saturationBoost: 1.2,
          minBrightness: 2,
          interpolationMs: 30,
          gamma: 1.0,
          activePresetLabel: 'Gaming',
        );
      case 'Desktop':
        return const ScreenPresetPatch(
          saturationBoost: 1.0,
          minBrightness: 0,
          interpolationMs: 80,
          gamma: 1.0,
          activePresetLabel: 'Desktop',
        );
      default:
        return null;
    }
  }

  static MusicPresetPatch? musicPatch(String name) {
    switch (name) {
      case 'Party':
        return const MusicPresetPatch(bass: 80, mid: 70, high: 70, activePresetLabel: 'Party');
      case 'Chill':
        return const MusicPresetPatch(bass: 40, mid: 40, high: 40, activePresetLabel: 'Chill');
      case 'Bass Focus':
        return const MusicPresetPatch(bass: 90, mid: 30, high: 20, activePresetLabel: 'Bass Focus');
      case 'Vocals':
        return const MusicPresetPatch(bass: 40, mid: 90, high: 40, activePresetLabel: 'Vocals');
      default:
        return null;
    }
  }
}
