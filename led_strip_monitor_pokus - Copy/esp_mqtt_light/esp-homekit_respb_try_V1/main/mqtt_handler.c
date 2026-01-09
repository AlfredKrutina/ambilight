/*
 * MQTT Handler - MQTT client management and message handling
 */

#include "mqtt_handler.h"
#include "config.h"
#include "esp_log.h"
#include "mqtt_client.h"
#include <stdio.h>
#include <string.h>

static const char *TAG = "MQTT_HANDLER";

static esp_mqtt_client_handle_t mqtt_client = NULL;
static power_cmd_cb_t power_callback = NULL;
static brightness_cmd_cb_t brightness_callback = NULL;
static color_cmd_cb_t color_callback = NULL;
static bool is_connected = false;

// Forward declaration
static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                               int32_t event_id, void *event_data);

esp_err_t mqtt_init(const char *broker_uri) {
  if (mqtt_client != NULL) {
    ESP_LOGW(TAG, "MQTT client already initialized");
    return ESP_OK;
  }

  esp_mqtt_client_config_t mqtt_cfg = {
      .broker.address.uri = broker_uri,
  };

  mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
  if (mqtt_client == NULL) {
    ESP_LOGE(TAG, "Failed to initialize MQTT client");
    return ESP_FAIL;
  }

  esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID,
                                 mqtt_event_handler, NULL);

  ESP_LOGI(TAG, "MQTT client initialized with broker: %s", broker_uri);
  return ESP_OK;
}

esp_err_t mqtt_start(void) {
  if (mqtt_client == NULL) {
    ESP_LOGE(TAG, "MQTT client not initialized");
    return ESP_ERR_INVALID_STATE;
  }

  esp_err_t ret = esp_mqtt_client_start(mqtt_client);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "Failed to start MQTT client: %s", esp_err_to_name(ret));
  } else {
    ESP_LOGI(TAG, "MQTT client started");
  }

  return ret;
}

esp_err_t mqtt_stop(void) {
  if (mqtt_client == NULL) {
    ESP_LOGW(TAG, "MQTT client not initialized");
    return ESP_OK;
  }

  esp_err_t ret = esp_mqtt_client_stop(mqtt_client);
  if (ret == ESP_OK) {
    is_connected = false;
    ESP_LOGI(TAG, "MQTT client stopped");
  }

  return ret;
}

esp_err_t mqtt_publish_power_state(bool power) {
  if (mqtt_client == NULL || !is_connected) {
    ESP_LOGW(TAG, "MQTT not ready for publishing");
    return ESP_ERR_INVALID_STATE;
  }

  const char *payload = power ? "true" : "false";
  int msg_id = esp_mqtt_client_publish(mqtt_client, MQTT_TOPIC_POWER_STATE,
                                       payload, 0, 1, 1);

  if (msg_id < 0) {
    ESP_LOGE(TAG, "Failed to publish power state");
    return ESP_FAIL;
  }

  ESP_LOGI(TAG, "Published power state: %s (msg_id=%d)", payload, msg_id);
  return ESP_OK;
}

esp_err_t mqtt_publish_brightness_state(uint8_t brightness) {
  if (mqtt_client == NULL || !is_connected) {
    ESP_LOGW(TAG, "MQTT not ready for publishing");
    return ESP_ERR_INVALID_STATE;
  }

  char payload[4];
  snprintf(payload, sizeof(payload), "%d", brightness);

  int msg_id = esp_mqtt_client_publish(mqtt_client, MQTT_TOPIC_BRIGHTNESS_STATE,
                                       payload, 0, 1, 1);

  if (msg_id < 0) {
    ESP_LOGE(TAG, "Failed to publish brightness state");
    return ESP_FAIL;
  }

  ESP_LOGI(TAG, "Published brightness state: %s (msg_id=%d)", payload, msg_id);
  return ESP_OK;
}

esp_err_t mqtt_publish_color_state(uint8_t r, uint8_t g, uint8_t b) {
  if (mqtt_client == NULL || !is_connected) {
    ESP_LOGW(TAG, "MQTT not ready for publishing");
    return ESP_ERR_INVALID_STATE;
  }

  char payload[16];
  snprintf(payload, sizeof(payload), "%d,%d,%d", r, g, b);

  int msg_id = esp_mqtt_client_publish(mqtt_client, MQTT_TOPIC_COLOR_STATE,
                                       payload, 0, 1, 1);

  if (msg_id < 0) {
    ESP_LOGE(TAG, "Failed to publish color state");
    return ESP_FAIL;
  }

  ESP_LOGI(TAG, "Published color state: %s (msg_id=%d)", payload, msg_id);
  return ESP_OK;
}

void mqtt_set_power_callback(power_cmd_cb_t cb) {
  power_callback = cb;
  ESP_LOGD(TAG, "Power callback set");
}

void mqtt_set_brightness_callback(brightness_cmd_cb_t cb) {
  brightness_callback = cb;
  ESP_LOGD(TAG, "Brightness callback set");
}

void mqtt_set_color_callback(color_cmd_cb_t cb) {
  color_callback = cb;
  ESP_LOGD(TAG, "Color callback set");
}

bool mqtt_is_connected(void) { return is_connected; }

static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                               int32_t event_id, void *event_data) {
  esp_mqtt_event_handle_t event = event_data;

  switch ((esp_mqtt_event_id_t)event_id) {
  case MQTT_EVENT_CONNECTED:
    ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
    is_connected = true;

    // Subscribe to command topics
    esp_mqtt_client_subscribe(mqtt_client, MQTT_TOPIC_POWER, 1);
    esp_mqtt_client_subscribe(mqtt_client, MQTT_TOPIC_BRIGHTNESS, 1);
    esp_mqtt_client_subscribe(mqtt_client, MQTT_TOPIC_COLOR, 1);

    ESP_LOGI(TAG, "Subscribed to all command topics");
    break;

  case MQTT_EVENT_DISCONNECTED:
    ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
    is_connected = false;
    break;

  case MQTT_EVENT_SUBSCRIBED:
    ESP_LOGI(TAG, "MQTT_EVENT_SUBSCRIBED, msg_id=%d", event->msg_id);
    break;

  case MQTT_EVENT_DATA:
    ESP_LOGI(TAG, "MQTT_EVENT_DATA");
    ESP_LOGI(TAG, "TOPIC=%.*s", event->topic_len, event->topic);
    ESP_LOGI(TAG, "DATA=%.*s", event->data_len, event->data);

    // Parse and handle power command
    if (strncmp(event->topic, MQTT_TOPIC_POWER, event->topic_len) == 0) {
      // Support both "true"/"false" and "1"/"0" formats
      bool power = false;
      if (event->data_len > 0) {
        // Check for "true" or "1"
        if ((strncmp(event->data, "true", event->data_len) == 0) ||
            (event->data_len == 1 && event->data[0] == '1')) {
          power = true;
        }
      }
      ESP_LOGI(TAG, "Received power command: %s", power ? "ON" : "OFF");
      if (power_callback) {
        power_callback(power);
      }
    }
    // Parse and handle brightness command
    else if (strncmp(event->topic, MQTT_TOPIC_BRIGHTNESS, event->topic_len) ==
             0) {
      char buf[4] = {0};
      int len = event->data_len < 3 ? event->data_len : 3;
      strncpy(buf, event->data, len);
      uint8_t brightness = (uint8_t)atoi(buf);
      ESP_LOGI(TAG, "Received brightness command: %d", brightness);
      if (brightness_callback) {
        brightness_callback(brightness);
      }
    }
    // Parse and handle color command
    else if (strncmp(event->topic, MQTT_TOPIC_COLOR, event->topic_len) == 0) {
      // Parse "R,G,B" format
      char buf[16] = {0};
      int len = event->data_len < 15 ? event->data_len : 15;
      strncpy(buf, event->data, len);

      uint8_t r = 0, g = 0, b = 0;
      if (sscanf(buf, "%hhu,%hhu,%hhu", &r, &g, &b) == 3) {
        ESP_LOGI(TAG, "Received color command: RGB(%d,%d,%d)", r, g, b);
        if (color_callback) {
          color_callback(r, g, b);
        }
      } else {
        ESP_LOGE(TAG, "Invalid color format: %s", buf);
      }
    }
    break;

  case MQTT_EVENT_ERROR:
    ESP_LOGI(TAG, "MQTT_EVENT_ERROR");
    if (event->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
      ESP_LOGE(TAG, "Last error code reported from esp-tls: 0x%x",
               event->error_handle->esp_tls_last_esp_err);
      ESP_LOGE(TAG, "Last tls stack error number: 0x%x",
               event->error_handle->esp_tls_stack_err);
      ESP_LOGE(TAG, "Last captured errno : %d (%s)",
               event->error_handle->esp_transport_sock_errno,
               strerror(event->error_handle->esp_transport_sock_errno));
    }
    break;

  default:
    ESP_LOGD(TAG, "Other event id:%d", event->event_id);
    break;
  }
}
