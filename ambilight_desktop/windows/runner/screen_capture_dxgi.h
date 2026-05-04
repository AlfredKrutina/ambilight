#pragma once

#include <Windows.h>

#include <cstdint>
#include <vector>

/// Desktop Duplication (GPU). [src_rect] musí přesně odpovídat [DXGI_OUTPUT_DESC.DesktopCoordinates].
bool AmbilightDxgiCaptureRect(const RECT& src_rect,
                              std::vector<uint8_t>& out_rgba,
                              int& out_w,
                              int& out_h);

void AmbilightDxgiShutdown();
