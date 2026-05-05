#pragma once

#include <stdbool.h>

#include "lwip/sockets.h"

/// Spustí HTTPS OTA z URL na pozadí (FreeRTOS task). Při úspěchu krátká LED zpětná vazba,
/// volitelně UDP `AMBILIGHT OTA_OK <verze>` na odesílatele, pak [esp_restart].
/// [url] musí být https:// nebo http://, délka až ~1300 znaků (shoda s desktopovým klientem).
///
/// [notify_udp_reply_target_or_null] — z [recvfrom] u příkazu `OTA_HTTP` (stejná IP:port jako
/// PC klient); u MQTT OTA předej NULL (UDP potvrzení se neposílá).
///
/// Spouštění z aplikace:
/// - UDP text na port 4210: `OTA_HTTP https://…/ambilight_esp32c6.bin`
/// - MQTT (subscribe už má `alfred/devices/<id>/#`): topic …/ota, payload = stejná URL (UTF-8).
void ambilight_start_ota(const char *url, const struct sockaddr_in *notify_udp_reply_target_or_null);

bool ambilight_ota_in_progress(void);
