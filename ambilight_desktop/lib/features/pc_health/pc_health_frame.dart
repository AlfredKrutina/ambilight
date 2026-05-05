import '../../core/json/json_utils.dart';
import '../../core/models/config_models.dart';
import 'pc_health_gradients.dart';
import 'pc_health_snapshot.dart';

/// Výpočet snímku pro režim `pchealth` — parita s `app.py` `_process_pchealth_mode`.
class PcHealthFrame {
  PcHealthFrame._();

  static List<(int, int, int)> compute(
    AppConfig config,
    PcHealthSnapshot systemValues, {
    required int virtualLedCount,
  }) {
    final settings = config.pcHealth;
    final ledCount = virtualLedCount.clamp(1, 4096);
    final zoneColors = <String, (int, int, int)>{
      'left': (0, 0, 0),
      'right': (0, 0, 0),
      'top': (0, 0, 0),
      'bottom': (0, 0, 0),
    };

    for (final raw in settings.metrics) {
      if (!asBool(raw['enabled'], true)) continue;

      final mName = asString(raw['metric'], 'cpu_usage');
      final val = systemValues.valueForMetric(mName);
      final minV = asDouble(raw['min_value'], 0);
      final maxV = asDouble(raw['max_value'], 100);
      final scale = asString(raw['color_scale'], 'blue_green_red');

      final gradCol = PcHealthGradients.gradientColor(
        val,
        minV,
        maxV,
        scale,
        colorLow: raw['color_low'] as List<dynamic>?,
        colorMid: raw['color_mid'] as List<dynamic>?,
        colorHigh: raw['color_high'] as List<dynamic>?,
      );

      final bMode = asString(raw['brightness_mode'], 'static');
      var brightnessVal = 255;
      if (bMode == 'static') {
        brightnessVal = asInt(raw['brightness'], 200);
      } else {
        final bMin = asInt(raw['brightness_min'], 50);
        final bMax = asInt(raw['brightness_max'], 255);
        final t = maxV != minV ? ((val - minV) / (maxV - minV)).clamp(0.0, 1.0) : 0.0;
        brightnessVal = (bMin + (bMax - bMin) * t).round();
      }

      final brFactor = brightnessVal / 255.0;
      final finalCol = (
        (gradCol.$1 * brFactor).round().clamp(0, 255),
        (gradCol.$2 * brFactor).round().clamp(0, 255),
        (gradCol.$3 * brFactor).round().clamp(0, 255),
      );

      final zones = raw['zones'];
      if (zones is List) {
        for (final z in zones) {
          final key = z.toString().toLowerCase();
          if (zoneColors.containsKey(key)) {
            zoneColors[key] = finalCol;
          }
        }
      }
    }

    final screenConfig = config.screenMode;
    final targets = List<(int, int, int)>.filled(ledCount, (0, 0, 0), growable: false);

    if (screenConfig.segments.isNotEmpty) {
      for (final seg in screenConfig.segments) {
        final segLen = (seg.ledEnd - seg.ledStart).abs() + 1;
        final step = seg.ledStart <= seg.ledEnd ? 1 : -1;
        final col = zoneColors[seg.edge] ?? (0, 0, 0);
        for (var i = 0; i < segLen; i++) {
          final idx = seg.ledStart + (i * step);
          if (idx >= 0 && idx < ledCount) {
            targets[idx] = col;
          }
        }
      }
    } else {
      var cLeft = (ledCount * 0.2).floor();
      var cTop = (ledCount * 0.3).floor();
      var cRight = (ledCount * 0.2).floor();
      var cBottom = ledCount - (cLeft + cTop + cRight);
      if (cBottom < 0) {
        cBottom = 0;
      }
      var idx = 0;
      for (var _ = 0; _ < cLeft; _++) {
        if (idx < ledCount) targets[idx++] = zoneColors['left']!;
      }
      for (var _ = 0; _ < cTop; _++) {
        if (idx < ledCount) targets[idx++] = zoneColors['top']!;
      }
      for (var _ = 0; _ < cRight; _++) {
        if (idx < ledCount) targets[idx++] = zoneColors['right']!;
      }
      for (var _ = 0; _ < cBottom; _++) {
        if (idx < ledCount) targets[idx++] = zoneColors['bottom']!;
      }
    }

    return targets;
  }
}
