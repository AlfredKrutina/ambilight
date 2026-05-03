import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

final _log = Logger('TrayModeIcon');

bool get _skip => Platform.environment['FLUTTER_TEST'] == 'true';

(im.ColorRgb8, String) _modeStyle(String startMode, bool enabled) {
  if (!enabled) {
    return (im.ColorRgb8(70, 70, 72), 'off');
  }
  switch (startMode) {
    case 'screen':
      return (im.ColorRgb8(33, 150, 243), 'screen');
    case 'music':
      return (im.ColorRgb8(156, 39, 176), 'music');
    case 'pchealth':
      return (im.ColorRgb8(76, 175, 80), 'pchealth');
    case 'light':
    default:
      return (im.ColorRgb8(255, 193, 7), 'light');
  }
}

/// Tray ikona podle režimu a zapnutí (Windows `.ico`, macOS/Linux `.png`).
Future<void> syncTrayIconForMode({
  required String startMode,
  required bool enabled,
}) async {
  if (_skip) return;
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

  try {
    final (baseColor, tag) = _modeStyle(startMode, enabled);
    const size = 32;
    final icon = im.Image(width: size, height: size, numChannels: 4);
    im.fill(icon, color: baseColor);
    im.drawCircle(
      icon,
      x: size ~/ 2,
      y: size ~/ 2,
      radius: 5,
      color: im.ColorRgba8(255, 255, 255, 210),
    );

    final dir = await getTemporaryDirectory();
    late final Uint8List bytes;
    late final String fileName;
    if (Platform.isWindows) {
      bytes = im.encodeIco(icon, singleFrame: true);
      fileName = 'ambilight_tray_$tag.ico';
    } else {
      bytes = im.encodePng(icon);
      fileName = 'ambilight_tray_$tag.png';
    }
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    await trayManager.setIcon(path);
  } catch (e, st) {
    _log.fine('syncTrayIconForMode: $e', e, st);
    await _fallbackStaticIcon();
  }
}

Future<void> _fallbackStaticIcon() async {
  try {
    if (Platform.isWindows) {
      await trayManager.setIcon('windows/runner/resources/app_icon.ico');
      return;
    }
    if (Platform.isMacOS) {
      final exe = File(Platform.resolvedExecutable);
      final icns = File('${exe.parent.parent.path}/Resources/AppIcon.icns');
      if (icns.existsSync()) {
        await trayManager.setIcon(icns.path);
      }
    }
  } catch (_) {}
}
