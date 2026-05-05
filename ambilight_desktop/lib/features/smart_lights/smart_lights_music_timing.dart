import '../../services/music/music_types.dart';

/// Kontext z FFT/hudby pro modulaci smart světel (bez stavu — drží ho [SmartLightCoordinator]).
class SmartLightsMusicTiming {
  const SmartLightsMusicTiming({
    required this.active,
    required this.beatEnvelope,
    required this.beatEdge,
  });

  /// Hudba + zapnutá detekce beatu v nastavení.
  final bool active;
  /// 0–1 po nárazu beatu, exponenciální pokles mezi beaty.
  final double beatEnvelope;
  /// Náběžná hrana složeného beatu (vhodné pro „kopnutí“ fáze).
  final bool beatEdge;

  static const inactive = SmartLightsMusicTiming(active: false, beatEnvelope: 0, beatEdge: false);
}

/// Stejná logika jako u výpočtu beatů ve vizualizaci pásku ([MusicSegmentRenderer]).
bool smartLightsMusicBeatComposite(MusicAnalysisSnapshot s) {
  return s.bass.isBeat ||
      s.lowMid.isBeat ||
      s.mid.isBeat ||
      s.brilliance.isBeat ||
      s.melodyBeat ||
      s.melodyOnset;
}
