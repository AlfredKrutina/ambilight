#pragma once

#include <stdbool.h>

/// Spustí HTTPS OTA z URL na pozadí (FreeRTOS task). Při úspěchu zařízení restartuje.
/// [url] musí být https:// nebo http://, délka rozumná pro UDP / MQTT payload.
///
/// Spouštění z aplikace:
/// - UDP text na port 4210: `OTA_HTTP https://…/ambilight_esp32c6.bin`
/// - MQTT (subscribe už má `alfred/devices/<id>/#`): topic …/ota, payload = stejná URL (UTF-8).
void ambilight_start_ota(const char *url);

bool ambilight_ota_in_progress(void);
