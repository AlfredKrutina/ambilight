import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/config_models.dart';
import 'spotify_api.dart' show SpotifyApi, SpotifyApiException;
import 'spotify_constants.dart';
import 'spotify_pkce.dart';
import 'spotify_token_store.dart';

final _log = Logger('SpotifyService');

/// OAuth PKCE + polling přehrávání; tokeny v [SpotifyTokenStore].
class SpotifyService extends ChangeNotifier {
  (int, int, int)? _dominantRgb;
  String? _accessToken;
  String? _refreshToken;
  bool _connected = false;
  String? _lastError;
  Timer? _pollTimer;
  DateTime? _apiBackoffUntil;

  (int, int, int)? get dominantRgb => _dominantRgb;
  bool get isConnected => _connected;
  String? get lastError => _lastError;

  /// Sloučí tokeny ze secure storage do runtime stavu (volat po načtení configu).
  Future<void> hydrateFromStorage(AppConfig config) async {
    final stored = await SpotifyTokenStore.read();
    _refreshToken = stored.$2 ?? config.spotify.refreshToken;
    _accessToken = stored.$1 ?? config.spotify.accessToken;
    _connected = (_refreshToken != null && _refreshToken!.isNotEmpty) ||
        (_accessToken != null && _accessToken!.isNotEmpty);
    notifyListeners();
  }

  void startPollingIfNeeded(AppConfig config) {
    _pollTimer?.cancel();
    if (!config.spotify.enabled) return;
    final cid = config.spotify.clientId;
    if (cid == null || cid.isEmpty) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollTick(config));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTick(AppConfig config) async {
    if (!config.spotify.enabled) return;
    final cid = config.spotify.clientId;
    if (cid == null || cid.isEmpty) return;
    final now = DateTime.now();
    if (_apiBackoffUntil != null && now.isBefore(_apiBackoffUntil!)) {
      return;
    }
    try {
      final ok = await _ensureAccessToken(config);
      if (!ok || _accessToken == null || _accessToken!.isEmpty) return;
      Map<String, dynamic>? player;
      try {
        player = await SpotifyApi.getPlayer(_accessToken!);
      } on SpotifyApiException catch (e) {
        if (e.statusCode == 429) {
          final sec = (e.retryAfterSeconds ?? 3).clamp(1, 120);
          _apiBackoffUntil = DateTime.now().add(Duration(seconds: sec));
          if (kDebugMode) _log.fine('Spotify 429: backoff ${sec}s');
          notifyListeners();
          return;
        }
        if (e.statusCode == 401 && _refreshToken != null && _refreshToken!.isNotEmpty) {
          _accessToken = null;
          final refreshed = await _ensureAccessToken(config);
          if (refreshed && _accessToken != null && _accessToken!.isNotEmpty) {
            player = await SpotifyApi.getPlayer(_accessToken!);
          }
        } else {
          rethrow;
        }
      }
      if (player == null) {
        _dominantRgb = null;
        notifyListeners();
        return;
      }
      if (!config.spotify.useAlbumColors) {
        _dominantRgb = null;
        notifyListeners();
        return;
      }
      final item = player['item'];
      if (item is! Map<String, dynamic>) return;
      final album = item['album'];
      if (album is! Map<String, dynamic>) return;
      final images = album['images'];
      if (images is! List || images.isEmpty) return;
      Map<String, dynamic>? best;
      var smallest = 1 << 30;
      for (final im in images) {
        if (im is Map<String, dynamic>) {
          final w = im['width'] is int ? im['width'] as int : 640;
          if (w < smallest) {
            smallest = w;
            best = im;
          }
        }
      }
      best ??= images.first as Map<String, dynamic>;
      final url = best['url']?.toString();
      if (url == null) return;
      final rgb = await _averageColorFromImageUrl(url);
      if (rgb != null) {
        _dominantRgb = rgb;
        _lastError = null;
        _connected = true;
        notifyListeners();
      }
    } catch (e, st) {
      _lastError = e.toString();
      if (kDebugMode) _log.fine('poll: $e', e, st);
      notifyListeners();
    }
  }

  /// Vrací false při neopravitelné chybě (např. [invalid_grant] — relog).
  Future<bool> _ensureAccessToken(AppConfig config) async {
    final cid = config.spotify.clientId!;
    if (_accessToken != null && _accessToken!.isNotEmpty) return true;
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final json = await SpotifyApi.refreshAccessToken(clientId: cid, refreshToken: _refreshToken!);
      _accessToken = json['access_token']?.toString();
      final newR = json['refresh_token']?.toString();
      if (newR != null && newR.isNotEmpty) _refreshToken = newR;
      if (_accessToken != null && _refreshToken != null && _refreshToken!.isNotEmpty) {
        await SpotifyTokenStore.write(accessToken: _accessToken!, refreshToken: _refreshToken!);
      }
      return _accessToken != null && _accessToken!.isNotEmpty;
    } on SpotifyApiException catch (e) {
      final code = e.message.toLowerCase();
      if (e.statusCode == 400 && code.contains('invalid_grant')) {
        _lastError = 'Spotify: relog (invalid_grant / revoked refresh).';
        await disconnect();
        notifyListeners();
        return false;
      }
      _lastError = e.toString();
      if (kDebugMode) _log.fine('refresh token: $e');
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) _log.fine('refresh: $e');
      return false;
    }
  }

  Future<(int, int, int)?> _averageColorFromImageUrl(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final bytes = Uint8List.fromList(res.bodyBytes);
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final small = img.copyResize(image, width: 32, height: 32);
    var r = 0, g = 0, b = 0, n = 0;
    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final px = small.getPixel(x, y);
        r += px.r.toInt();
        g += px.g.toInt();
        b += px.b.toInt();
        n++;
      }
    }
    if (n == 0) return null;
    return ((r / n).round(), (g / n).round(), (b / n).round());
  }

  /// Spustí localhost redirect server a otevře prohlížeč.
  Future<void> connectPkce(AppConfig config) async {
    final clientId = config.spotify.clientId;
    if (clientId == null || clientId.isEmpty) {
      _lastError = 'Chybí spotify.client_id v konfiguraci.';
      notifyListeners();
      return;
    }

    final verifier = SpotifyPkce.randomVerifier();
    final challenge = SpotifyPkce.challengeForVerifier(verifier);
    final scope = kSpotifyScopes.join(' ');

    final completer = Completer<String>();
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
    } catch (e) {
      _lastError = 'Port 8767 obsazený nebo zakázaný: $e';
      notifyListeners();
      return;
    }

    final sub = server.listen((req) async {
      if (req.uri.path != '/callback') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      final code = req.uri.queryParameters['code'];
      final err = req.uri.queryParameters['error'];
      req.response.headers.contentType = ContentType.html;
      req.response.write(
        err != null
            ? '<html><body>Chyba: $err. Zavři okno.</body></html>'
            : '<html><body>Připojeno ke Spotify. Můžeš zavřít okno.</body></html>',
      );
      await req.response.close();
      if (!completer.isCompleted) {
        if (code != null) {
          completer.complete(code);
        } else {
          completer.completeError(err ?? 'unknown');
        }
      }
    });

    final authUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': kSpotifyRedirectUri,
      'scope': scope,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
    });

    final ok = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await sub.cancel();
      await server.close(force: true);
      _lastError = 'Nepodařilo se otevřít prohlížeč.';
      notifyListeners();
      return;
    }

    try {
      final code = await completer.future.timeout(const Duration(minutes: 5));
      final tokenJson = await SpotifyApi.exchangeCode(
        clientId: clientId,
        code: code,
        codeVerifier: verifier,
      );
      _accessToken = tokenJson['access_token']?.toString();
      _refreshToken = tokenJson['refresh_token']?.toString() ?? _refreshToken;
      if (_accessToken != null && _refreshToken != null) {
        await SpotifyTokenStore.write(accessToken: _accessToken!, refreshToken: _refreshToken!);
        _connected = true;
        _lastError = null;
      }
    } on SpotifyApiException catch (e) {
      _lastError = e.message;
      if (kDebugMode) _log.warning('oauth token exchange: $e');
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) _log.warning('oauth: $e');
    } finally {
      sub.cancel();
      await server.close(force: true);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await SpotifyTokenStore.clear();
    _accessToken = null;
    _refreshToken = null;
    _connected = false;
    _dominantRgb = null;
    _apiBackoffUntil = null;
    notifyListeners();
  }
}
