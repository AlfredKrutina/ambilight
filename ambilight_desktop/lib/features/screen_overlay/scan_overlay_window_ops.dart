import 'dart:ui' show Rect;

import 'scan_overlay_window_ops_stub.dart'
    if (dart.library.io) 'scan_overlay_window_ops_io.dart' as impl;

Future<Rect?> scanOverlayDisplayRectForMonitor(int mssIndex) =>
    impl.scanOverlayDisplayRectForMonitor(mssIndex);

/// Uloží stav okna a přesune je na zadaný obdélník (plocha monitoru), frameless + on-top.
Future<void> scanOverlayEnterFullscreenRegion(Rect frame) =>
    impl.scanOverlayEnterFullscreenRegion(frame);

/// Obnoví stav okna po náhledu overlay.
Future<void> scanOverlayRestoreWindow() => impl.scanOverlayRestoreWindow();

/// Po přesunu okna na monitor — vždy false, aby Windows neposílaly události mimo Flutter.
Future<void> scanOverlayEnsureFlutterReceivesPointer() =>
    impl.scanOverlayEnsureFlutterReceivesPointer();
