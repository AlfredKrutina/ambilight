#include "now_playing_winrt.h"

#include <Windows.h>
#include <cstring>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Security.Cryptography.h>
#include <winrt/Windows.Storage.Streams.h>

#include <mutex>

#include <winrt/base.h>

using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Media::Control;
using namespace Windows::Security::Cryptography;
using namespace Windows::Storage::Streams;

namespace {

void WCopy(wchar_t* dst, int cch, hstring const& s) {
  if (!dst || cch <= 0) {
    return;
  }
  wcsncpy_s(dst, static_cast<size_t>(cch), s.c_str(), _TRUNCATE);
}

void EnsureApartment() {
  static std::once_flag once;
  std::call_once(once, [] {
    try {
      init_apartment(apartment_type::multi_threaded);
    } catch (hresult_error const&) {
      // COM už inicializované jiným apartmentem — pokračovat.
    }
  });
}

}  // namespace

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
  if (!out_thumb) {
    return -1;
  }
  out_thumb->data = nullptr;
  out_thumb->len = 0;
  if (title && title_cch > 0) {
    title[0] = L'\0';
  }
  if (artist && artist_cch > 0) {
    artist[0] = L'\0';
  }
  if (aumid && aumid_cch > 0) {
    aumid[0] = L'\0';
  }

  EnsureApartment();

  try {
    auto const mgr = GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
    auto session = mgr.GetCurrentSession();
    if (!session) {
      return 0;
    }
    WCopy(aumid, aumid_cch, session.SourceAppUserModelId());

    auto props = session.TryGetMediaPropertiesAsync().get();
    if (!props) {
      return 0;
    }
    WCopy(title, title_cch, props.Title());
    WCopy(artist, artist_cch, props.Artist());

    IRandomAccessStreamReference thumb_ref = props.Thumbnail();
    if (!thumb_ref) {
      return 0;
    }

    IRandomAccessStreamWithContentType ras = thumb_ref.OpenReadAsync().get();
    if (!ras) {
      return 0;
    }
    const uint64_t size64 = ras.Size();
    if (size64 == 0 || size64 > 8 * 1024 * 1024) {
      return 0;
    }
    const uint32_t size = static_cast<uint32_t>(size64);

    IInputStream input = ras.GetInputStreamAt(0);
    DataReader reader(input);
    reader.ByteOrder(ByteOrder::LittleEndian);
    reader.LoadAsync(size).get();
    IBuffer buffer = reader.ReadBuffer(size);

    com_array<uint8_t> bytes;
    CryptographicBuffer::CopyToByteArray(buffer, bytes);
    if (bytes.empty()) {
      return 0;
    }

    void* heap = malloc(bytes.size());
    if (!heap) {
      return -1;
    }
    memcpy(heap, bytes.data(), bytes.size());
    out_thumb->data = static_cast<uint8_t*>(heap);
    out_thumb->len = bytes.size();
    return 1;
  } catch (hresult_error const&) {
    AmbilightThumbBlob_Free(out_thumb);
    return -1;
  } catch (...) {
    AmbilightThumbBlob_Free(out_thumb);
    return -1;
  }
}
