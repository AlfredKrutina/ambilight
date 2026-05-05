import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/context_ext.dart';

/// Řízení probíhající operace z [FirmwareProgressDialog.onRun].
class FirmwareProgressHandle {
  FirmwareProgressHandle({
    required void Function(String) updateSubtitle,
    required VoidCallback showCloseOnly,
    required bool Function() getCancelled,
    required VoidCallback markCancelled,
    required VoidCallback pop,
  })  : _updateSubtitle = updateSubtitle,
        _showCloseOnly = showCloseOnly,
        _getCancelled = getCancelled,
        _markCancelled = markCancelled,
        _pop = pop;

  final void Function(String) _updateSubtitle;
  final VoidCallback _showCloseOnly;
  final bool Function() _getCancelled;
  final VoidCallback _markCancelled;
  final VoidCallback _pop;

  bool get isCancelled => _getCancelled();

  void updateSubtitle(String s) => _updateSubtitle(s);

  void showCloseOnly() => _showCloseOnly();

  void cancel() {
    _markCancelled();
    _pop();
  }
}

typedef FirmwareProgressJob = Future<bool> Function(FirmwareProgressHandle handle);

/// Animovaný dialog průběhu flash / OTA. [onRun] vrátí `true` = dialog zůstane (např. fáze „aktualizuje zařízení“).
class FirmwareProgressDialog extends StatefulWidget {
  const FirmwareProgressDialog({
    super.key,
    required this.title,
    required this.initialSubtitle,
    required this.onRun,
  });

  final String title;
  final String initialSubtitle;
  final FirmwareProgressJob onRun;

  @override
  State<FirmwareProgressDialog> createState() => _FirmwareProgressDialogState();
}

class _FirmwareProgressDialogState extends State<FirmwareProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late String _subtitle;
  late final FirmwareProgressHandle _handle;

  bool _closeOnly = false;
  bool _dialogClosed = false;
  bool _userCancelled = false;

  void _safePop() {
    if (!_dialogClosed && mounted) {
      _dialogClosed = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _subtitle = widget.initialSubtitle;
    _handle = FirmwareProgressHandle(
      updateSubtitle: (s) => setState(() => _subtitle = s),
      showCloseOnly: () {
        setState(() {
          _closeOnly = true;
          _animationController.stop();
        });
      },
      getCancelled: () => _userCancelled,
      markCancelled: () => _userCancelled = true,
      pop: _safePop,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var keepOpen = false;
      try {
        keepOpen = await widget.onRun(_handle);
      } catch (e, st) {
        assert(() {
          debugPrint('FirmwareProgressDialog: $e\n$st');
          return true;
        }());
        keepOpen = false;
      }
      if (!mounted) return;
      if (!_dialogClosed && !keepOpen) _safePop();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            SizedBox(
              height: 104,
              width: 104,
              child: _closeOnly
                  ? Icon(Icons.system_update_alt_rounded, size: 56, color: scheme.primary)
                  : AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final pulse = math.sin(_animationController.value * math.pi * 2) * 0.045 + 1.0;
                        return Transform.scale(
                          scale: pulse,
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _animationController,
                            child: SizedBox(
                              width: 92,
                              height: 92,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                                color: scheme.primary.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                          RotationTransition(
                            turns: ReverseAnimation(_animationController),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                strokeCap: StrokeCap.round,
                                color: scheme.tertiary.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
        actions: [
          if (_closeOnly)
            FilledButton(
              onPressed: _safePop,
              child: Text(context.l10n.close),
            )
          else
            TextButton(
              onPressed: _handle.cancel,
              child: Text(context.l10n.cancel),
            ),
        ],
      ),
    );
  }
}
