#pragma once

#include "lwip/sockets.h"

/// Po úspěšné OTA (před [esp_restart]): fialové „nadechnutí“ na pásku + volitelný UDP
/// text `AMBILIGHT OTA_OK <verze>` na adresu odesílatele příkazu `OTA_HTTP`.
/// [notify_udp_or_null] — NULL nebo `sin_port==0` / `sin_addr==0`: jen LED, bez UDP.
void ambilight_ota_success_client_feedback(const struct sockaddr_in *notify_udp_or_null);
