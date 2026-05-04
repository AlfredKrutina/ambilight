# Home Assistant a AmbiLight na stejném ESP

Firmware lampy nemá oddělené „kanály“ pro více ovladačů současně. **Home Assistant** (MQTT / REST / nativní integrace podle tvého FW) a **AmbiLight desktop** oba posílají barvy do stejného řetězce LED.

## Doporučené pravidlo

- Při **živém streamu** z PC (screen / music) **nepouštěj** HA automatizace, které na stejné světlo volají změnu barvy / efektu (`light.turn_on`, scény, `rgb_color`, …).
- Nebo v HA použij **podmínku** (input_boolean „ambilight_active“), kterou PC ručně / přes MQTT přepíná — mimo rozsah této aplikace, ale typický vzor.

## `control_via_ha` v JSON

Zařízení s `control_via_ha: true` říká desktop klientovi, aby **neodesílal** RGB na serial/UDP (pouze HA). Tím se vyhneš přímému souboji **v aplikaci** — stále ale pozor na jiné skripty mimo AmbiLight.

## Diagnostika

- Pokud je stream z PC plynulý jen po **vypnutí** HA scén → konflikt ovládání, ne špatný protokol.
