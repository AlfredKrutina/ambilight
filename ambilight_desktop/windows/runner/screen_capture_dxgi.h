#pragma once

#include <Windows.h>

#include <cstdint>
#include <vector>

/// Desktop Duplication (GPU).
/// [output_desktop_rect] musí přesně odpovídat [DXGI_OUTPUT_DESC.DesktopCoordinates] daného výstupu.
/// [capture_desktop_rect] je výřez ve stejných souřadnicích (podmnožina výstupu).
/// [acquire_timeout_ms] — 0 = neblokovat; 16+ = čekání na nový frame od kompositoru (push režim).
/// [out_wait_timeout]: true při [DXGI_ERROR_WAIT_TIMEOUT].
bool AmbilightDxgiCaptureRect(const RECT& output_desktop_rect,
                              const RECT& capture_desktop_rect,
                              std::vector<uint8_t>& out_rgba,
                              int& out_w,
                              int& out_h,
                              bool* out_wait_timeout = nullptr,
                              UINT acquire_timeout_ms = 0);

void AmbilightDxgiShutdown();
