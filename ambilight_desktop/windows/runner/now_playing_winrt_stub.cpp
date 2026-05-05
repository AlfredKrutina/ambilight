// Fallback, pokud CMake nenajde cppwinrt (bez GSMTC buildu).
#include "now_playing_winrt.h"

#include <stdlib.h>
#include <string.h>

extern "C" void AmbilightThumbBlob_Free(AmbilightThumbBlob* b) {
  if (!b) {
    return;
  }
  if (b->data) {
    free(b->data);
    b->data = nullptr;
  }
  b->len = 0;
}

extern "C" int AmbilightNowPlaying_FetchThumbnail(AmbilightThumbBlob* out_thumb,
                                                wchar_t* title,
                                                int title_cch,
                                                wchar_t* artist,
                                                int artist_cch,
                                                wchar_t* aumid,
                                                int aumid_cch) {
  (void)title;
  (void)title_cch;
  (void)artist;
  (void)artist_cch;
  (void)aumid;
  (void)aumid_cch;
  if (out_thumb) {
    out_thumb->data = nullptr;
    out_thumb->len = 0;
  }
  return 0;
}
