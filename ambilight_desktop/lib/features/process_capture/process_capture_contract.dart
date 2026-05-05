import 'dart:typed_data';

/// E7 — volitelné zaměření screen režimu na okno / proces (MASTER E7).
/// Implementace patří nativní vrstvě (A1) + napojení na engine (A2); FW se nemění.

/// Cíl snímání (PID z OS; název exe pro UI / log).
class ProcessCaptureTarget {
  const ProcessCaptureTarget({
    required this.processId,
    this.executableName,
  });

  final int processId;
  final String? executableName;
}

/// Jedna snímka „surface“ procesu ve formátu RGBA (stejná sémantika jako [ScreenFrame]).
class ProcessCaptureFrame {
  const ProcessCaptureFrame({
    required this.width,
    required this.height,
    required this.rgba,
    this.processId = 0,
  });

  final int width;
  final int height;
  final Uint8List rgba;
  final int processId;

  bool get isValid =>
      width > 0 && height > 0 && rgba.length == width * height * 4;
}

/// Abstrakce zdroje pro budoucí integraci do screen pipeline.
abstract interface class ProcessCaptureSource {
  Future<ProcessCaptureFrame?> capture(ProcessCaptureTarget target);

  void dispose();
}

/// Placeholder do doby, než A1 dodá nativní implementaci.
final class ProcessCaptureStub implements ProcessCaptureSource {
  @override
  Future<ProcessCaptureFrame?> capture(ProcessCaptureTarget target) async => null;

  @override
  void dispose() {}
}
