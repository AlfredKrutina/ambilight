#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  uint8_t* data;
  size_t len;
} AmbilightThumbBlob;

void AmbilightThumbBlob_Free(AmbilightThumbBlob* b);

/// 1 = OK (i prázdná miniatura se nepočítá — len==0 vrací 0), 0 = žádná relace/miniatura, -1 = chyba.
int AmbilightNowPlaying_FetchThumbnail(AmbilightThumbBlob* out_thumb,
                                       wchar_t* title,
                                       int title_cch,
                                       wchar_t* artist,
                                       int artist_cch,
                                       wchar_t* aumid,
                                       int aumid_cch);

#ifdef __cplusplus
}
#endif
