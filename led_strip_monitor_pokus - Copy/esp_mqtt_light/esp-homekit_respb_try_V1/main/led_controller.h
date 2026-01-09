/*
 * LED Controller - State management and color calculation
 */

#ifndef LED_CONTROLLER_H
#define LED_CONTROLLER_H

#include "esp_err.h"
#include <stdbool.h>
#include <stdint.h>

/**
 * @brief LED state structure
 */
typedef struct {
  bool power;         // true = LED on, false = LED off
  uint8_t brightness; // 0-100 (percentage)
  uint8_t r;          // 0-255 (red component)
  uint8_t g;          // 0-255 (green component)
  uint8_t b;          // 0-255 (blue component)
} led_state_t;

/**
 * @brief Initialize LED controller
 * Loads saved state from NVS if available, otherwise uses defaults
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_controller_init(void);

/**
 * @brief Set LED power state
 *
 * @param power true to turn on, false to turn off
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_set_power(bool power);

/**
 * @brief Set LED brightness
 *
 * @param brightness Brightness level (0-100)
 * @return esp_err_t ESP_OK on success, ESP_ERR_INVALID_ARG if out of range
 */
esp_err_t led_set_brightness(uint8_t brightness);

/**
 * @brief Set LED color
 *
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_set_color(uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief Get current LED state
 *
 * @param state Pointer to led_state_t structure to fill
 */
void led_get_state(led_state_t *state);

/**
 * @brief Calculate final color values with brightness applied
 *
 * @param final_r Pointer to store final red value
 * @param final_g Pointer to store final green value
 * @param final_b Pointer to store final blue value
 */
void led_calculate_final_color(uint8_t *final_r, uint8_t *final_g,
                               uint8_t *final_b);

/**
 * @brief Apply current state to hardware
 * Internal function called automatically by setters
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_apply_state(void);

/**
 * @brief Save current state to NVS
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t led_save_state(void);

#endif // LED_CONTROLLER_H
