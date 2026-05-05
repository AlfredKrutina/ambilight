# Rozhodnutí: UDP pacing a jeden transport pro stream

## Kontext (FW lampa)

V `led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c` v `task_udp`:

- Rámce **`0x02`** (bulk RGB) jsou po zpracování **omezeny** minimálním intervalem cca **15 ms** mezi přijatými rámci — rychlejší rámce se **zahodí** (`continue`).
- Po nedávné **sériové** komunikaci FW **ignoruje UDP** po dobu `SERIAL_TIMEOUT_US` (~2,5 s).
- **Jedna řídící IP** pro UDP (lock proti cizím odesílatelům).

## Rozhodnutí (plán B1 + B3)

1. **B1 — Doporučený provoz:** pro živý ambilight používej **jednu fyzickou cestu** (typicky **Wi‑Fi UDP**); USB nech na flash / debug / kalibraci. Neprovozuj současně plný stream na COM i UDP na **stejný** čip bez vědomí dopadů source locku.
2. **B3 — Klient:** `UdpDeviceTransport` **slučuje (coalescuje)** odeslání bulk `0x02` tak, aby mezi skutečnými `send` nebylo méně než **16 ms** (bezpečná rezerva k FW 15 ms). Nejnovější barvy vyhrávají — žádné hromadění zastaralých rámců ve frontě.

Úprava intervalu přímo ve FW (varianta B2) zůstává volitelná pro fork; výchozí repové chování neměníme v tomto kroku.

## Metriky (staging)

Při `AMBI_VERBOSE_LOGS=true` nebo `kDebugMode` logger `UdpTransport` občas vypíše souhrn **coalesced** (sloučených) požadavků — indikuje, že tick běží rychleji než FW stíhá.
