import 'package:flutter/material.dart';

import 'layout_breakpoints.dart';

/// Vycentruje obsah a omezí max. šířku na ultrawide / 4K — texty se neroztahují přes celý monitor.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cap = AppBreakpoints.maxContentWidth(maxWidth);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: child,
      ),
    );
  }
}
