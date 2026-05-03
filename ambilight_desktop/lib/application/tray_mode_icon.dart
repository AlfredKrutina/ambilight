import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as im;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';

final _log = Logger('TrayModeIcon');

const _kBrandAsset = 'assets/branding/app_icon_dark.png';

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

Future<im.Image?> _decodeBrand32() async {
  try {
    final bd = await rootBundle.load(_kBrandAsset);
    final src = im.decodeImage(bd.buffer.asUint8List());
    if (src == null) return null;
    return im.copyResize(src, width: 32, height: 32, interpolation: im.Interpolation.cubic);
  } catch (e, st) {
    _log.fine('brand decode: $e', e, st);
    return null;
  }
}

/// Tray ikona: macOS = branding z assetu (API `tray_manager` načítá jen `rootBundle`).
/// Windows/Linux = branding + malý barevný štítek režimu do temp souboru (`.ico` / `.png`).
Future<void> syncTrayIconForMode({
  required String startMode,
  required bool enabled,
}) async {
  if (_skip) return;
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

  if (Platform.isMacOS) {
    try {
      await trayManager.setIcon(
        _kBrandAsset,
        isTemplate: false,
        iconSize: 22,
      );
    } catch (e, st) {
      _log.fine('syncTrayIconForMode mac: $e', e, st);
      await _fallbackStaticIcon();
    }
    return;
  }

  try {
    final (badgeColor, tag) = _modeStyle(startMode, enabled);
    final branded = await _decodeBrand32();
    var icon = branded ?? im.Image(width: 32, height: 32, numChannels: 4);
    if (branded == null) {
      im.fill(icon, color: im.ColorRgb8(32, 32, 34));
    }
    if (!enabled) {
      icon = im.grayscale(icon);
    }
    im.drawCircle(
      icon,
      x: 24,
      y: 24,
      radius: 6,
      color: im.ColorRgba8(
        badgeColor.r.toInt(),
        badgeColor.g.toInt(),
        badgeColor.b.toInt(),
        230,
      ),
    );
    im.drawCircle(
      icon,
      x: 24,
      y: 24,
      radius: 2,
      color: im.ColorRgba8(255, 255, 255, 200),
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
      final branded = await _decodeBrand32();
      if (branded != null) {
        final bytes = im.encodeIco(branded, singleFrame: true);
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'ambilight_tray_fallback.ico');
        await File(path).writeAsBytes(bytes, flush: true);
        await trayManager.setIcon(path);
        return;
      }
    }
    if (Platform.isMacOS) {
      await trayManager.setIcon(_kBrandAsset, isTemplate: false, iconSize: 22);
      return;
    }
    if (Platform.isLinux) {
      final branded = await _decodeBrand32();
      if (branded != null) {
        final bytes = im.encodePng(branded);
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'ambilight_tray_fallback.png');
        await File(path).writeAsBytes(bytes, flush: true);
        await trayManager.setIcon(path);
      }
    }
  } catch (_) {}
}
