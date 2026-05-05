import '../../core/json/json_utils.dart';

/// Odpovídá `desktop-manifest.json` u GitHub Release (asset u [releases/latest/download/…]).
class DesktopUpdateManifest {
  const DesktopUpdateManifest({
    required this.version,
    required this.channel,
    required this.assets,
    this.releaseNotesUrl = '',
    this.releasePageUrl = '',
  });

  final String version;
  final String channel;
  final Map<String, DesktopUpdateAsset> assets;
  final String releaseNotesUrl;
  final String releasePageUrl;

  static DesktopUpdateManifest? tryParse(Map<String, dynamic> j) {
    final ver = asString(j['version']).trim();
    if (ver.isEmpty) return null;
    final rawAssets = j['assets'];
    if (rawAssets is! Map) return null;
    final assets = <String, DesktopUpdateAsset>{};
    rawAssets.forEach((k, v) {
      final key = k.toString();
      final m = asMap(v);
      final url = asString(m['url']).trim();
      if (url.isEmpty || !url.startsWith('https://')) return;
      final kind = asString(m['kind'], 'zip');
      final sha = asString(m['sha256']).trim().toLowerCase();
      if (kind == 'zip') {
        if (sha.length != 64) return;
      } else if (kind == 'browser') {
        // jen odkaz (macOS / Linux v první vlně)
      } else {
        return;
      }
      assets[key] = DesktopUpdateAsset(url: url, sha256Hex: sha, kind: kind);
    });
    if (assets.isEmpty) return null;
    return DesktopUpdateManifest(
      version: ver,
      channel: asString(j['channel'], 'stable').trim().toLowerCase(),
      assets: assets,
      releaseNotesUrl: asString(j['release_notes_url']).trim(),
      releasePageUrl: asString(j['release_page_url']).trim(),
    );
  }

  DesktopUpdateAsset? assetForKey(String key) => assets[key];
}

class DesktopUpdateAsset {
  const DesktopUpdateAsset({
    required this.url,
    required this.sha256Hex,
    required this.kind,
  });

  final String url;
  final String sha256Hex;
  final String kind;
}
