/*
 * Alfred LED Controller - Main Application
 * Smart HomeKit-enabled LED controller with BLE provisioning
 */

#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include <stdio.h>

#include "config.h"
#include "led_controller.h"
#include "mqtt_handler.h"
#include "provisioning_manager.h"

static const char *TAG = APP_LOG_TAG;

// MQTT command callback handlers
static void handle_power_command(bool power) {
  ESP_LOGI(TAG, "Handling power command: %s", power ? "ON" : "OFF");

  esp_err_t ret = led_set_power(power);
  if (ret == ESP_OK) {
    mqtt_publish_power_state(power);
  } else {
    ESP_LOGE(TAG, "Failed to set power: %s", esp_err_to_name(ret));
  }
}

static void handle_brightness_command(uint8_t brightness) {
  ESP_LOGI(TAG, "Handling brightness command: %d%%", brightness);

  esp_err_t ret = led_set_brightness(brightness);
  if (ret == ESP_OK) {
    mqtt_publish_brightness_state(brightness);
  } else {
    ESP_LOGE(TAG, "Failed to set brightness: %s", esp_err_to_name(ret));
  }
}

static void handle_color_command(uint8_t r, uint8_t g, uint8_t b) {
  ESP_LOGI(TAG, "Handling color command: RGB(%d,%d,%d)", r, g, b);

  esp_err_t ret = led_set_color(r, g, b);
  if (ret == ESP_OK) {
    mqtt_publish_color_state(r, g, b);
  } else {
    ESP_LOGE(TAG, "Failed to set color: %s", esp_err_to_name(ret));
  }
}

// Called when Wi-Fi successfully connects and gets IP
static void on_wifi_connected(void) {
  ESP_LOGI(TAG, "Wi-Fi connected! Starting MQTT client...");

  esp_err_t ret = mqtt_start();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to start MQTT: %s", esp_err_to_name(ret));
    return;
  }

  // Give MQTT time to connect, then publish initial state
  vTaskDelay(pdMS_TO_TICKS(2000));

  led_state_t state;
  led_get_state(&state);

  ESP_LOGI(TAG, "Publishing initial state to Homebridge...");
  mqtt_publish_power_state(state.power);
  mqtt_publish_brightness_state(state.brightness);
  mqtt_publish_color_state(state.r, state.g, state.b);
}

void app_main(void) {
  ESP_LOGI(TAG, "============================================");
  ESP_LOGI(TAG, "  Alfred LED Controller - ESP32-C6");
  ESP_LOGI(TAG, "  HomeKit Integration via MQTT");
  ESP_LOGI(TAG, "============================================");
  ESP_LOGI(TAG, "[APP] Startup...");
  ESP_LOGI(TAG, "[APP] Free memory: %lu bytes", esp_get_free_heap_size());
  ESP_LOGI(TAG, "[APP] IDF version: %s", esp_get_idf_version());

  // Step 1: Initialize NVS (required for Wi-Fi and state storage)
  ESP_LOGI(TAG, "Initializing NVS...");
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
      ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_LOGW(TAG, "NVS partition was truncated, erasing...");
    ESP_ERROR_CHECK(nvs_flash_erase());
    ret = nvs_flash_init();
  }
  ESP_ERROR_CHECK(ret);
  ESP_LOGI(TAG, "NVS initialized");

  // Step 2: Initialize LED controller (hardware + state management)
  ESP_LOGI(TAG, "Initializing LED controller...");
  ret = led_controller_init();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to initialize LED controller: %s",
             esp_err_to_name(ret));
    ESP_LOGE(TAG, "Cannot continue without LED hardware");
    return;
  }
  ESP_LOGI(TAG, "LED controller ready");

  // Step 3: Initialize MQTT client (but don't start yet)
  ESP_LOGI(TAG, "Initializing MQTT client...");
  ret = mqtt_init(MQTT_BROKER_URI);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to initialize MQTT: %s", esp_err_to_name(ret));
    return;
  }

  // Register MQTT command callbacks
  mqtt_set_power_callback(handle_power_command);
  mqtt_set_brightness_callback(handle_brightness_command);
  mqtt_set_color_callback(handle_color_command);
  ESP_LOGI(TAG, "MQTT callbacks registered");

  // Step 4: Set Wi-Fi connected callback
  set_wifi_connected_callback(on_wifi_connected);

  // Step 5: Start provisioning/Wi-Fi connection
  ESP_LOGI(TAG, "Starting provisioning manager...");
  ret = provisioning_init();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to initialize provisioning: %s",
             esp_err_to_name(ret));
    return;
  }

  ESP_LOGI(TAG, "============================================");
  ESP_LOGI(TAG, "  Initialization complete!");
  ESP_LOGI(TAG, "  - LED strip initialized on GPIO%d", LED_STRIP_GPIO);
  ESP_LOGI(TAG, "  - MQTT broker: %s", MQTT_BROKER_URI);
  ESP_LOGI(TAG, "  - BLE provisioning: %s", PROV_DEVICE_NAME);
  ESP_LOGI(TAG, "============================================");
  ESP_LOGI(TAG, "Waiting for Wi-Fi connection...");
}
