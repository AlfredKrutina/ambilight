#include "ambilight_screen_capture.h"

#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

FlMethodChannel* g_channel = nullptr;

struct MonitorRect {
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
  bool primary = false;
};

static int MaskShift(unsigned long mask) {
  int s = 0;
  while (mask != 0u && (mask & 1u) == 0u) {
    mask >>= 1u;
    s++;
  }
  return s;
}

static bool CompareMonitorTopLeft(const MonitorRect& a, const MonitorRect& b) {
  if (a.x != b.x) {
    return a.x < b.x;
  }
  return a.y < b.y;
}

static std::vector<MonitorRect> ListMonitorsXrr(Display* dpy, Window root) {
  std::vector<MonitorRect> out;
  int event_base = 0;
  int error_base = 0;
  if (!XRRQueryExtension(dpy, &event_base, &error_base)) {
    return out;
  }
  int nmon = 0;
  XRRMonitorInfo* info = XRRGetMonitors(dpy, root, True, &nmon);
  if (info == nullptr || nmon <= 0) {
    if (info != nullptr) {
      XRRFreeMonitors(info);
    }
    return out;
  }
  for (int i = 0; i < nmon; i++) {
    MonitorRect m;
    m.x = info[i].x;
    m.y = info[i].y;
    m.width = static_cast<int>(info[i].width);
    m.height = static_cast<int>(info[i].height);
    m.primary = info[i].primary != 0;
    out.push_back(m);
  }
  XRRFreeMonitors(info);
  std::sort(out.begin(), out.end(), CompareMonitorTopLeft);
  return out;
}

static MonitorRect VirtualUnion(const std::vector<MonitorRect>& mons) {
  MonitorRect u{};
  if (mons.empty()) {
    return u;
  }
  int minx = mons[0].x;
  int miny = mons[0].y;
  int maxx = mons[0].x + mons[0].width;
  int maxy = mons[0].y + mons[0].height;
  for (const auto& m : mons) {
    minx = std::min(minx, m.x);
    miny = std::min(miny, m.y);
    maxx = std::max(maxx, m.x + m.width);
    maxy = std::max(maxy, m.y + m.height);
  }
  u.x = minx;
  u.y = miny;
  u.width = maxx - minx;
  u.height = maxy - miny;
  u.primary = false;
  return u;
}

static bool XImageToRgba(XImage* im, int w, int h, std::vector<uint8_t>& rgba) {
  if (im == nullptr || im->bits_per_pixel != 32) {
    return false;
  }
  const int rsh = MaskShift(im->red_mask);
  const int gsh = MaskShift(im->green_mask);
  const int bsh = MaskShift(im->blue_mask);
  rgba.resize(static_cast<size_t>(w) * static_cast<size_t>(h) * 4u);
  for (int y = 0; y < h; y++) {
    const char* row = im->data + static_cast<ptrdiff_t>(y) * im->bytes_per_line;
    for (int x = 0; x < w; x++) {
      const auto* px = reinterpret_cast<const uint32_t*>(row) + x;
      const uint32_t p = *px;
      const uint8_t r = static_cast<uint8_t>((p & im->red_mask) >> rsh);
      const uint8_t g = static_cast<uint8_t>((p & im->green_mask) >> gsh);
      const uint8_t b = static_cast<uint8_t>((p & im->blue_mask) >> bsh);
      const size_t o =
          (static_cast<size_t>(y) * static_cast<size_t>(w) + static_cast<size_t>(x)) * 4u;
      rgba[o] = r;
      rgba[o + 1] = g;
      rgba[o + 2] = b;
      rgba[o + 3] = 255;
    }
  }
  return true;
}

static bool CaptureRect(Display* dpy, Window root, const MonitorRect& r, int resolved_index,
                        std::vector<uint8_t>& rgba, int& out_w, int& out_h, int& out_idx) {
  if (r.width <= 0 || r.height <= 0) {
    return false;
  }
  XImage* im =
      XGetImage(dpy, root, r.x, r.y, static_cast<unsigned int>(r.width),
                static_cast<unsigned int>(r.height), AllPlanes, ZPixmap);
  if (im == nullptr) {
    return false;
  }
  if (!XImageToRgba(im, r.width, r.height, rgba)) {
    XDestroyImage(im);
    return false;
  }
  XDestroyImage(im);
  out_w = r.width;
  out_h = r.height;
  out_idx = resolved_index;
  return true;
}

static bool ResolveCapture(Display* dpy, Window root, const std::vector<MonitorRect>& mons,
                           int mss_style_index, MonitorRect& rect, int& resolved) {
  if (mons.empty()) {
    XWindowAttributes attr;
    if (XGetWindowAttributes(dpy, root, &attr) == 0) {
      return false;
    }
    rect.x = 0;
    rect.y = 0;
    rect.width = attr.width;
    rect.height = attr.height;
    resolved = mss_style_index <= 0 ? 0 : 1;
    return rect.width > 0 && rect.height > 0;
  }
  if (mss_style_index <= 0) {
    rect = VirtualUnion(mons);
    resolved = 0;
    return rect.width > 0 && rect.height > 0;
  }
  const int idx = mss_style_index - 1;
  if (idx < 0 || idx >= static_cast<int>(mons.size())) {
    rect = mons.front();
    resolved = 1;
    return rect.width > 0 && rect.height > 0;
  }
  rect = mons[static_cast<size_t>(idx)];
  resolved = mss_style_index;
  return rect.width > 0 && rect.height > 0;
}

static FlValue* BuildMonitorListValue(Display* dpy, Window root) {
  auto mons = ListMonitorsXrr(dpy, root);
  g_autoptr(FlValue) list = fl_value_new_list();
  if (mons.empty()) {
    XWindowAttributes attr;
    if (XGetWindowAttributes(dpy, root, &attr) != 0) {
      g_autoptr(FlValue) m0 = fl_value_new_map();
      fl_value_set_string_take(m0, "mssStyleIndex", fl_value_new_int(0));
      fl_value_set_string_take(m0, "left", fl_value_new_int(0));
      fl_value_set_string_take(m0, "top", fl_value_new_int(0));
      fl_value_set_string_take(m0, "width", fl_value_new_int(attr.width));
      fl_value_set_string_take(m0, "height", fl_value_new_int(attr.height));
      fl_value_set_string_take(m0, "isPrimary", fl_value_new_bool(FALSE));
      fl_value_append_take(list, g_steal_pointer(&m0));
    }
    return static_cast<FlValue*>(g_steal_pointer(&list));
  }

  MonitorRect virt = VirtualUnion(mons);
  g_autoptr(FlValue) m0 = fl_value_new_map();
  fl_value_set_string_take(m0, "mssStyleIndex", fl_value_new_int(0));
  fl_value_set_string_take(m0, "left", fl_value_new_int(virt.x));
  fl_value_set_string_take(m0, "top", fl_value_new_int(virt.y));
  fl_value_set_string_take(m0, "width", fl_value_new_int(virt.width));
  fl_value_set_string_take(m0, "height", fl_value_new_int(virt.height));
  fl_value_set_string_take(m0, "isPrimary", fl_value_new_bool(FALSE));
  fl_value_append_take(list, g_steal_pointer(&m0));

  int idx = 1;
  for (const auto& mr : mons) {
    g_autoptr(FlValue) em = fl_value_new_map();
    fl_value_set_string_take(em, "mssStyleIndex", fl_value_new_int(idx));
    fl_value_set_string_take(em, "left", fl_value_new_int(mr.x));
    fl_value_set_string_take(em, "top", fl_value_new_int(mr.y));
    fl_value_set_string_take(em, "width", fl_value_new_int(mr.width));
    fl_value_set_string_take(em, "height", fl_value_new_int(mr.height));
    fl_value_set_string_take(em, "isPrimary", fl_value_new_bool(mr.primary ? TRUE : FALSE));
    fl_value_append_take(list, g_steal_pointer(&em));
    idx++;
  }
  return static_cast<FlValue*>(g_steal_pointer(&list));
}

static FlValue* SessionInfoMap() {
  const char* wl = std::getenv("WAYLAND_DISPLAY");
  const char* disp = std::getenv("DISPLAY");
  g_autoptr(FlValue) m = fl_value_new_map();
  fl_value_set_string_take(m, "os", fl_value_new_string("linux"));
  if (wl != nullptr && wl[0] != '\0') {
    fl_value_set_string_take(m, "sessionType", fl_value_new_string("wayland_present"));
    std::string note = "WAYLAND_DISPLAY is set; X11 capture uses DISPLAY (often XWayland). Pure Wayland needs PipeWire portal (not implemented).";
    fl_value_set_string_take(m, "note", fl_value_new_string(note.c_str()));
  } else if (disp != nullptr && disp[0] != '\0') {
    fl_value_set_string_take(m, "sessionType", fl_value_new_string("x11"));
    fl_value_set_string_take(m, "note", fl_value_new_string("X11 via XGetImage + XRandR monitors."));
  } else {
    fl_value_set_string_take(m, "sessionType", fl_value_new_string("unknown"));
    fl_value_set_string_take(m, "note", fl_value_new_string("No DISPLAY; open an X11 session or set DISPLAY."));
  }
  fl_value_set_string_take(m, "captureBackend", fl_value_new_string("x11_xgetimage"));
  return static_cast<FlValue*>(g_steal_pointer(&m));
}

static void MethodCallHandler(FlMethodChannel* /*channel*/, FlMethodCall* call, gpointer /*ud*/) {
  const gchar* name = fl_method_call_get_name(call);

  if (g_strcmp0(name, "sessionInfo") == 0) {
    g_autoptr(FlValue) result = SessionInfoMap();
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(g_steal_pointer(&result)));
    fl_method_call_respond(call, response, nullptr);
    return;
  }

  if (g_strcmp0(name, "requestPermission") == 0) {
    g_autoptr(FlValue) ok = fl_value_new_bool(TRUE);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(g_steal_pointer(&ok)));
    fl_method_call_respond(call, response, nullptr);
    return;
  }

  Display* dpy = XOpenDisplay(nullptr);
  if (dpy == nullptr) {
    if (g_strcmp0(name, "listMonitors") == 0) {
      g_autoptr(FlValue) empty = fl_value_new_list();
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(g_steal_pointer(&empty)));
      fl_method_call_respond(call, response, nullptr);
      return;
    }
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "no_display", "XOpenDisplay failed (missing DISPLAY or X server).", nullptr));
    fl_method_call_respond(call, response, nullptr);
    return;
  }

  const int screen = DefaultScreen(dpy);
  const Window root = RootWindow(dpy, screen);
  auto mons = ListMonitorsXrr(dpy, root);

  if (g_strcmp0(name, "listMonitors") == 0) {
    g_autoptr(FlValue) result = BuildMonitorListValue(dpy, root);
    XCloseDisplay(dpy);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(g_steal_pointer(&result)));
    fl_method_call_respond(call, response, nullptr);
    return;
  }

  if (g_strcmp0(name, "capture") == 0) {
    int monitor_index = 1;
    FlValue* args = fl_method_call_get_args(call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* idxv = fl_value_lookup_string(args, "monitorIndex");
      if (idxv != nullptr && fl_value_get_type(idxv) == FL_VALUE_TYPE_INT) {
        monitor_index = fl_value_get_int(idxv);
      }
    }

    MonitorRect rect{};
    int resolved = monitor_index;
    if (!ResolveCapture(dpy, root, mons, monitor_index, rect, resolved)) {
      XCloseDisplay(dpy);
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "capture_failed", "Could not resolve monitor rectangle.", nullptr));
      fl_method_call_respond(call, response, nullptr);
      return;
    }

    std::vector<uint8_t> rgba;
    int w = 0;
    int h = 0;
    int out_idx = resolved;
    if (!CaptureRect(dpy, root, rect, resolved, rgba, w, h, out_idx)) {
      XCloseDisplay(dpy);
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "capture_failed", "XGetImage failed (size limits, permissions, or compositor).", nullptr));
      fl_method_call_respond(call, response, nullptr);
      return;
    }
    XCloseDisplay(dpy);

    g_autoptr(FlValue) map = fl_value_new_map();
    fl_value_set_string_take(map, "width", fl_value_new_int(w));
    fl_value_set_string_take(map, "height", fl_value_new_int(h));
    fl_value_set_string_take(map, "monitorIndex", fl_value_new_int(out_idx));
    g_autoptr(FlValue) bytes =
        fl_value_new_uint8_list(rgba.data(), rgba.size());
    fl_value_set_string_take(map, "rgba", g_steal_pointer(&bytes));

    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(g_steal_pointer(&map)));
    fl_method_call_respond(call, response, nullptr);
    return;
  }

  XCloseDisplay(dpy);
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(call, response, nullptr);
}

}  // namespace

extern "C" void ambilight_screen_capture_register(FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);
  g_channel = fl_method_channel_new(messenger, "ambilight/screen_capture", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_channel, MethodCallHandler, nullptr, nullptr);
}
