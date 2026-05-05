import 'package:ambilight_desktop/features/spotify/spotify_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAccountsErrorField reads JSON error', () {
    expect(
      SpotifyApi.parseAccountsErrorField('{"error":"invalid_grant","error_description":"x"}'),
      'invalid_grant',
    );
    expect(SpotifyApi.parseAccountsErrorField('not json'), isNull);
  });
}
