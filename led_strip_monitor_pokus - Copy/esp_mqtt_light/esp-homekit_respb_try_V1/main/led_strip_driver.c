/*
 * LED Strip Driver - WS2812B control via RMT peripheral
 */

#include "led_strip_driver.h"
#include "config.h"
#include "esp_log.h"
#include "led_strip.h"

static const char *TAG = "LED_STRIP_DRV";
static led_strip_handle_t led_strip_handle = NULL;
static uint32_t strip_num_leds = 0;

esp_err_t led_init(uint32_t num_leds, gpio_num_t gpio_pin) {
  if (led_strip_handle != NULL) {
    ESP_LOGW(TAG, "LED strip already initialized");
    return ESP_OK;
  }

  strip_num_leds = num_leds;

  // Configure LED strip
  led_strip_config_t strip_config = {
      .strip_gpio_num = gpio_pin,
      .max_leds = num_leds,
      .led_pixel_format = LED_PIXEL_FORMAT_GRB, // WS2812B uses GRB format
      .led_model = LED_MODEL_WS2812,
      .flags.invert_out = false,
  };

  // Configure RMT backend
  led_strip_rmt_config_t rmt_config = {
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
      .clk_src = RMT_CLK_SRC_DEFAULT,
      .resolution_hz = 10 * 1000 * 1000, // 10 MHz
      .flags.with_dma = false,
#else
      .rmt_channel = 0,
#endif
  };

  // Create LED strip instance
  esp_err_t ret =
      led_strip_new_rmt_device(&strip_config, &rmt_config, &led_strip_handle);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to create LED strip: %s", esp_err_to_name(ret));
    return ret;
  }

  // Clear all LEDs initially
  ret = led_strip_clear(led_strip_handle);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to clear LED strip: %s", esp_err_to_name(ret));
    return ret;
  }

  ESP_LOGI(TAG, "LED strip initialized: %lu LEDs on GPIO%d", num_leds,
           gpio_pin);
  return ESP_OK;
}

esp_err_t led_set_pixel(uint32_t index, uint8_t r, uint8_t g, uint8_t b) {
  if (led_strip_handle == NULL) {
    ESP_LOGE(TAG, "LED strip not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  if (index >= strip_num_leds) {
    ESP_LOGE(TAG, "LED index %lu out of range (max: %lu)", index,
             strip_num_leds - 1);
    return ESP_ERR_INVALID_ARG;
  }

  return led_strip_set_pixel(led_strip_handle, index, r, g, b);
}

esp_err_t led_refresh(void) {
  if (led_strip_handle == NULL) {
    ESP_LOGE(TAG, "LED strip not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  return led_strip_refresh(led_strip_handle);
}

esp_err_t led_set_all(uint8_t r, uint8_t g, uint8_t b) {
  if (led_strip_handle == NULL) {
    ESP_LOGE(TAG, "LED strip not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  esp_err_t ret;
  for (uint32_t i = 0; i < strip_num_leds; i++) {
    ret = led_strip_set_pixel(led_strip_handle, i, r, g, b);
    if (ret != ESP_OK) {
      ESP_LOGE(TAG, "Failed to set pixel %lu", i);
      return ret;
    }
  }

  return led_strip_refresh(led_strip_handle);
}

esp_err_t led_clear(void) {
  if (led_strip_handle == NULL) {
    ESP_LOGE(TAG, "LED strip not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  return led_strip_clear(led_strip_handle);
}

esp_err_t led_deinit(void) {
  if (led_strip_handle == NULL) {
    ESP_LOGW(TAG, "LED strip not initialized");
    return ESP_OK;
  }

  esp_err_t ret = led_strip_del(led_strip_handle);
  if (ret == ESP_OK) {
    led_strip_handle = NULL;
    strip_num_leds = 0;
    ESP_LOGI(TAG, "LED strip deinitialized");
  } else {
    ESP_LOGE(TAG, "Failed to deinitialize LED strip: %s", esp_err_to_name(ret));
  }

  return ret;
}
