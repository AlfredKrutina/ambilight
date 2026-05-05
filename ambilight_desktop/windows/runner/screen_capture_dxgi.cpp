#include "screen_capture_dxgi.h"

#include <d3d11.h>
#include <dxgi1_2.h>

#include <algorithm>
#include <cstdint>
#include <mutex>
#include <vector>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

namespace {

std::mutex g_mu;
ID3D11Device* g_dev = nullptr;
ID3D11DeviceContext* g_ctx = nullptr;
IDXGIOutputDuplication* g_dup = nullptr;
RECT g_dup_bounds{};

void ReleaseDupLocked() {
  if (g_dup) {
    g_dup->Release();
    g_dup = nullptr;
  }
  if (g_ctx) {
    g_ctx->Release();
    g_ctx = nullptr;
  }
  if (g_dev) {
    g_dev->Release();
    g_dev = nullptr;
  }
  g_dup_bounds = {};
}

bool SameRect(const RECT& a, const RECT& b) {
  return a.left == b.left && a.top == b.top && a.right == b.right && a.bottom == b.bottom;
}

bool BuildDuplicationForRect(const RECT& target) {
  ReleaseDupLocked();

  IDXGIFactory1* factory = nullptr;
  if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                reinterpret_cast<void**>(&factory))) ||
      !factory) {
    return false;
  }

  IDXGIAdapter1* adapter = nullptr;
  IDXGIOutput* output = nullptr;
  bool picked = false;

  for (UINT ai = 0; factory->EnumAdapters1(ai, &adapter) != DXGI_ERROR_NOT_FOUND; ++ai) {
    for (UINT oi = 0; adapter->EnumOutputs(oi, &output) != DXGI_ERROR_NOT_FOUND; ++oi) {
      DXGI_OUTPUT_DESC desc{};
      output->GetDesc(&desc);
      if (SameRect(desc.DesktopCoordinates, target)) {
        picked = true;
        break;
      }
      output->Release();
      output = nullptr;
    }
    if (picked) {
      break;
    }
    adapter->Release();
    adapter = nullptr;
  }
  factory->Release();

  if (!picked || !adapter || !output) {
    if (output) {
      output->Release();
    }
    if (adapter) {
      adapter->Release();
    }
    return false;
  }

  IDXGIOutput1* out1 = nullptr;
  HRESULT hr = output->QueryInterface(__uuidof(IDXGIOutput1), reinterpret_cast<void**>(&out1));
  output->Release();
  output = nullptr;
  if (FAILED(hr) || !out1) {
    adapter->Release();
    return false;
  }

  D3D_FEATURE_LEVEL fl{};
  hr = D3D11CreateDevice(adapter, D3D_DRIVER_TYPE_UNKNOWN, nullptr, 0, nullptr, 0,
                         D3D11_SDK_VERSION, &g_dev, &fl, &g_ctx);
  adapter->Release();
  adapter = nullptr;

  if (FAILED(hr) || !g_dev || !g_ctx) {
    ReleaseDupLocked();
    out1->Release();
    return false;
  }

  hr = out1->DuplicateOutput(g_dev, &g_dup);
  DXGI_OUTPUT_DESC desc{};
  out1->GetDesc(&desc);
  out1->Release();

  if (FAILED(hr) || !g_dup) {
    ReleaseDupLocked();
    return false;
  }

  g_dup_bounds = desc.DesktopCoordinates;
  return true;
}

}  // namespace

bool AmbilightDxgiCaptureRect(const RECT& src_rect,
                              std::vector<uint8_t>& out_rgba,
                              int& out_w,
                              int& out_h,
                              bool* out_wait_timeout) {
  if (out_wait_timeout) {
    *out_wait_timeout = false;
  }
  const int cw = src_rect.right - src_rect.left;
  const int ch = src_rect.bottom - src_rect.top;
  if (cw <= 0 || ch <= 0) {
    return false;
  }

  std::lock_guard<std::mutex> lock(g_mu);

  if (!g_dup || !SameRect(g_dup_bounds, src_rect)) {
    if (!BuildDuplicationForRect(src_rect)) {
      return false;
    }
  }

  IDXGIResource* desktop_resource = nullptr;
  DXGI_OUTDUPL_FRAME_INFO fi{};
  // 0 ms — neblokuje na kompozitor; při WAIT_TIMEOUT vracíme false (Dart ponechá poslední snímek).
  HRESULT hr = g_dup->AcquireNextFrame(0, &fi, &desktop_resource);
  if (hr == DXGI_ERROR_WAIT_TIMEOUT) {
    if (out_wait_timeout) {
      *out_wait_timeout = true;
    }
    return false;
  }
  if (FAILED(hr) || !desktop_resource) {
    if (hr == DXGI_ERROR_ACCESS_LOST || hr == DXGI_ERROR_ACCESS_DENIED ||
        hr == DXGI_ERROR_DEVICE_REMOVED) {
      ReleaseDupLocked();
    }
    return false;
  }

  ID3D11Texture2D* acquired = nullptr;
  hr = desktop_resource->QueryInterface(__uuidof(ID3D11Texture2D),
                                         reinterpret_cast<void**>(&acquired));
  desktop_resource->Release();
  if (FAILED(hr) || !acquired) {
    g_dup->ReleaseFrame();
    return false;
  }

  D3D11_TEXTURE2D_DESC td{};
  acquired->GetDesc(&td);
  if (td.Format != DXGI_FORMAT_B8G8R8A8_UNORM) {
    acquired->Release();
    g_dup->ReleaseFrame();
    ReleaseDupLocked();
    return false;
  }

  const UINT off_x = static_cast<UINT>(src_rect.left - g_dup_bounds.left);
  const UINT off_y = static_cast<UINT>(src_rect.top - g_dup_bounds.top);
  if (off_x + static_cast<UINT>(cw) > td.Width || off_y + static_cast<UINT>(ch) > td.Height) {
    acquired->Release();
    g_dup->ReleaseFrame();
    ReleaseDupLocked();
    return false;
  }

  D3D11_TEXTURE2D_DESC st{};
  st.Width = static_cast<UINT>(cw);
  st.Height = static_cast<UINT>(ch);
  st.MipLevels = 1;
  st.ArraySize = 1;
  st.Format = td.Format;
  st.SampleDesc.Count = 1;
  st.Usage = D3D11_USAGE_STAGING;
  st.CPUAccessFlags = D3D11_CPU_ACCESS_READ;

  ID3D11Texture2D* staging = nullptr;
  hr = g_dev->CreateTexture2D(&st, nullptr, &staging);
  if (FAILED(hr) || !staging) {
    acquired->Release();
    g_dup->ReleaseFrame();
    return false;
  }

  D3D11_BOX box{};
  box.left = off_x;
  box.top = off_y;
  box.front = 0;
  box.right = off_x + static_cast<UINT>(cw);
  box.bottom = off_y + static_cast<UINT>(ch);
  box.back = 1;

  g_ctx->CopySubresourceRegion(staging, 0, 0, 0, 0, acquired, 0, &box);
  acquired->Release();

  D3D11_MAPPED_SUBRESOURCE map{};
  hr = g_ctx->Map(staging, 0, D3D11_MAP_READ, 0, &map);
  if (FAILED(hr)) {
    staging->Release();
    g_dup->ReleaseFrame();
    return false;
  }

  const size_t npix = static_cast<size_t>(cw) * static_cast<size_t>(ch);
  out_rgba.resize(npix * 4u);
  auto* src_row = reinterpret_cast<const uint8_t*>(map.pData);
  for (int y = 0; y < ch; ++y) {
    const auto* row = src_row + static_cast<size_t>(y) * map.RowPitch;
    for (int x = 0; x < cw; ++x) {
      const size_t di = (static_cast<size_t>(y) * static_cast<size_t>(cw) + static_cast<size_t>(x)) * 4u;
      const uint8_t b = row[x * 4];
      const uint8_t g = row[x * 4 + 1];
      const uint8_t r = row[x * 4 + 2];
      (void)row[x * 4 + 3];
      out_rgba[di] = r;
      out_rgba[di + 1] = g;
      out_rgba[di + 2] = b;
      out_rgba[di + 3] = 255;
    }
  }

  g_ctx->Unmap(staging, 0);
  staging->Release();
  g_dup->ReleaseFrame();

  out_w = cw;
  out_h = ch;
  return true;
}

void AmbilightDxgiShutdown() {
  std::lock_guard<std::mutex> lock(g_mu);
  ReleaseDupLocked();
}
