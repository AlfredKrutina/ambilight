import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';

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
  }) async {
    if (_base.isEmpty || _token.isEmpty) {
      return (false, 'Missing URL or token');
    }
    if (!entityId.startsWith('light.')) {
      return (false, 'Not a light entity');
    }
    final body = jsonEncode({
      'entity_id': entityId,
      'rgb_color': [r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)],
      'brightness_pct': brightnessPct.clamp(0, 100),
      'transition': transitionSeconds.clamp(0.0, 10.0),
    });
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
