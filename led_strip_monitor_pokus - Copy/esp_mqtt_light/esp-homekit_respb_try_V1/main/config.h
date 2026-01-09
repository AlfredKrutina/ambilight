/*
 * Alfred LED Controller - Configuration Header
 * Centralized configuration for MQTT topics, hardware pins, and defaults
 */

#ifndef CONFIG_H
#define CONFIG_H

#include "hal/gpio_types.h"

// MQTT Broker Configuration
#define MQTT_BROKER_URI "mqtt://192.168.1.125"
#define MQTT_BROKER_PORT 1883

// MQTT Topics - Commands (Homebridge -> ESP32)
#define MQTT_TOPIC_POWER "alfred/led/power"
#define MQTT_TOPIC_BRIGHTNESS "alfred/led/brightness"
#define MQTT_TOPIC_COLOR "alfred/led/color"

// MQTT Topics - States (ESP32 -> Homebridge)
#define MQTT_TOPIC_POWER_STATE "alfred/led/power/state"
#define MQTT_TOPIC_BRIGHTNESS_STATE "alfred/led/brightness/state"
#define MQTT_TOPIC_COLOR_STATE "alfred/led/color/state"

// BLE Provisioning Configuration
#define PROV_DEVICE_NAME "Alfred-C6"
#define PROV_POP_PASSWORD "abcd1234" // Proof of Possession password
#define PROV_SECURITY_VERSION WIFI_PROV_SECURITY_1
#define PROV_SCHEME wifi_prov_scheme_ble

// LED Hardware Configuration
#ifndef CONFIG_LED_STRIP_GPIO
#define LED_STRIP_GPIO GPIO_NUM_8
#else
#define LED_STRIP_GPIO CONFIG_LED_STRIP_GPIO
#endif

#ifndef CONFIG_LED_STRIP_NUM_LEDS
#define LED_STRIP_NUM_LEDS 1 // Onboard WS2812 LED on ESP32-C6 DevKit
#else
#define LED_STRIP_NUM_LEDS CONFIG_LED_STRIP_NUM_LEDS
#endif

// Default LED State
#define LED_DEFAULT_POWER false
#define LED_DEFAULT_BRIGHTNESS 100
#define LED_DEFAULT_R 255
#define LED_DEFAULT_G 255
#define LED_DEFAULT_B 255

// NVS Storage Keys
#define NVS_NAMESPACE "alfred_led"
#define NVS_KEY_POWER "power"
#define NVS_KEY_BRIGHTNESS "brightness"
#define NVS_KEY_COLOR_R "color_r"
#define NVS_KEY_COLOR_G "color_g"
#define NVS_KEY_COLOR_B "color_b"

// System Configuration
#define APP_LOG_TAG "ALFRED_LED"
#define MQTT_RECONNECT_TIMEOUT 5000  // ms
#define WIFI_RECONNECT_TIMEOUT 10000 // ms

#endif // CONFIG_H
