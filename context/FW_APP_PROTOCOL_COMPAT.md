# Kompatibilita ESP32 lamp FW ↔ ambilight_desktop

**Firmware:** [`led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c`](../led_strip_monitor_pokus%20-%20Copy/esp32c3_lamp_firmware/main/ambilight.c)  
**Aplikace:** [`ambilight_desktop/lib/core/protocol/`](../ambilight_desktop/lib/core/protocol/), [`udp_device_transport.dart`](../ambilight_desktop/lib/data/udp_device_transport.dart)

## Matice protokolu

| Kanál | Formát | Aplikace | FW |
|-------|--------|----------|-----|
| UDP bulk | `0x02`, `bri`, N×(R,G,B); max N=499 / datagram | `UdpAmbilightProtocol.buildRgbFrame` | `task_udp`, ověření `(len-2)%3==0`, zápis omezen na `g_serial_strip_max`; vždy zapisuje od LED **0** + `clear_tail` |
| UDP chunky | `0x06`, idx_hi, idx_lo, N×(R,G,B); max N=498 | `buildRgbChunkOpcode06` | jen zápis do `led_colors`, **bez** refresh (levné); lock stejně jako `0x02` |
| UDP flush | `0x08`, `bri`, total_hi, total_lo (4 B) | `buildFlushOpcode08` | `clear_tail_leds(total)` + `update_leds(bri)`; sdílený ~15 ms throttle s `0x02` |
| UDP pixel | `0x03`, idx_hi, idx_lo, R,G,B (BE index) | `buildSinglePixel` (kalibrace / wizard) | FW volá `update_leds(255)` na celý pásek |
| UDP discover | UTF-8 `DISCOVER_ESP32` | `LedDiscoveryService`, port 4210 | odpověď `ESP32_PONG|mac|name|ledCount|FW_VER|2.1|temporal` (legacy 5–6 polí bez `FW_VER`); **ledCount = `g_serial_strip_max`** |
| UDP identify | `IDENTIFY` | `UdpDeviceCommands` | modrá 1 s |
| UDP reset | `RESET_WIFI` | `UdpDeviceCommands` | NVS erase + reboot |
| UDP OTA | `OTA_HTTP <url>` | `UdpDeviceCommands` / `sendOtaHttpUrlAwaitOtaOk` (stejné kontroly znaků jako FW + bez NUL v UTF‑8) | `ambilight_start_ota(url, notify_addr?)`; FW také vyžaduje `strlen(payload)==len` datagramu; po úspěchu volitelně `AMBILIGHT OTA_OK <ver>` zpět na klienta |
| Serial | `0xAA→0xBB`, `0xA5 0x5A` + u16 LE, `0xFF…0xFE`, `0xFC…0xFE` | `serial_frame.dart` | `task_serial` |

## Omezení a chování

1. **UDP pacing:** FW zahazuje `0x02` častěji než ~15 ms; aplikace drží ~16 ms mezi bulk (`UdpDeviceTransport`).
2. **Tail >499 LED:** Desktop posílá série **`0x06`** (chunky podle indexu) a na konec jeden **`0x08`** (flush + `clear_tail`). Starší záplava samostatných `0x03` přetěžovala ESP (každý paket = celý refresh pásku).
3. **Serial lock:** Pokud byl nedávno USB traffic (`SERIAL_TIMEOUT_US`), UDP `0x02`/`0x03` se ignorují — očekávané.
4. **Logická délka:** `g_serial_strip_max` nastaví USB `0xA5 0x5A`; bez toho je výchozí `LED_STRIP_NUM_LEDS`. Discovery hlásí tuto logickou délku.
5. **OTA:** Po dobu `ambilight_ota_in_progress()` lampa zahazuje UDP ambilight `0x02`/`0x03`, neposílá na pásek sériové snímky ani MQTT „immediate“ obnovu LED; Home restore po UDP timeoutu se přeskočí — menší kolize se zápisem flash / Wi‑Fi stackem.
6. **Home / IDENTIFY:** Jednobarevné stavy (MQTT Home, UDP návrat z PC režimu, IDENTIFY) svítí jen po **logický** počet LED; zbytek fyzického řetězce se zhasne. `RESET_WIFI` stále bliká přes celý compile-time buffer (vizuální feedback).
7. **UDP socket:** `SO_REUSEADDR` snižuje riziko „address in use“ po rychlém restartu. Text `OTA_HTTP` musí být jeden spojitý UTF‑8 řetězec bez vloženého NUL (`strlen` == délka datagramu).
8. **DNS captive:** Parsování QNAME kontroluje délky labelů proti `len` — při poškozeném dotazu se neposílá odpověď.

## Ruční checklist (hardware)

- [ ] Broadcast discovery: odpověď `ESP32_PONG`, ledCount odpovídá nastavení po announce z USB.
- [ ] UDP ambilight: 120+ FPS tick na PC → pásek stabilní (FW drop kvůli 15 ms je OK).
- [ ] Konfigurace 512 LED: dva bulk + tail `0x03`, barvy souhlasí.
- [ ] Serial: ping `0xAA`, announce délky, wide frame &gt;256 LED.
- [ ] `IDENTIFY` / `RESET_WIFI` z aplikace (Dialog zařízení).

## Konstanty v aplikaci (Dart)

| Konstanta | Hodnota | Soubor |
|-----------|---------|--------|
| `UdpAmbilightProtocol.maxRgbPixelsPerUdpDatagram` | 499 | `udp_frame.dart` |
| `SerialAmbilightProtocol.maxLedsPerDevice` | 2000 | `serial_frame.dart` |
| `SerialAmbilightProtocol.legacyFrameMaxLeds` | 256 | `serial_frame.dart` |
| `UdpDeviceCommands.maxSafeUtf8PayloadBytes` | 1400 | `udp_device_commands.dart` |
| `sendOtaHttpUrl` délka URL | 12…1300 znaků | `udp_device_commands.dart` |

## Archive FW vs lamp FW

| Oblast | Archive (`esp32c3_monitor_firmware_ARCHIVE`) | Lamp (`esp32c3_lamp_firmware`) |
|--------|----------------------------------------------|--------------------------------|
| Serial | Legacy `0xFF` + index 8b; bez `0xFC` wide / bez `0xA5 0x5A` announce jako v desktop | Wide `0xFC`, announce `0xA5 0x5A`, shoda s `serial_frame.dart` |
| `LED_STRIP_NUM_LEDS` | typicky 200 (compile-time buffer) | vyšší limit + logická délka `g_serial_strip_max` |
| UDP `0x02` | bez `(len-2)%3` kontroly; clamp na buffer dle FW | validace `(len-2)%3==0`, zápis omezen `g_serial_strip_max` |
| UDP `0x03` | index &lt; buffer | navíc `idx < g_serial_strip_max` |
| PONG `ledCount` | dříve fyzický `LED_STRIP_NUM_LEDS` | **`g_serial_strip_max`** (USB announce) |

Porovnání kódu lokálně: `diff -ru esp32c3_monitor_firmware_ARCHIVE esp32c3_lamp_firmware` (zejm. `main/ambilight.c`).

## Nástroj: hex vzorky

Z kořene `ambilight_desktop`:  
`dart run tool/fw_protocol_hex_samples.dart` — vytiskne UTF-8 příkazy a binární rámcové hlavičky pro ruční kontrolu (Wireshark atd.).

## Automatické testy

- [`fw_udp_contract_test.dart`](../ambilight_desktop/test/fw_udp_contract_test.dart) — golden bajty UDP `0x02` / `0x03`.
- [`udp_frame_test.dart`](../ambilight_desktop/test/udp_frame_test.dart), [`serial_frame_test.dart`](../ambilight_desktop/test/serial_frame_test.dart).
- [`led_discovery_pong_test.dart`](../ambilight_desktop/test/led_discovery_pong_test.dart) — parsování `ESP32_PONG`.
- [`udp_device_commands_contract_test.dart`](../ambilight_desktop/test/udp_device_commands_contract_test.dart) — délky UTF-8 příkazů a limity OTA URL.

Související přehled příkazů: [`UDP_TASK_UDP_COMMANDS.md`](UDP_TASK_UDP_COMMANDS.md).
