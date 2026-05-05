// SYNC (staging): `assets/branding/app_icon_dark.png` → macOS AppIcon.appiconset + Windows app_icon.ico.
// Středový výřez čtverce (široké PNG jako zdroj), pak resize — stejná logika jako dřív jen pro .ico, rozšířeno na macOS.
// Spuštění z kořene ambilight_desktop: dart run tool/sync_desktop_app_icons.dart
import 'dart:io';

import 'package:image/image.dart' as im;

/// Výřez min(w,h)×min(w,h) ze středu — stabilní app ikona z obdélníkového brand PNG.
im.Image squareFromBranding(im.Image src) {
  final w = src.width;
  final h = src.height;
  final side = w < h ? w : h;
  final x = (w - side) ~/ 2;
  final y = (h - side) ~/ 2;
  return im.copyCrop(src, x: x, y: y, width: side, height: side);
}

Future<void> main(List<String> args) async {
  final srcPath =
      args.isNotEmpty ? args.first : 'assets/branding/app_icon_dark.png';
  final srcFile = File(srcPath);
  if (!srcFile.existsSync()) {
    stderr.writeln('Chybí $srcPath');
    exitCode = 1;
    return;
  }

  final decoded = im.decodeImage(srcFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Nelze dekódovat obrázek: $srcPath');
    exitCode = 1;
    return;
  }

  final master = squareFromBranding(decoded);

  const macSizes = [16, 32, 64, 128, 256, 512, 1024];
  final macDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final s in macSizes) {
    final sized = im.copyResize(
      master,
      width: s,
      height: s,
      interpolation: im.Interpolation.cubic,
    );
    await File('$macDir/app_icon_$s.png').writeAsBytes(im.encodePng(sized));
  }

  const icoSizes = [256, 64, 48, 32, 16];
  final frames = <im.Image>[];
  for (final s in icoSizes) {
    frames.add(
      im.copyResize(
        master,
        width: s,
        height: s,
        interpolation: im.Interpolation.cubic,
      ),
    );
  }
  final icoBytes = im.IcoEncoder().encodeImages(frames);
  const icoOut = 'windows/runner/resources/app_icon.ico';
  await File(icoOut).writeAsBytes(icoBytes);

  // ignore: avoid_print
  print('OK: $macDir/*.png (${macSizes.length} velikostí), $icoOut (${icoBytes.length} B)');
}
