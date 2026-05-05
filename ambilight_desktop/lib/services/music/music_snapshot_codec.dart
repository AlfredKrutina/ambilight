import 'music_types.dart';

Map<String, Object?> musicSnapshotToMap(MusicAnalysisSnapshot s) {
  Map<String, Object?> band(MusicBandSnapshot b) => <String, Object?>{
        'b': b.isBeat,
        'i': b.intensity,
        's': b.smoothed,
        'e': b.energy,
      };
  return <String, Object?>{
    'sub': band(s.subBass),
    'ba': band(s.bass),
    'lm': band(s.lowMid),
    'mi': band(s.mid),
    'hm': band(s.highMid),
    'pr': band(s.presence),
    'br': band(s.brilliance),
    'ol': s.overallLoudness,
    'sr': s.sampleRate,
    'mo': s.melodyOnset,
    'mb': s.melodyBeat,
    'mph': s.melodyPitchHz,
    'mnc': s.melodyNoteClass,
    'mpc': s.melodyPitchConfidence,
    'md': s.melodyDynamics,
  };
}

MusicBandSnapshot _bandFromMap(Object? raw) {
  if (raw is! Map) return MusicBandSnapshot.empty;
  final m = Map<String, Object?>.from(raw);
  return MusicBandSnapshot(
    isBeat: m['b'] == true,
    intensity: (m['i'] as num?)?.toDouble() ?? 0,
    smoothed: (m['s'] as num?)?.toDouble() ?? 0,
    energy: (m['e'] as num?)?.toDouble() ?? 0,
  );
}

MusicAnalysisSnapshot musicSnapshotFromMap(Map<String, Object?> m) {
  return MusicAnalysisSnapshot(
    subBass: _bandFromMap(m['sub']),
    bass: _bandFromMap(m['ba']),
    lowMid: _bandFromMap(m['lm']),
    mid: _bandFromMap(m['mi']),
    highMid: _bandFromMap(m['hm']),
    presence: _bandFromMap(m['pr']),
    brilliance: _bandFromMap(m['br']),
    overallLoudness: (m['ol'] as num?)?.toDouble() ?? 0,
    sampleRate: (m['sr'] as num?)?.toInt() ?? 48000,
    melodyOnset: m['mo'] == true,
    melodyBeat: m['mb'] == true,
    melodyPitchHz: (m['mph'] as num?)?.toDouble() ?? 0,
    melodyNoteClass: (m['mnc'] as num?)?.toInt() ?? -1,
    melodyPitchConfidence: (m['mpc'] as num?)?.toDouble() ?? 0,
    melodyDynamics: (m['md'] as num?)?.toDouble() ?? 0,
  );
}
