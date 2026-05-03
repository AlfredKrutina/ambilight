import '../core/models/config_models.dart';

/// Placeholder dokud nejsou hotové capture / audio / systémové metriky.
class MusicModeStub {
  static List<(int, int, int)> black(int n) =>
      List<(int, int, int)>.filled(n, (0, 0, 0), growable: false);
}

/// Vrací jas pro režim (stejná pole jako Python typicky 0–255).
int brightnessForMode(AppConfig c) {
  switch (c.globalSettings.startMode) {
    case 'light':
      return c.lightMode.brightness;
    case 'screen':
      return c.screenMode.brightness;
    case 'music':
      return c.musicMode.brightness;
    case 'pchealth':
      // Barvy už mají zahrnutý jas z metrik (`_process_pchealth_mode` vrací 255).
      return 255;
    default:
      return 200;
  }
}
