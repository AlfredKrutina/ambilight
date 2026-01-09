/*
 * Provisioning Manager - Wi-Fi setup via BLE provisioning
 */

#ifndef PROVISIONING_MANAGER_H
#define PROVISIONING_MANAGER_H

#include "esp_err.h"
#include <stdbool.h>

/**
 * @brief Callback function type for Wi-Fi connected event
 */
typedef void (*wifi_connected_cb_t)(void);

/**
 * @brief Initialize provisioning manager
 * Checks if device is provisioned, starts BLE provisioning if not,
 * otherwise connects to saved Wi-Fi network
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t provisioning_init(void);

/**
 * @brief Check if Wi-Fi credentials are already provisioned
 *
 * @return true if provisioned, false otherwise
 */
bool is_wifi_provisioned(void);

/**
 * @brief Start BLE provisioning process
 * Device will advertise as configured name and wait for credentials
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t start_ble_provisioning(void);

/**
 * @brief Connect to Wi-Fi using saved credentials
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t connect_wifi(void);

/**
 * @brief Set callback for Wi-Fi connected event
 * Callback will be invoked when device successfully connects and gets IP
 *
 * @param cb Callback function pointer
 */
void set_wifi_connected_callback(wifi_connected_cb_t cb);

/**
 * @brief Reset Wi-Fi credentials (factory reset)
 * Clears saved credentials and restarts device
 *
 * @return esp_err_t ESP_OK on success
 */
esp_err_t wifi_reset_credentials(void);

#endif // PROVISIONING_MANAGER_H
