import re

path = r"c:/Users/alfid/ESP_Projects/led_strip_monitor_pokus - Copy/esp32c3_lamp_firmware/main/ambilight.c"

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Define the target block to replace (UDP Timeout)
# We match loosely on the LOG message and the surrounding structure
# "if(was_pc_mode && ... ESP_LOGI(TAG, "PC Data Stopped. Restoring Home Mode.") ... }"

# Regex to find the block
# We look for the line with 5000000, then the log, then the block content until closing brace of that if
pattern = r'(if\s*\(was_pc_mode\s*&&\s*\(esp_timer_get_time\(\)\s*-\s*g_last_data_interaction\)\s*>\s*5000000\)\s*\{.*?ESP_LOGI\(TAG,\s*"PC Data Stopped\. Restoring Home Mode\."\);.*?\}\s*\}\s*if)'

replacement = r'''// 2.5s Silence (Auto-Off)
                 if(was_pc_mode && (esp_timer_get_time() - g_last_data_interaction) > 2500000) { 
                       ESP_LOGI(TAG, "PC Data Stopped. Turning Off.");
                       was_pc_mode = false;
                       g_has_received_data = false;
                       
                       // APP CLOSED -> TURN OFF
                       g_home_power = false; // Force OFF
                       
                       xSemaphoreTake(led_mutex, portMAX_DELAY);
                       update_leds(0); // Clear
                       xSemaphoreGive(led_mutex);

                       // SYNC MQTT
                       if(g_mqtt_connected) {
                           char state_topic[64];
                           // 1. Power State -> OFF
                           snprintf(state_topic, sizeof(state_topic), "alfred/devices/%s/power/state", g_device_id);
                           esp_mqtt_client_publish(mqtt_client, state_topic, "false", 0, 1, 0);

                           // 2. Color State
                           snprintf(state_topic, sizeof(state_topic), "alfred/devices/%s/color/state", g_device_id);
                           char c_str[32]; sprintf(c_str, "%d,%d,%d", g_home_color.r, g_home_color.g, g_home_color.b);
                           esp_mqtt_client_publish(mqtt_client, state_topic, c_str, 0, 1, 0);
                       }
                 }
            }

            if'''

# Use re.DOTALL to match newlines
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

if new_content == content:
    print("FAILED: match not found")
else:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("SUCCESS: Patched ambilight.c")
