# Smart lights — virtuální místnost (efekty)

| `room_effect` | Chování |
|---------------|---------|
| `none` | Bez modulace; do HA jde `rgb_color` a `brightness_pct` jen z enginu. |
| `wave` | `sin(fáze)`; prostorová část podle `wave_geometry`. |
| `breath` | Globální pulz, nezávislý na poloze žárovky. |
| `chase` | Pořadí podle projekce na osu (`wave_geometry`), fáze posunutá rankem. |
| `sparkle` | Čas + hash `id` + slabá prostorová složka. |

| `wave_geometry` | Prostorová složka (vlna / chase řazení) |
|-----------------|------------------------------------------|
| `radial_from_tv` | Vzdálenost od TV v 0–1 plánku. |
| `along_user_view` | Kolmo na pohled uživatele (user→TV + `user_facing_deg`). |
| `horizontal_room` | `(room_x - tv_x)`. |
| `vertical_room` | `(room_y - tv_y)`. |
| `custom_angle` | Projektce na osu pod `wave_extra_angle_deg`. |

| `brightness_modulation` | RGB | `brightness_pct` do HA |
|---------------------------|-----|---------------------------|
| `both` | × m | × m |
| `rgb_only` | × m | 1 |
| `brightness_only` | beze změny | × m |

HA služba zůstává `light.turn_on` s `rgb_color` a `brightness_pct` ([`HaApiClient`](ambilight_desktop/lib/features/smart_lights/ha_api_client.dart)).

### Hudba (režim Music)

Při `start_mode == music` a zapnuté **detekci beatu** v nastavení hudby (`beat_detection_enabled`) [`SmartLightCoordinator`](ambilight_desktop/lib/features/smart_lights/smart_light_coordinator.dart) předává [`SmartLightsMusicTiming`](ambilight_desktop/lib/features/smart_lights/smart_lights_music_timing.dart) do [`VirtualRoomEffects`](ambilight_desktop/lib/features/smart_lights/virtual_room_effects.dart):

- **Breath / Chase / Wave / Sparkle** — fáze se posouvá podle složeného beatu (náraz + envelope mezi beaty), aby modulace seděla na rytmus.
- **Throttle na HA** — při beat edge nebo vyšším envelope se zkracuje minimální interval mezi požadavky na fixture (rychlejší aktualizace v „živých“ okamžicích).

Režim **None** beat nevyužívá; při vypnuté detekci beatu je chování jako dřív (jen `animationTick`).
