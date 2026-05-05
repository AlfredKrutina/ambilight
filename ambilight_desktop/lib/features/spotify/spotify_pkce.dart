import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 PKCE pro veřejné desktop klienty (bez client_secret).
class SpotifyPkce {
  SpotifyPkce._();

  static String randomVerifier([int length = 64]) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(length, (_) => charset[rnd.nextInt(charset.length)]).join();
  }

  static String challengeForVerifier(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
