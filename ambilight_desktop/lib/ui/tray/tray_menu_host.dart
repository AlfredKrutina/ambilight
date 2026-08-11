import 'package:flutter/material.dart';

import '../../application/desktop_chrome_stub.dart'
    if (dart.library.io) '../../application/desktop_chrome_io.dart'
    as desktop_chrome;

/// Tray host — kontextové menu je nativní u systémové tray ikony.
class TrayMenuHost extends StatefulWidget {
  const TrayMenuHost({super.key, required this.child});

  final Widget child;

  @override
  State<TrayMenuHost> createState() => _TrayMenuHostState();
}

class _TrayMenuHostState extends State<TrayMenuHost> {
  @override
  void initState() {
    super.initState();
    desktop_chrome.registerTrayThemedPopup(null);
  }

  @override
  void dispose() {
    desktop_chrome.registerTrayThemedPopup(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
