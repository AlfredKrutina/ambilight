import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../../application/build_environment.dart';
import 'desktop_update_models.dart';

/// Výsledek kontroly aktualizace (bez sítě u [upToDate]/[parseError]).
sealed class DesktopUpdateCheckResult {}

class DesktopUpdateCheckUpToDate extends DesktopUpdateCheckResult {}

class DesktopUpdateCheckParseError extends DesktopUpdateCheckResult {
  DesktopUpdateCheckParseError(this.message);
  final String message;
}

class DesktopUpdateCheckChannelMismatch extends DesktopUpdateCheckResult {
  DesktopUpdateCheckChannelMismatch(this.manifestChannel, this.appChannel);
  final String manifestChannel;
  final String appChannel;
}

class DesktopUpdateCheckAvailable extends DesktopUpdateCheckResult {
  DesktopUpdateCheckAvailable({
    required this.manifest,
    required this.currentVersion,
    required this.assetKey,
    required this.asset,
  });

  final DesktopUpdateManifest manifest;
  final String currentVersion;
  final String assetKey;
  final DesktopUpdateAsset asset;
}

/// Stažení ZIPu a ověření SHA-256.
class DesktopUpdateDownloadResult {
  DesktopUpdateDownloadResult.ok(this.zipFile)
      : error = null,
        isOk = true;

  DesktopUpdateDownloadResult.err(this.error)
      : zipFile = null,
        isOk = false;

  final bool isOk;
  final File? zipFile;
  final String? error;
}

class DesktopUpdateService {
  DesktopUpdateService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const Duration _manifestTimeout = Duration(seconds: 25);
  static const Duration _downloadSendTimeout = Duration(seconds: 45);
  /// Mezi dvěma příchozími bloky dat — odhalí „uvázlé“ TCP bez ukončení celkového limitu stahování.
  static const Duration _downloadChunkGapTimeout = Duration(minutes: 3);
  static const int _maxZipBytes = 400 * 1024 * 1024;

  static const Map<String, String> _httpHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'AmbiLight-Desktop/self-update',
  };

  static String? platformAssetKey() {
    if (Platform.isWindows) return 'windows_x64';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux_x64';
    return null;
  }

  /// `true` pokud [remote] je novější než [current] (semver).
  static bool isRemoteNewer(String remote, String current) {
    try {
      final rv = Version.parse(_semverPrimary(remote));
      final cv = Version.parse(_semverPrimary(current));
      return rv > cv;
    } catch (_) {
      return false;
    }
  }

  static String _semverPrimary(String v) {
    final t = v.trim();
    final plus = t.indexOf('+');
    return plus > 0 ? t.substring(0, plus) : t;
  }

  Future<DesktopUpdateCheckResult> checkForUpdates({
    String? manifestUrl,
    PackageInfo? packageInfo,
  }) async {
    final url = (manifestUrl ?? ambilightDesktopUpdateManifestUrl).trim();
    if (!url.startsWith('https://')) {
      return DesktopUpdateCheckParseError('Neplatná URL manifestu (vyžadováno HTTPS).');
    }
    final uri = Uri.parse(url);
    late final http.Response res;
    try {
      res = await _http.get(uri, headers: _httpHeaders).timeout(_manifestTimeout);
    } on TimeoutException {
      return DesktopUpdateCheckParseError('Časový limit při stahování manifestu.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return DesktopUpdateCheckParseError('HTTP ${res.statusCode}');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return DesktopUpdateCheckParseError('JSON: $e');
    }
    final manifest = DesktopUpdateManifest.tryParse(j);
    if (manifest == null) {
      return DesktopUpdateCheckParseError('Neplatný manifest (version / assets).');
    }
    final mCh = manifest.channel.isEmpty ? 'stable' : manifest.channel;
    final appCh = ambilightReleaseChannel.trim().toLowerCase();
    if (mCh != appCh) {
      return DesktopUpdateCheckChannelMismatch(manifest.channel, ambilightReleaseChannel);
    }
    final key = platformAssetKey();
    if (key == null) {
      return DesktopUpdateCheckParseError('Nepodporovaná platforma.');
    }
    final asset = manifest.assetForKey(key);
    if (asset == null) {
      return DesktopUpdateCheckParseError('V manifestu chybí asset „$key“.');
    }
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    final current = info.version;
    if (!isRemoteNewer(manifest.version, current)) {
      return DesktopUpdateCheckUpToDate();
    }
    return DesktopUpdateCheckAvailable(
      manifest: manifest,
      currentVersion: current,
      assetKey: key,
      asset: asset,
    );
  }

  Future<DesktopUpdateDownloadResult> downloadVerifiedZip(DesktopUpdateAsset asset) async {
    if (asset.kind == 'browser') {
      return DesktopUpdateDownloadResult.err('Pro tento kanál není balíček ke stažení (pouze prohlížeč).');
    }
    if (asset.kind != 'zip') {
      return DesktopUpdateDownloadResult.err('Nepodporovaný typ balíčku: ${asset.kind}');
    }
    final uri = Uri.parse(asset.url);
    if (!uri.isScheme('https')) {
      return DesktopUpdateDownloadResult.err('Stažení jen přes HTTPS.');
    }
    final dir = await Directory.systemTemp.createTemp('ambi_desktop_up_');
    final zip = File(p.join(dir.path, 'update.zip'));
    IOSink? sink;
    try {
      final req = http.Request('GET', uri)..headers['User-Agent'] = 'AmbiLight-Desktop/self-update';
      final streamed = await _http.send(req).timeout(_downloadSendTimeout);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        await _drainStreamedBody(streamed);
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err('Stažení: HTTP ${streamed.statusCode}');
      }
      final out = zip.openWrite();
      sink = out;
      var total = 0;
      await for (final chunk in streamed.stream.timeout(_downloadChunkGapTimeout)) {
        total += chunk.length;
        if (total > _maxZipBytes) {
          await _closeSinkQuietly(sink);
          sink = null;
          await _deleteTree(dir);
          return DesktopUpdateDownloadResult.err('Stažený soubor je příliš velký (>${_maxZipBytes ~/ (1024 * 1024)} MiB).');
        }
        out.add(chunk);
      }
      await out.flush();
      await out.close();
      sink = null;
      final hash = sha256.convert(await zip.readAsBytes()).toString().toLowerCase();
      final expected = asset.sha256Hex.toLowerCase();
      if (hash != expected) {
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err('SHA-256 nesedí (očekáváno $expected, je $hash).');
      }
      return DesktopUpdateDownloadResult.ok(zip);
    } on TimeoutException {
      await _closeSinkQuietly(sink);
      await _deleteTree(dir);
      return DesktopUpdateDownloadResult.err('Časový limit stahování nebo manifestu.');
    } catch (e) {
      await _closeSinkQuietly(sink);
      await _deleteTree(dir);
      return DesktopUpdateDownloadResult.err('$e');
    }
  }

  static Future<void> _drainStreamedBody(http.StreamedResponse r) async {
    try {
      await r.stream.drain();
    } catch (_) {}
  }

  static Future<void> _closeSinkQuietly(IOSink? s) async {
    if (s == null) return;
    try {
      await s.flush();
      await s.close();
    } catch (_) {}
  }

  static Future<void> _deleteTree(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  void close() => _http.close();
}
