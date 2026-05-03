#ifndef RUNNER_SCREEN_CAPTURE_CHANNEL_H_
#define RUNNER_SCREEN_CAPTURE_CHANNEL_H_

#include <flutter/flutter_engine.h>

#include <windows.h>

/// Registruje method channel `ambilight/screen_capture` (GDI BitBlt, worker thread).
/// Kontrakt metod: viz `context/SCREEN_CAPTURE_CHANNEL.md`.
void RegisterAmbilightScreenCapture(HWND window_handle, flutter::FlutterEngine* engine);

void UnregisterAmbilightScreenCapture();

bool TryHandleAmbilightWindowMessage(HWND hwnd,
                                     UINT message,
                                     WPARAM wparam,
                                     LPARAM lparam);

#endif  // RUNNER_SCREEN_CAPTURE_CHANNEL_H_
