import '../application/build_environment.dart';
import '../application/debug_trace.dart';
import '../core/models/config_models.dart';

/// Výchozí denní křivka jasu (screen), když je rozvrh zapnutý a seznam bodů je prázdný.
const List<BrightnessSchedulePoint> kDefaultScreenBrightnessSchedule = [
  BrightnessSchedulePoint(minutesOfDay: 7 * 60, brightnessPct: 80),
  BrightnessSchedulePoint(minutesOfDay: 9 * 60, brightnessPct: 100),
  BrightnessSchedulePoint(minutesOfDay: 18 * 60, brightnessPct: 85),
  BrightnessSchedulePoint(minutesOfDay: 22 * 60, brightnessPct: 45),
  BrightnessSchedulePoint(minutesOfDay: 30, brightnessPct: 25),
];

/// Lineární interpolace jasu (%) mezi body v čase; wrap přes půlnoc.
double scheduleBrightnessPctAt(
  List<BrightnessSchedulePoint> points,
  DateTime now,
) {
  if (points.isEmpty) return 100;
  if (points.length == 1) return points.first.brightnessPct.clamp(0, 100).toDouble();

  final sorted = List<BrightnessSchedulePoint>.of(points)
    ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
  final t = now.hour * 60 + now.minute + now.second / 60.0;

  BrightnessSchedulePoint? prev;
  BrightnessSchedulePoint? next;
  for (var i = 0; i < sorted.length; i++) {
    final p = sorted[i];
    if (p.minutesOfDay <= t) {
      prev = p;
      next = sorted[(i + 1) % sorted.length];
    }
  }
  prev ??= sorted.last;
  next ??= sorted.first;

  final aMin = prev.minutesOfDay.toDouble();
  final bMin = next.minutesOfDay.toDouble();
  final aPct = prev.brightnessPct.clamp(0, 100).toDouble();
  final bPct = next.brightnessPct.clamp(0, 100).toDouble();

  var span = bMin - aMin;
  var elapsed = t - aMin;
  if (span <= 0) {
    // Přes půlnoc: A → 1440 → B
    span = (1440 - aMin) + bMin;
    if (t >= aMin) {
      elapsed = t - aMin;
    } else {
      elapsed = (1440 - aMin) + t;
    }
  }
  if (span <= 0) return aPct;
  final u = (elapsed / span).clamp(0.0, 1.0);
  return aPct + (bPct - aPct) * u;
}

/// Efektivní body rozvrhu (vloží výchozí, pokud je seznam prázdný).
List<BrightnessSchedulePoint> effectiveBrightnessSchedulePoints(
  ScreenModeSettings s,
) {
  if (s.brightnessSchedule.isEmpty) return kDefaultScreenBrightnessSchedule;
  return s.brightnessSchedule;
}

double? _lastLoggedEffectivePct;

/// Screen: režimový jas × master % × (rozvrh %, pokud zapnutý).
int applyScreenMasterAndScheduleBrightness(
  ScreenModeSettings s, {
  DateTime? now,
}) {
  final modeBri = s.brightness.clamp(0, 255);
  final master = s.masterBrightnessPct.clamp(0, 100) / 100.0;
  var scheduleFactor = 1.0;
  if (s.brightnessScheduleEnabled) {
    final pts = effectiveBrightnessSchedulePoints(s);
    scheduleFactor = scheduleBrightnessPctAt(pts, now ?? DateTime.now()) / 100.0;
  }
  final effective = (modeBri * master * scheduleFactor).round().clamp(0, 255);
  final effectivePct = master * scheduleFactor * 100;
  if (ambilightDebugTraceEnabled) {
    final prev = _lastLoggedEffectivePct;
    if (prev == null || (effectivePct - prev).abs() >= 5) {
      _lastLoggedEffectivePct = effectivePct;
      ambilightDebugTrace(
        'screen bri: mode=$modeBri master=${s.masterBrightnessPct}% '
        'schedule=${s.brightnessScheduleEnabled ? (scheduleFactor * 100).toStringAsFixed(1) : "off"}% '
        '-> $effective',
      );
    }
  }
  return effective;
}
