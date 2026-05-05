import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/models/config_models.dart';
import 'now_playing_channel.dart';

/// Barva z náhledu obalu u aktuálního OS přehrávače (GSMTC na Windows).
///
/// Apple Music (Win), často YouTube Music v prohlížeči — pokud aplikace poskytne miniaturu.
class SystemMediaNowPlayingService extends ChangeNotifier {
  (int, int, int)? _dominantRgb;
  String? _lastError;
  String? _lastTitle;
  String? _lastArtist;
  String? _lastSourceAumid;
  Timer? _pollTimer;
  AppConfig _pollConfig = AppConfig.defaults();

  (int, int, int)? get dominantRgb => _dominantRgb;
  String? get lastError => _lastError;
  String? get lastTitle => _lastTitle;
  String? get lastArtist => _lastArtist;
  String? get lastSourceAumid => _lastSourceAumid;

  void attachPollConfig(AppConfig config) {
    _pollConfig = config;
  }

  void startPollingIfNeeded(AppConfig config) {
    attachPollConfig(config);
    _pollTimer?.cancel();
    _pollTimer = null;
    final m = config.systemMediaAlbum;
    if (!m.enabled || !m.useAlbumColors) {
      _dominantRgb = null;
      _lastError = null;
      notifyListeners();
      return;
    }
    final intervalSec = config.globalSettings.performanceMode ? 20 : 5;
    _pollTimer = Timer.periodic(Duration(seconds: intervalSec), (_) {
      unawaited(_pollTick());
    });
    unawaited(_pollTick());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTick() async {
    final config = _pollConfig;
    if (!config.systemMediaAlbum.enabled || !config.systemMediaAlbum.useAlbumColors) {
      _dominantRgb = null;
      notifyListeners();
      return;
    }
    try {
      final map = await NowPlayingChannel.getThumbnail();
      if (map == null) {
        if (!kIsWeb && Platform.isWindows) {
          _lastError = 'Nativní kanál now_playing není k dispozici (zkontroluj build Windows).';
        } else {
          _lastError = null;
        }
        _dominantRgb = null;
        notifyListeners();
        return;
      }
      _lastTitle = map['title']?.toString();
      _lastArtist = map['artist']?.toString();
      _lastSourceAumid = map['sourceAppUserModelId']?.toString();
      final thumb = map['thumbnail'];
      if (thumb is! Uint8List || thumb.isEmpty) {
        _dominantRgb = null;
        _lastError = null;
        notifyListeners();
        return;
      }
      final rgb = _averageColorFromImageBytes(thumb);
      _dominantRgb = rgb;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _lastError = e.toString();
      _dominantRgb = null;
      if (kDebugMode) {
        debugPrint('SystemMediaNowPlayingService: $e\n$st');
      }
      notifyListeners();
    }
  }

  static (int, int, int)? _averageColorFromImageBytes(Uint8List bytes) {
    var image = img.decodeImage(bytes);
    image ??= img.decodeBmp(bytes);
    if (image == null) return null;
    final small = img.copyResize(image, width: 32, height: 32);
    var r = 0, g = 0, b = 0, n = 0;
    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final px = small.getPixel(x, y);
        r += px.r.toInt();
        g += px.g.toInt();
        b += px.b.toInt();
        n++;
      }
    }
    if (n == 0) return null;
    return ((r / n).round(), (g / n).round(), (b / n).round());
  }
}
