# UDP příkazy (`task_udp`, `ambilight.c`)

Port: **4210** (`UDP_PORT`), UTF-8 textové příkazy bez terminatoru; odpovědi textem kde uvedeno.

Kompatibilita FW ↔ desktop (matice, limity, checklist): [**FW_APP_PROTOCOL_COMPAT.md**](FW_APP_PROTOCOL_COMPAT.md).

| Příkaz / formát | Směr | Bajty / řetězec | Poznámka |
|-----------------|-------|-----------------|----------|
| Discovery | PC → ESP | UTF-8 `DISCOVER_ESP32` (14 B) | broadcast nebo unicast |
| PONG | ESP → PC | UTF-8 `ESP32_PONG\|MAC\|Name\|ledCount\|ver` | **lamp FW:** `ledCount` = logická délka `g_serial_strip_max` (USB `0xA5 0x5A`), ne jen compile-time max |
| Identify | PC → ESP | UTF-8 `IDENTIFY` (8 B) | modrá 1 s, pak obnovení stavu |
| Reset Wi‑Fi | PC → ESP | UTF-8 `RESET_WIFI` (10 B) | červené bliknutí, erase credentials, reboot |
| OTA z URL | PC → ESP | UTF-8 `OTA_HTTP ` + URL | Desktop: URL 12…1300 znaků; jeden datagram ≤ `UdpDeviceCommands.maxSafeUtf8PayloadBytes` (1400 B UTF‑8). HTTPS OTA (`ota_update.c`), reboot; dvě `ota_*` partition |
| RGB rámec | PC → ESP | `[0x02, bri_u8, r,g,b,…]` | Po `(udp_len - 2)` musí jít o násobek 3; **lamp FW** jinak rámec zahodí. Rate limit ~15–16 ms mezi rámců |
| RGB chunky | PC → ESP | `[0x06, idx_hi, idx_lo, r,g,b,…]` | jen zápis do bufferu LED; `(len-3)` násobek 3; max ~498 LED / datagram (`ambilight_desktop`) |
| RGB flush | PC → ESP | `[0x08, bri, total_hi, total_lo]` (4 B) | po sérii `0x06`: `clear_tail` + `update_leds`; sdílený ~15 ms limit s `0x02` |
| Pixel | PC → ESP | `[0x03, idx_hi, idx_lo, r, g, b]` (6 B) | kalibrace / wizard; index &lt; `g_serial_strip_max` na lampě |

Implementace: [`UdpDeviceCommands`](../ambilight_desktop/lib/data/udp_device_commands.dart), [`UdpAmbilightProtocol`](../ambilight_desktop/lib/core/protocol/udp_frame.dart), discovery [`LedDiscoveryService`](../ambilight_desktop/lib/services/led_discovery_service.dart) (`parseEsp32PongDatagram`).
