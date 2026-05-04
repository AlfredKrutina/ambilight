#include "screen_capture_channel.h"
#include "screen_capture_dxgi.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr UINT kAmbilightCaptureDone = WM_APP + 64;
// Oddělení od jiných WM_APP zpráv; nezávislé na [g_window] při unregister.
constexpr WPARAM kAmbilightCaptureMagic = 0x414d4243u;  // 'AMBC'

struct MonitorRect {
  RECT rect{};
  bool primary = false;
};

struct CaptureDonePayload {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  std::vector<uint8_t> rgba;
  int width = 0;
  int height = 0;
  int monitor_index = 0;
};

HWND g_window = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

int RectWidth(const RECT& r) { return r.right - r.left; }
int RectHeight(const RECT& r) { return r.bottom - r.top; }

bool CompareMonitorTopLeft(const MonitorRect& a, const MonitorRect& b) {
  if (a.rect.left != b.rect.left) {
    return a.rect.left < b.rect.left;
  }
  return a.rect.top < b.rect.top;
}

BOOL CALLBACK MonitorEnumProc(HMONITOR monitor, HDC, LPRECT, LPARAM param) {
  auto* vec = reinterpret_cast<std::vector<MonitorRect>*>(param);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (!::GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }
  MonitorRect mr;
  mr.rect = info.rcMonitor;
  mr.primary = (info.dwFlags & MONITORINFOF_PRIMARY) != 0;
  vec->push_back(mr);
  return TRUE;
}

std::vector<MonitorRect> EnumerateMonitorsSorted() {
  std::vector<MonitorRect> mons;
  ::EnumDisplayMonitors(nullptr, nullptr, MonitorEnumProc,
                        reinterpret_cast<LPARAM>(&mons));
  std::sort(mons.begin(), mons.end(), CompareMonitorTopLeft);
  return mons;
}

RECT VirtualScreenRect() {
  RECT r{};
  r.left = ::GetSystemMetrics(SM_XVIRTUALSCREEN);
  r.top = ::GetSystemMetrics(SM_YVIRTUALSCREEN);
  r.right = r.left + ::GetSystemMetrics(SM_CXVIRTUALSCREEN);
  r.bottom = r.top + ::GetSystemMetrics(SM_CYVIRTUALSCREEN);
  return r;
}

bool RectToRgba(const RECT& src_rect, std::vector<uint8_t>& out_rgba, int& out_w,
                int& out_h) {
  const int w = RectWidth(src_rect);
  const int h = RectHeight(src_rect);
  if (w <= 0 || h <= 0) {
    return false;
  }
  const size_t wz = static_cast<size_t>(w);
  const size_t hz = static_cast<size_t>(h);
  if (wz > 16384 || hz > 16384) {
    return false;
  }
  if (wz != 0 && hz > (SIZE_MAX / 4u) / wz) {
    return false;
  }

  HDC screen_dc = ::GetDC(nullptr);
  if (!screen_dc) {
    return false;
  }

  HDC mem_dc = ::CreateCompatibleDC(screen_dc);
  if (!mem_dc) {
    ::ReleaseDC(nullptr, screen_dc);
    return false;
  }

  BITMAPINFOHEADER bi{};
  bi.biSize = sizeof(bi);
  bi.biWidth = w;
  bi.biHeight = -h;
  bi.biPlanes = 1;
  bi.biBitCount = 32;
  bi.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP dib = ::CreateDIBSection(screen_dc, reinterpret_cast<BITMAPINFO*>(&bi),
                                   DIB_RGB_COLORS, &bits, nullptr, 0);
  if (!dib || !bits) {
    ::DeleteDC(mem_dc);
    ::ReleaseDC(nullptr, screen_dc);
    return false;
  }

  HGDIOBJ old = ::SelectObject(mem_dc, dib);
  // Bez CAPTUREBLT — sníží problikávání hardwarového kurzoru při častém snímání.
  if (!::BitBlt(mem_dc, 0, 0, w, h, screen_dc, src_rect.left, src_rect.top, SRCCOPY)) {
    ::SelectObject(mem_dc, old);
    ::DeleteObject(dib);
    ::DeleteDC(mem_dc);
    ::ReleaseDC(nullptr, screen_dc);
    return false;
  }

  const size_t nbytes = wz * hz * 4u;
  out_rgba.resize(nbytes);
  auto* px = reinterpret_cast<const uint8_t*>(bits);
  for (size_t i = 0; i < nbytes; i += 4) {
    const uint8_t b = px[i];
    const uint8_t g = px[i + 1];
    const uint8_t r = px[i + 2];
    // GDI DIB často dává alpha 0 — pro RGBA pipeline v Dartu držíme neprůhlednost.
    (void)px[i + 3];
    out_rgba[i] = r;
    out_rgba[i + 1] = g;
    out_rgba[i + 2] = b;
    out_rgba[i + 3] = 255;
  }

  ::SelectObject(mem_dc, old);
  ::DeleteObject(dib);
  ::DeleteDC(mem_dc);
  ::ReleaseDC(nullptr, screen_dc);

  out_w = w;
  out_h = h;
  return true;
}

// Maximální delší strana výstupu (RGBA). 1440p → ~256×144×4 ≈ 147 KiB místo ~15 MiB přes isolát.
constexpr int kAmbilightCaptureDownscaleMaxSide = 256;

/// Shrání captured framebufferu se zachováním poměru stran (ROI v Dartu zůstávají v % platné).
/// Vstup musí být už převedený RGBA s kanály R,G,B,A v tomto pořadí (GDI/DXGI BGRA→RGBA výše).
void DownscaleRgbaForAmbilight(const std::vector<uint8_t>& src_rgba,
                               int src_w,
                               int src_h,
                               std::vector<uint8_t>& out_rgba,
                               int& out_w,
                               int& out_h) {
  if (src_w <= 0 || src_h <= 0) {
    out_rgba.clear();
    out_w = 0;
    out_h = 0;
    return;
  }
  const size_t expected = static_cast<size_t>(src_w) * static_cast<size_t>(src_h) * 4u;
  if (src_rgba.size() < expected) {
    out_rgba.clear();
    out_w = 0;
    out_h = 0;
    return;
  }
  if (src_w <= kAmbilightCaptureDownscaleMaxSide &&
      src_h <= kAmbilightCaptureDownscaleMaxSide) {
    out_rgba = src_rgba;
    out_w = src_w;
    out_h = src_h;
    return;
  }

  const double scale_w =
      static_cast<double>(kAmbilightCaptureDownscaleMaxSide) /
      static_cast<double>(src_w);
  const double scale_h =
      static_cast<double>(kAmbilightCaptureDownscaleMaxSide) /
      static_cast<double>(src_h);
  const double scale = std::min(scale_w, scale_h);
  out_w = std::max(1, static_cast<int>(std::lround(static_cast<double>(src_w) * scale)));
  out_h = std::max(1, static_cast<int>(std::lround(static_cast<double>(src_h) * scale)));

  const size_t cells = static_cast<size_t>(out_w) * static_cast<size_t>(out_h);
  std::vector<uint64_t> acc_r(cells);
  std::vector<uint64_t> acc_g(cells);
  std::vector<uint64_t> acc_b(cells);
  std::vector<uint64_t> acc_a(cells);
  std::vector<uint64_t> acc_n(cells);

  for (int y = 0; y < src_h; ++y) {
    const int dy =
        std::min(out_h - 1, static_cast<int>((static_cast<int64_t>(y) * out_h) / src_h));
    for (int x = 0; x < src_w; ++x) {
      const int dx =
          std::min(out_w - 1, static_cast<int>((static_cast<int64_t>(x) * out_w) / src_w));
      const size_t si = (static_cast<size_t>(y) * static_cast<size_t>(src_w) +
                          static_cast<size_t>(x)) *
                         4u;
      const size_t di = static_cast<size_t>(dy) * static_cast<size_t>(out_w) +
                        static_cast<size_t>(dx);
      acc_r[di] += src_rgba[si];
      acc_g[di] += src_rgba[si + 1];
      acc_b[di] += src_rgba[si + 2];
      acc_a[di] += src_rgba[si + 3];
      acc_n[di]++;
    }
  }

  out_rgba.resize(cells * 4u);
  for (size_t i = 0; i < cells; ++i) {
    const uint64_t n = acc_n[i] == 0 ? 1 : acc_n[i];
    const size_t o = i * 4u;
    out_rgba[o] = static_cast<uint8_t>((acc_r[i] + n / 2) / n);
    out_rgba[o + 1] = static_cast<uint8_t>((acc_g[i] + n / 2) / n);
    out_rgba[o + 2] = static_cast<uint8_t>((acc_b[i] + n / 2) / n);
    out_rgba[o + 3] = 255;
  }
}

bool ResolveCaptureRect(int mss_style_index, RECT& out_rect, int& out_resolved_index) {
  if (mss_style_index <= 0) {
    out_rect = VirtualScreenRect();
    out_resolved_index = 0;
    return RectWidth(out_rect) > 0 && RectHeight(out_rect) > 0;
  }

  auto mons = EnumerateMonitorsSorted();
  if (mons.empty()) {
    return false;
  }
  const int idx = mss_style_index - 1;
  if (idx < 0 || idx >= static_cast<int>(mons.size())) {
    out_rect = mons.front().rect;
    out_resolved_index = 1;
    return true;
  }
  out_rect = mons[idx].rect;
  out_resolved_index = mss_style_index;
  return RectWidth(out_rect) > 0 && RectHeight(out_rect) > 0;
}

void DispatchCaptureAsync(int monitor_index,
                          const std::string& capture_backend,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND hwnd = g_window;
  if (!hwnd) {
    result->Error("no_window", "Capture window not ready",
                  flutter::EncodableValue());
    return;
  }
  std::thread([monitor_index, capture_backend, r = std::move(result), hwnd]() mutable {
    RECT rc{};
    int resolved = monitor_index;
    std::vector<uint8_t> rgba;
    int w = 0;
    int h = 0;
    bool ok = ResolveCaptureRect(monitor_index, rc, resolved);
    bool got = false;
    if (ok && capture_backend == "dxgi" && resolved > 0) {
      got = AmbilightDxgiCaptureRect(rc, rgba, w, h);
    }
    if (!got && ok) {
      got = RectToRgba(rc, rgba, w, h);
    }
    if (got) {
      std::vector<uint8_t> rgba_small;
      int dw = w;
      int dh = h;
      DownscaleRgbaForAmbilight(rgba, w, h, rgba_small, dw, dh);
      rgba = std::move(rgba_small);
      w = dw;
      h = dh;
      got = !rgba.empty() && w > 0 && h > 0;
    }
    auto payload = std::make_unique<CaptureDonePayload>();
    payload->result = std::move(r);
    if (got) {
      payload->rgba = std::move(rgba);
      payload->width = w;
      payload->height = h;
      payload->monitor_index = resolved;
    }
    if (!hwnd || !::IsWindow(hwnd)) {
      if (payload->result) {
        payload->result->Error("no_window", "Capture window gone before completion",
                               flutter::EncodableValue());
      }
      return;
    }
    CaptureDonePayload* raw = payload.get();
    if (!::PostMessageW(hwnd, kAmbilightCaptureDone, kAmbilightCaptureMagic,
                         reinterpret_cast<LPARAM>(raw))) {
      if (payload->result) {
        payload->result->Error(
            "post_failed", "Could not post capture result to UI thread",
            flutter::EncodableValue());
      }
      return;
    }
    (void)payload.release();
  }).detach();
}

flutter::EncodableList BuildMonitorListEncodable() {
  flutter::EncodableList list;
  RECT virt = VirtualScreenRect();
  flutter::EncodableMap m0;
  m0[flutter::EncodableValue("mssStyleIndex")] = flutter::EncodableValue(0);
  m0[flutter::EncodableValue("left")] = flutter::EncodableValue(virt.left);
  m0[flutter::EncodableValue("top")] = flutter::EncodableValue(virt.top);
  m0[flutter::EncodableValue("width")] = flutter::EncodableValue(RectWidth(virt));
  m0[flutter::EncodableValue("height")] = flutter::EncodableValue(RectHeight(virt));
  m0[flutter::EncodableValue("isPrimary")] = flutter::EncodableValue(false);
  list.push_back(flutter::EncodableValue(std::move(m0)));

  auto mons = EnumerateMonitorsSorted();
  int idx = 1;
  for (const auto& m : mons) {
    flutter::EncodableMap em;
    em[flutter::EncodableValue("mssStyleIndex")] = flutter::EncodableValue(idx);
    em[flutter::EncodableValue("left")] = flutter::EncodableValue(m.rect.left);
    em[flutter::EncodableValue("top")] = flutter::EncodableValue(m.rect.top);
    em[flutter::EncodableValue("width")] = flutter::EncodableValue(RectWidth(m.rect));
    em[flutter::EncodableValue("height")] = flutter::EncodableValue(RectHeight(m.rect));
    em[flutter::EncodableValue("isPrimary")] = flutter::EncodableValue(m.primary);
    list.push_back(flutter::EncodableValue(std::move(em)));
    idx++;
  }
  return list;
}

}  // namespace

bool TryHandleAmbilightWindowMessage(HWND /*hwnd*/, UINT message,
                                     WPARAM wparam, LPARAM lparam) {
  if (message != kAmbilightCaptureDone || wparam != kAmbilightCaptureMagic) {
    return false;
  }
  auto* raw = reinterpret_cast<CaptureDonePayload*>(lparam);
  if (!raw) {
    return true;
  }
  std::unique_ptr<CaptureDonePayload> payload(raw);
  if (!payload->result) {
    return true;
  }
  if (payload->rgba.empty() || payload->width <= 0 || payload->height <= 0) {
    payload->result->Error("capture_failed", "Screen capture failed",
                           flutter::EncodableValue());
    return true;
  }
  flutter::EncodableMap map;
  map[flutter::EncodableValue("width")] = flutter::EncodableValue(payload->width);
  map[flutter::EncodableValue("height")] = flutter::EncodableValue(payload->height);
  map[flutter::EncodableValue("monitorIndex")] =
      flutter::EncodableValue(payload->monitor_index);
  map[flutter::EncodableValue("rgba")] =
      flutter::EncodableValue(std::move(payload->rgba));
  payload->result->Success(flutter::EncodableValue(std::move(map)));
  return true;
}

void RegisterAmbilightScreenCapture(HWND window_handle,
                                    flutter::FlutterEngine* engine) {
  g_window = window_handle;
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "ambilight/screen_capture",
      &flutter::StandardMethodCodec::GetInstance());

  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "listMonitors") {
          flutter::EncodableList list = BuildMonitorListEncodable();
          result->Success(flutter::EncodableValue(std::move(list)));
          return;
        }
        if (call.method_name() == "sessionInfo") {
          flutter::EncodableMap m;
          m[flutter::EncodableValue("os")] = flutter::EncodableValue("windows");
          m[flutter::EncodableValue("sessionType")] =
              flutter::EncodableValue("win32");
          m[flutter::EncodableValue("captureBackend")] =
              flutter::EncodableValue("gdi_or_dxgi");
          m[flutter::EncodableValue("note")] = flutter::EncodableValue(
              "Windows: gdi/dxgi capture is downscaled (max side " +
                  std::to_string(kAmbilightCaptureDownscaleMaxSide) +
                  " px, RGBA) before MethodChannel to reduce isolate payload.");
          result->Success(flutter::EncodableValue(std::move(m)));
          return;
        }
        if (call.method_name() == "requestPermission") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "capture") {
          int monitor_index = 1;
          std::string capture_backend = "gdi";
          const flutter::EncodableValue* root = call.arguments();
          const auto* args =
              root ? std::get_if<flutter::EncodableMap>(root) : nullptr;
          if (args) {
            auto it = args->find(flutter::EncodableValue("monitorIndex"));
            if (it != args->end()) {
              if (const int32_t* v = std::get_if<int32_t>(&it->second)) {
                monitor_index = static_cast<int>(*v);
              } else if (const int64_t* v64 = std::get_if<int64_t>(&it->second)) {
                monitor_index = static_cast<int>(*v64);
              }
            }
            auto itb = args->find(flutter::EncodableValue("captureBackend"));
            if (itb != args->end()) {
              if (const auto* s = std::get_if<std::string>(&itb->second)) {
                capture_backend = *s;
              }
            }
          }
          DispatchCaptureAsync(monitor_index, capture_backend, std::move(result));
          return;
        }
        result->NotImplemented();
      });
}

void UnregisterAmbilightScreenCapture() {
  AmbilightDxgiShutdown();
  if (g_channel) {
    g_channel->SetMethodCallHandler(nullptr);
    g_channel.reset();
  }
  g_window = nullptr;
}
