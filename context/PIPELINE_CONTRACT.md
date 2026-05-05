# Kontrakt pipeline (screen → ESP)

## Kdo volá `_distribute` / `_distributeSync`

| Zdroj | Kdy | `flushImmediately` |
|--------|-----|---------------------|
| `_tick` | Periodický timer; strip + smart lights | `true` u keepalive / wizard / kalibrace / error strip; u screen izolátu dle větve |
| `_eagerDistributeScreenIfDue` | Po `ScreenPipelineIsolateResult` (`out`) | vždy `true` |
| Vypnutí app / černý výstup | `_tick` větev `!_enabled` | `true` |
| `dispose` | flush `_distributePending` | přes `_distributeSync` |

## Screen izolát + `_lastDistributedScreenSeq`

- Po úspěšném odeslání z **eager** nebo z **tick** (plný strip, ne noop) se pro `useScreenIsolate` nastaví `_lastDistributedScreenSeq = _screenPipelineAppliedSeq`.
- **Noop tick**: `_screenPipelineAppliedSeq == _lastDistributedScreenSeq`, žádný UDP keepalive a **není** aktivní tick error strip → jen `_invokeSmartLightsOnFrame` (error strip musí stále poslat `_distribute`).

## Diagnostika

- `udp_emit_skip` / `sinceCaptureMs`: čas od posledního DXGI `capture_frame` (EventChannel). Při dedupe a **dlouhé** prodlevě DXGI / main threadu může růst i když UDP jen přeskakuje stejný hash — porovnej `sinceSubmitMs` (poslední submit do screen izolátu) a příznak `longGapSinceCapture=1`. Souhrn `capToIsolateAvgMs` je průměr **ms** (ne „tisíce ms“).
- `AMBI_PIPELINE_DIAGNOSTICS=true` — podrobné fáze + souhrn včetně `PipelineSchedulerDiagStats` (v běžném `flutter run` **vypnuto**; řádky jsou throttlované ~5/s). Bez define žádný `PIPELINE_DIAG` / izolát stdout z této sady.
- `AMBI_SCREEN_EAGER_DISTRIBUTE=false` — vypne eager flush (chování blíž starému „až na tick“).

## UDP

- Dedupe stejného RGB rámce v `UdpDeviceTransport._emitFramePacedRgb` (okno `_kUdpDedupeMaxSkipAgeMs`).
- **Packed fast path (Wi‑Fi screen izolát):** pokud `perDevice` je přesně poslední `_asyncScreenColors` (stejná reference jako výstup izolátu — žádný error strip / music freeze / klon), `_distributeSync` pošle na `UdpDeviceTransport` [`sendPackedRgbBytes`](../ambilight_desktop/lib/data/udp_device_transport.dart) z mapy `_asyncScreenPacked` (už `[r,g,b,…]` z workeru). Pro ostatní transporty / stavy zůstává tuple list → `sendColors`. FW protokol je stejný (`0x02` / `0x06`+`0x08`), jen aplikace nemusí znovu skládat bytes z listu tuple.
- **Eager po `ScreenPipelineIsolateResult`:** nejdřív `_flushUdpWifiStripsFromPackedMap` (UDP z raw packed **před** synchronním `unpackDeviceColors` na hlavním vlákně), pak rozbalení pro serial / smart lights a `_distributeSync` s `skipUdpWifiAmbilight` jen u zařízení, která už měla neprázdný packed (žádný duplicitní packet).
- `sendColorsNow` / `_waitRgbTransportIdle` — limit čekání, viz [udp_device_transport.dart](../ambilight_desktop/lib/data/udp_device_transport.dart).
