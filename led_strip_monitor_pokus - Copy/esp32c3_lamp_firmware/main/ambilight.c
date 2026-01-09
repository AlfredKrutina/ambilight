#include "driver/gpio.h"
#include "driver/usb_serial_jtag.h"
#include "esp_event.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "led_strip.h"
#include "led_strip_spi.h"
#include "lwip/err.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#include "mdns.h"
#include "mqtt_client.h"
#include "nvs.h"
#include "nvs_flash.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============ CONFIG ============
#define LED_STRIP_GPIO_PIN 8
#define LED_STRIP_NUM_LEDS 200
#define UDP_PORT 4210
#define AP_SSID "Ambilight_Setup"
#define SERIAL_TIMEOUT_US (25 * 100000LL) // 2.5 seconds (Faster Auto-Off)

static const char *TAG = "Ambilight";
static led_strip_handle_t led_strip = NULL;

typedef struct {
  uint8_t r, g, b;
} rgb_t;

// State Globals
static volatile int64_t g_last_serial_interaction = 0;
static bool g_wifi_enabled = false;
static bool g_is_provisioned =
    false; // Flag to prevent auto-connect loops when unconfigured
static bool g_ap_disabled_after_connection = false;
static rgb_t led_colors[LED_STRIP_NUM_LEDS] = {0};
static SemaphoreHandle_t led_mutex;
static volatile int g_scan_status = 0; // 0=IDLE, 1=SCANNING, 2=DONE
static volatile int64_t g_last_data_interaction = 0;
#define DATA_TIMEOUT_US (5 * 60 * 1000000LL) // 5 minutes
static bool g_suppress_reconnect = false;
static bool g_has_received_data = false; // Flag to disable timeout once active
static int g_connection_retries = 0;
#define MAX_RETRIES 5

// Source Locking Globals
static volatile uint32_t g_controller_ip = 0;
static volatile int64_t g_last_controller_time = 0;

// MQTT Globals
static esp_mqtt_client_handle_t mqtt_client = NULL;
static bool g_mqtt_connected = false;
static char g_mqtt_uri[65] = {0};
static char g_mqtt_user[33] = {0};
static char g_mqtt_pass[65] = {0};
static rgb_t g_home_color = {255, 180, 50}; // Default Warm White
static bool g_home_power = true;
static int g_home_bri = 100;       // Brightness 0-100
static char g_device_id[32] = {0}; // Unique ID generated from MAC
// MQTT Topics
#define MQTT_TOPIC_SET "ambilight/set"
#define MQTT_TOPIC_STATUS "ambilight/status"

// Wifi Event Logic
static EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

// Forward Decls
// Forward Decls
void start_wifi_subsystem();
void stop_wifi_subsystem();
void disable_onboard_leds();
esp_err_t load_wifi_creds(char *ssid, size_t ssid_len, char *pass,
                          size_t pass_len, char *mqtt_uri, size_t uri_len,
                          char *mqtt_user, size_t user_len, char *mqtt_pass,
                          size_t mpass_len);
esp_err_t save_wifi_creds(const char *ssid, const char *pass,
                          const char *mqtt_uri, const char *mqtt_user,
                          const char *mqtt_pass);
esp_err_t erase_wifi_creds();
void update_leds(uint8_t global_brightness);
void start_mqtt();
void stop_mqtt();
void update_leds(uint8_t global_brightness);
void clear_tail_leds(int start_idx);
void start_webserver(void);
void stop_webserver(void);

// ============ UTILS ============

// Helper for JSON escaping to prevent JSON breaks on weird SSIDs
void json_escape(char *dst, const char *src, size_t dst_len) {
  size_t i = 0;
  while (*src && i < dst_len - 1) {
    if (*src == '"' || *src == '\\') {
      if (i >= dst_len - 2)
        break;
      dst[i++] = '\\';
    }
    dst[i++] = *src++;
  }
  dst[i] = '\0';
}

void url_decode(char *dst, const char *src) {
  char a, b;
  while (*src) {
    if ((*src == '%') && ((a = src[1]) && (b = src[2])) &&
        (isxdigit((unsigned char)a) && isxdigit((unsigned char)b))) {
      if (a >= 'a')
        a -= 'a' - 'A';
      if (a >= 'A')
        a -= ('A' - 10);
      else
        a -= '0';
      if (b >= 'a')
        b -= 'a' - 'A';
      if (b >= 'A')
        b -= ('A' - 10);
      else
        b -= '0';
      *dst++ = 16 * a + b;
      src += 3;
    } else if (*src == '+') {
      *dst++ = ' ';
      src++;
    } else {
      *dst++ = *src++;
    }
  }
  *dst++ = '\0';
}

void clear_tail_leds(int start_idx) {
  if (start_idx < LED_STRIP_NUM_LEDS) {
    memset(&led_colors[start_idx], 0,
           (LED_STRIP_NUM_LEDS - start_idx) * sizeof(rgb_t));
  }
}

// ============ HTTP SERVER ============
static httpd_handle_t server = NULL;

static const char *config_page_html =
    "<!DOCTYPE html><html lang='en'><head>"
    "<meta charset='UTF-8'><meta name='viewport' content='width=device-width, "
    "initial-scale=1.0'>"
    "<title>Ambilight Setup</title>"
    "<style>"
    ":root{--bg:linear-gradient(135deg, #0f0c29, #302b63, "
    "#24243e);--primary:#0A84FF;--text:#fff;--text-sec:rgba(255,255,255,0.7);--"
    "glass:rgba(255, 255, 255, 0.05);--glass-border:rgba(255, 255, 255, 0.1);}"
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe "
    "UI',Roboto,sans-serif;background:var(--bg);color:var(--text);display:flex;"
    "justify-content:center;align-items:center;min-height:100vh;margin:0;"
    "padding:20px;box-sizing:border-box}"
    ".container{background:rgba(30, 30, 30, "
    "0.6);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);"
    "padding:2.5rem;border-radius:24px;border:1px solid "
    "var(--glass-border);box-shadow:0 8px 32px "
    "rgba(0,0,0,0.5);width:100%;max-width:400px;animation:fadeIn 0.6s "
    "cubic-bezier(0.22, 1, 0.36, 1)}"
    "@keyframes fadeIn{from{opacity:0;transform:translateY(20px) "
    "scale(0.95)}to{opacity:1;transform:translateY(0) scale(1)}}"
    "h1{text-align:center;color:var(--primary);margin:0 0 0.5rem "
    "0;font-weight:700;font-size:26px;text-shadow:0 0 20px "
    "rgba(10,132,255,0.3)}"
    ".subtitle{text-align:center;color:var(--text-sec);font-size:14px;margin-"
    "bottom:2rem}"
    "label{display:block;margin-bottom:0.8rem;color:var(--text-sec);font-size:"
    "12px;font-weight:600;text-transform:uppercase;letter-spacing:1px}"
    "input{width:100%;padding:16px;margin-bottom:1.5rem;background:rgba(0,0,0,"
    "0.2);border:1px solid "
    "var(--glass-border);border-radius:12px;color:#fff;font-size:16px;box-"
    "sizing:border-box;transition:0.3s}"
    "input:focus{border-color:var(--primary);outline:none;background:rgba(0,0,"
    "0,0.4);box-shadow:0 0 0 4px rgba(10,132,255,0.1)}"
    "button{width:100%;padding:16px;background:var(--primary);color:white;"
    "border:none;border-radius:12px;font-size:16px;font-weight:600;cursor:"
    "pointer;transition:0.3s;box-shadow:0 4px 15px rgba(10,132,255,0.3)}"
    "button:hover{background:#0071e3;transform:translateY(-2px);box-shadow:0 "
    "6px 20px rgba(10,132,255,0.4)}"
    "button:active{transform:translateY(1px)}"
    "button.secondary{background:rgba(255,255,255,0.05);margin-top:1.5rem;"
    "color:var(--text);box-shadow:none;border:1px solid var(--glass-border)}"
    "button.secondary:hover{background:rgba(255,255,255,0.1);transform:"
    "translateY(-2px)}"
    ".list-container{margin-top:0;max-height:0;overflow:hidden;transition:all "
    "0.5s cubic-bezier(0.4, 0, 0.2, "
    "1);border-radius:12px;background:rgba(0,0,0,0.2)}"
    ".list-container.open{max-height:300px;overflow-y:auto;margin-top:1.5rem;"
    "border:1px solid var(--glass-border)}"
    ".wifi-list{list-style:none;padding:0;margin:0}"
    ".wifi-item{display:flex;justify-content:space-between;align-items:center;"
    "padding:16px;border-bottom:1px solid "
    "var(--glass-border);cursor:pointer;transition:0.2s;animation:slideIn 0.3s "
    "ease-out forwards;opacity:0;transform:translateY(10px)}"
    "@keyframes slideIn{to{opacity:1;transform:translateY(0)}}"
    ".wifi-item:hover{background:rgba(255,255,255,0.05)}"
    ".wifi-item:last-child{border-bottom:none}"
    ".wifi-name{font-weight:500;font-size:15px}"
    ".wifi-info{display:flex;align-items:center;gap:12px}"
    ".signal-bars{display:flex;gap:2px;align-items:flex-end;height:12px;width:"
    "16px}"
    ".bar{width:3px;background:rgba(255,255,255,0.3);border-radius:1px}"
    ".bar.active{background:var(--primary)}"
    ".lock{font-size:12px;opacity:0.7}"
    ".spinner{width:20px;height:20px;border:3px solid "
    "rgba(255,255,255,0.1);border-radius:50%;border-top-color:#fff;animation:"
    "spin 0.8s ease-in-out infinite;margin-right:10px;display:none}"
    "@keyframes spin{to{transform:rotate(360deg)}}"
    ".footer{text-align:center;margin-top:2rem;font-size:11px;color:rgba(255,"
    "255,255,0.3);letter-spacing:1px;text-transform:uppercase}"
    "</style></head><body>"
    "<div class='container'>"
    "<h1>Ambilight</h1>"
    "<div class='subtitle'>Device Setup</div>"
    "<form action='/save' method='post'>"
    "<label>Wi-Fi Network</label><input id='ssid' name='ssid' "
    "placeholder='Select or Enter SSID' required autocomplete='off'>"
    "<label>Password</label><input id='pass' name='pass' type='password' "
    "placeholder='Enter Password'>"
    "<div class='subtitle' style='margin-top:20px;margin-bottom:10px'>Apple "
    "Home / MQTT (Optional)</div>"
    "<label>MQTT Broker URI</label><input id='m_uri' name='m_uri' "
    "value='mqtt://192.168.1.126:1883' placeholder='mqtt://192.168.1.126:1883'>"
    "<label>User</label><input id='m_user' name='m_user' value='mqtt-user' "
    "placeholder='User'>"
    "<label>Password</label><input id='m_pass' name='m_pass' type='password' "
    "value='mqtt' placeholder='Password'>"

    "<button type='submit'>Save & Connect</button>"
    "</form>"
    "<button class='secondary' id='scanBtn' onclick='scanWifi()'>"
    "<div class='spinner' id='spinner'></div><span id='scanText'>Scan "
    "Networks</span>"
    "</button>"
    "<div class='list-container' id='listContainer'>"
    "<ul class='wifi-list' id='wifiList'></ul>"
    "</div>"
    "<div class='footer'>Firmware 2.3 • ESP32-C3</div>"
    "</div>"
    "<script>"
    "function getSignalBars(rssi){"
    "let n=0;if(rssi>=-50)n=4;else if(rssi>=-60)n=3;else if(rssi>=-70)n=2;else "
    "if(rssi>=-80)n=1;"
    "return `<div class='signal-bars'>`+[1,2,3,4].map(i=>`<div class='bar "
    "${i<=n?'active':''}'></div>`).map((h,i)=>`<div "
    "style='height:${(i+1)*3}px' class='bar "
    "${i<n?'active':''}'></div>`).join('')+`</div>`;"
    "}"
    "function scanWifi(){"
    "const "
    "b=document.getElementById('scanBtn'),s=document.getElementById('spinner'),"
    "t=document.getElementById('scanText'),l=document.getElementById('wifiList'"
    "),c=document.getElementById('listContainer');"
    "b.disabled=true;s.style.display='block';t.textContent='Scanning...';l."
    "innerHTML='';c.classList.remove('open');"
    "function poll(){"
    "fetch('/scan').then(r=>r.json()).then(d=>{ "
    "if(d.status==='failed') throw new Error('Scan Failed/Busy');"
    "if(d.status==='scanning') { setTimeout(poll, 1000); return; }"
    "if(d.status==='complete' && d.networks) { "
    "l.innerHTML=d.networks.map((n,i)=>`<li class='wifi-item' "
    "style='animation-delay:${i*0.05}s' "
    "onclick=\"select('${n.ssid.replace(/'/g, \"\\\\'\")}')\"><span "
    "class='wifi-name'>${n.ssid}</span><div "
    "class='wifi-info'>${n.auth>0?'<span "
    "class=\"lock\">🔒</span>':''}${getSignalBars(n.rssi)}</div></"
    "li>`).join('');"
    "c.classList.add('open'); "
    "b.disabled=false;s.style.display='none';t.textContent='Refresh Networks';"
    "} }).catch(e=>{console.log(e);t.textContent='Scan "
    "Failed';b.disabled=false;s.style.display='none';});"
    "}"
    "poll();"
    "}"
    "function select(n){const "
    "i=document.getElementById('ssid');i.value=n;i.classList.add('pulse');"
    "setTimeout(()=>i.classList.remove('pulse'),300);document.getElementById('"
    "pass').focus();}"
    "window.onload=scanWifi;"
    "</script></body></html>";

static const char *reboot_page_html =
    "<!DOCTYPE html><html lang='en'><head>"
    "<meta charset='UTF-8'><meta name='viewport' content='width=device-width, "
    "initial-scale=1.0'>"
    "<title>Rebooting...</title>"
    "<style>"
    ":root{--bg:linear-gradient(135deg, #0f0c29, #302b63, "
    "#24243e);--primary:#0A84FF;--text:#fff;--text-sec:rgba(255,255,255,0.7);--"
    "glass:rgba(255, 255, 255, 0.05);--glass-border:rgba(255, 255, 255, 0.1);}"
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe "
    "UI',Roboto,sans-serif;background:var(--bg);color:var(--text);display:flex;"
    "justify-content:center;align-items:center;min-height:100vh;margin:0;"
    "padding:20px;box-sizing:border-box}"
    ".container{background:rgba(30, 30, 30, "
    "0.6);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);"
    "padding:2.5rem;border-radius:24px;border:1px solid "
    "var(--glass-border);box-shadow:0 8px 32px "
    "rgba(0,0,0,0.5);width:100%;max-width:400px;animation:fadeIn 0.6s "
    "cubic-bezier(0.22, 1, 0.36, 1);text-align:center}"
    "@keyframes fadeIn{from{opacity:0;transform:translateY(20px) "
    "scale(0.95)}to{opacity:1;transform:translateY(0) scale(1)}}"
    "h1{color:var(--primary);margin:0 0 0.5rem "
    "0;font-weight:700;font-size:26px;text-shadow:0 0 20px "
    "rgba(10,132,255,0.3)}"
    ".subtitle{color:var(--text-sec);font-size:14px;margin-bottom:2rem}"
    ".spinner{width:50px;height:50px;border:4px solid "
    "rgba(255,255,255,0.1);border-radius:50%;border-top-color:var(--primary);"
    "animation:spin 1s ease-in-out infinite;margin:0 auto 1.5rem auto}"
    "@keyframes spin{to{transform:rotate(360deg)}}"
    ".progress-container{width:100%;height:4px;background:rgba(255,255,255,0.1)"
    ";border-radius:2px;overflow:hidden;margin-top:1.5rem}"
    ".progress-bar{height:100%;background:var(--primary);width:0%;transition:"
    "width 0.1s linear;box-shadow:0 0 10px rgba(10,132,255,0.5)}"
    "</style></head><body>"
    "<div class='container'>"
    "<div class='spinner'></div>"
    "<h1>Settings Saved</h1>"
    "<div class='subtitle'>Device is restarting...<br>Please wait while "
    "changes apply.</div>"
    "<div class='progress-container'><div class='progress-bar' "
    "id='bar'></div></div>"
    "</div>"
    "<script>"
    "let p=0;const b=document.getElementById('bar');"
    "const "
    "i=setInterval(()=>{p+=1;b.style.width=p+'%';if(p>=100){clearInterval(i);"
    "window.location.href='/';}},100);"
    "</script></body></html>";

esp_err_t scan_get_handler(httpd_req_t *req) {
  // ASYNC STATE MACHINE
  httpd_resp_set_type(req, "application/json");

  if (g_scan_status == 0) {
    // IDLE -> START SCAN
    wifi_scan_config_t scan_config = {
        .ssid = 0, .bssid = 0, .channel = 0, .show_hidden = false};
    if (!g_is_provisioned) {
      esp_wifi_disconnect(); // Ensure we are not in a 'Connecting' state
      vTaskDelay(pdMS_TO_TICKS(100));
    }

    // NON-BLOCKING call
    esp_err_t ret = esp_wifi_scan_start(&scan_config, false);
    if (ret == ESP_OK) {
      g_scan_status = 1; // SCANNING
      httpd_resp_send(req, "{\"status\":\"scanning\"}", HTTPD_RESP_USE_STRLEN);
    } else {
      char err_buf[64];
      sprintf(err_buf, "{\"status\":\"failed\",\"code\":%d}", ret);
      ESP_LOGE(TAG, "Scan Failed: %d (0x%x)", ret, ret);
      httpd_resp_send(req, err_buf, HTTPD_RESP_USE_STRLEN);
    }
    return ESP_OK;
  } else if (g_scan_status == 1) {
    // SCANNING -> WAIT
    httpd_resp_send(req, "{\"status\":\"scanning\"}", HTTPD_RESP_USE_STRLEN);
    return ESP_OK;
  } else if (g_scan_status == 2) {
    // DONE -> RETURN RESULTS
    uint16_t ap_count = 0;
    esp_wifi_scan_get_ap_num(&ap_count);
    if (ap_count > 15)
      ap_count = 15; // Reduce logic to 15 to save heap

    wifi_ap_record_t *ap_list =
        (wifi_ap_record_t *)malloc(sizeof(wifi_ap_record_t) * ap_count);
    if (!ap_list) {
      ESP_LOGE(TAG, "OOM in scan_get_handler! Free Heap: %lu",
               esp_get_free_heap_size());
      httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "OOM");
      return ESP_FAIL;
    }

    esp_wifi_scan_get_ap_records(&ap_count, ap_list);

    httpd_resp_send_chunk(req, "{\"status\":\"complete\",\"networks\":[",
                          HTTPD_RESP_USE_STRLEN);

    char buf[128]; // Use stack buffer instead of malloc to reduce fragmentation
    char ssid_safe[65] = {0};

    for (int i = 0; i < ap_count; i++) {
      if (i > 0)
        httpd_resp_send_chunk(req, ",", 1);
      json_escape(ssid_safe, (char *)ap_list[i].ssid, sizeof(ssid_safe));
      if (strlen(ssid_safe) == 0)
        continue;
      snprintf(buf, sizeof(buf), "{\"ssid\":\"%s\",\"rssi\":%d,\"auth\":%d}",
               ssid_safe, ap_list[i].rssi, ap_list[i].authmode);
      httpd_resp_send_chunk(req, buf, strlen(buf));
    }

    httpd_resp_send_chunk(req, "]}", HTTPD_RESP_USE_STRLEN);
    httpd_resp_send_chunk(req, NULL, 0);

    free(ap_list);

    // Reset to IDLE so we can scan again later
    g_scan_status = 0;
    return ESP_OK;
  }

  return ESP_OK;
}

// ============ NVS HELPERS ============
esp_err_t save_wifi_creds(const char *ssid, const char *pass, const char *muri,
                          const char *muser, const char *mpass) {
  nvs_handle_t nvs_handle;
  esp_err_t err = nvs_open("storage", NVS_READWRITE, &nvs_handle);
  if (err != ESP_OK)
    return err;

  nvs_set_str(nvs_handle, "ssid", ssid);
  nvs_set_str(nvs_handle, "pass", pass);

  // Save MQTT creds if provided, else erase them
  if (muri && strlen(muri) > 0)
    nvs_set_str(nvs_handle, "m_uri", muri);
  else
    nvs_erase_key(nvs_handle, "m_uri");

  if (muser && strlen(muser) > 0)
    nvs_set_str(nvs_handle, "m_user", muser);
  else
    nvs_erase_key(nvs_handle, "m_user");

  if (mpass && strlen(mpass) > 0)
    nvs_set_str(nvs_handle, "m_pass", mpass);
  else
    nvs_erase_key(nvs_handle, "m_pass");

  err = nvs_commit(nvs_handle);
  nvs_close(nvs_handle);
  return err;
}

esp_err_t load_wifi_creds(char *ssid, size_t ssid_len, char *pass,
                          size_t pass_len, char *muri, size_t muri_len,
                          char *muser, size_t muser_len, char *mpass,
                          size_t mpass_len) {
  nvs_handle_t nvs_handle;
  if (nvs_open("storage", NVS_READONLY, &nvs_handle) != ESP_OK)
    return ESP_FAIL;

  size_t required_size;

  // Load SSID
  if (nvs_get_str(nvs_handle, "ssid", NULL, &required_size) == ESP_OK &&
      required_size <= ssid_len)
    nvs_get_str(nvs_handle, "ssid", ssid, &required_size);
  else {
    nvs_close(nvs_handle);
    return ESP_FAIL;
  }

  // Load Password
  if (nvs_get_str(nvs_handle, "pass", NULL, &required_size) == ESP_OK &&
      required_size <= pass_len)
    nvs_get_str(nvs_handle, "pass", pass, &required_size);
  else {
    nvs_close(nvs_handle);
    return ESP_FAIL;
  }

  // Load MQTT (Optional) using safe defaults if missing
  // MIGRATION LOGIC: Check new keys ("m_*"), then fallback to old keys
  // ("mqtt_*")

  if (muri) {
    if (nvs_get_str(nvs_handle, "m_uri", NULL, &required_size) == ESP_OK &&
        required_size <= muri_len) {
      nvs_get_str(nvs_handle, "m_uri", muri, &required_size);
    } else if (nvs_get_str(nvs_handle, "mqtt_uri", NULL, &required_size) ==
                   ESP_OK &&
               required_size <= muri_len) {
      nvs_get_str(nvs_handle, "mqtt_uri", muri, &required_size);
    } else {
      muri[0] = 0;
    }
  }

  if (muser) {
    if (nvs_get_str(nvs_handle, "m_user", NULL, &required_size) == ESP_OK &&
        required_size <= muser_len) {
      nvs_get_str(nvs_handle, "m_user", muser, &required_size);
    } else if (nvs_get_str(nvs_handle, "mqtt_user", NULL, &required_size) ==
                   ESP_OK &&
               required_size <= muser_len) {
      nvs_get_str(nvs_handle, "mqtt_user", muser, &required_size);
    } else {
      muser[0] = 0;
    }
  }

  if (mpass) {
    if (nvs_get_str(nvs_handle, "m_pass", NULL, &required_size) == ESP_OK &&
        required_size <= mpass_len) {
      nvs_get_str(nvs_handle, "m_pass", mpass, &required_size);
    } else if (nvs_get_str(nvs_handle, "mqtt_pass", NULL, &required_size) ==
                   ESP_OK &&
               required_size <= mpass_len) {
      nvs_get_str(nvs_handle, "mqtt_pass", mpass, &required_size);
    } else {
      mpass[0] = 0;
    }
  }

  nvs_close(nvs_handle);
  return ESP_OK;
}

esp_err_t erase_wifi_creds() {
  nvs_handle_t nvs_handle;
  if (nvs_open("storage", NVS_READWRITE, &nvs_handle) != ESP_OK)
    return ESP_FAIL;
  nvs_erase_all(nvs_handle);
  nvs_commit(nvs_handle);
  nvs_close(nvs_handle);
  return ESP_OK;
}

// ============ HTTP HANDLERS ============

esp_err_t root_get_handler(httpd_req_t *req) {
  httpd_resp_send(req, config_page_html, HTTPD_RESP_USE_STRLEN);
  return ESP_OK;
}

esp_err_t save_post_handler(httpd_req_t *req) {
  char buf[512];
  int ret, remaining = req->content_len;
  if (remaining >= sizeof(buf))
    remaining = sizeof(buf) - 1;
  if ((ret = httpd_req_recv(req, buf, remaining)) <= 0)
    return ESP_FAIL;
  buf[ret] = '\0';

  char ssid_enc[33] = {0}, pass_enc[65] = {0}, ssid_dec[33] = {0},
       pass_dec[65] = {0};
  char muri_enc[65] = {0}, muser_enc[33] = {0}, mpass_enc[65] = {0};
  char muri_dec[65] = {0}, muser_dec[33] = {0}, mpass_dec[65] = {0};

// Helper macro for extraction
#define EXTRACT_PARAM(key, dest, size)                                         \
  do {                                                                         \
    char *p = strstr(buf, key "=");                                            \
    if (p) {                                                                   \
      p += strlen(key) + 1;                                                    \
      char *e = strchr(p, '&');                                                \
      if (!e)                                                                  \
        e = buf + strlen(buf);                                                 \
      int len = e - p;                                                         \
      if (len >= size)                                                         \
        len = size - 1;                                                        \
      strncpy(dest, p, len);                                                   \
      dest[len] = '\0';                                                        \
    }                                                                          \
  } while (0)

  EXTRACT_PARAM("ssid", ssid_enc, sizeof(ssid_enc));
  EXTRACT_PARAM("pass", pass_enc, sizeof(pass_enc));
  EXTRACT_PARAM("m_uri", muri_enc, sizeof(muri_enc));
  EXTRACT_PARAM("m_user", muser_enc, sizeof(muser_enc));
  EXTRACT_PARAM("m_pass", mpass_enc, sizeof(mpass_enc));

  url_decode(ssid_dec, ssid_enc);
  url_decode(pass_dec, pass_enc);
  url_decode(muri_dec, muri_enc);
  url_decode(muser_dec, muser_enc);
  url_decode(mpass_dec, mpass_enc);

  save_wifi_creds(ssid_dec, pass_dec, muri_dec, muser_dec, mpass_dec);

  // Reset boot count to prevent sticky safe mode
  nvs_handle_t nvs_handle;
  if (nvs_open("storage", NVS_READWRITE, &nvs_handle) == ESP_OK) {
    int32_t zero = 0;
    nvs_set_i32(nvs_handle, "boot_count", zero);
    nvs_commit(nvs_handle);
    nvs_close(nvs_handle);
  }

  httpd_resp_send(req, reboot_page_html, HTTPD_RESP_USE_STRLEN);
  vTaskDelay(pdMS_TO_TICKS(1000));
  esp_restart();
  return ESP_OK;
}

// Redirect Handler for Captive Portal (Catch-All)
// Redirect Handler for Captive Portal (Catch-All)
esp_err_t redirect_handler(httpd_req_t *req) {
  // Get our IP address dynamically
  char redirect_url[64];
  esp_netif_ip_info_t ip_info;
  esp_netif_t *netif = esp_netif_get_handle_from_ifkey("WIFI_AP_DEF");

  // Default to standard SoftAP IP if lookup fails
  uint32_t ip = 0xC0A80401; // 192.168.4.1

  if (netif && esp_netif_get_ip_info(netif, &ip_info) == ESP_OK) {
    ip = ip_info.ip.addr;
  }

  // IP is in Network Byte Order (Big Endian), we need to format it x.x.x.x
  // IP2STR macro helps here: "IP2STR(&ip_info.ip)" expansion:
  // Manual expansion if macros are missing or types mismatch.
  uint8_t *octets = (uint8_t *)&ip;
  sprintf(redirect_url, "http://%d.%d.%d.%d/", octets[0], octets[1], octets[2],
          octets[3]);

  httpd_resp_set_status(req, "302 Found");
  httpd_resp_set_hdr(req, "Location", redirect_url);
  // Prevent caching of the redirect
  httpd_resp_set_hdr(req, "Cache-Control",
                     "no-store, no-cache, must-revalidate, max-age=0");
  httpd_resp_send(req, NULL, 0);
  return ESP_OK;
}

void start_webserver(void) {
  if (server)
    return;
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.max_open_sockets = 5; // Increased for concurrent probes
  config.lru_purge_enable = true;
  config.max_uri_handlers = 16; // Increased for captive portal + scan handlers

  if (httpd_start(&server, &config) == ESP_OK) {
    httpd_uri_t r = {
        .uri = "/", .method = HTTP_GET, .handler = root_get_handler};
    httpd_register_uri_handler(server, &r);
    httpd_uri_t s = {
        .uri = "/save", .method = HTTP_POST, .handler = save_post_handler};
    httpd_register_uri_handler(server, &s);

    httpd_uri_t sc = {
        .uri = "/scan", .method = HTTP_GET, .handler = scan_get_handler};
    httpd_register_uri_handler(server, &sc);

    // Common Captive Portal Probe URIs
    const char *captive_uris[] = {"/generate_204",   "/gen_204",
                                  "/ncsi.txt",       "/hotspot-detect.html",
                                  "/canonical.html", "/connecttest.txt",
                                  "/success.txt"};

    for (int i = 0; i < sizeof(captive_uris) / sizeof(captive_uris[0]); i++) {
      httpd_uri_t func_uri = {.uri = captive_uris[i],
                              .method = HTTP_GET,
                              .handler = redirect_handler};
      httpd_register_uri_handler(server, &func_uri);
    }

    // CATCH ALL for Captive Portal (redirects all other URLs to /)
    httpd_uri_t catch_all = {
        .uri = "/*", .method = HTTP_GET, .handler = redirect_handler};
    httpd_register_uri_handler(server, &catch_all);
  }
}

void stop_webserver(void) {
  if (server) {
    httpd_stop(server);
    server = NULL;
  }
}

static void event_handler(void *arg, esp_event_base_t base, int32_t id,
                          void *data) {
  if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
    g_connection_retries = 0;
    if (g_is_provisioned) {
      esp_wifi_connect();
    } else {
      ESP_LOGI(TAG, "No credentials. Waiting in STA mode (for scanning).");
    }
  } else if (base == WIFI_EVENT && id == WIFI_EVENT_SCAN_DONE) {
    g_scan_status = 2; // SCAN DONE
    ESP_LOGI(TAG, "Wi-Fi Scan Complete");
  } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
    if (g_suppress_reconnect) {
      ESP_LOGI(TAG, "Timeout Disconnect. Switching to AP Mode (No Reconnect).");
      esp_wifi_set_mode(WIFI_MODE_APSTA);
      g_ap_disabled_after_connection = false;
      g_suppress_reconnect = false; // Reset flag
      xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
      return;
    }

    // Connection Failure Handling
    g_connection_retries++;
    if (g_connection_retries > MAX_RETRIES) {
      ESP_LOGW(TAG, "Connection Failed (Max Retries). Fallback to APSTA.");

      // Visual Feedback: Red Flash (Failure) - 50% Brightness
      xSemaphoreTake(led_mutex, portMAX_DELAY);
      for (int k = 0; k < 3; k++) {
        for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
          led_strip_set_pixel(led_strip, i, 76, 0, 0); // 30% RED
        led_strip_refresh(led_strip);
        vTaskDelay(pdMS_TO_TICKS(200));
        led_strip_clear(led_strip);
        led_strip_refresh(led_strip);
        vTaskDelay(pdMS_TO_TICKS(200));
      }
      update_leds(0); // OFF
      xSemaphoreGive(led_mutex);

      // Fallback to APSTA (Web Server accessible)
      esp_wifi_set_mode(WIFI_MODE_APSTA);
      g_ap_disabled_after_connection = false;
      // Stop Retrying
      xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
      return;
    }

    // Critical Fix: If we lost connection, ensure AP is back up so user can
    // reach us We might be in STA_ONLY mode, so switch back to APSTA
    if (g_ap_disabled_after_connection) {
      ESP_LOGI(TAG, "Wi-Fi Lost. Re-enabling AP (APSTA Mode).");
      esp_wifi_set_mode(WIFI_MODE_APSTA);
      g_ap_disabled_after_connection = false;
    }
    if (g_is_provisioned) {
      ESP_LOGI(TAG, "Retry Connection (%d/%d)...", g_connection_retries,
               MAX_RETRIES);
      esp_wifi_connect(); // Retry connection
    } else {
      ESP_LOGI(TAG, "Disconnected (Unprovisioned). Not retrying.");
    }
    xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
  } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
    // Connected!
    g_connection_retries = 0;    // Reset retries
    g_has_received_data = false; // Reset data flag (fresh session)

    xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    g_last_data_interaction =
        esp_timer_get_time(); // Init timer to prevent instant timeout

    // Generate Device ID early for mDNS
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(g_device_id, sizeof(g_device_id), "AF%02X%02X%02X", mac[3], mac[4],
             mac[5]);

    // Init mDNS for .local resolution
    if (mdns_init() == ESP_OK) {
      char hostname[64];
      snprintf(hostname, sizeof(hostname), "ambilight-%s", g_device_id);
      mdns_hostname_set(hostname);
      mdns_instance_name_set("Ambilight LED Controller");
      ESP_LOGI(TAG, "mDNS Init: %s.local", hostname);
    }

    // Start MQTT
    start_mqtt();

    // VISUAL INDICATION: Green Flash (3x) - 50% Brightness
    xSemaphoreTake(led_mutex, portMAX_DELAY);
    for (int k = 0; k < 3; k++) {
      for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
        led_strip_set_pixel(led_strip, i, 0, 76, 0); // 30% Green
      led_strip_refresh(led_strip);
      vTaskDelay(pdMS_TO_TICKS(200));
      led_strip_clear(led_strip);
      led_strip_refresh(led_strip);
      vTaskDelay(pdMS_TO_TICKS(200));
    }
    update_leds(255); // Restore
    xSemaphoreGive(led_mutex);

    // Switch to STA Mode only to save AP overhead
    if (!g_ap_disabled_after_connection) {
      ESP_LOGI(TAG, "Connected to Wi-Fi. Switching to STA only.");
      esp_wifi_set_mode(WIFI_MODE_STA);
      g_ap_disabled_after_connection = true;
    }
  }
}

void start_wifi_subsystem() {
  if (g_wifi_enabled)
    return;

  ESP_LOGI(TAG, "Starting Wi-Fi Subsystem...");

  // === 0. Boot Loop Protection ===
  // Initialize NVS
  esp_err_t err = nvs_flash_init();
  if (err == ESP_ERR_NVS_NO_FREE_PAGES ||
      err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    err = nvs_flash_init();
  }
  ESP_ERROR_CHECK(err);

  // Read & Increment Boot Count
  nvs_handle_t nvs_handle;
  int32_t boot_count = 0;
  bool force_safe_mode = false;

  if (nvs_open("storage", NVS_READWRITE, &nvs_handle) == ESP_OK) {
    nvs_get_i32(nvs_handle, "boot_count", &boot_count);
    boot_count++;
    // FLASH WEAR PROTECTION: Cap writes at 10.
    // If we are already in a loop, don't kill the flash.
    if (boot_count < 10) {
      nvs_set_i32(nvs_handle, "boot_count", boot_count);
      nvs_commit(nvs_handle);
    }
    nvs_close(nvs_handle);
  }

  if (boot_count > 5) {
    ESP_LOGE(TAG,
             "BOOT LOOP DETECTED (Count: %d). Forcing Safe Mode (AP Only).",
             boot_count);
    force_safe_mode = true;
    // Visual Indication: RED Slow Pulse
    xSemaphoreTake(led_mutex, portMAX_DELAY);
    for (int k = 0; k < 5; k++) {
      for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
        led_strip_set_pixel(led_strip, i, 76, 0, 0); // 30% Red
      led_strip_refresh(led_strip);
      vTaskDelay(pdMS_TO_TICKS(500));
      led_strip_clear(led_strip);
      led_strip_refresh(led_strip);
      vTaskDelay(pdMS_TO_TICKS(500));
    }
    xSemaphoreGive(led_mutex);
  } else {
    ESP_LOGI(TAG, "Boot Count: %d (Healthy)", boot_count);
  }

  // === 1. Smart SSID Selection (Scanning) ===
  // We start in STA mode first to scan for conflicts
  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_start());

  char unique_ssid[33] = AP_SSID;

  // Perform Blocking Scan
  wifi_scan_config_t scan_config = {
      .ssid = 0, .bssid = 0, .channel = 0, .show_hidden = false};
  ESP_LOGI(TAG, "Scanning for SSID conflicts...");
  esp_err_t ret = esp_wifi_scan_start(&scan_config, true); // true = BLOCKING

  if (ret == ESP_OK) {
    uint16_t ap_count = 0;
    esp_wifi_scan_get_ap_num(&ap_count);
    wifi_ap_record_t *ap_list =
        (wifi_ap_record_t *)malloc(sizeof(wifi_ap_record_t) * ap_count);

    if (ap_list && esp_wifi_scan_get_ap_records(&ap_count, ap_list) == ESP_OK) {
      int suffix = 0;
      bool conflict = true;

      while (conflict && suffix < 65534) { // Limit to 65534 tries
        conflict = false;
        // Generate Candidate Name
        if (suffix == 0)
          strcpy(unique_ssid, AP_SSID);
        else
          sprintf(unique_ssid, "%s_%d", AP_SSID, suffix);

        // Check against scan results
        for (int i = 0; i < ap_count; i++) {
          if (strcmp((char *)ap_list[i].ssid, unique_ssid) == 0) {
            conflict = true;
            ESP_LOGW(TAG, "Conflict found: %s", unique_ssid);
            break;
          }
        }

        if (conflict)
          suffix++;
      }
      if (!conflict)
        ESP_LOGI(TAG, "Selected Unique SSID: %s", unique_ssid);
      else
        ESP_LOGW(TAG, "Could not find unique SSID, using default: %s",
                 unique_ssid);
    }
    if (ap_list)
      free(ap_list);
  }

  // Stop temporary scan mode
  esp_wifi_stop();
  g_scan_status = 0; // Reset dirty status from blocking scan

  // === 2. Actual Startup ===
  char ssid[33] = {0};
  char pass[65] = {0};
  // Using globals g_mqtt_uri, g_mqtt_user, g_mqtt_pass
  bool has_creds = false;

  if (!force_safe_mode) {
    has_creds =
        (load_wifi_creds(ssid, sizeof(ssid), pass, sizeof(pass), g_mqtt_uri,
                         sizeof(g_mqtt_uri), g_mqtt_user, sizeof(g_mqtt_user),
                         g_mqtt_pass, sizeof(g_mqtt_pass)) == ESP_OK);
  } else {
    ESP_LOGW(TAG, "Safe Mode Active: Ignoring stored credentials.");
  }
  g_is_provisioned = has_creds;

  wifi_config_t ap_cfg = {.ap = {.ssid = "",
                                 .ssid_len = 0,
                                 .channel = 1,
                                 .max_connection = 4,
                                 .authmode = WIFI_AUTH_OPEN}};

  // Copy chosen unique SSID
  strncpy((char *)ap_cfg.ap.ssid, unique_ssid, 32);
  ap_cfg.ap.ssid_len = strlen(unique_ssid);

  wifi_config_t sta_cfg = {0};

  if (has_creds) {
    strncpy((char *)sta_cfg.sta.ssid, ssid, 32);
    strncpy((char *)sta_cfg.sta.password, pass, 64);
    ESP_LOGI(TAG, "Connecting to %s", ssid);

    xSemaphoreTake(led_mutex, portMAX_DELAY);
    for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
      led_strip_set_pixel(led_strip, i, 76, 40, 0); // 30% Orange
    led_strip_refresh(led_strip);
    xSemaphoreGive(led_mutex);

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_cfg));
  } else {
    ESP_LOGI(TAG, "No Creds. AP Mode (switching to APSTA to allow scanning).");
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
    wifi_config_t empty_cfg = {0};
    esp_wifi_set_config(WIFI_IF_STA, &empty_cfg);
  }

  ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &ap_cfg));
  ESP_ERROR_CHECK(esp_wifi_start());

  start_webserver();

  // DISABLE POWER SAVE to ensure low latency for UDP/Ambilight and reliable
  // ping
  esp_wifi_set_ps(WIFI_PS_NONE);

  g_wifi_enabled = true;
  g_ap_disabled_after_connection = false;
}

void stop_wifi_subsystem() {
  if (!g_wifi_enabled)
    return;
  ESP_LOGI(TAG, "Stopping Wi-Fi Subsystem (Serial Active)...");
  stop_webserver();
  stop_mqtt();

  // Signal UDP task to stop
  g_wifi_enabled = false;
  // Give UDP task time to break loop and close socket
  vTaskDelay(pdMS_TO_TICKS(500));

  esp_wifi_stop(); // Turns off radio
}

// ============ TASKS ============

void task_monitor(void *arg) {
  while (1) {
    int64_t now = esp_timer_get_time();
    bool serial_active = (now - g_last_serial_interaction) < SERIAL_TIMEOUT_US;

    if (serial_active) {
      // Signal Priority: Serial active.
      // We do NOT stop Wi-Fi anymore. We just let Serial take over LED control
      // (handled in update logic).
    }

    // Timeout Logic for STA Mode (Idle Disconnect)
    if (g_wifi_enabled &&
        !g_ap_disabled_after_connection) { // Wait, !g_ap_disabled means AP IS
                                           // ENABLED.
      // Logic Check: When connected, g_ap_disabled_after_connection = true.
      // So we want to check when it IS true (STA Only mode)
    }

    // Correct Logic: If we are in STA mode (AP disabled), check for data
    // timeout
    if (g_wifi_enabled && g_ap_disabled_after_connection) {
      EventBits_t bits = xEventGroupGetBits(s_wifi_event_group);
      if (bits & WIFI_CONNECTED_BIT) {
        // Check if Data Timeout exceeded AND we haven't actively used the
        // device
        if (!g_has_received_data &&
            (esp_timer_get_time() - g_last_data_interaction) >
                DATA_TIMEOUT_US) {
          // Check if MQTT Home Mode is active. If so, DO NOT disconnect.
          if (g_mqtt_connected) {
            // We are in Home Mode.
          } else {
            ESP_LOGW(TAG, "Idle Timeout (5min) & No Data & No MQTT. "
                          "Disconnecting to AP Mode.");
            g_suppress_reconnect = true; // Don't auto-reconnect
            esp_wifi_disconnect();
          }
        }

        // Restore Home Color if UDP stops (Auto-Off / Auto-Home)
        static bool s_has_restored_home = false;

        if ((esp_timer_get_time() - g_last_data_interaction) < 2000000) {
          s_has_restored_home = false; // PC is active
        } else {
          // Timeout Exceeded (>2s)
          if (!s_has_restored_home && !serial_active && g_mqtt_connected) {
            ESP_LOGI(TAG, "PC Data Stopped. Restoring Home Mode.");
            xSemaphoreTake(led_mutex, portMAX_DELAY);
            if (g_home_power) {
              float factor = g_home_bri / 100.0f;
              uint8_t r = (uint8_t)(g_home_color.r * factor);
              uint8_t g = (uint8_t)(g_home_color.g * factor);
              uint8_t b = (uint8_t)(g_home_color.b * factor);
              for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
                led_strip_set_pixel(led_strip, i, r, g, b);
            } else {
              led_strip_clear(led_strip);
            }
            led_strip_refresh(led_strip);
            xSemaphoreGive(led_mutex);
            s_has_restored_home = true;
          }
        }
      }
    }

    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

/**
 * @brief JTAG Serial Task (High Performance LED Control)
 *
 * Handles incoming data from USB-JTAG interface.
 * Priority: 10 (High) - Preempts IDLE and Wi-Fi helper tasks, but yields to
 * critical System tasks.
 *
 * Protocol:
 * - 0xAA: Handshake PING (Responds with 0xBB)
 * - 0xFF: Frame Sync (Start of Frame)
 * - 0xFE: End of Frame (Triggers LED Update)
 * - [Idx, R, G, B]: 4-byte Pixel Tuple (Binary Mode)
 *
 * Stability Features:
 * - Stack Size: 8192 bytes (Prevents Stack Overflow during heavy MQTT/JSON
 * usage)
 * - Watchdog Safety: Calls vTaskDelay(1) every batch to yield to IDLE task
 * (feeds WDT).
 * - Mutex Protection: Uses led_mutex to coordinate with Wi-Fi/UDP tasks.
 * - Auto-Home: Updates `g_last_serial_interaction` to prevent 'Restore Home
 * Mode' flickering.
 */
void task_serial(void *arg) {
  usb_serial_jtag_driver_config_t c = {.rx_buffer_size = 2048,
                                       .tx_buffer_size = 1024};
  usb_serial_jtag_driver_install(&c);

  usb_serial_jtag_driver_install(&c);

  // BUFFER INCREASE: 2048 bytes matches Driver Buffer.
  // Allows reading full frames (802 bytes) in one loop iteration.
  // Prevents stutter caused by vTaskDelay(1) splitting frames.
  uint8_t buf[2048];

  // State Machine
  enum { STATE_IDLE, STATE_DATA } state = STATE_IDLE;
  uint8_t tuple_buf[4];
  int tuple_pos = 0;
  bool dirty = false;

  bool frame_complete = false;

  while (1) {
    // Increased timeout (20ms) to bridge gaps caused by Wi-Fi interrupts
    int len = usb_serial_jtag_read_bytes(buf, sizeof(buf), pdMS_TO_TICKS(20));

    if (len > 0) {
      g_last_serial_interaction = esp_timer_get_time();

      for (int i = 0; i < len; i++) {
        uint8_t b = buf[i];

        // UNIVERSAL SYNC: 0xFF is ALWAYS Start of Frame
        if (b == 0xFF) {
          if (dirty)
            frame_complete = true; // Recover previous frame
          state = STATE_DATA;
          tuple_pos = 0;
          continue;
        }
        // END OF FRAME: 0xFE
        if (b == 0xFE && state == STATE_DATA) {
          frame_complete = true;
          state = STATE_IDLE;
          continue;
        }

        if (state == STATE_IDLE) {
          if (b == 0xAA) {
            // HANDSHAKE PING -> PONG
            uint8_t pong = 0xBB;
            usb_serial_jtag_write_bytes(&pong, 1, pdMS_TO_TICKS(10));

            // VISUAL DEBUG: Set 1st Pixel GREEN to indicate JTAG Connected
            memset(led_colors, 0, sizeof(led_colors));
            led_colors[0].g = 50; // Green Marker

            dirty = true;
            frame_complete = true; // Force update

            // SYNC HA: JTAG Connected = Power ON
            if (g_mqtt_connected) {
              char state_topic[64];
              snprintf(state_topic, sizeof(state_topic),
                       "alfred/devices/%s/power/state", g_device_id);
              esp_mqtt_client_publish(mqtt_client, state_topic, "true", 0, 1,
                                      0);
            }
          }
        } else if (state == STATE_DATA) {
          tuple_buf[tuple_pos++] = b;
          if (tuple_pos == 4) {
            // [Idx, R, G, B]
            uint8_t idx = tuple_buf[0];
            if (idx < LED_STRIP_NUM_LEDS) {
              led_colors[idx].r = tuple_buf[1];
              led_colors[idx].g = tuple_buf[2];
              led_colors[idx].b = tuple_buf[3];
              dirty = true;
            }
            tuple_pos = 0;
          }
        }
      }
      if (frame_complete) {
        xSemaphoreTake(led_mutex, portMAX_DELAY);
        // USB SAFETY LIMIT REMOVED: Full Brightness (User Confirmed Protocol
        // Fix)
        update_leds(255);
        xSemaphoreGive(led_mutex);
        dirty = false;
        frame_complete = false;

        // SMOOTHNESS FIX: Only sleep AFTER a full frame is processed.
        // This allows reading partial chunks aggressively.
        vTaskDelay(1);
      }

      // REMOVED unconditional sleep here.

    } else {
      // TIMEOUT (Silence) meaning end of batch
      if (state == STATE_DATA && dirty) {
        xSemaphoreTake(led_mutex, portMAX_DELAY);
        update_leds(255);
        xSemaphoreGive(led_mutex);
        dirty = false;
        state = STATE_IDLE;
      }
    }
  }
}

void task_udp(void *arg) {
  char rx_buffer[1500];
  struct sockaddr_in dest_addr;
  dest_addr.sin_addr.s_addr = htonl(INADDR_ANY);
  dest_addr.sin_family = AF_INET;
  dest_addr.sin_port = htons(UDP_PORT);

  while (1) {
    if (!g_wifi_enabled) {
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (sock < 0) {
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }

    // Timeout for recv so we can check g_wifi_enabled
    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    if (bind(sock, (struct sockaddr *)&dest_addr, sizeof(dest_addr)) < 0) {
      close(sock);
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    // Timeout tracking for Home Mode Recovery
    bool was_pc_mode = false;

    while (g_wifi_enabled) { // Inner loop checks flag
      struct sockaddr_in source_addr;
      socklen_t socklen = sizeof(source_addr);
      int len = recvfrom(sock, rx_buffer, sizeof(rx_buffer) - 1, 0,
                         (struct sockaddr *)&source_addr, &socklen);

      // Check if we need to restore HOME MODE (Silence detected)
      if (len <= 0) {
        if (was_pc_mode && (esp_timer_get_time() - g_last_data_interaction) >
                               5000000) { // 5s Silence
          ESP_LOGI(TAG, "PC Data Stopped. Restoring Home Mode.");
          was_pc_mode = false;

          // FEEDBACK: Notify HomeKit we are idle (Restore Home State)
          if (g_mqtt_connected) {
            char state_topic[64];
            // 1. Power State
            snprintf(state_topic, sizeof(state_topic),
                     "alfred/devices/%s/power/state", g_device_id);
            esp_mqtt_client_publish(mqtt_client, state_topic,
                                    g_home_power ? "true" : "false", 0, 1, 0);

            // 2. Color State
            snprintf(state_topic, sizeof(state_topic),
                     "alfred/devices/%s/color/state", g_device_id);
            char c_str[32];
            sprintf(c_str, "%d,%d,%d", g_home_color.r, g_home_color.g,
                    g_home_color.b);
            esp_mqtt_client_publish(mqtt_client, state_topic, c_str, 0, 1, 0);
          }

          bool serial_active = (esp_timer_get_time() -
                                g_last_serial_interaction) < SERIAL_TIMEOUT_US;
          if (g_mqtt_connected && g_home_power && !serial_active) {
            xSemaphoreTake(led_mutex, portMAX_DELAY);
            for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
              led_strip_set_pixel(led_strip, i, g_home_color.r, g_home_color.g,
                                  g_home_color.b);
            led_strip_refresh(led_strip);
            xSemaphoreGive(led_mutex);
          }
        }
      }

      if (len > 0) {
        if (!was_pc_mode) {
          // FEEDBACK: Notify HomeKit we are active (Ambilight is effectively
          // Power ON)
          if (g_mqtt_connected) {
            char state_topic[64];
            snprintf(state_topic, sizeof(state_topic),
                     "alfred/devices/%s/power/state", g_device_id);
            esp_mqtt_client_publish(mqtt_client, state_topic, "true", 0, 1, 0);
          }
        }
        was_pc_mode = true;
        rx_buffer[len] = 0;

        if (strncmp(rx_buffer, "DISCOVER_ESP32", 14) == 0) {
          uint8_t mac[6];
          esp_wifi_get_mac(WIFI_IF_STA, mac);
          char resp[128];
          ESP_LOGI(TAG, "Discovery Broadcast Received from %s",
                   inet_ntoa(source_addr.sin_addr.s_addr));
          sprintf(resp, "ESP32_PONG|%02x%02x%02x|Ambilight_%02x|%d|2.0", mac[3],
                  mac[4], mac[5], mac[5], LED_STRIP_NUM_LEDS);
          int sent =
              sendto(sock, resp, strlen(resp), 0,
                     (struct sockaddr *)&source_addr, sizeof(source_addr));
          if (sent < 0)
            ESP_LOGE(TAG, "Failed to send PONG: %d", errno);
          else
            ESP_LOGI(TAG, "Sent PONG: %s", resp);
          continue;
        }

        if (strncmp(rx_buffer, "IDENTIFY", 8) == 0) {
          ESP_LOGI(TAG, "Identify Request!");
          // Flash Blue for 1s
          xSemaphoreTake(led_mutex, portMAX_DELAY);
          for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
            led_strip_set_pixel(led_strip, i, 0, 0, 255); // Blue
          led_strip_refresh(led_strip);
          xSemaphoreGive(led_mutex);

          vTaskDelay(pdMS_TO_TICKS(1000));

          xSemaphoreTake(led_mutex, portMAX_DELAY);
          update_leds(255); // Restore state
          xSemaphoreGive(led_mutex);
          continue;
        }

        if (strncmp(rx_buffer, "RESET_WIFI", 10) == 0) {
          ESP_LOGW(TAG, "RESET_WIFI Requested!");

          // Visual Feedback: Red Flash (Rapid)
          xSemaphoreTake(led_mutex, portMAX_DELAY);
          for (int k = 0; k < 5; k++) {
            for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
              led_strip_set_pixel(led_strip, i, 255, 0, 0);
            led_strip_refresh(led_strip);
            vTaskDelay(pdMS_TO_TICKS(100));
            led_strip_clear(led_strip);
            led_strip_refresh(led_strip);
            vTaskDelay(pdMS_TO_TICKS(100));
          }
          xSemaphoreGive(led_mutex);

          // Erase Credentials
          erase_wifi_creds();

          ESP_LOGI(TAG, "Rebooting...");
          esp_restart();
          continue;
        }

        if (len >= 6 && (uint8_t)rx_buffer[0] ==
                            0x03) { // Single Pixel [0x03, IdxH, IdxL, R, G, B]
          // SOURCE LOCK CHECK
          if ((esp_timer_get_time() - g_last_serial_interaction) <
              SERIAL_TIMEOUT_US)
            continue;

          uint16_t idx = ((uint8_t)rx_buffer[1] << 8) | (uint8_t)rx_buffer[2];
          uint8_t r = rx_buffer[3];
          uint8_t g = rx_buffer[4];
          uint8_t b_val = rx_buffer[5];

          if (idx < LED_STRIP_NUM_LEDS) {
            xSemaphoreTake(led_mutex, portMAX_DELAY);
            led_colors[idx].r = r;
            led_colors[idx].g = g;
            led_colors[idx].b = b_val;
            // Update strip immediately with max brightness for calibration
            // visibility
            update_leds(255);
            xSemaphoreGive(led_mutex);
          }
          continue;
        }

        if (len >= 4 && (uint8_t)rx_buffer[0] ==
                            0x02) { // Binary Frame [0x02, Bri, R, G, B...]
          // SOURCE LOCK CHECK
          if ((esp_timer_get_time() - g_last_serial_interaction) <
              SERIAL_TIMEOUT_US)
            continue;

          // Source Locking Logic (Anti-Flicker)
          int64_t now_us = esp_timer_get_time();
          uint32_t sender_ip = source_addr.sin_addr.s_addr;

          // 1. Check if lock expired (2 seconds)
          if (now_us - g_last_controller_time > 2000000) {
            g_controller_ip = 0; // Release lock
          }

          // 2. Enforce Lock
          if (g_controller_ip != 0 && g_controller_ip != sender_ip) {
            static int drop_log = 0;
            if (drop_log++ % 100 == 0) {
              ESP_LOGW(TAG,
                       "Dropped packet from unauthorized source (Locked).");
            }
            continue;
          }

          // 3. Update Lock
          g_controller_ip = sender_ip;
          g_last_controller_time = now_us;

          g_last_data_interaction = esp_timer_get_time(); // Refresh Timeout

          // ANTI-FLICKER: Sequence Number Check
          // Packet Format: [0x02, Bri, Seq, R, G, B...] (New Format) vs [0x02,
          // Bri, R, G, B...] (Old) We can heuristically detect if byte 2 is a
          // sequence number if we assume old format rarely changes. BETTER:
          // Just assume unsequenced for now, but enforces strict timing.

          // Simple Jitter Fix: If packet is older than last one (reordered),
          // drop it. Since we don't have seq num in current protocol, we rely
          // on arrival time. But UDP arrival time IS the order we see it.

          // The issue is likely partial updates or buffer tearing?
          // UDP ensures full message or nothing.

          // Real Issue: Direct immediate update causes tearing if update rate >
          // strip refresh rate. Fix: Enforce Min Frame Time (e.g. 15ms ~
          // 60fps).
          static int64_t last_frame_time = 0;
          if (now_us - last_frame_time < 15000) {
            continue; // Limit to ~66 FPS to prevent LED latching issues
          }
          last_frame_time = now_us;

          // Boot Loop Protection Reset
          // If we receive valid data, the system is working. Reset crash
          // counter.
          if (!g_has_received_data) {
            g_has_received_data = true; // DISABLE Timeout for this session

            // Reset NVS Boot Count
            nvs_handle_t nvs_handle;
            if (nvs_open("storage", NVS_READWRITE, &nvs_handle) == ESP_OK) {
              int32_t zero = 0;
              nvs_set_i32(nvs_handle, "boot_count", zero);
              nvs_commit(nvs_handle);
              nvs_close(nvs_handle);
              ESP_LOGI(TAG, "Valid Data Received. Boot Count Reset to 0.");
            }
          }

          static int pkt_count = 0;
          uint8_t *d = (uint8_t *)(rx_buffer + 2);
          if (pkt_count == 0 || pkt_count % 300 == 0) {
            ESP_LOGI(TAG, "UDP Data #%d (Len:%d, Bri:%d) 1st RGB: [%d,%d,%d]",
                     pkt_count, len, (uint8_t)rx_buffer[1], d[0], d[1], d[2]);
          }
          pkt_count++;

          uint8_t bri = (uint8_t)rx_buffer[1];
          int num = (len - 2) / 3;
          if (num > LED_STRIP_NUM_LEDS)
            num = LED_STRIP_NUM_LEDS;

          xSemaphoreTake(led_mutex, portMAX_DELAY);
          uint8_t *ptr = (uint8_t *)(rx_buffer + 2);
          for (int i = 0; i < num; i++) {
            led_colors[i].r = *ptr++;
            led_colors[i].g = *ptr++;
            led_colors[i].b = *ptr++;
          }
          clear_tail_leds(num);
          update_leds(bri);
          xSemaphoreGive(led_mutex);
        }
      }
    }
    close(sock);
  }
}

// ============ DNS SERVER (CAPTIVE PORTAL) ============
// Basic DNS Hijack: Answer ALL queries with our SoftAP IP
void task_dns_server(void *arg) {
  char rx_buffer[512];
  struct sockaddr_in dest_addr;
  dest_addr.sin_addr.s_addr = htonl(INADDR_ANY);
  dest_addr.sin_family = AF_INET;
  dest_addr.sin_port = htons(53);

  while (1) {
    if (!g_wifi_enabled) {
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (sock < 0) {
      vTaskDelay(pdMS_TO_TICKS(100));
      continue;
    }

    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    if (bind(sock, (struct sockaddr *)&dest_addr, sizeof(dest_addr)) < 0) {
      close(sock);
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    ESP_LOGI(TAG, "DNS Server Started");

    while (g_wifi_enabled) {
      struct sockaddr_in source_addr;
      socklen_t socklen = sizeof(source_addr);
      memset(rx_buffer, 0, sizeof(rx_buffer));
      int len = recvfrom(sock, rx_buffer, sizeof(rx_buffer) - 1, 0,
                         (struct sockaddr *)&source_addr, &socklen);

      if (len > 0) {
        // Get IP dynamically
        esp_netif_ip_info_t ip_info;
        esp_netif_t *netif = esp_netif_get_handle_from_ifkey("WIFI_AP_DEF");
        uint32_t my_ip = 0xC0A80401; // 192.168.4.1 default
        if (netif && esp_netif_get_ip_info(netif, &ip_info) == ESP_OK) {
          my_ip = ip_info.ip.addr;
        }

        // Craft Response from Query
        // Transaction ID (Bytes 0-1) is kept from query

        // Flags (Bytes 2-3): Standard Response (0x8000) | Authoritative
        // (0x0400) | No Error 0x8180 = QR(1)|Op(0000)|AA(1)|TC(0)|RD(1) |
        // RA(1)|Z(0)|RCODE(0)
        rx_buffer[2] = 0x81;
        rx_buffer[3] = 0x80;

        // QDCOUNT (Questions): Keep (usually 1)
        // ANCOUNT (Answers): Set to 1
        rx_buffer[6] = 0x00;
        rx_buffer[7] = 0x01;
        // NSCOUNT (Authority): 0
        rx_buffer[8] = 0x00;
        rx_buffer[9] = 0x00;
        // ARCOUNT (Additional): 0
        rx_buffer[10] = 0x00;
        rx_buffer[11] = 0x00;

        // Skip Question Section to append Answer
        // QNAME is [len, label, len, label, 0x00]
        int ptr = 12;
        while (ptr < len && rx_buffer[ptr] != 0) {
          int label_len = rx_buffer[ptr];
          ptr += label_len + 1;
        }
        ptr++;    // Skip 0x00 null terminator
        ptr += 4; // Skip QTYPE (2) and QCLASS (2)

        // Safely append Answer Record
        if (ptr <= sizeof(rx_buffer) - 16) {
          // Name: Pointer to 0x0C (Start of QNAME in Header)
          rx_buffer[ptr++] = 0xC0;
          rx_buffer[ptr++] = 0x0C;
          // TYPE: A (0x0001)
          rx_buffer[ptr++] = 0x00;
          rx_buffer[ptr++] = 0x01;
          // CLASS: IN (0x0001)
          rx_buffer[ptr++] = 0x00;
          rx_buffer[ptr++] = 0x01;
          // TTL: 60s
          rx_buffer[ptr++] = 0x00;
          rx_buffer[ptr++] = 0x00;
          rx_buffer[ptr++] = 0x00;
          rx_buffer[ptr++] = 0x3C;
          // RDLENGTH: 4
          rx_buffer[ptr++] = 0x00;
          rx_buffer[ptr++] = 0x04;
          // RDATA: IP Address
          memcpy(&rx_buffer[ptr], &my_ip, 4);
          ptr += 4;

          sendto(sock, rx_buffer, ptr, 0, (struct sockaddr *)&source_addr,
                 socklen);
        }
      }
    }
    close(sock);
  }
}

void led_init(void) {
  led_strip_config_t strip_config = {
      .strip_gpio_num = LED_STRIP_GPIO_PIN,
      .max_leds = LED_STRIP_NUM_LEDS,
      .led_model = LED_MODEL_WS2812,
      .led_pixel_format = LED_PIXEL_FORMAT_GRB,
      .flags = {.invert_out = false},
  };
  // SPI Configuration for Robustness against Wi-Fi Interrupts
  led_strip_spi_config_t spi_config = {
      .spi_bus = SPI2_HOST,
      .flags.with_dma = true,
  };
  ESP_ERROR_CHECK(
      led_strip_new_spi_device(&strip_config, &spi_config, &led_strip));
  led_strip_clear(led_strip);
  led_strip_refresh(led_strip);
}

void update_leds(uint8_t global_brightness) {
  float scale = global_brightness / 255.0;
  for (int i = 0; i < LED_STRIP_NUM_LEDS; i++) {
    led_strip_set_pixel(led_strip, i, led_colors[i].r * scale,
                        led_colors[i].g * scale, led_colors[i].b * scale);
  }
  led_strip_refresh(led_strip);
}

void disable_onboard_leds() {
  // Common Blue/Warm LED pins on C3 boards
  // Configured as OUTPUT and set HIGH (assuming active low)
  gpio_reset_pin(12);
  gpio_set_direction(12, GPIO_MODE_OUTPUT);
  gpio_set_level(12, 1);

  gpio_reset_pin(13);
  gpio_set_direction(13, GPIO_MODE_OUTPUT);
  gpio_set_level(13, 1);
}

void app_main(void) {
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
      ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    nvs_flash_erase();
    nvs_flash_init();
  }

  ESP_LOGW(TAG, "Reset Reason: %d", esp_reset_reason()); // Log why we rebooted
  ESP_LOGE(TAG, "=== FIRMWARE v1.10: MAX BRIGHTNESS (255) ===");

  disable_onboard_leds(); // Turn off onboard LEDs

  led_mutex = xSemaphoreCreateMutex();
  led_init();

  // Init Wi-Fi Driver once
  esp_netif_init();
  esp_event_loop_create_default();
  esp_netif_create_default_wifi_sta();
  esp_netif_create_default_wifi_ap();
  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  esp_wifi_init(&cfg);
  esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                      &event_handler, NULL, NULL);
  esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                      &event_handler, NULL, NULL);
  s_wifi_event_group = xEventGroupCreate();

  // Start Tasks MOVED to after Boot Anim to prevent Concurrency Crash

  // Initial State: Wi-Fi OFF.
  // If no Serial comes in 10s, Monitor will enable it.
  // If Serial works, Monitor will keep it off.

  // Boot Anim
  // Boot Anim (Dark Blue)
  for (int i = 0; i < 30; i++) {
    led_strip_set_pixel(led_strip, i, 0, 0, 50);
    led_strip_refresh(led_strip);
    vTaskDelay(pdMS_TO_TICKS(10));
  }
  led_strip_clear(led_strip);
  led_strip_refresh(led_strip);

  led_strip_clear(led_strip);
  led_strip_refresh(led_strip);

  ESP_LOGI(TAG, "Boot Anim Complete. Starting High Priority Tasks...");

  // Start Tasks NOW (After LED mutex is safe)
  // 1. Serial (Priority 10) - High enough for data, but yields to Wi-Fi/IDLE
  xTaskCreate(task_serial, "serial", 8192, NULL, 10, NULL);
  // 2. Monitor (Controls Wi-Fi State)
  xTaskCreate(task_monitor, "monitor", 5120, NULL, 12, NULL);
  // 3. UDP (Only needed for Wi-Fi)
  xTaskCreate(task_udp, "udp", 5120, NULL, 15, NULL);
  // 4. DNS
  xTaskCreate(task_dns_server, "dns", 4096, NULL, 5, NULL);

  // Start Wi-Fi immediately (Concurrent Mode)
  start_wifi_subsystem();

  ESP_LOGI(TAG, "System Ready. Serial & Wi-Fi Active.");
}

// ======================================================
// MQTT Implementation
// ======================================================

static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                               int32_t event_id, void *event_data) {
  esp_mqtt_event_handle_t event = event_data;
  if (event->event_id == MQTT_EVENT_CONNECTED) {
    ESP_LOGI(TAG, "MQTT Connected");
    g_mqtt_connected = true;

    // Reset Boot Count logic (Device is working via MQTT)
    nvs_handle_t nvs_handle;
    if (nvs_open("storage", NVS_READWRITE, &nvs_handle) == ESP_OK) {
      int32_t zero = 0;
      nvs_set_i32(nvs_handle, "boot_count", zero);
      nvs_commit(nvs_handle);
      nvs_close(nvs_handle);
    }

    // 1. Generate Unique ID from MAC (AF + Last 3 bytes)
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(g_device_id, sizeof(g_device_id), "AF%02X%02X%02X", mac[3], mac[4],
             mac[5]);

    // 2. Announce Discovery
    // Topic: alfred/discovery
    // Payload: {"id": "AF1101", "name": "Lampa AF1101"}
    char discovery_payload[128];
    snprintf(discovery_payload, sizeof(discovery_payload),
             "{\"id\": \"%s\", \"name\": \"Lampa %s\"}", g_device_id,
             g_device_id);
    esp_mqtt_client_publish(mqtt_client, "alfred/discovery", discovery_payload,
                            0, 1, 0);
    ESP_LOGI(TAG, "Sent Discovery: %s", discovery_payload);

    // 2.5 Home Assistant Discovery (Auto-Config)
    // Topic: homeassistant/light/<ID>/config
    char ha_topic[64];
    snprintf(ha_topic, sizeof(ha_topic), "homeassistant/light/%s/config",
             g_device_id);

    char ha_payload[1024];
    // Using "pl_on":"true" to match our existing logic
    snprintf(ha_payload, sizeof(ha_payload),
             "{\"name\":\"Lampa %s\",\"unique_id\":\"%s_light\","
             "\"cmd_t\":\"alfred/devices/%s/power\",\"stat_t\":\"alfred/"
             "devices/%s/power/state\","
             "\"pl_on\":\"true\",\"pl_off\":\"false\","
             "\"bri_cmd_t\":\"alfred/devices/%s/"
             "brightness\",\"bri_stat_t\":\"alfred/devices/%s/brightness/"
             "state\",\"bri_scl\":100,"
             "\"rgb_cmd_t\":\"alfred/devices/%s/"
             "color\",\"rgb_stat_t\":\"alfred/devices/%s/color/state\","
             "\"dev\":{\"ids\":[\"%s\"],\"name\":\"Ambilight "
             "Lampa\",\"mf\":\"Alfred\",\"mdl\":\"ESP32-C3\"}}",
             g_device_id, g_device_id, g_device_id, g_device_id, g_device_id,
             g_device_id, g_device_id, g_device_id, g_device_id);

    // QOS 1, Retain 1 (Critical for HA to see it after restart)
    esp_mqtt_client_publish(mqtt_client, ha_topic, ha_payload, 0, 1, 1);
    ESP_LOGI(TAG, "Sent HA Discovery to %s", ha_topic);

    // 3. Subscribe to UNIQUE Topics (Command path)
    // alfred/devices/<ID>/#
    char sub_topic[64];
    snprintf(sub_topic, sizeof(sub_topic), "alfred/devices/%s/#", g_device_id);
    esp_mqtt_client_subscribe(mqtt_client, sub_topic, 0);
    ESP_LOGI(TAG, "Subscribed to: %s", sub_topic);

    // 4. Publish Online Status
    char status_topic[64];
    snprintf(status_topic, sizeof(status_topic), "alfred/devices/%s/status",
             g_device_id);
    esp_mqtt_client_publish(mqtt_client, status_topic,
                            "{\"status\":\"online\"}", 0, 1, 0);

  } else if (event->event_id == MQTT_EVENT_DISCONNECTED) {
    ESP_LOGI(TAG, "MQTT Disconnected");
    g_mqtt_connected = false;
  } else if (event->event_id == MQTT_EVENT_DATA) {
    ESP_LOGI(TAG, "MQTT Data: %.*s", event->topic_len, event->topic);

    // Extract Topic
    char topic[128];
    if (event->topic_len < 127) {
      strncpy(topic, event->topic, event->topic_len);
      topic[event->topic_len] = 0;
    } else
      return;

    // Extract Payload
    char *payload = (char *)malloc(event->data_len + 1);
    if (!payload)
      return;
    memcpy(payload, event->data, event->data_len);
    payload[event->data_len] = 0;

    // 1. POWER COMMAND (alfred/devices/<ID>/power)
    if (strstr(topic, "/power") && !strstr(topic, "/state")) {
      if (payload[0] == '1' || strstr(payload, "true"))
        g_home_power = true;
      else
        g_home_power = false;
      ESP_LOGI(TAG, "MQTT Power CMD: %d", g_home_power);

      // FEEDBACK: Publish State
      char state_topic[64];
      snprintf(state_topic, sizeof(state_topic),
               "alfred/devices/%s/power/state", g_device_id);
      esp_mqtt_client_publish(mqtt_client, state_topic,
                              g_home_power ? "true" : "false", 0, 1, 0);
    }
    // 2. BRIGHTNESS COMMAND
    else if (strstr(topic, "/brightness") && !strstr(topic, "/state")) {
      int b = atoi(payload);
      if (b >= 0 && b <= 100)
        g_home_bri = b;
      ESP_LOGI(TAG, "MQTT Brightness CMD: %d", g_home_bri);

      // FEEDBACK: Publish State
      char state_topic[64];
      snprintf(state_topic, sizeof(state_topic),
               "alfred/devices/%s/brightness/state", g_device_id);
      char b_str[8];
      sprintf(b_str, "%d", g_home_bri);
      esp_mqtt_client_publish(mqtt_client, state_topic, b_str, 0, 1, 0);
    }
    // 3. COLOR COMMAND
    else if (strstr(topic, "/color") && !strstr(topic, "/state")) {
      sscanf(payload, "%hhu,%hhu,%hhu", &g_home_color.r, &g_home_color.g,
             &g_home_color.b);
      ESP_LOGI(TAG, "MQTT Color CMD: %d,%d,%d", g_home_color.r, g_home_color.g,
               g_home_color.b);

      // FEEDBACK: Publish State
      char state_topic[64];
      snprintf(state_topic, sizeof(state_topic),
               "alfred/devices/%s/color/state", g_device_id);
      char c_str[32];
      sprintf(c_str, "%d,%d,%d", g_home_color.r, g_home_color.g,
              g_home_color.b);
      esp_mqtt_client_publish(mqtt_client, state_topic, c_str, 0, 1, 0);
    }

    free(payload);

    // SOURCE LOCK CHECK: If Serial (JTAG) is active, ignore MQTT updates
    if ((esp_timer_get_time() - g_last_serial_interaction) <
        SERIAL_TIMEOUT_US) {
      // Serial is active, do not override LEDs
      return;
    }

    // IMMEDIATE UPDATE
    if ((esp_timer_get_time() - g_last_data_interaction) > 5000000) {
      xSemaphoreTake(led_mutex, portMAX_DELAY);
      if (g_home_power) {
        float factor = g_home_bri / 100.0f;
        uint8_t r = (uint8_t)(g_home_color.r * factor);
        uint8_t g = (uint8_t)(g_home_color.g * factor);
        uint8_t b = (uint8_t)(g_home_color.b * factor);
        for (int i = 0; i < LED_STRIP_NUM_LEDS; i++)
          led_strip_set_pixel(led_strip, i, r, g, b);
      } else {
        led_strip_clear(led_strip);
      }
      led_strip_refresh(led_strip);
      xSemaphoreGive(led_mutex);
    }
  }
}
void start_mqtt() {
  if (strlen(g_mqtt_uri) == 0) {
    ESP_LOGW(TAG, "MQTT not configured (Empty URI)");
    return;
  }

  // Generate Device ID first to ensure LWT topic is correct
  if (strlen(g_device_id) == 0) {
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    snprintf(g_device_id, sizeof(g_device_id), "AF%02X%02X%02X", mac[3], mac[4],
             mac[5]);
  }

  // Prepare LWT Topic
  static char lwt_topic[64];
  snprintf(lwt_topic, sizeof(lwt_topic), "alfred/devices/%s/status",
           g_device_id);

  esp_mqtt_client_config_t mqtt_cfg = {
      .broker.address.uri = g_mqtt_uri,
      .credentials.username = (strlen(g_mqtt_user) > 0) ? g_mqtt_user : NULL,
      .credentials.authentication.password =
          (strlen(g_mqtt_pass) > 0) ? g_mqtt_pass : NULL,
      // LWT Configuration
      .session.last_will.topic = lwt_topic,
      .session.last_will.msg = "{\"status\":\"offline\"}",
      .session.last_will.qos = 1,
      .session.last_will.retain = 1};

  ESP_LOGI(TAG, "Starting MQTT Client (URI: %s)...", g_mqtt_uri);

  mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
  if (!mqtt_client) {
    ESP_LOGE(TAG, "Failed to init MQTT client");
    return;
  }

  esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID,
                                 mqtt_event_handler, NULL);
  if (esp_mqtt_client_start(mqtt_client) != ESP_OK) {
    ESP_LOGE(TAG, "Failed to start MQTT client");
  }
}

void stop_mqtt() {
  if (mqtt_client) {
    ESP_LOGI(TAG, "Stopping MQTT Client...");
    esp_mqtt_client_stop(mqtt_client);
    esp_mqtt_client_destroy(mqtt_client);
    mqtt_client = NULL;
    g_mqtt_connected = false;
  }
}