#include "ota_update.h"

#include <stdlib.h>
#include <string.h>

#include "esp_app_format.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_https_ota.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG_OTA = "LampOTA";
static volatile bool s_ota_busy;

bool ambilight_ota_in_progress(void) { return s_ota_busy; }

static void ota_task(void *pv) {
  char *url = (char *)pv;
  esp_http_client_config_t http_cfg = {
      .url = url,
      .timeout_ms = 180000,
      .crt_bundle_attach = esp_crt_bundle_attach,
      .keep_alive_enable = true,
  };
  esp_https_ota_config_t ota_cfg = {
      .http_config = &http_cfg,
  };
  const esp_app_desc_t *app = esp_app_get_description();
  ESP_LOGI(TAG_OTA, "Start OTA (běží %s) → %s", app ? app->version : "?", url);
  esp_err_t ret = esp_https_ota(&ota_cfg);
  free(url);
  s_ota_busy = false;
  if (ret == ESP_OK) {
    ESP_LOGI(TAG_OTA, "OTA hotovo, restart");
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
  }
  ESP_LOGE(TAG_OTA, "OTA selhalo: %s", esp_err_to_name(ret));
  vTaskDelete(NULL);
}

void ambilight_start_ota(const char *url_in) {
  if (url_in == NULL) {
    return;
  }
  if (s_ota_busy) {
    ESP_LOGW(TAG_OTA, "OTA už běží");
    return;
  }
  size_t n = strlen(url_in);
  /* Shoda s ambilight_desktop UdpDeviceCommands.sendOtaHttpUrl (max 1300). */
  if (n < 12 || n > 1300) {
    ESP_LOGW(TAG_OTA, "Neplatná délka URL");
    return;
  }
  if (strncmp(url_in, "https://", 8) != 0 && strncmp(url_in, "http://", 7) != 0) {
    ESP_LOGW(TAG_OTA, "URL musí začínat http:// nebo https://");
    return;
  }
  char *url = (char *)malloc(n + 1);
  if (url == NULL) {
    ESP_LOGE(TAG_OTA, "malloc");
    return;
  }
  memcpy(url, url_in, n + 1);
  s_ota_busy = true;
  const BaseType_t ok = xTaskCreate(ota_task, "lamp_ota", 12288, url, 5, NULL);
  if (ok != pdPASS) {
    s_ota_busy = false;
    free(url);
    ESP_LOGE(TAG_OTA, "xTaskCreate selhalo");
  }
}
