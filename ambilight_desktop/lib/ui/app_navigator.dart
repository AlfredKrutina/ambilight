import 'package:flutter/material.dart';

/// Globální navigátor pro tématický tray popup ([showMenu]) — musí sedět s [MaterialApp.navigatorKey].
final GlobalKey<NavigatorState> ambiNavigatorKey = GlobalKey<NavigatorState>();

/// Vrátí kontext pod [Navigator], vhodný pro `showDialog`/`showMenu`.
///
/// [fallbackContext] se použije pouze pokud už má dostupný root navigator.
/// Nikdy nevrací kontext bez Navigatoru (např. vrstvy z [MaterialApp.builder]).
BuildContext? ambiNavigatorModalContext([BuildContext? fallbackContext]) {
  final rootNav = fallbackContext == null
      ? null
      : Navigator.maybeOf(fallbackContext, rootNavigator: true);
  final rootCtx = rootNav?.context;
  if (rootCtx != null && rootCtx.mounted) return rootCtx;
  final navState = ambiNavigatorKey.currentState;
  final keyCtx = navState?.overlay?.context ?? navState?.context ?? ambiNavigatorKey.currentContext;
  if (keyCtx != null && keyCtx.mounted) {
    if (Navigator.maybeOf(keyCtx, rootNavigator: true) != null) return keyCtx;
  }
  return null;
}

/// Spustí [showDialog] na kontextu s root [Navigator] (bezpečné z onboarding/builder vrstev).
Future<T?> showAmbiDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  final dialogContext = ambiNavigatorModalContext(context);
  if (dialogContext == null) return Future<T?>.value();
  return showDialog<T>(
    context: dialogContext,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

/// [MaterialApp.builder] sedí mimo Navigatorův [Overlay] — onboarding, fault banner,
/// [Slider]/[Tooltip] potřebují vlastní Overlay nad celým builder stromem.
class AmbiBuilderOverlay extends StatefulWidget {
  const AmbiBuilderOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AmbiBuilderOverlay> createState() => _AmbiBuilderOverlayState();
}

class _AmbiBuilderOverlayState extends State<AmbiBuilderOverlay> {
  OverlayEntry? _entry;
  late Widget _currentChild;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
    _entry = OverlayEntry(
      maintainState: true,
      opaque: false,
      builder: (context) => _currentChild,
    );
  }

  @override
  void didUpdateWidget(covariant AmbiBuilderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.child, widget.child)) {
      _currentChild = widget.child;
      _entry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    // [Overlay] si entry uvolní sám — nevolat [OverlayEntry.remove] zde.
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) return widget.child;
    return Overlay(
      clipBehavior: Clip.none,
      initialEntries: [entry],
    );
  }
}
