#ifndef RUNNER_NOW_PLAYING_CHANNEL_H_
#define RUNNER_NOW_PLAYING_CHANNEL_H_

#include <flutter/flutter_engine.h>

/// Kanál `ambilight/now_playing` — Windows GSMTC (náhled obalu z aktuálního přehrávače).
void RegisterAmbilightNowPlaying(flutter::FlutterEngine* engine);

void UnregisterAmbilightNowPlaying();

#endif  // RUNNER_NOW_PLAYING_CHANNEL_H_
