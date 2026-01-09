/*
 * LED Controller - State management and color calculation
 */

#include "led_controller.h"
#include "config.h"
#include "esp_log.h"
#include "led_strip_driver.h"
#include "nvs.h"
#include "nvs_flash.h"
#include <string.h>

static const char *TAG = "LED_CTRL";
static led_state_t current_state;
static bool initialized = false;

esp_err_t led_controller_init(void) {
  if (initialized) {
    ESP_LOGW(TAG, "LED controller already initialized");
    return ESP_OK;
  }

  // Initialize LED strip driver
  esp_err_t ret = led_init(LED_STRIP_NUM_LEDS, LED_STRIP_GPIO);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to initialize LED strip driver");
    return ret;
  }

  // Try to load state from NVS
  nvs_handle_t nvs_handle;
  ret = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
  if (ret == ESP_OK) {
    // Load power state
    uint8_t power_val = LED_DEFAULT_POWER;
    nvs_get_u8(nvs_handle, NVS_KEY_POWER, &power_val);
    current_state.power = (power_val != 0);

    // Load brightness
    current_state.brightness = LED_DEFAULT_BRIGHTNESS;
    nvs_get_u8(nvs_handle, NVS_KEY_BRIGHTNESS, &current_state.brightness);

    // Load RGB values
    current_state.r = LED_DEFAULT_R;
    current_state.g = LED_DEFAULT_G;
    current_state.b = LED_DEFAULT_B;
    nvs_get_u8(nvs_handle, NVS_KEY_COLOR_R, &current_state.r);
    nvs_get_u8(nvs_handle, NVS_KEY_COLOR_G, &current_state.g);
    nvs_get_u8(nvs_handle, NVS_KEY_COLOR_B, &current_state.b);

    nvs_close(nvs_handle);
    ESP_LOGI(TAG,
             "Loaded state from NVS: power=%d, brightness=%d, RGB=(%d,%d,%d)",
             current_state.power, current_state.brightness, current_state.r,
             current_state.g, current_state.b);
  } else {
    // Use defaults
    current_state.power = LED_DEFAULT_POWER;
    current_state.brightness = LED_DEFAULT_BRIGHTNESS;
    current_state.r = LED_DEFAULT_R;
    current_state.g = LED_DEFAULT_G;
    current_state.b = LED_DEFAULT_B;
    ESP_LOGI(TAG, "Using default state");
  }

  // Mark as initialized before applying state
  initialized = true;

  // Apply initial state
  ret = led_apply_state();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to apply initial state");
    initialized = false; // Rollback on failure
    return ret;
  }

  ESP_LOGI(TAG, "LED controller initialized");
  return ESP_OK;
}

esp_err_t led_set_power(bool power) {
  if (!initialized) {
    ESP_LOGE(TAG, "LED controller not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  ESP_LOGI(TAG, "Setting power: %s", power ? "ON" : "OFF");
  current_state.power = power;

  esp_err_t ret = led_apply_state();
  if (ret == ESP_OK) {
    led_save_state();
  }
  return ret;
}

esp_err_t led_set_brightness(uint8_t brightness) {
  if (!initialized) {
    ESP_LOGE(TAG, "LED controller not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  if (brightness > 100) {
    ESP_LOGE(TAG, "Invalid brightness: %d (must be 0-100)", brightness);
    return ESP_ERR_INVALID_ARG;
  }

  ESP_LOGI(TAG, "Setting brightness: %d%%", brightness);
  current_state.brightness = brightness;

  esp_err_t ret = led_apply_state();
  if (ret == ESP_OK) {
    led_save_state();
  }
  return ret;
}

esp_err_t led_set_color(uint8_t r, uint8_t g, uint8_t b) {
  if (!initialized) {
    ESP_LOGE(TAG, "LED controller not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  ESP_LOGI(TAG, "Setting color: RGB(%d,%d,%d)", r, g, b);
  current_state.r = r;
  current_state.g = g;
  current_state.b = b;

  esp_err_t ret = led_apply_state();
  if (ret == ESP_OK) {
    led_save_state();
  }
  return ret;
}

void led_get_state(led_state_t *state) {
  if (state != NULL) {
    memcpy(state, &current_state, sizeof(led_state_t));
  }
}

void led_calculate_final_color(uint8_t *final_r, uint8_t *final_g,
                               uint8_t *final_b) {
  if (!current_state.power) {
    // If power is off, all colors are 0
    *final_r = 0;
    *final_g = 0;
    *final_b = 0;
    return;
  }

  // Apply brightness scaling
  *final_r = (current_state.r * current_state.brightness) / 100;
  *final_g = (current_state.g * current_state.brightness) / 100;
  *final_b = (current_state.b * current_state.brightness) / 100;
}

esp_err_t led_apply_state(void) {
  if (!initialized) {
    ESP_LOGE(TAG, "LED controller not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  uint8_t final_r, final_g, final_b;
  led_calculate_final_color(&final_r, &final_g, &final_b);

  ESP_LOGD(TAG, "Applying state - Final RGB(%d,%d,%d)", final_r, final_g,
           final_b);

  // Set all LEDs to the calculated color
  esp_err_t ret = led_set_all(final_r, final_g, final_b);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to apply LED state: %s", esp_err_to_name(ret));
  }

  return ret;
}

esp_err_t led_save_state(void) {
  nvs_handle_t nvs_handle;
  esp_err_t ret = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to open NVS for saving: %s", esp_err_to_name(ret));
    return ret;
  }

  // Save all state values
  nvs_set_u8(nvs_handle, NVS_KEY_POWER, current_state.power ? 1 : 0);
  nvs_set_u8(nvs_handle, NVS_KEY_BRIGHTNESS, current_state.brightness);
  nvs_set_u8(nvs_handle, NVS_KEY_COLOR_R, current_state.r);
  nvs_set_u8(nvs_handle, NVS_KEY_COLOR_G, current_state.g);
  nvs_set_u8(nvs_handle, NVS_KEY_COLOR_B, current_state.b);

  ret = nvs_commit(nvs_handle);
  nvs_close(nvs_handle);

  if (ret == ESP_OK) {
    ESP_LOGD(TAG, "State saved to NVS");
  } else {
    ESP_LOGE(TAG, "Failed to commit NVS: %s", esp_err_to_name(ret));
  }

  return ret;
}
