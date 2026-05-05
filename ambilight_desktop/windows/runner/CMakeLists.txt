cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "now_playing_channel.cpp"
  "screen_capture_channel.cpp"
  "screen_capture_dxgi.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "gdi32.lib" "user32.lib" "d3d11.lib" "dxgi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# GSMTC (Windows.Media.Control) — OBJECT knihovna s /EHsc; runner jinak používá _HAS_EXCEPTIONS=0.
set(_AMBILIGHT_CPPWINRT "")
if(DEFINED ENV{WindowsSdkDir} AND DEFINED ENV{WindowsSDKVersion})
  file(TO_CMAKE_PATH "$ENV{WindowsSdkDir}" _WIN_SDK_DIR)
  set(_TRY_CPPWINRT "${_WIN_SDK_DIR}/Include/$ENV{WindowsSDKVersion}/cppwinrt")
  if(EXISTS "${_TRY_CPPWINRT}/winrt/Windows.Media.Control.h")
    set(_AMBILIGHT_CPPWINRT "${_TRY_CPPWINRT}")
  endif()
endif()
if(_AMBILIGHT_CPPWINRT STREQUAL "")
  file(GLOB _KIT_INCLUDES LIST_DIRECTORIES true
    "C:/Program Files (x86)/Windows Kits/10/Include/10.*")
  list(SORT _KIT_INCLUDES COMPARE NATURAL ORDER DESCENDING)
  foreach(_INC IN LISTS _KIT_INCLUDES)
    if(EXISTS "${_INC}/cppwinrt/winrt/Windows.Media.Control.h")
      set(_AMBILIGHT_CPPWINRT "${_INC}/cppwinrt")
      break()
    endif()
  endforeach()
endif()
if(NOT _AMBILIGHT_CPPWINRT STREQUAL "")
  add_library(now_playing_winrt_obj OBJECT "now_playing_winrt.cpp")
  target_compile_features(now_playing_winrt_obj PUBLIC cxx_std_20)
  target_compile_options(now_playing_winrt_obj PRIVATE /EHsc /W4 /wd4100 /bigobj)
  target_compile_definitions(now_playing_winrt_obj PRIVATE "NOMINMAX" "UNICODE" "_UNICODE")
  target_include_directories(now_playing_winrt_obj PRIVATE "${_AMBILIGHT_CPPWINRT}")
  target_sources(${BINARY_NAME} PRIVATE $<TARGET_OBJECTS:now_playing_winrt_obj>)
  target_link_libraries(${BINARY_NAME} PRIVATE windowsapp)
else()
  target_sources(${BINARY_NAME} PRIVATE "now_playing_winrt_stub.cpp")
  message(WARNING "cppwinrt nenalezen — now_playing použije stub (žádný náhled z OS média).")
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
