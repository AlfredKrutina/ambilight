import 'dart:async';

import 'package:flutter/material.dart';

/// Posuvník pro nastavení z [draft] + debounced [queueConfigApply]: při častém
/// [ChangeNotifier.notifyListeners] by nativní [Slider] skákal zpět na starou hodnotu,
/// pokud prst ještě držíš nebo dokud se konfig neuloží. Tento widget drží poslední
/// hodnotu z tažení a krátce po puštění, dokud [value] z rodiče nedoběhne.
///
/// Větší palec / kolej + svislý padding snižuje riziko, že rodičovský [ScrollView]
/// „ukradne“ gesto při mírném vyjetí mimo úzký pruh.
class ConfigDragSlider extends StatefulWidget {
  const ConfigDragSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    required this.max,
    this.divisions,
    this.label,
    required this.onChanged,
    this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeEnd;

  @override
  State<ConfigDragSlider> createState() => _ConfigDragSliderState();
}

class _ConfigDragSliderState extends State<ConfigDragSlider> {
  bool _dragging = false;
  double? _held;
  Timer? _releaseTimer;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _scheduleClearHeld() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 480), () {
      if (mounted) setState(() => _held = null);
    });
  }

  bool _matchesParent(double parent, double held) {
    final d = widget.divisions;
    if (d == null || d <= 0) {
      return (parent - held).abs() < 1e-5;
    }
    final span = widget.max - widget.min;
    if (span <= 0) return parent == held;
    final step = span / d;
    return (parent - held).abs() < step / 2;
  }

  @override
  void didUpdateWidget(covariant ConfigDragSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_held != null && !_dragging && _matchesParent(widget.value, _held!)) {
      _held = null;
      _releaseTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.value.clamp(widget.min, widget.max);
    final effective = _dragging && _held != null
        ? _held!.clamp(widget.min, widget.max)
        : (_held != null ? _held!.clamp(widget.min, widget.max) : parent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        ),
        child: Slider(
          value: effective,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          label: widget.label,
          onChangeStart: (start) {
            setState(() {
              _dragging = true;
              _held = start.clamp(widget.min, widget.max);
            });
          },
          onChanged: (v) {
            _held = v;
            widget.onChanged(v);
            setState(() {});
          },
          onChangeEnd: (_) {
            setState(() => _dragging = false);
            _scheduleClearHeld();
            widget.onChangeEnd?.call();
          },
        ),
      ),
    );
  }
}
