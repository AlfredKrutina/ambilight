#include "ota_update.h"

#include <stdlib.h>
#include <string.h>

#include "ambilight_ota_feedback.h"
#include "esp_app_format.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_https_ota.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG_OTA = "LampOTA";
static volatile bool s_ota_busy;

bool ambilight_ota_in_progress(void) { return s_ota_busy; }

typedef struct {
  char *url;
  struct sockaddr_in notify;
  bool notify_valid;
} ota_bundle_t;

/// Zakáže řídicí znaky a mezery-only URL (HTTP klient / stabilita).
static bool ota_url_chars_valid(const char *u) {
  if (u == NULL || *u == '\0') {
    return false;
  }
  bool seen_non_space = false;
  for (const char *p = u; *p; p++) {
    unsigned char c = (unsigned char)*p;
    if (c < 0x20 || c == 0x7f) {
      return false;
    }
    if (c != ' ' && c != '\t') {
      seen_non_space = true;
    }
  }
  return seen_non_space;
}

static void ota_task(void *pv) {
  ota_bundle_t *bundle = (ota_bundle_t *)pv;
  char *url = bundle->url;
  struct sockaddr_in notify = bundle->notify;
  const bool notify_valid = bundle->notify_valid;
  free(bundle);
  bundle = NULL;

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
  ESP_LOGI(TAG_OTA, "heap free=%u před esp_https_ota",
           (unsigned)heap_caps_get_free_size(MALLOC_CAP_INTERNAL));
  esp_err_t ret = esp_https_ota(&ota_cfg);
  ESP_LOGI(TAG_OTA, "esp_https_ota → %s", esp_err_to_name(ret));
  free(url);
  s_ota_busy = false;
  if (ret == ESP_OK) {
    ESP_LOGI(TAG_OTA, "OTA hotovo, zpětná vazba + restart");
    ambilight_ota_success_client_feedback(notify_valid ? &notify : NULL);
    vTaskDelay(pdMS_TO_TICKS(200));
    esp_restart();
  }
  ESP_LOGE(TAG_OTA, "OTA selhalo: %s", esp_err_to_name(ret));
  vTaskDelete(NULL);
}

void ambilight_start_ota(const char *url_in,
                           const struct sockaddr_in *notify_udp_reply_target_or_null) {
  ESP_LOGI(TAG_OTA, "ambilight_start_ota voláno");
  if (url_in == NULL) {
    ESP_LOGW(TAG_OTA, "url_in=NULL");
    return;
  }
  if (s_ota_busy) {
    ESP_LOGW(TAG_OTA, "OTA už běží");
    return;
  }
  size_t n = strlen(url_in);
  ESP_LOGI(TAG_OTA, "délka URL=%u", (unsigned)n);
  /* Shoda s ambilight_desktop UdpDeviceCommands.sendOtaHttpUrl (max 1300). */
  if (n < 12 || n > 1300) {
    ESP_LOGW(TAG_OTA, "Neplatná délka URL");
    return;
  }
  if (strncmp(url_in, "https://", 8) != 0 && strncmp(url_in, "http://", 7) != 0) {
    ESP_LOGW(TAG_OTA, "URL musí začínat http:// nebo https://");
    return;
  }
  if (!ota_url_chars_valid(url_in)) {
    ESP_LOGW(TAG_OTA, "Neplatné znaky v URL");
    return;
  }
  ota_bundle_t *b = (ota_bundle_t *)malloc(sizeof(ota_bundle_t));
  if (b == NULL) {
    ESP_LOGE(TAG_OTA, "malloc(bundle) selhal");
    return;
  }
  memset(b, 0, sizeof(*b));
  b->url = (char *)malloc(n + 1);
  if (b->url == NULL) {
    ESP_LOGE(TAG_OTA, "malloc(url) selhal (n=%u)", (unsigned)n);
    free(b);
    return;
  }
  memcpy(b->url, url_in, n + 1);
  if (notify_udp_reply_target_or_null != NULL &&
      notify_udp_reply_target_or_null->sin_port != 0 &&
      notify_udp_reply_target_or_null->sin_addr.s_addr != 0) {
    b->notify = *notify_udp_reply_target_or_null;
    b->notify_valid = true;
  }
  s_ota_busy = true;
  ESP_LOGI(TAG_OTA, "startuji task lamp_ota (stack 12288, prio 5)");
  const BaseType_t ok = xTaskCreate(ota_task, "lamp_ota", 12288, b, 5, NULL);
  if (ok != pdPASS) {
    s_ota_busy = false;
    free(b->url);
    free(b);
    ESP_LOGE(TAG_OTA, "xTaskCreate selhalo");
  }
}
