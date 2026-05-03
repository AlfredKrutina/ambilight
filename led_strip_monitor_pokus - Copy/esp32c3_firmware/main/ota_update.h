#pragma once

#include <stdbool.h>

/// Spustí HTTPS OTA z URL na pozadí (FreeRTOS task). Při úspěchu zařízení restartuje.
/// [url] musí být https:// nebo http://, délka rozumná pro UDP payload.
void ambilight_start_ota(const char *url);

bool ambilight_ota_in_progress(void);
