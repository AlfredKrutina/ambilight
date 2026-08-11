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
  static const Duration _downloadSendTimeout = Duration(seconds: 60);
  /// Mezi dvěma příchozími bloky dat — odhalí „uvázlé“ TCP.
  static const Duration _downloadChunkGapTimeout = Duration(minutes: 3);
  static const int _maxZipBytes = 400 * 1024 * 1024;
  static const int _downloadAttempts = 3;

  static const Map<String, String> _httpHeaders = {
    'Accept': 'application/json, text/plain, */*',
    'User-Agent': 'AmbiLight-Desktop/self-update',
  };

  static String? platformAssetKey() {
    if (Platform.isWindows) return 'windows_x64';
    if (Platform.isMacOS) return 'macos_dmg';
    if (Platform.isLinux) return 'linux_x64';
    return null;
  }

  /// `true` pokud [remote] je novější než [current] (semver; při shodě primární verze i `+build`).
  static bool isRemoteNewer(String remote, String current) {
    try {
      final rv = Version.parse(_semverPrimary(remote));
      final cv = Version.parse(_semverPrimary(current));
      if (rv != cv) return rv > cv;
      final rb = _numericBuild(remote);
      final cb = _numericBuild(current);
      if (rb != null && cb != null) return rb > cb;
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _semverPrimary(String v) {
    final t = v.trim();
    final plus = t.indexOf('+');
    return plus > 0 ? t.substring(0, plus) : t;
  }

  static int? _numericBuild(String v) {
    final t = v.trim();
    final plus = t.indexOf('+');
    if (plus < 0 || plus >= t.length - 1) return null;
    return int.tryParse(t.substring(plus + 1));
  }

  static String currentVersionLabel(PackageInfo info) {
    final build = info.buildNumber.trim();
    if (build.isEmpty || build == '0') return info.version;
    return '${info.version}+$build';
  }

  Future<DesktopUpdateCheckResult> checkForUpdates({
    String? manifestUrl,
    PackageInfo? packageInfo,
  }) async {
    final primary = (manifestUrl ?? ambilightDesktopUpdateManifestUrl).trim();
    final fallback = ambilightDesktopUpdateManifestFallbackUrl.trim();
    final urls = <String>[
      if (primary.startsWith('https://')) primary,
      if (fallback.startsWith('https://') && fallback != primary) fallback,
    ];
    if (urls.isEmpty) {
      return DesktopUpdateCheckParseError('Neplatná URL manifestu (vyžadováno HTTPS).');
    }

    DesktopUpdateCheckParseError? lastErr;
    for (final url in urls) {
      final fetched = await _fetchManifestJson(url);
      if (fetched.error != null) {
        lastErr = DesktopUpdateCheckParseError(fetched.error!);
        continue;
      }
      return _evaluateManifest(fetched.json!, packageInfo: packageInfo);
    }
    return lastErr ?? DesktopUpdateCheckParseError('Nepodařilo se načíst manifest.');
  }

  Future<({Map<String, dynamic>? json, String? error})> _fetchManifestJson(String url) async {
    final uri = Uri.parse(url);
    late final http.Response res;
    try {
      res = await _http.get(uri, headers: _httpHeaders).timeout(_manifestTimeout);
    } on TimeoutException {
      return (json: null, error: 'Časový limit při stahování manifestu ($url).');
    } catch (e) {
      return (json: null, error: '$e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return (json: null, error: 'HTTP ${res.statusCode} ($url)');
    }
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (json: j, error: null);
    } catch (e) {
      return (json: null, error: 'JSON: $e');
    }
  }

  Future<DesktopUpdateCheckResult> _evaluateManifest(
    Map<String, dynamic> j, {
    PackageInfo? packageInfo,
  }) async {
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
    var asset = manifest.assetForKey(key);
    if (asset == null && key == 'macos_dmg') {
      asset = manifest.assetForKey('macos');
    }
    if (asset == null) {
      return DesktopUpdateCheckParseError('V manifestu chybí asset „$key“.');
    }
    final info = packageInfo ?? await PackageInfo.fromPlatform();
    final current = currentVersionLabel(info);
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

  /// Stáhne ZIP s retry (síť / timeout / hash) a ověří SHA-256 + ZIP magickou hlavičku.
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

    await purgeStaleDownloadTemps();

    DesktopUpdateDownloadResult? last;
    for (var attempt = 1; attempt <= _downloadAttempts; attempt++) {
      last = await _downloadVerifiedZipOnce(asset, uri: uri, attempt: attempt);
      if (last.isOk) return last;
      final err = (last.error ?? '').toLowerCase();
      final permanent = err.contains('https') ||
          err.contains('prohlížeč') ||
          err.contains('nepodporovaný') ||
          err.contains('příliš velký');
      if (permanent) return last;
      if (attempt < _downloadAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return last ?? DesktopUpdateDownloadResult.err('Stažení selhalo.');
  }

  Future<DesktopUpdateDownloadResult> _downloadVerifiedZipOnce(
    DesktopUpdateAsset asset, {
    required Uri uri,
    required int attempt,
  }) async {
    final dir = await Directory.systemTemp.createTemp('ambi_desktop_up_');
    final zip = File(p.join(dir.path, 'update.zip'));
    IOSink? sink;
    try {
      final req = http.Request('GET', uri)
        ..headers['User-Agent'] = 'AmbiLight-Desktop/self-update'
        ..headers['Accept'] = 'application/zip, application/octet-stream, */*';
      final streamed = await _http.send(req).timeout(_downloadSendTimeout);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        await _drainStreamedBody(streamed);
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err(
          'Stažení (pokus $attempt): HTTP ${streamed.statusCode}',
        );
      }

      final expectedLen = streamed.contentLength;
      if (expectedLen != null && expectedLen > _maxZipBytes) {
        await _drainStreamedBody(streamed);
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err(
          'Stažený soubor je příliš velký (>${_maxZipBytes ~/ (1024 * 1024)} MiB).',
        );
      }
      if (asset.sizeBytes != null && asset.sizeBytes! > 0 && expectedLen != null && expectedLen > 0) {
        if (expectedLen != asset.sizeBytes) {
          await _drainStreamedBody(streamed);
          await _deleteTree(dir);
          return DesktopUpdateDownloadResult.err(
            'Content-Length nesedí s manifestem (HTTP $expectedLen, manifest ${asset.sizeBytes}).',
          );
        }
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
          return DesktopUpdateDownloadResult.err(
            'Stažený soubor je příliš velký (>${_maxZipBytes ~/ (1024 * 1024)} MiB).',
          );
        }
        out.add(chunk);
      }
      await out.flush();
      await out.close();
      sink = null;

      if (total < 64) {
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err('Stažený soubor je prázdný nebo poškozený ($total B).');
      }
      if (expectedLen != null && expectedLen > 0 && total != expectedLen) {
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err(
          'Neúplné stažení ($total / $expectedLen B) — pokus $attempt.',
        );
      }
      if (asset.sizeBytes != null && asset.sizeBytes! > 0 && total != asset.sizeBytes) {
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err(
          'Velikost nesedí s manifestem ($total / ${asset.sizeBytes} B).',
        );
      }

      final magicOk = await _looksLikeZip(zip);
      if (!magicOk) {
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err('Stažený soubor není platný ZIP (pokus $attempt).');
      }

      final digest = await sha256.bind(zip.openRead()).first;
      final hash = digest.toString().toLowerCase();
      final expected = asset.sha256Hex.toLowerCase();
      if (hash != expected) {
        await _deleteTree(dir);
        return DesktopUpdateDownloadResult.err(
          'SHA-256 nesedí (očekáváno $expected, je $hash) — pokus $attempt.',
        );
      }
      return DesktopUpdateDownloadResult.ok(zip);
    } on TimeoutException {
      await _closeSinkQuietly(sink);
      await _deleteTree(dir);
      return DesktopUpdateDownloadResult.err('Časový limit stahování (pokus $attempt).');
    } catch (e) {
      await _closeSinkQuietly(sink);
      await _deleteTree(dir);
      return DesktopUpdateDownloadResult.err('$e (pokus $attempt)');
    }
  }

  /// Smaže osiřelé `ambi_desktop_up_*` ve %TEMP% starší než [maxAge].
  static Future<void> purgeStaleDownloadTemps({Duration maxAge = const Duration(hours: 6)}) async {
    try {
      final root = Directory.systemTemp;
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('ambi_desktop_up_')) continue;
        try {
          final stat = await entity.stat();
          if (DateTime.now().difference(stat.modified) > maxAge) {
            await entity.delete(recursive: true);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Smaže temp složku kolem staženého ZIPu (`ambi_desktop_up_*`).
  static Future<void> deleteDownloadTempForZip(File? zip) async {
    if (zip == null) return;
    try {
      final parent = zip.parent;
      final name = p.basename(parent.path);
      if (!name.startsWith('ambi_desktop_up_')) return;
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (_) {}
  }

  static Future<bool> _looksLikeZip(File zip) async {
    try {
      final raf = await zip.open();
      try {
        final magic = await raf.read(4);
        return magic.length >= 2 && magic[0] == 0x50 && magic[1] == 0x4b;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
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
