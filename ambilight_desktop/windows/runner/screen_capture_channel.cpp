#include "screen_capture_channel.h"
#include "screen_capture_dxgi.h"

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace ambilight_native_capture {

constexpr UINT kAmbilightCaptureDone = WM_APP + 64;
// Oddělení od jiných WM_APP zpráv; nezávislé na [g_window] při unregister.
constexpr WPARAM kAmbilightCaptureMagic = 0x414d4243u;  // 'AMBC'

constexpr UINT kAmbilightStreamFrame = WM_APP + 66;
constexpr WPARAM kAmbilightStreamMagic = 0x414d5354u;  // 'AMST'

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
  /// DXGI [AcquireNextFrame(0)] — žádný nový frame; Dart má ponechat poslední snímek.
  bool no_update = false;
  /// Nativní rozměry monitoru (MSS index [resolved]); ROI výpočty v Dartu.
  int layout_width = 0;
  int layout_height = 0;
  /// Levý horní roh snímku v souřadnicích monitoru (0…layout), před downscale.
  int buffer_origin_x = 0;
  int buffer_origin_y = 0;
  int native_buffer_width = 0;
  int native_buffer_height = 0;
};

HWND g_window = nullptr;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

struct CaptureJob {
  int monitor_index = 0;
  std::string capture_backend;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  HWND reply_hwnd = nullptr;
  bool has_crop = false;
  RECT crop_desktop{};
  UINT dxgi_acquire_timeout_ms = 0;
};

std::mutex g_capture_queue_mu;
std::condition_variable g_capture_queue_cv;
std::deque<CaptureJob> g_capture_queue;
bool g_capture_worker_shutdown = false;
std::thread g_capture_worker;

std::mutex g_stream_sink_mu;
std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> g_stream_sink;

struct StreamParams {
  int monitor_index = 1;
  std::string capture_backend = "dxgi";
  bool has_crop = false;
  RECT crop_desktop{};
  UINT dxgi_acquire_timeout_ms = 16;
};
std::mutex g_stream_params_mu;
StreamParams g_stream_params;

std::atomic<bool> g_stream_thread_stop{true};
std::thread g_stream_thread;

std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> g_evt_channel;

// Jedno worker vlákno — bez mutexu. Po řadě DXGI WAIT_TIMEOUT bez nového snímku DWM často „mlčí“
// i přes změny na obrazovce; GDI pojistka obnoví pixely (viz ExecuteCaptureJob).
static int g_dxgi_timeout_streak = 0;
static uint64_t g_last_successful_capture_tick64 = 0;

bool ResolveCaptureRect(int mss_style_index, RECT& out_rect, int& out_resolved_index);
int RectWidth(const RECT& r);
int RectHeight(const RECT& r);
bool RectToRgba(const RECT& src_rect, std::vector<uint8_t>& out_rgba, int& out_w, int& out_h);
void DownscaleRgbaForAmbilight(const std::vector<uint8_t>& src_rgba,
                                int src_w,
                                int src_h,
                                std::vector<uint8_t>& out_rgba,
                                int& out_w,
                                int& out_h);

void PostCapturePayloadToUi(HWND hwnd, std::unique_ptr<CaptureDonePayload> payload) {
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
      payload->result->Error("post_failed", "Could not post capture result to UI thread",
                             flutter::EncodableValue());
    }
    return;
  }
  (void)payload.release();
}

/// Společné jádro snímku (pull MethodChannel i push stream). [payload] bez [result] pro stream.
void AmbilightExecuteCaptureCore(int monitor_index,
                                 const std::string& capture_backend,
                                 bool has_crop,
                                 const RECT& crop_desktop,
                                 UINT dxgi_acquire_timeout_ms,
                                 CaptureDonePayload& payload,
                                 int diag_kind) {
  const uint64_t tick_now = ::GetTickCount64();
  RECT rc{};
  int resolved = monitor_index;
  std::vector<uint8_t> rgba;
  int w = 0;
  int h = 0;
  bool ok = ResolveCaptureRect(monitor_index, rc, resolved);
  RECT capture_rc = rc;
  if (ok && has_crop) {
    RECT inter{};
    if (!::IntersectRect(&inter, &rc, &crop_desktop)) {
      ok = false;
    } else {
      capture_rc = inter;
    }
  }
  bool got = false;
  const bool want_dxgi = ok && capture_backend == "dxgi" && resolved > 0;
  bool dxgi_ok = false;
  bool dxgi_wait_timeout = false;
  std::string path_tag = !ok ? "resolve_fail" : "pending";

  if (want_dxgi) {
    dxgi_ok = AmbilightDxgiCaptureRect(rc, capture_rc, rgba, w, h, &dxgi_wait_timeout,
                                       dxgi_acquire_timeout_ms);
    got = dxgi_ok;
    if (dxgi_ok) {
      path_tag = "dxgi";
      g_dxgi_timeout_streak = 0;
    } else if (dxgi_wait_timeout) {
      path_tag = "dxgi_no_frame";
      g_dxgi_timeout_streak++;
    } else {
      g_dxgi_timeout_streak = 0;
    }
  }

  constexpr int kGdiAfterDxgiTimeouts = 6;
  constexpr uint64_t kStaleNoSuccessMs = 400;
  const bool stale_wall = g_last_successful_capture_tick64 != 0 &&
                          (tick_now - g_last_successful_capture_tick64) > kStaleNoSuccessMs;
  const bool force_gdi_insurance =
      want_dxgi && dxgi_wait_timeout && ok && !got &&
      (g_dxgi_timeout_streak >= kGdiAfterDxgiTimeouts || stale_wall);

  if (!got && ok && (!(want_dxgi && dxgi_wait_timeout) || force_gdi_insurance)) {
    const bool gdi_ok = RectToRgba(capture_rc, rgba, w, h);
    got = gdi_ok;
    if (gdi_ok) {
      if (force_gdi_insurance) {
        path_tag = "gdi_insurance";
        g_dxgi_timeout_streak = 0;
      } else {
        path_tag = want_dxgi && !dxgi_ok ? "gdi_fallback" : "gdi";
      }
    }
  }
  if (!got && path_tag == "pending") {
    path_tag = "capture_failed";
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
    if (got) {
      g_last_successful_capture_tick64 = ::GetTickCount64();
    }
  }

  {
    static std::mutex capture_diag_mu;
    static uint64_t capture_diag_last_tick = 0;
    const uint64_t now = ::GetTickCount64();
    std::lock_guard<std::mutex> lock(capture_diag_mu);
    if (now - capture_diag_last_tick >= 2000) {
      capture_diag_last_tick = now;
      const char* wtag = diag_kind == 1 ? "stream=1" : "worker=1";
      std::string msg = std::string("[ambilight] CAPTURE path=") + path_tag +
                        " requested=" + capture_backend + " final_ok=" + (got ? "1" : "0");
      if (want_dxgi && !dxgi_ok && dxgi_wait_timeout && ok && !got) {
        msg += " dxgi_noop=1";
      }
      msg += " ";
      msg += wtag;
      msg += "\n";
      ::OutputDebugStringA(msg.c_str());
    }
  }

  if (!got && want_dxgi && !dxgi_ok && dxgi_wait_timeout && ok) {
    payload.no_update = true;
  } else if (got) {
    payload.rgba = std::move(rgba);
    payload.width = w;
    payload.height = h;
    payload.monitor_index = resolved;
    payload.layout_width = RectWidth(rc);
    payload.layout_height = RectHeight(rc);
    payload.buffer_origin_x = capture_rc.left - rc.left;
    payload.buffer_origin_y = capture_rc.top - rc.top;
    payload.native_buffer_width = RectWidth(capture_rc);
    payload.native_buffer_height = RectHeight(capture_rc);
  }
}

/// Jedno zpracování — běží na dedikovaném worker vlákně (žádný `std::thread::detach` na snímek).
void ExecuteCaptureJob(CaptureJob job) {
  HWND hwnd = job.reply_hwnd;
  auto payload = std::make_unique<CaptureDonePayload>();
  payload->result = std::move(job.result);
  AmbilightExecuteCaptureCore(job.monitor_index, job.capture_backend, job.has_crop, job.crop_desktop,
                              job.dxgi_acquire_timeout_ms, *payload, 0);
  PostCapturePayloadToUi(hwnd, std::move(payload));
}

void CaptureWorkerLoop() {
  (void)::SetThreadPriority(::GetCurrentThread(), THREAD_PRIORITY_ABOVE_NORMAL);
  for (;;) {
    CaptureJob job;
    {
      std::unique_lock<std::mutex> lk(g_capture_queue_mu);
      g_capture_queue_cv.wait(lk, [] {
        return g_capture_worker_shutdown || !g_capture_queue.empty();
      });
      if (g_capture_worker_shutdown && g_capture_queue.empty()) {
        return;
      }
      if (g_capture_queue.empty()) {
        continue;
      }
      job = std::move(g_capture_queue.front());
      g_capture_queue.pop_front();
    }
    ExecuteCaptureJob(std::move(job));
  }
}

void EnsureCaptureWorkerStarted() {
  std::lock_guard<std::mutex> lk(g_capture_queue_mu);
  if (g_capture_worker.joinable()) {
    return;
  }
  g_capture_worker_shutdown = false;
  g_dxgi_timeout_streak = 0;
  g_last_successful_capture_tick64 = 0;
  g_capture_worker = std::thread(CaptureWorkerLoop);
}

void StopCaptureWorkerAndDrain() {
  std::deque<CaptureJob> leftovers;
  {
    std::lock_guard<std::mutex> lk(g_capture_queue_mu);
    g_capture_worker_shutdown = true;
    leftovers.swap(g_capture_queue);
  }
  g_capture_queue_cv.notify_all();
  if (g_capture_worker.joinable()) {
    g_capture_worker.join();
  }
  // Po join žádný worker nevolá DXGI — bezpečně dokončíme čekající Future na UI vlákně jako no_update.
  for (auto& j : leftovers) {
    if (!j.result) {
      continue;
    }
    auto payload = std::make_unique<CaptureDonePayload>();
    payload->result = std::move(j.result);
    payload->no_update = true;
    PostCapturePayloadToUi(j.reply_hwnd, std::move(payload));
  }
  g_dxgi_timeout_streak = 0;
  g_last_successful_capture_tick64 = 0;
}

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

/// Stejné volitelné klíče jako u Event streamu (`cropLeft` … `cropHeight`).
void ParseCropFromEncodableMap(const flutter::EncodableMap& args,
                               bool& has_crop,
                               RECT& crop_desktop) {
  has_crop = false;
  auto ic = args.find(flutter::EncodableValue("cropLeft"));
  auto itc = args.find(flutter::EncodableValue("cropTop"));
  auto iw = args.find(flutter::EncodableValue("cropWidth"));
  auto ih = args.find(flutter::EncodableValue("cropHeight"));
  if (ic == args.end() || itc == args.end() || iw == args.end() || ih == args.end()) {
    return;
  }
  int cl = 0, ct = 0, cw = 0, ch = 0;
  if (const int32_t* v = std::get_if<int32_t>(&ic->second)) {
    cl = static_cast<int>(*v);
  } else if (const int64_t* v64 = std::get_if<int64_t>(&ic->second)) {
    cl = static_cast<int>(*v64);
  }
  if (const int32_t* v = std::get_if<int32_t>(&itc->second)) {
    ct = static_cast<int>(*v);
  } else if (const int64_t* v64 = std::get_if<int64_t>(&itc->second)) {
    ct = static_cast<int>(*v64);
  }
  if (const int32_t* v = std::get_if<int32_t>(&iw->second)) {
    cw = static_cast<int>(*v);
  } else if (const int64_t* v64 = std::get_if<int64_t>(&iw->second)) {
    cw = static_cast<int>(*v64);
  }
  if (const int32_t* v = std::get_if<int32_t>(&ih->second)) {
    ch = static_cast<int>(*v);
  } else if (const int64_t* v64 = std::get_if<int64_t>(&ih->second)) {
    ch = static_cast<int>(*v64);
  }
  if (cw > 0 && ch > 0) {
    has_crop = true;
    crop_desktop.left = cl;
    crop_desktop.top = ct;
    crop_desktop.right = cl + cw;
    crop_desktop.bottom = ct + ch;
  }
}

bool TryParseDxgiTimeoutMsFromEncodableMap(const flutter::EncodableMap& args, UINT& out_ms) {
  auto ito = args.find(flutter::EncodableValue("dxgiAcquireTimeoutMs"));
  if (ito == args.end()) {
    return false;
  }
  if (const int32_t* v = std::get_if<int32_t>(&ito->second)) {
    out_ms = static_cast<UINT>(std::max(0, static_cast<int>(*v)));
    return true;
  }
  if (const int64_t* v64 = std::get_if<int64_t>(&ito->second)) {
    out_ms = static_cast<UINT>(std::max<int64_t>(0, *v64));
    return true;
  }
  return false;
}

void EnqueueCaptureJob(CaptureJob job) {
  HWND hwnd = g_window;
  if (!hwnd) {
    if (job.result) {
      job.result->Error("no_window", "Capture window not ready", flutter::EncodableValue());
    }
    return;
  }
  job.reply_hwnd = hwnd;
  {
    std::lock_guard<std::mutex> lk(g_capture_queue_mu);
    if (g_capture_worker_shutdown) {
      if (job.result) {
        job.result->Error("shutdown", "Screen capture worker stopped", flutter::EncodableValue());
      }
      return;
    }
    g_capture_queue.push_back(std::move(job));
  }
  g_capture_queue_cv.notify_one();
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

void PostStreamPayloadToUi(HWND hwnd, std::unique_ptr<CaptureDonePayload> payload) {
  if (!hwnd || !::IsWindow(hwnd)) {
    return;
  }
  CaptureDonePayload* raw = payload.get();
  if (!::PostMessageW(hwnd, kAmbilightStreamFrame, kAmbilightStreamMagic,
                       reinterpret_cast<LPARAM>(raw))) {
    return;
  }
  (void)payload.release();
}

void StreamCaptureWorkerLoop() {
  (void)::SetThreadPriority(::GetCurrentThread(), THREAD_PRIORITY_ABOVE_NORMAL);
  while (!g_stream_thread_stop.load()) {
    StreamParams sp;
    {
      std::lock_guard<std::mutex> lk(g_stream_params_mu);
      sp = g_stream_params;
    }
    HWND hwnd = g_window;
    if (!hwnd || !::IsWindow(hwnd)) {
      ::Sleep(50);
      continue;
    }
    auto posted = std::make_unique<CaptureDonePayload>();
    posted->result = nullptr;
    AmbilightExecuteCaptureCore(sp.monitor_index, sp.capture_backend, sp.has_crop, sp.crop_desktop,
                                sp.dxgi_acquire_timeout_ms, *posted, 1);
    if (posted->no_update) {
      PostStreamPayloadToUi(hwnd, std::move(posted));
    } else if (!posted->rgba.empty() && posted->width > 0 && posted->height > 0) {
      PostStreamPayloadToUi(hwnd, std::move(posted));
    } else {
      posted.reset();
      ::Sleep(1);
    }
    // Po zrušení streamu se vlákno ukončí; mezitím vyhnout se busy-spin při rychlých smyčkách bez bloku v DXGI.
    ::Sleep(0);
  }
}

void StopStreamCaptureWorker() {
  g_stream_thread_stop.store(true);
  if (g_stream_thread.joinable()) {
    g_stream_thread.join();
  }
  // Uvolnit duplikaci dřív, než znovu naběhne pull capture nebo jiný stream (žádné držení DXGI „naprázdno“).
  AmbilightDxgiShutdown();
}

bool InternalTryHandleHostWindowMessage(HWND /*hwnd*/, UINT message,
                                        WPARAM wparam, LPARAM lparam) {
  if (message == kAmbilightStreamFrame && wparam == kAmbilightStreamMagic) {
    auto* raw = reinterpret_cast<CaptureDonePayload*>(lparam);
    if (!raw) {
      return true;
    }
    std::unique_ptr<CaptureDonePayload> payload(raw);
    std::lock_guard<std::mutex> lk(g_stream_sink_mu);
    if (!g_stream_sink) {
      return true;
    }
    if (payload->no_update) {
      flutter::EncodableMap map;
      map[flutter::EncodableValue("noUpdate")] = flutter::EncodableValue(true);
      g_stream_sink->Success(flutter::EncodableValue(std::move(map)));
      return true;
    }
    if (payload->rgba.empty() || payload->width <= 0 || payload->height <= 0) {
      return true;
    }
    flutter::EncodableMap map;
    map[flutter::EncodableValue("width")] = flutter::EncodableValue(payload->width);
    map[flutter::EncodableValue("height")] = flutter::EncodableValue(payload->height);
    map[flutter::EncodableValue("monitorIndex")] =
        flutter::EncodableValue(payload->monitor_index);
    map[flutter::EncodableValue("rgba")] = flutter::EncodableValue(std::move(payload->rgba));
    if (payload->layout_width > 0 && payload->layout_height > 0) {
      map[flutter::EncodableValue("layoutWidth")] = flutter::EncodableValue(payload->layout_width);
      map[flutter::EncodableValue("layoutHeight")] = flutter::EncodableValue(payload->layout_height);
      map[flutter::EncodableValue("bufferOriginX")] =
          flutter::EncodableValue(payload->buffer_origin_x);
      map[flutter::EncodableValue("bufferOriginY")] =
          flutter::EncodableValue(payload->buffer_origin_y);
      map[flutter::EncodableValue("nativeBufferWidth")] =
          flutter::EncodableValue(payload->native_buffer_width);
      map[flutter::EncodableValue("nativeBufferHeight")] =
          flutter::EncodableValue(payload->native_buffer_height);
    }
    g_stream_sink->Success(flutter::EncodableValue(std::move(map)));
    return true;
  }

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
  if (payload->no_update) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("noUpdate")] = flutter::EncodableValue(true);
    payload->result->Success(flutter::EncodableValue(std::move(map)));
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
  if (payload->layout_width > 0 && payload->layout_height > 0) {
    map[flutter::EncodableValue("layoutWidth")] = flutter::EncodableValue(payload->layout_width);
    map[flutter::EncodableValue("layoutHeight")] = flutter::EncodableValue(payload->layout_height);
    map[flutter::EncodableValue("bufferOriginX")] =
        flutter::EncodableValue(payload->buffer_origin_x);
    map[flutter::EncodableValue("bufferOriginY")] =
        flutter::EncodableValue(payload->buffer_origin_y);
    map[flutter::EncodableValue("nativeBufferWidth")] =
        flutter::EncodableValue(payload->native_buffer_width);
    map[flutter::EncodableValue("nativeBufferHeight")] =
        flutter::EncodableValue(payload->native_buffer_height);
  }
  payload->result->Success(flutter::EncodableValue(std::move(map)));
  return true;
}

void InternalUnregisterAmbilightScreenCapture() {
  HWND hwnd = g_window;
  StopStreamCaptureWorker();
  if (g_evt_channel) {
    g_evt_channel->SetStreamHandler(nullptr);
    g_evt_channel.reset();
  }
  StopCaptureWorkerAndDrain();
  AmbilightDxgiShutdown();
  if (g_channel) {
    g_channel->SetMethodCallHandler(nullptr);
    g_channel.reset();
  }
  if (hwnd && ::IsWindow(hwnd)) {
    MSG msg{};
    while (::PeekMessageW(&msg, hwnd, kAmbilightStreamFrame, kAmbilightStreamFrame, PM_REMOVE)) {
      InternalTryHandleHostWindowMessage(hwnd, msg.message, msg.wParam, msg.lParam);
    }
    while (::PeekMessageW(&msg, hwnd, kAmbilightCaptureDone, kAmbilightCaptureDone, PM_REMOVE)) {
      InternalTryHandleHostWindowMessage(hwnd, msg.message, msg.wParam, msg.lParam);
    }
  }
  g_window = nullptr;
}

void InternalRegisterAmbilightScreenCapture(HWND window_handle, flutter::FlutterEngine* engine) {
  g_window = window_handle;
  EnsureCaptureWorkerStarted();
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
          const flutter::EncodableValue* root = call.arguments();
          const auto* args =
              root ? std::get_if<flutter::EncodableMap>(root) : nullptr;
          CaptureJob job;
          job.monitor_index = 1;
          job.capture_backend = "dxgi";
          job.result = std::move(result);
          if (args) {
            auto it = args->find(flutter::EncodableValue("monitorIndex"));
            if (it != args->end()) {
              if (const int32_t* v = std::get_if<int32_t>(&it->second)) {
                job.monitor_index = static_cast<int>(*v);
              } else if (const int64_t* v64 = std::get_if<int64_t>(&it->second)) {
                job.monitor_index = static_cast<int>(*v64);
              }
            }
            auto itb = args->find(flutter::EncodableValue("captureBackend"));
            if (itb != args->end()) {
              if (const auto* s = std::get_if<std::string>(&itb->second)) {
                job.capture_backend = *s;
              }
            }
            ParseCropFromEncodableMap(*args, job.has_crop, job.crop_desktop);
            UINT dxgi = 0;
            if (TryParseDxgiTimeoutMsFromEncodableMap(*args, dxgi)) {
              job.dxgi_acquire_timeout_ms = dxgi;
            }
          }
          EnqueueCaptureJob(std::move(job));
          return;
        }
        result->NotImplemented();
      });

  g_evt_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      engine->messenger(), "ambilight/screen_capture_stream",
      &flutter::StandardMethodCodec::GetInstance());

  auto stream_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [](const flutter::EncodableValue* arguments,
         std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        StreamParams sp;
        sp.dxgi_acquire_timeout_ms = 16;
        if (arguments) {
          if (const auto* args = std::get_if<flutter::EncodableMap>(arguments)) {
            auto it = args->find(flutter::EncodableValue("monitorIndex"));
            if (it != args->end()) {
              if (const int32_t* v = std::get_if<int32_t>(&it->second)) {
                sp.monitor_index = static_cast<int>(*v);
              } else if (const int64_t* v64 = std::get_if<int64_t>(&it->second)) {
                sp.monitor_index = static_cast<int>(*v64);
              }
            }
            auto itb = args->find(flutter::EncodableValue("captureBackend"));
            if (itb != args->end()) {
              if (const auto* s = std::get_if<std::string>(&itb->second)) {
                sp.capture_backend = *s;
              }
            }
            ParseCropFromEncodableMap(*args, sp.has_crop, sp.crop_desktop);
            UINT dxgi = sp.dxgi_acquire_timeout_ms;
            if (TryParseDxgiTimeoutMsFromEncodableMap(*args, dxgi)) {
              sp.dxgi_acquire_timeout_ms = dxgi;
            }
          }
        }
        {
          std::lock_guard<std::mutex> lk(g_stream_params_mu);
          g_stream_params = sp;
        }
        {
          std::lock_guard<std::mutex> lk(g_stream_sink_mu);
          g_stream_sink = std::move(events);
        }
        g_stream_thread_stop.store(false);
        if (g_stream_thread.joinable()) {
          g_stream_thread.join();
        }
        g_stream_thread = std::thread(StreamCaptureWorkerLoop);
        return nullptr;
      },
      [](const flutter::EncodableValue* /*arguments*/)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        StopStreamCaptureWorker();
        std::lock_guard<std::mutex> lk(g_stream_sink_mu);
        g_stream_sink.reset();
        return nullptr;
      });

  g_evt_channel->SetStreamHandler(std::move(stream_handler));
}

}  // namespace ambilight_native_capture

bool TryHandleAmbilightWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  return ambilight_native_capture::InternalTryHandleHostWindowMessage(hwnd, message, wparam, lparam);
}

void RegisterAmbilightScreenCapture(HWND window_handle, flutter::FlutterEngine* engine) {
  ambilight_native_capture::InternalRegisterAmbilightScreenCapture(window_handle, engine);
}

void UnregisterAmbilightScreenCapture() {
  ambilight_native_capture::InternalUnregisterAmbilightScreenCapture();
}
