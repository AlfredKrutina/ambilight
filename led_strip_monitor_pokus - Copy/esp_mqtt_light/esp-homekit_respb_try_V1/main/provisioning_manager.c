/*
 * Provisioning Manager - Wi-Fi setup via BLE provisioning
 */

#include "provisioning_manager.h"
#include "config.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_wifi.h"
#include "nvs_flash.h"
#include "wifi_provisioning/manager.h"
#include "wifi_provisioning/scheme_ble.h"
#include <string.h>

static const char *TAG = "PROV_MGR";
static wifi_connected_cb_t wifi_connected_cb = NULL;
static bool provisioning_in_progress = false;

// Event handler for Wi-Fi events
static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data) {
  if (event_base == WIFI_PROV_EVENT) {
    switch (event_id) {
    case WIFI_PROV_START:
      ESP_LOGI(TAG, "Provisioning started");
      break;
    case WIFI_PROV_CRED_RECV: {
      wifi_sta_config_t *wifi_sta_cfg = (wifi_sta_config_t *)event_data;
      ESP_LOGI(TAG, "Received Wi-Fi credentials - SSID: %s",
               (const char *)wifi_sta_cfg->ssid);
      break;
    }
    case WIFI_PROV_CRED_FAIL: {
      wifi_prov_sta_fail_reason_t *reason =
          (wifi_prov_sta_fail_reason_t *)event_data;
      ESP_LOGE(TAG, "Provisioning failed - Reason: %s",
               (*reason == WIFI_PROV_STA_AUTH_ERROR) ? "Wi-Fi auth error"
                                                     : "Wi-Fi AP not found");
      break;
    }
    case WIFI_PROV_CRED_SUCCESS:
      ESP_LOGI(TAG, "Provisioning successful");
      break;
    case WIFI_PROV_END:
      ESP_LOGI(TAG, "Provisioning ended");
      wifi_prov_mgr_deinit();
      provisioning_in_progress = false;
      break;
    default:
      break;
    }
  } else if (event_base == WIFI_EVENT) {
    switch (event_id) {
    case WIFI_EVENT_STA_START:
      ESP_LOGI(TAG, "Wi-Fi station started");
      esp_wifi_connect();
      break;
    case WIFI_EVENT_STA_DISCONNECTED:
      ESP_LOGI(TAG, "Wi-Fi disconnected, retrying...");
      esp_wifi_connect();
      break;
    default:
      break;
    }
  } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
    ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
    ESP_LOGI(TAG, "Got IP Address: " IPSTR, IP2STR(&event->ip_info.ip));

    // Call user callback if set
    if (wifi_connected_cb) {
      wifi_connected_cb();
    }
  }
}

esp_err_t provisioning_init(void) {
  // Initialize TCP/IP
  ESP_ERROR_CHECK(esp_netif_init());

  // Create default event loop if not already created
  esp_event_loop_create_default();

  // Create default Wi-Fi station
  esp_netif_create_default_wifi_sta();

  // Initialize Wi-Fi with default config
  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  // Register event handlers
  ESP_ERROR_CHECK(esp_event_handler_register(WIFI_PROV_EVENT, ESP_EVENT_ANY_ID,
                                             &wifi_event_handler, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                             &wifi_event_handler, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                             &wifi_event_handler, NULL));

  // Check if already provisioned
  bool provisioned = false;
  wifi_prov_mgr_config_t prov_config = {
      .scheme = wifi_prov_scheme_ble,
      .scheme_event_handler = WIFI_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BTDM};

  ESP_ERROR_CHECK(wifi_prov_mgr_init(prov_config));
  ESP_ERROR_CHECK(wifi_prov_mgr_is_provisioned(&provisioned));

  if (!provisioned) {
    ESP_LOGI(TAG, "Device not provisioned, starting BLE provisioning...");
    return start_ble_provisioning();
  } else {
    ESP_LOGI(TAG, "Device already provisioned, connecting to Wi-Fi...");
    wifi_prov_mgr_deinit();
    return connect_wifi();
  }
}

bool is_wifi_provisioned(void) {
  bool provisioned = false;
  wifi_prov_mgr_is_provisioned(&provisioned);
  return provisioned;
}

esp_err_t start_ble_provisioning(void) {
  if (provisioning_in_progress) {
    ESP_LOGW(TAG, "Provisioning already in progress");
    return ESP_OK;
  }

  provisioning_in_progress = true;

  // Generate unique device name with MAC address
  uint8_t eth_mac[6];
  esp_wifi_get_mac(WIFI_IF_STA, eth_mac);
  char service_name[32];
  snprintf(service_name, sizeof(service_name), "%s_%02X%02X%02X",
           PROV_DEVICE_NAME, eth_mac[3], eth_mac[4], eth_mac[5]);

  // Security version 1 with proof of possession
  wifi_prov_security_t security = WIFI_PROV_SECURITY_1;
  const char *pop = PROV_POP_PASSWORD;

  // Service key (for BLE)
  const char *service_key = NULL;

  ESP_LOGI(TAG, "Starting BLE provisioning with name: %s", service_name);
  ESP_LOGI(TAG, "Proof of Possession (PoP): %s", pop);

  esp_err_t ret = wifi_prov_mgr_start_provisioning(security, pop, service_name,
                                                   service_key);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to start provisioning: %s", esp_err_to_name(ret));
    provisioning_in_progress = false;
    return ret;
  }

  ESP_LOGI(
      TAG,
      "BLE provisioning started. Use ESP BLE Prov app to configure Wi-Fi.");
  return ESP_OK;
}

esp_err_t connect_wifi(void) {
  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_start());

  // Disable Wi-Fi power save for low latency (10ms instead of 400ms)
  // Critical for instant MQTT response - we're powered, not battery
  ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));
  ESP_LOGI(TAG, "Wi-Fi power save disabled for low-latency operation");

  ESP_LOGI(TAG, "Connecting to Wi-Fi...");
  return ESP_OK;
}

void set_wifi_connected_callback(wifi_connected_cb_t cb) {
  wifi_connected_cb = cb;
  ESP_LOGI(TAG, "Wi-Fi connected callback registered");
}

esp_err_t wifi_reset_credentials(void) {
  ESP_LOGI(TAG, "Resetting Wi-Fi credentials...");

  esp_err_t ret = wifi_prov_mgr_reset_provisioning();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to reset provisioning: %s", esp_err_to_name(ret));
    return ret;
  }

  ESP_LOGI(TAG, "Wi-Fi credentials reset. Restarting...");
  vTaskDelay(1000 / portTICK_PERIOD_MS);
  esp_restart();

  return ESP_OK;
}
