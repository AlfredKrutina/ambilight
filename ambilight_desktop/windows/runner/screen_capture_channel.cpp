#include "screen_capture_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <memory>
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
  if (!::BitBlt(mem_dc, 0, 0, w, h, screen_dc, src_rect.left, src_rect.top,
                SRCCOPY | CAPTUREBLT)) {
    ::SelectObject(mem_dc, old);
    ::DeleteObject(dib);
    ::DeleteDC(mem_dc);
    ::ReleaseDC(nullptr, screen_dc);
    return false;
  }

  const size_t nbytes = static_cast<size_t>(w) * static_cast<size_t>(h) * 4u;
  out_rgba.resize(nbytes);
  auto* px = reinterpret_cast<const uint8_t*>(bits);
  for (size_t i = 0; i < nbytes; i += 4) {
    const uint8_t b = px[i];
    const uint8_t g = px[i + 1];
    const uint8_t r = px[i + 2];
    const uint8_t a = px[i + 3];
    out_rgba[i] = r;
    out_rgba[i + 1] = g;
    out_rgba[i + 2] = b;
    out_rgba[i + 3] = a;
  }

  ::SelectObject(mem_dc, old);
  ::DeleteObject(dib);
  ::DeleteDC(mem_dc);
  ::ReleaseDC(nullptr, screen_dc);

  out_w = w;
  out_h = h;
  return true;
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
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND hwnd = g_window;
  if (!hwnd) {
    result->Error("no_window", "Capture window not ready",
                  flutter::EncodableValue());
    return;
  }
  std::thread([monitor_index, r = std::move(result), hwnd]() mutable {
    RECT rc{};
    int resolved = monitor_index;
    std::vector<uint8_t> rgba;
    int w = 0;
    int h = 0;
    const bool ok = hwnd && ResolveCaptureRect(monitor_index, rc, resolved) &&
                    RectToRgba(rc, rgba, w, h);
    auto* payload = new CaptureDonePayload();
    payload->result = std::move(r);
    if (ok) {
      payload->rgba = std::move(rgba);
      payload->width = w;
      payload->height = h;
      payload->monitor_index = resolved;
    }
    if (hwnd) {
      ::PostMessageW(hwnd, kAmbilightCaptureDone, kAmbilightCaptureMagic,
                     reinterpret_cast<LPARAM>(payload));
    }
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
              flutter::EncodableValue("gdi_bitblt");
          m[flutter::EncodableValue("note")] = flutter::EncodableValue(
              "BitBlt virtual screen / per-monitor; HDR and exclusive fullscreen "
              "may differ.");
          result->Success(flutter::EncodableValue(std::move(m)));
          return;
        }
        if (call.method_name() == "requestPermission") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "capture") {
          int monitor_index = 1;
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
          }
          DispatchCaptureAsync(monitor_index, std::move(result));
          return;
        }
        result->NotImplemented();
      });
}

void UnregisterAmbilightScreenCapture() {
  if (g_channel) {
    g_channel->SetMethodCallHandler(nullptr);
    g_channel.reset();
  }
  g_window = nullptr;
}
