import 'dart:convert';

/// `manifest.json` z CI (GitHub Pages) — USB flash díly + URL jen pro aplikační binárku (OTA).
class FirmwareManifest {
  FirmwareManifest({
    required this.schema,
    required this.version,
    required this.chip,
    required this.flashMode,
    required this.flashFreq,
    required this.flashSize,
    required this.parts,
    required this.otaHttpUrl,
  });

  final int schema;
  final String version;
  final String chip;
  final String flashMode;
  final String flashFreq;
  final String flashSize;
  final List<FirmwareSerialPart> parts;
  final String? otaHttpUrl;

  static FirmwareManifest parseJsonString(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic>) {
      throw const FormatException('manifest: kořen musí být objekt');
    }
    return FirmwareManifest.fromJson(j);
  }

  factory FirmwareManifest.fromJson(Map<String, dynamic> j) {
    final serial = j['serial_flash'];
    if (serial is! Map) {
      throw const FormatException('manifest: chybí serial_flash');
    }
    final sm = Map<String, dynamic>.from(serial);
    final rawParts = sm['parts'];
    final parts = <FirmwareSerialPart>[];
    if (rawParts is List) {
      for (final e in rawParts) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        parts.add(
          FirmwareSerialPart(
            offset: m['offset']?.toString() ?? '',
            file: m['file']?.toString() ?? '',
            url: m['url']?.toString() ?? '',
            sha256: m['sha256']?.toString() ?? '',
          ),
        );
      }
    }
    int _offHex(String o) {
      final s = o.toLowerCase().replaceFirst('0x', '');
      return int.tryParse(s, radix: 16) ?? 0;
    }

    parts.sort((a, b) => _offHex(a.offset).compareTo(_offHex(b.offset)));
    return FirmwareManifest(
      schema: (j['schema'] as num?)?.toInt() ?? 1,
      version: j['version']?.toString() ?? '',
      chip: j['chip']?.toString() ?? 'esp32c6',
      flashMode: sm['flash_mode']?.toString() ?? 'dio',
      flashFreq: sm['flash_freq']?.toString() ?? '80m',
      flashSize: sm['flash_size']?.toString() ?? 'detect',
      parts: parts,
      otaHttpUrl: j['ota_http_url']?.toString(),
    );
  }
}

class FirmwareSerialPart {
  const FirmwareSerialPart({
    required this.offset,
    required this.file,
    required this.url,
    required this.sha256,
  });

  final String offset;
  final String file;
  final String url;
  final String sha256;
}
