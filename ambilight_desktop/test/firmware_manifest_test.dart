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
    expect(m.resolvedOtaHttpUrl, 'https://x/app.bin');
  });

  test('resolvedOtaHttpUrl falls back to app part when ota_http_url missing', () {
    const raw = '''
{
  "schema": 1,
  "version": "1",
  "chip": "esp32c6",
  "serial_flash": {
    "flash_mode": "dio",
    "flash_freq": "80m",
    "flash_size": "detect",
    "parts": [
      {"offset": "0x0", "file": "bootloader.bin", "url": "https://x/boot.bin", "sha256": "a"},
      {"offset": "0x8000", "file": "partition-table.bin", "url": "https://x/pt.bin", "sha256": "b"},
      {"offset": "0x10000", "file": "ambilight_esp32c6.bin", "url": "https://x/app.bin", "sha256": "c"}
    ]
  }
}
''';
    final m = FirmwareManifest.parseJsonString(raw);
    expect(m.otaHttpUrl, isNull);
    expect(m.resolvedOtaHttpUrl, 'https://x/app.bin');
  });
}
