import 'dart:io' show Platform;
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

Rect? _savedBounds;
bool _entered = false;

bool get _skipOps => Platform.environment['FLUTTER_TEST'] == 'true';

Future<Rect?> scanOverlayDisplayRectForMonitor(int mssIndex) async {
  if (_skipOps) return null;
  try {
    final list = await ScreenRetriever.instance.getAllDisplays();
    if (list.isEmpty) return null;
    final i = mssIndex <= 0 ? 0 : (mssIndex - 1).clamp(0, list.length - 1);
    final d = list[i];
    final o = d.visiblePosition ?? Offset.zero;
    final s = d.size;
    return Rect.fromLTWH(o.dx, o.dy, s.width, s.height);
  } catch (_) {
    return null;
  }
}

Future<void> scanOverlayEnterFullscreenRegion(Rect frame) async {
  if (_skipOps) return;
  if (_entered) return;
  try {
    _savedBounds = await windowManager.getBounds();
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setBackgroundColor(Colors.transparent);
    // Jen přesné bounds monitoru — setFullScreen může na více displejích
    // přesunout okno na primární a rozbít 1:1 náhled oblasti snímání.
    await windowManager.setBounds(frame);
    _entered = true;
  } catch (_) {
    _savedBounds = null;
    _entered = false;
  }
}

Future<void> scanOverlayRestoreWindow() async {
  if (_skipOps) return;
  if (!_entered) return;
  _entered = false;
  try {
    final b = _savedBounds;
    if (b != null) {
      await windowManager.setBounds(b);
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setBackgroundColor(Colors.white);
  } catch (_) {}
  _savedBounds = null;
}
