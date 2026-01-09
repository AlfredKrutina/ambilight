# Alfred LED Controller - ESP32-C6

Inteligentní RGB LED kontroler s Apple HomeKit integrací přes Homebridge a MQTT.

## 🎯 Vlastnosti

✅ **BLE Provisioning** - Bez hardcoded Wi-Fi credentials  
✅ **MQTT komunikace** - Připojení k Raspberry Pi MQTT brokeru  
✅ **HomeKit integrace** - Ovládání přes iPhone/iPad aplikaci Domácnost  
✅ **WS2812B podpora** - Plná kontrola RGB barev a jasu  
✅ **NVS persistence** - Zapamatování stavu po restartu  
✅ **Retain messages** - Synchronizace stavu s Homebridge  

---

## 📋 Požadavky

### Hardware
- **ESP32-C6 DevKit**
- **WS2812B LED pásek** (nebo SK6812)
- **Level Shifter** (SN74HCT125) pro 3.3V → 5V konverzi
- **5V napájecí zdroj** (dimenzovaný podle počtu LED: ~60mA/LED)

### Software
- **ESP-IDF v5.0+** ([instalace](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/))
- **Raspberry Pi** s MQTT brokerem (Mosquitto)
- **Homebridge** s pluginem `homebridge-mqttthing`
- **ESP BLE Provisioning app** ([iOS](https://apps.apple.com/app/esp-ble-prov/id1473590141) / [Android](https://play.google.com/store/apps/details?id=com.espressif.provble))

---

## 🔌 Hardware zapojení

```
ESP32-C6 DevKit
    GPIO8 ──→ Level Shifter IN (3.3V logic)
    GND ────→ Level Shifter GND
    3.3V ───→ Level Shifter VCC

Level Shifter (SN74HCT125)
    OUT ────→ WS2812B Data In (DIN)
    GND ────→ Common GND

5V Power Supply
    +5V ────→ WS2812B VCC
    GND ────→ WS2812B GND + ESP32 GND (SPOLEČNÁ ZEM!)
```

> ⚠️ **Důležité:** Vždy propojte GND z ESP32, level shifteru, napájecího zdroje a LED pásku!

---

## 🛠️ Konfigurace a build

### 1. Klonování projektu
```bash
cd /Users/alfred/Documents/my_local_projects/esp-homekit_respb_try_V1
```

### 2. Nastavení ESP32-C6 cíle
```bash
idf.py set-target esp32c6
```

### 3. Konfigurace (volitelné)
```bash
idf.py menuconfig
```

V menu najdete sekci **"Alfred LED Controller Configuration"** kde můžete změnit:
- GPIO pin pro LED pásek (default: GPIO8)
- Počet LED (default: 60)
- MQTT broker IP (default: 192.168.1.125)
- BLE provisioning jméno (default: Alfred-C6)

### 4. Build
```bash
idf.py build
```

### 5. Flash na ESP32-C6
```bash
idf.py -p /dev/tty.* flash monitor
```

---

## 📱 Nastavení Wi-Fi (BLE Provisioning)

### První spuštění:

1. **ESP32 spustí BLE** - V monitoru uvidíte:
   ```
   Provisioning started
   Starting BLE provisioning with name: Alfred-C6_XXXXXX
   ```

2. **Otevřete "ESP BLE Prov" app** na iPhone/Android

3. **Vyberte "Alfred-C6_XXXXXX"**

4. **Zadejte Proof of Possession:** `abcd1234`

5. **Vyberte Wi-Fi síť** a zadejte heslo

6. **Počkejte na připojení** - ESP se připojí a uloží credentials do NVS

### Příští spuštění:
ESP se automaticky připojí k uložené Wi-Fi síti!

---

## 🏠 Nastavení Raspberry Pi

### 1. Instalace MQTT Brokeru (Mosquitto)
```bash
sudo apt update
sudo apt install mosquitto mosquitto-clients -y
sudo systemctl enable mosquitto
sudo systemctl start mosquitto
```

### 2. Instalace Homebridge
```bash
sudo npm install -g --unsafe-perm homebridge homebridge-config-ui-x
sudo npm install -g homebridge-mqttthing
```

### 3. Konfigurace Homebridge

Přidejte do `~/.homebridge/config.json`:

```json
{
    "bridge": {
        "name": "Homebridge",
        "username": "CC:22:3D:E3:CE:30",
        "port": 51826,
        "pin": "031-45-154"
    },
    "accessories": [
        {
            "accessory": "mqttthing",
            "type": "lightbulb-RGB",
            "name": "Obývák LED",
            "url": "mqtt://localhost:1883",
            "topics": {
                "getOn": "alfred/led/power/state",
                "setOn": "alfred/led/power",
                "getBrightness": "alfred/led/brightness/state",
                "setBrightness": "alfred/led/brightness",
                "getRGB": "alfred/led/color/state",
                "setRGB": "alfred/led/color"
            },
            "onValue": "true",
            "offValue": "false",
            "integerValue": true,
            "hex": false,
            "rgbwCapable": false
        }
    ]
}
```

### 4. Restart Homebridge
```bash
sudo systemctl restart homebridge
```

---

## 🧪 Testování

### Test 1: MQTT komunikace (bez Homebridge)

```bash
# Zapnout LED
mosquitto_pub -h 192.168.1.125 -t alfred/led/power -m "true"

# Nastavit jas na 50%
mosquitto_pub -h 192.168.1.125 -t alfred/led/brightness -m "50"

# Nastavit červenou barvu
mosquitto_pub -h 192.168.1.125 -t alfred/led/color -m "255,0,0"

# Poslouchat stavy
mosquitto_sub -h 192.168.1.125 -t alfred/led/+/state -v
```

### Test 2: Apple Home

1. **Přidejte Homebridge** do aplikace Domácnost (naskenujte QR kód)
2. **Najděte "Obývák LED"** v příslušenstvích
3. **Zkušejte ovládat:**
   - Zapnout/Vypnout
   - Změnit jas
   - Změnit barvu

---

## 📡 MQTT Témata

### Příkazy (Homebridge → ESP32)
| Topic | Payload | Popis |
|-------|---------|-------|
| `alfred/led/power` | `true` / `false` | Zapnout/Vypnout |
| `alfred/led/brightness` | `0` - `100` | Nastavit jas |
| `alfred/led/color` | `R,G,B` | RGB barva (např. `255,128,0`) |

### Stavy (ESP32 → Homebridge)
| Topic | Payload | Popis |
|-------|---------|-------|
| `alfred/led/power/state` | `true` / `false` | Aktuální stav |
| `alfred/led/brightness/state` | `0` - `100` | Aktuální jas |
| `alfred/led/color/state` | `R,G,B` | Aktuální barva |

> 💡 **Retain flag:** Všechny /state zprávy mají retain=1, takže Homebridge získá poslední stav i po restartu.

---

## 🐛 Troubleshooting

### ESP se nepřipojuje k Wi-Fi
- Zkontrolujte SSID a heslo v BLE Prov app
- Zkuste reset credentials: dlouhé stisknutí BOOT tlačítka (pokud implementováno)

### LED se nerozsvěcují
- ✅ Zkontrolujte společnou zem (GND)
- ✅ Ověřte level shifter zapojení
- ✅ Zkontrolujte napájení LED pásku (5V, dostatečný proud)
- ✅ Ověřte GPIO pin v menuconfig

### Homebridge neukazuje změny
- Zkontrolujte MQTT broker: `sudo systemctl status mosquitto`
- Zkontrolujte Homebridge logy: `tail -f ~/.homebridge/homebridge.log`
- Ověřte IP adresu Raspberry Pi

### MQTT zprávy se nepřijímají
- Zkontrolujte IP broker v `config.h` nebo menuconfig
- Ověřte že ESP má IP adresu: `idf.py monitor`
- Test mosquitto: `mosquitto_sub -h 192.168.1.125 -t '#' -v`

---

## 📂 Struktura projektu

```
esp-homekit_respb_try_V1/
├── main/
│   ├── app_main.c              # Hlavní aplikace
│   ├── config.h                # Centrální konfigurace
│   ├── provisioning_manager.c/h # BLE provisioning + Wi-Fi
│   ├── mqtt_handler.c/h        # MQTT klient
│   ├── led_controller.c/h      # LED state management
│   ├── led_strip_driver.c/h    # RMT driver pro WS2812B
│   └── CMakeLists.txt
├── CMakeLists.txt
├── sdkconfig.defaults          # Default konfigurace
└── README.md                   # Tento soubor
```

---

## 🔧 Pokročilé

### Factory Reset
Pro vymazání Wi-Fi credentials volejte:
```c
wifi_reset_credentials();
```

### Změna počtu LED za běhu
Upravte v `menuconfig` nebo přímo v `config.h`:
```c
#define LED_STRIP_NUM_LEDS 120  // Změňte na váš počet
```

### Přidání animací
V `led_strip_driver.c` můžete implementovat vlastní funkce pro animace.

---

## 📚 Reference

- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c6/)
- [WS2812B Datasheet](https://cdn-shop.adafruit.com/datasheets/WS2812B.pdf)
- [Homebridge MQTT-Thing](https://github.com/arachnetech/homebridge-mqttthing)
- [ESP BLE Provisioning](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/provisioning/wifi_provisioning.html)

---

## 📝 Autor

Alfred's Smart Home Project  
ESP32-C6 + Homebridge + Apple HomeKit Integration

## 📄 License

Tento projekt je open-source.
