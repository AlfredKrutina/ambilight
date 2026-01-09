idf_component_register(SRCS "ambilight.c"
                       INCLUDE_DIRS "."
                       PRIV_REQUIRES esp_driver_rmt led_strip driver esp_timer nvs_flash esp_wifi esp_netif esp_event lwip esp_http_server mqtt mdns)
