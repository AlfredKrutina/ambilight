import 'package:ambilight_desktop/core/models/config_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeMusicColorSource', () {
    test('genre and spectral map to spectrum', () {
      expect(normalizeMusicColorSource('genre'), 'spectrum');
      expect(normalizeMusicColorSource('GENRE'), 'spectrum');
      expect(normalizeMusicColorSource('spectral'), 'spectrum');
    });

    test('known modes preserved', () {
      expect(normalizeMusicColorSource('fixed'), 'fixed');
      expect(normalizeMusicColorSource('spectrum'), 'spectrum');
      expect(normalizeMusicColorSource('monitor'), 'monitor');
    });

    test('unknown maps to fixed', () {
      expect(normalizeMusicColorSource('bogus'), 'fixed');
      expect(normalizeMusicColorSource(''), 'fixed');
    });
  });

  group('MusicModeSettings genre import', () {
    test('fromJson genre becomes spectrum; toJson stores spectrum', () {
      final m = MusicModeSettings.fromJson({'color_source': 'genre'});
      expect(m.colorSource, 'spectrum');
      expect(m.toJson()['color_source'], 'spectrum');
    });
  });
}
