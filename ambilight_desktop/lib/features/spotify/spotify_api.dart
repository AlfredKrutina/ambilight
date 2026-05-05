import 'dart:convert';

import 'package:http/http.dart' as http;

import 'spotify_constants.dart';

class SpotifyApiException implements Exception {
  SpotifyApiException(this.message, [this.statusCode, this.retryAfterSeconds]);
  final String message;
  final int? statusCode;
  /// Z HTTP `Retry-After` (429).
  final int? retryAfterSeconds;
  @override
  String toString() => 'SpotifyApiException($statusCode): $message';
}

/// REST volání k Accounts API a Web API.
class SpotifyApi {
  SpotifyApi._();

  static const _accounts = 'https://accounts.spotify.com';
  static const _api = 'https://api.spotify.com/v1';

  /// `error` z JSON těla Accounts API (`invalid_grant`, …).
  static String? parseAccountsErrorField(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] != null) {
        return m['error'].toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> exchangeCode({
    required String clientId,
    required String code,
    required String codeVerifier,
  }) async {
    final body = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': kSpotifyRedirectUri,
      'client_id': clientId,
      'code_verifier': codeVerifier,
    };
    final res = await http.post(
      Uri.parse('$_accounts/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode != 200) {
      final err = parseAccountsErrorField(res.body) ?? res.body;
      throw SpotifyApiException(err, res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> refreshAccessToken({
    required String clientId,
    required String refreshToken,
  }) async {
    final body = {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
    };
    final res = await http.post(
      Uri.parse('$_accounts/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode != 200) {
      final err = parseAccountsErrorField(res.body) ?? res.body;
      throw SpotifyApiException(err, res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static int? _retryAfterFromHeaders(Map<String, String> headers) {
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == 'retry-after') {
        return int.tryParse(e.value.trim());
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPlayer(String accessToken) async {
    final res = await http.get(
      Uri.parse('$_api/me/player'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode == 204) return null;
    if (res.statusCode == 429) {
      final ra = _retryAfterFromHeaders(res.headers);
      throw SpotifyApiException('rate_limited', 429, ra ?? 3);
    }
    if (res.statusCode != 200) {
      throw SpotifyApiException(res.body, res.statusCode);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
