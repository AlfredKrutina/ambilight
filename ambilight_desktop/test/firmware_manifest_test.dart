import 'package:ambilight_desktop/features/firmware_legacy_old_code/firmware_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FirmwareManifest.fromJson parses serial_flash + ota', () {
    const raw = '''
{
  "schema": 1,
  "version": "abc",
  "chip": "esp32c6",
  "serial_flash": {
    "flash_mode": "dio",
    "flash_freq": "80m",
    "flash_size": "detect",
    "parts": [
      {"offset": "0x0", "file": "bootloader.bin", "url": "https://x/bootloader.bin", "sha256": "aa"}
    ]
  },
  "ota_http_url": "https://x/app.bin"
}
''';
    final m = FirmwareManifest.parseJsonString(raw);
    expect(m.version, 'abc');
    expect(m.chip, 'esp32c6');
    expect(m.parts, hasLength(1));
    expect(m.parts.single.file, 'bootloader.bin');
    expect(m.otaHttpUrl, 'https://x/app.bin');
  });
}
