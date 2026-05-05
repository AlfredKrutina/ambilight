import 'package:ambilight_desktop/core/json/json_utils.dart';
import 'package:ambilight_desktop/services/desktop_update/desktop_update_models.dart';
import 'package:ambilight_desktop/services/desktop_update/desktop_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest parses and requires https assets', () {
    final m = DesktopUpdateManifest.tryParse(asMap({
      'version': '1.1.0',
      'channel': 'stable',
      'assets': {
        'windows_x64': {
          'url': 'https://example.com/a.zip',
          'sha256': 'ab' * 32,
          'kind': 'zip',
        },
      },
    }));
    expect(m, isNotNull);
    expect(m!.version, '1.1.0');
    expect(m.assetForKey('windows_x64')?.url, 'https://example.com/a.zip');
  });

  test('manifest browser asset without sha256', () {
    final m = DesktopUpdateManifest.tryParse(asMap({
      'version': '2.0.0',
      'channel': 'stable',
      'assets': {
        'linux_x64': {
          'url': 'https://github.com/a/b/releases/tag/x',
          'sha256': '',
          'kind': 'browser',
        },
      },
    }));
    expect(m, isNotNull);
    expect(m!.assetForKey('linux_x64')?.kind, 'browser');
  });

  test('manifest rejects http url', () {
    final m = DesktopUpdateManifest.tryParse(asMap({
      'version': '2.0.0',
      'assets': {
        'windows_x64': {
          'url': 'http://insecure.com/a.zip',
          'sha256': '00' * 32,
          'kind': 'zip',
        },
      },
    }));
    expect(m, isNull);
  });

  test('isRemoteNewer semver', () {
    expect(DesktopUpdateService.isRemoteNewer('1.0.4', '1.0.3'), isTrue);
    expect(DesktopUpdateService.isRemoteNewer('1.0.3', '1.0.3'), isFalse);
    expect(DesktopUpdateService.isRemoteNewer('1.0.3+2', '1.0.4'), isFalse);
    expect(DesktopUpdateService.isRemoteNewer('1.1.0', '1.0.99'), isTrue);
  });
}
