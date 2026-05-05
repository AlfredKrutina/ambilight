# The following lines of boilerplate have to be in your project's CMakeLists
# in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
# Na IDF 5.5+ je CA bundle uvnitř mbedtls; samostatná komponenta esp_crt_bundle už není v CMake grafu.
# Plný graf komponent (MINIMAL_BUILD OFF) je pro lampu v pořádku (HTTPS OTA, MQTT, Wi‑Fi).
idf_build_set_property(MINIMAL_BUILD OFF)
# Verze v esp_app_desc (OTA / manifest / log)
set(PROJECT_VER "1.12.0")
project(ambilight_esp32c6)
