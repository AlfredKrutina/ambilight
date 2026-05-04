import 'package:ambilight_desktop/application/ambilight_app_controller.dart';
import 'package:ambilight_desktop/features/spotify/spotify_service.dart';
import 'package:ambilight_desktop/features/system_media/system_media_now_playing_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Stejné jako v produkčním [main.dart] — [HomePage] používá [Selector2] na Spotify.
Widget ambiProviderScope(AmbilightAppController controller, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      ChangeNotifierProvider<SpotifyService>.value(value: controller.spotify),
      ChangeNotifierProvider<SystemMediaNowPlayingService>.value(
        value: controller.systemMediaNowPlaying,
      ),
    ],
    child: child,
  );
}
