#pragma once

#include <Windows.h>

#include <cstdint>
#include <vector>

/// Desktop Duplication (GPU). [src_rect] musí přesně odpovídat [DXGI_OUTPUT_DESC.DesktopCoordinates].
/// [out_wait_timeout]: nastaveno na true při [DXGI_ERROR_WAIT_TIMEOUT] ([AcquireNextFrame(0)]).
bool AmbilightDxgiCaptureRect(const RECT& src_rect,
                              std::vector<uint8_t>& out_rgba,
                              int& out_w,
                              int& out_h,
                              bool* out_wait_timeout = nullptr);

void AmbilightDxgiShutdown();
