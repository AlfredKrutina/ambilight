#include "now_playing_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <vector>

#include "now_playing_winrt.h"
#include "utils.h"

namespace {

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_now_playing;

}  // namespace

void RegisterAmbilightNowPlaying(flutter::FlutterEngine* engine) {
  g_now_playing = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "ambilight/now_playing",
      &flutter::StandardMethodCodec::GetInstance());

  g_now_playing->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "getThumbnail") {
          result->NotImplemented();
          return;
        }
        AmbilightThumbBlob blob{};
        wchar_t title[512]{};
        wchar_t artist[512]{};
        wchar_t aumid[512]{};
        const int rc =
            AmbilightNowPlaying_FetchThumbnail(&blob, title, 512, artist, 512, aumid, 512);
        if (rc < 0) {
          AmbilightThumbBlob_Free(&blob);
          result->Error("now_playing_failed", "Windows.Media.Control (GSMTC) selhalo.",
                        flutter::EncodableValue());
          return;
        }
        flutter::EncodableMap m;
        m[flutter::EncodableValue("title")] = flutter::EncodableValue(Utf8FromUtf16(title));
        m[flutter::EncodableValue("artist")] = flutter::EncodableValue(Utf8FromUtf16(artist));
        m[flutter::EncodableValue("sourceAppUserModelId")] =
            flutter::EncodableValue(Utf8FromUtf16(aumid));
        if (blob.data != nullptr && blob.len > 0) {
          m[flutter::EncodableValue("thumbnail")] = flutter::EncodableValue(
              std::vector<uint8_t>(blob.data, blob.data + blob.len));
        } else {
          m[flutter::EncodableValue("thumbnail")] = flutter::EncodableValue();
        }
        AmbilightThumbBlob_Free(&blob);
        result->Success(flutter::EncodableValue(std::move(m)));
      });
}

void UnregisterAmbilightNowPlaying() {
  if (g_now_playing) {
    g_now_playing->SetMethodCallHandler(nullptr);
    g_now_playing.reset();
  }
}
