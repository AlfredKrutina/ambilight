# FW temporal smoothing (`0xF1`) — sync s desktopem

- **NVS** `storage` / klíč `fw_temporal` (`fw_temp` v kódu): `u8` hodnota 0…2; po bootu `ambilight_fw_temporal_load()` + sync `s_smooth_rgb` z `led_colors`.
- **UDP** (port 4210): paket přesně 2 bajty `[0xF1, mode]` → zápis NVS, sync smooth, **ACK** stejné 2 bajty (jako `UdpDeviceCommands.sendTemporalModeWithAck`).
- **USB serial**: ve `ST_IDLE` sekvence `F1` + druhý bajt (mode 0…2); ACK 2 bajty; při `0xFF`/`0xFC` se zruší čekání na druhý bajt (nekoliduje s wide/legacy).
- **`update_leds`**: režim **1** = exponenciální dojetí k `led_colors` v `s_smooth_rgb`; **0** a **2** = okamžitá kopie cíle (snap = stejné jako vypnuto, kompatibilní s PyQt významem „snap“ jako tvrdý náběh).
- **PONG**: osmé pole zůstává `rej88`; šesté pole (`temporal` v parseru aplikace) = skutečný `g_fw_temporal_mode`.
- **IDENTIFY**: po modré prodlevě před `update_leds(255)` sync smooth z `led_colors`, aby obnova nebyla „zašlá“ při zapnuté plynulosti.

Soubor: `led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c`.

## PC aplikace vs. log `AKCEPTACE op=0x02`

- **`0x02`** (RGB rámce): FW je jen zpracuje a loguje „AKCEPTACE“ — **žádný UDP ACK zpět na PC** (stream není potvrzovací).
- **`0xF1`** (plynulost): FW musí odpovědět **2 bajty** `[0xF1, mode]` na zdrojovou adresu odesílatele; desktop na to čeká (`sendTemporalModeWithAck`).
- Na **Windows** může selhat `InternetAddress ==` pro stejnou IPv4; v `udp_device_commands.dart` se odesílatel ACK ověřuje přes **`rawAddress`** (`_udpSourceMatchesTarget`).
