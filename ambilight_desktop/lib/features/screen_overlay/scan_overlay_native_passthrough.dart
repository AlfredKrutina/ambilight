import 'package:flutter/material.dart';

import 'scan_overlay_native_passthrough_impl_stub.dart'
    if (dart.library.io) 'scan_overlay_native_passthrough_impl_io.dart' as impl;

/// Dříve nativní prokliknutí (Windows); u jednoho okna to rozbilo Flutter hit-test.
/// Náhled je jen [IgnorePointer] + malý ovládací chip v [main.dart].
class ScanOverlayNativePassthrough extends StatelessWidget {
  const ScanOverlayNativePassthrough({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => impl.buildNativePassthroughWrapper(child);
}
