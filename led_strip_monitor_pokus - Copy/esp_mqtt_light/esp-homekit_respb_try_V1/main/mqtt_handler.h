/*
 * MQTT Handler - MQTT client management and message handling
 */

#ifndef MQTT_HANDLER_H
#define MQTT_HANDLER_H

#include "esp_err.h"
#include <stdbool.h>
#include <stdint.h>

/**
 * @brief Callback function types for MQTT command reception
 */
typedef void (*power_cmd_cb_t)(bool power);
typedef void (*brightness_cmd_cb_t)(uint8_t brightness);
typedef void (*color_cmd_cb_t)(uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief Initialize MQTT client
 * Configure broker URI and event handlers, but don't start yet
 *
 * @param broker_uri MQTT broker URI (e.g., "mqtt://192.168.1.125")
 * @return esp_err_t ESP_OK on success
 */
esp_err_t mqtt_init(const char *broker_uri);

/**
 * @brief Start MQTT client
 * Connect to broker and subscribe to command topics
 * Should be called after Wi-Fi is connected
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t mqtt_start(void);

/**
 * @brief Stop MQTT client
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t mqtt_stop(void);

/**
 * @brief Publish LED power state
 *
 * @param power Current power state (true/false)
 * @return esp_err_t ESP_OK on success
 */
esp_err_t mqtt_publish_power_state(bool power);

/**
 * @brief Publish LED brightness state
 *
 * @param brightness Current brightness (0-100)
 * @return esp_err_t ESP_OK on success
 */
esp_err_t mqtt_publish_brightness_state(uint8_t brightness);

/**
 * @brief Publish LED color state
 *
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @return esp_err_t ESP_OK on success
 */
esp_err_t mqtt_publish_color_state(uint8_t r, uint8_t g, uint8_t b);

/**
 * @brief Set callback for power commands
 *
 * @param cb Callback function pointer
 */
void mqtt_set_power_callback(power_cmd_cb_t cb);

/**
 * @brief Set callback for brightness commands
 *
 * @param cb Callback function pointer
 */
void mqtt_set_brightness_callback(brightness_cmd_cb_t cb);

/**
 * @brief Set callback for color commands
 *
 * @param cb Callback function pointer
 */
void mqtt_set_color_callback(color_cmd_cb_t cb);

/**
 * @brief Check if MQTT client is connected
 *
 * @return true if connected, false otherwise
 */
bool mqtt_is_connected(void);

#endif // MQTT_HANDLER_H
