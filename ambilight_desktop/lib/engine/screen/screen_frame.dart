import 'dart:isolate';
import 'dart:typed_data';

/// Jedna snímka monitoru ve formátu RGBA (4 B / pixel, řádek po řádku).
///
/// [monitorIndex]: MSS-styl (`0` = celý virtuální desktop, `1`…`n` = fyzické monitory).
/// Shodně s [ScreenCaptureSource.captureFrame] a `LedSegment.monitorIdx`.
class ScreenFrame {
  const ScreenFrame({
    required this.monitorIndex,
    required this.width,
    required this.height,
    required this.rgba,
  }) : assert(width >= 0 && height >= 0);

  final int monitorIndex;
  final int width;
  final int height;
  final Uint8List rgba;

  int get byteLength => rgba.length;

  bool get isValid =>
      width > 0 &&
      height > 0 &&
      rgba.length == width * height * 4;

  int pixelOffset(int x, int y) => (y * width + x) * 4;

  /// Předání pixelů do jiného isolatu bez kopírování (po [detachForIsolate] už nelze číst [rgba]).
  TransferableTypedData detachForIsolate() {
    return TransferableTypedData.fromList(<TypedData>[rgba]);
  }

  /// Opak [detachForIsolate] na cílovém isolatu (kopie pixelů).
  static Uint8List importFromIsolate(TransferableTypedData transferable) {
    final mat = transferable.materialize();
    final view = mat.asUint8List();
    return Uint8List.fromList(view);
  }

  Map<String, Object?> toDebugMap() => <String, Object?>{
        'width': width,
        'height': height,
        'monitorIndex': monitorIndex,
        'byteLength': rgba.length,
      };
}

/// Mock snímek pro vývoj — architektura stejná jako u reálného zdroje.
abstract final class MockScreenFrame {
  /// Jednoduchý horizontální gradient (R podle x, G podle y, B konstantní).
  static ScreenFrame gradient({
    int monitorIndex = 0,
    int width = 320,
    int height = 180,
    int phase = 0,
  }) {
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final r = ((x + phase) * 255 / (width - 1).clamp(1, 999999)).clamp(0, 255).round();
        final g = (y * 255 / (height - 1).clamp(1, 999999)).clamp(0, 255).round();
        rgba[i] = r;
        rgba[i + 1] = g;
        rgba[i + 2] = 128;
        rgba[i + 3] = 255;
      }
    }
    return ScreenFrame(monitorIndex: monitorIndex, width: width, height: height, rgba: rgba);
  }
}
