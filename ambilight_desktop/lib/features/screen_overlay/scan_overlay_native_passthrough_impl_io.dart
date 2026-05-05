import 'package:flutter/material.dart';

/// Dříve WS_EX_TRANSPARENT + periodická synchronizace; u jednoho okna to blokovalo Flutter UI.
/// Prokliknutí náhledu řeší [IgnorePointer] kolem [CustomPaint] v [main.dart].
Widget buildNativePassthroughWrapper(Widget child) => child;
