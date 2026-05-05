import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/io_client.dart';

/// RGB → Home Assistant `hs_color`: hue [0,360), saturation [0,100].
/// Stejný model jako ve screen pipeline (H,S,V ∈ [0,1] pro výpočet, pak převod do HA jednotek).
List<double> haRgbToHsColor(int r, int g, int b) {
  final rn = r.clamp(0, 255) / 255.0;
  final gn = g.clamp(0, 255) / 255.0;
  final bn = b.clamp(0, 255) / 255.0;
  final maxc = math.max(rn, math.max(gn, bn));
  final minc = math.min(rn, math.min(gn, bn));
  final d = maxc - minc;
  double hDeg;
  if (d < 1e-10) {
    hDeg = 0;
  } else if (maxc == rn) {
    hDeg = 60 * (((gn - bn) / d) % 6);
  } else if (maxc == gn) {
    hDeg = 60 * (((bn - rn) / d) + 2);
  } else {
    hDeg = 60 * (((rn - gn) / d) + 4);
  }
  if (hDeg < 0) hDeg += 360;
  final sPct = maxc <= 0 ? 0.0 : (d / maxc) * 100.0;
  return [hDeg, sPct];
}

/// Minimální Home Assistant Core REST klient (bez WebSocket — dostačující pro ambient).
class HaApiClient {
  HaApiClient({
    required String baseUrl,
    required String token,
    required bool allowInsecureCert,
    required Duration timeout,
  })  : _base = _normalizeBase(baseUrl),
        _token = token.trim(),
        _timeout = timeout {
    final hc = HttpClient();
    if (allowInsecureCert) {
      hc.badCertificateCallback = (cert, host, port) => true;
    }
    _client = IOClient(hc);
  }

  final String _base;
  final String _token;
  final Duration _timeout;
  late final IOClient _client;

  static String _normalizeBase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void close() => _client.close();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  /// `GET /api/` — ověření tokenu.
  Future<(bool ok, String message)> ping() async {
    if (_base.isEmpty || _token.isEmpty) {
      return (false, 'Missing URL or token');
    }
    try {
      final r = await _client.get(Uri.parse('$_base/api/'), headers: _headers).timeout(_timeout);
      if (r.statusCode == 200) {
        return (true, 'Home Assistant OK');
      }
      return (false, 'HTTP ${r.statusCode}');
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// Všechny entity stavu; caller filtruje `light.`.
  Future<(bool ok, List<Map<String, dynamic>> states, String error)> getStates() async {
    if (_base.isEmpty || _token.isEmpty) {
      return (false, const <Map<String, dynamic>>[], 'Missing URL or token');
    }
    try {
      final r =
          await _client.get(Uri.parse('$_base/api/states'), headers: _headers).timeout(_timeout);
      if (r.statusCode != 200) {
        return (false, const <Map<String, dynamic>>[], 'HTTP ${r.statusCode}');
      }
      final decoded = jsonDecode(r.body);
      if (decoded is! List) {
        return (false, const <Map<String, dynamic>>[], 'Invalid JSON');
      }
      final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return (true, list, '');
    } catch (e) {
      return (false, const <Map<String, dynamic>>[], e.toString());
    }
  }

  Future<(bool ok, String error)> lightTurnOnRgb({
    required String entityId,
    required int r,
    required int g,
    required int b,
    required int brightnessPct,
    double transitionSeconds = 0,
    /// `true` pro ambient z PC: HA u `rgb_color` + `brightness_pct` často sníží sytost;
    /// `hs_color` + mírný boost drží barvu živější.
    bool haPreferHsColor = true,
    /// Jen pokud [haPreferHsColor]; násobitel saturace [0,100] z RGB (typicky 1.25–1.45).
    double haSaturationGain = 1.38,
  }) async {
    if (_base.isEmpty || _token.isEmpty) {
      return (false, 'Missing URL or token');
    }
    if (!entityId.startsWith('light.')) {
      return (false, 'Not a light entity');
    }
    final bp = brightnessPct.clamp(0, 100);
    final tr = transitionSeconds.clamp(0.0, 10.0);
    final rc = r.clamp(0, 255);
    final gc = g.clamp(0, 255);
    final bc = b.clamp(0, 255);

    final Map<String, Object?> payload = {
      'entity_id': entityId,
      'brightness_pct': bp,
      'transition': tr,
    };

    // U téměř černé nemá HS stabilní odstín — držíme přesné RGB.
    final useHs = haPreferHsColor &&
        bp > 0 &&
        math.max(rc, math.max(gc, bc)) >= 6;

    if (useHs) {
      final hs = haRgbToHsColor(rc, gc, bc);
      var hue = hs[0];
      var sat = hs[1];
      final gain = haSaturationGain.clamp(1.0, 2.0);
      // Část „zbývající“ nesytosti přidá i při už vysoké S — přirozenější než čistý násobek.
      sat = math.min(100.0, sat * gain + (100.0 - sat) * 0.06 * (gain - 1.0));
      payload['hs_color'] = [
        double.parse(hue.toStringAsFixed(2)),
        double.parse(sat.toStringAsFixed(2)),
      ];
    } else {
      payload['rgb_color'] = [rc, gc, bc];
    }

    final body = jsonEncode(payload);
    try {
      final r = await _client
          .post(
            Uri.parse('$_base/api/services/light/turn_on'),
            headers: _headers,
            body: body,
          )
          .timeout(_timeout);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return (true, '');
      }
      return (false, 'HTTP ${r.statusCode} ${r.body.length > 200 ? r.body.substring(0, 200) : r.body}');
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<(bool ok, String error)> lightTurnOff({required String entityId}) async {
    if (_base.isEmpty || _token.isEmpty) {
      return (false, 'Missing URL or token');
    }
    final body = jsonEncode({'entity_id': entityId});
    try {
      final r = await _client
          .post(
            Uri.parse('$_base/api/services/light/turn_off'),
            headers: _headers,
            body: body,
          )
          .timeout(_timeout);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return (true, '');
      }
      return (false, 'HTTP ${r.statusCode}');
    } catch (e) {
      return (false, e.toString());
    }
  }
}
