// Zdrojové PNG (dark) → `windows/runner/resources/app_icon.ico` (PNG v ICO, MSVC / RC2176).
// Spuštění z kořene projektu: `dart run tool/build_app_icon_ico.dart`
import 'dart:io';

import 'package:image/image.dart' as im;

void main(List<String> args) {
  final srcPath = args.isNotEmpty ? args.first : 'assets/branding/app_icon_dark.png';
  final outPath = 'windows/runner/resources/app_icon.ico';

  final srcFile = File(srcPath);
  if (!srcFile.existsSync()) {
    stderr.writeln('Chybí $srcPath — vygeneruj PNG (viz assets/branding).');
    exitCode = 1;
    return;
  }

  final src = im.decodePng(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Nelze dekódovat PNG: $srcPath');
    exitCode = 1;
    return;
  }

  const sizes = [256, 64, 48, 32, 16];
  final frames = <im.Image>[];
  for (final s in sizes) {
    frames.add(im.copyResize(src, width: s, height: s, interpolation: im.Interpolation.cubic));
  }

  final bytes = im.IcoEncoder().encodeImages(frames);
  File(outPath).writeAsBytesSync(bytes);
  // ignore: avoid_print
  print('OK: $outPath (${bytes.length} B, ${frames.length} velikostí)');
}
