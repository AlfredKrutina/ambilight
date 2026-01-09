from enum import Enum, auto

class AppMode(str, Enum):
    LIGHT = "light"
    SCREEN = "screen"
    MUSIC = "music"

class LightEffect(str, Enum):
    STATIC = "static"
    BREATHING = "breathing"
    RAINBOW = "rainbow"
    CHASE = "chase"
    CUSTOM_ZONES = "custom_zones"

class MusicEffect(str, Enum):
    SPECTRUM = "spectrum"
    ENERGY = "energy"
    STROBE = "strobe"
    VUMETER = "vumeter"
    VUMETER_SPECTRUM = "vumeter_spectrum"

class ScanMode(str, Enum):
    EDGES = "edges"
    CORNERS = "corners"
    FULL = "full"

class LedLayout(str, Enum):
    RECTANGLE = "rectangle"

class PCHealthMode(str, Enum):
    CPU_GPU_RAM = "cpu_gpu_ram"
    TEMPERATURES = "temps"
    NETWORK = "network"

# Default fallback values (if config is missing or corrupt)
DEFAULTS = {
    "serial_port": "COM5",
    "baud_rate": 115200,
    "theme": "dark",
    "led_count": 66,
}
