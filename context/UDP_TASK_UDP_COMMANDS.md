# UDP příkazy (`task_udp`, `ambilight.c`)

Port: **4210** (`UDP_PORT`), UTF-8 textové příkazy bez terminatoru; odpovědi textem kde uvedeno.

| Příkaz / formát | Směr | Bajty / řetězec | Poznámka |
|-----------------|-------|-----------------|----------|
| Discovery | PC → ESP | UTF-8 `DISCOVER_ESP32` (14 B) | broadcast nebo unicast |
| PONG | ESP → PC | UTF-8 `ESP32_PONG\|MAC\|Name\|ledCount\|ver` | např. `…\|2.0` — FW v posledním poli |
| Identify | PC → ESP | UTF-8 `IDENTIFY` (8 B) | modrá 1 s, pak obnovení stavu |
| Reset Wi‑Fi | PC → ESP | UTF-8 `RESET_WIFI` (10 B) | červené bliknutí, erase credentials, reboot |
| RGB rámec | PC → ESP | `[0x02, bri_u8, r,g,b,…]` | `bri` + trojice na LED; rate limit ~66 Hz na FW |
| Pixel | PC → ESP | `[0x03, idx_hi, idx_lo, r, g, b]` (6 B) | kalibrace / wizard |

Implementace: `UdpDeviceCommands` + `UdpAmbilightProtocol` v `ambilight_desktop/lib/data/`.
