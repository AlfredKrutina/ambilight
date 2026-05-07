/// Snímek analýzy (7 pásem + hlasitost), kompatibilní s Python `audio_analyzer.py`.
class MusicBandSnapshot {
  const MusicBandSnapshot({
    required this.isBeat,
    required this.intensity,
    required this.smoothed,
    required this.energy,
  });

  final bool isBeat;
  final double intensity;
  final double smoothed;
  final double energy;

  static const empty = MusicBandSnapshot(
    isBeat: false,
    intensity: 0,
    smoothed: 0,
    energy: 0,
  );
}

class MusicAnalysisSnapshot {
  const MusicAnalysisSnapshot({
    required this.subBass,
    required this.bass,
    required this.lowMid,
    required this.mid,
    required this.highMid,
    required this.presence,
    required this.brilliance,
    required this.overallLoudness,
    required this.sampleRate,
    this.melodyOnset = false,
    this.melodyBeat = false,
    this.melodyPitchHz = 0,
    this.melodyNoteClass = -1,
    this.melodyPitchConfidence = 0,
    this.melodyDynamics = 0,
  });

  final MusicBandSnapshot subBass;
  final MusicBandSnapshot bass;
  final MusicBandSnapshot lowMid;
  final MusicBandSnapshot mid;
  final MusicBandSnapshot highMid;
  final MusicBandSnapshot presence;
  final MusicBandSnapshot brilliance;
  final double overallLoudness;
  final int sampleRate;

  /// Port `melody_detector` — chromatická třída 0–11, nebo -1.
  final bool melodyOnset;
  final bool melodyBeat;
  final double melodyPitchHz;
  final int melodyNoteClass;
  final double melodyPitchConfidence;
  final double melodyDynamics;

  MusicBandSnapshot named(String n) {
    switch (n) {
      case 'sub_bass':
        return subBass;
      case 'bass':
        return bass;
      case 'low_mid':
        return lowMid;
      case 'mid':
        return mid;
      case 'high_mid':
        return highMid;
      case 'presence':
        return presence;
      case 'brilliance':
        return brilliance;
      default:
        return MusicBandSnapshot.empty;
    }
  }

  static MusicAnalysisSnapshot silent({int sampleRate = 48000}) => MusicAnalysisSnapshot(
        subBass: MusicBandSnapshot.empty,
        bass: MusicBandSnapshot.empty,
        lowMid: MusicBandSnapshot.empty,
        mid: MusicBandSnapshot.empty,
        highMid: MusicBandSnapshot.empty,
        presence: MusicBandSnapshot.empty,
        brilliance: MusicBandSnapshot.empty,
        overallLoudness: 0,
        sampleRate: sampleRate,
        melodyOnset: false,
        melodyBeat: false,
        melodyPitchHz: 0,
        melodyNoteClass: -1,
        melodyPitchConfidence: 0,
        melodyDynamics: 0,
      );
}

/// Vstupní zařízení pro UI / výběr (index = pozice v aktuálním seznamu).
class MusicCaptureDeviceInfo {
  const MusicCaptureDeviceInfo({
    required this.index,
    required this.id,
    required this.label,
    required this.isLoopback,
  });

  final int index;
  final String id;
  final String label;
  final bool isLoopback;
}

/// Capture backend pro UI diagnostiku — který kanál právě bere zvuk.
enum MusicCaptureBackend {
  /// Žádný capture neběží (idle / mód není „music“).
  none,
  /// `record` plugin (mic / virtuální vstup typu BlackHole / Aggregate / VB‑Cable).
  recordPackage,
  /// `desktop_audio_capture` WASAPI loopback (Windows výchozí render device).
  windowsWasapiLoopback,
}

/// Stručný popis aktuálního capture stavu pro UI; aktualizuje [MusicAudioService.captureInfoNotifier].
class MusicCaptureInfo {
  const MusicCaptureInfo({
    required this.active,
    required this.backend,
    required this.deviceLabel,
    required this.sampleRate,
    required this.channels,
    required this.isLoopback,
  });

  const MusicCaptureInfo.idle()
      : active = false,
        backend = MusicCaptureBackend.none,
        deviceLabel = '',
        sampleRate = 0,
        channels = 0,
        isLoopback = false;

  final bool active;
  final MusicCaptureBackend backend;
  final String deviceLabel;
  final int sampleRate;
  final int channels;
  final bool isLoopback;
}
