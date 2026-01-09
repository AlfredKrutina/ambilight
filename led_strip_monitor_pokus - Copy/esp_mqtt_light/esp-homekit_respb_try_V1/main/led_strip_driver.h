/*
 * LED Strip Driver - WS2812B control via RMT peripheral
 */

#ifndef LED_STRIP_DRIVER_H
#define LED_STRIP_DRIVER_H

#include "esp_err.h"
#include "hal/gpio_types.h"
#include <stdint.h>

/**
 * @brief Initialize LED strip driver
 *
 * @param num_leds Number of LEDs in the strip
 * @param gpio_pin GPIO pin connected to LED data line
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_init(uint32_t num_leds, gpio_num_t gpio_pin);

/**
 * @brief Set a single pixel color (buffered, requires refresh)
 *
 * @param index LED index (0-based)
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_set_pixel(uint32_t index, uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief Apply buffered changes to LED strip
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_refresh(void);

/**
 * @brief Set all LEDs to the same color
 *
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_set_all(uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief Clear all LEDs (turn off)
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_clear(void);

/**
 * @brief Deinitialize LED strip driver and free resources
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_deinit(void);

#endif // LED_STRIP_DRIVER_H
