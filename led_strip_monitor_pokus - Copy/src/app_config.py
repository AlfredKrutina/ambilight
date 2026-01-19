import json
import os
from dataclasses import dataclass, field, asdict, fields
from typing import List, Optional, Dict, Tuple
import uuid
from constants import DEFAULTS, AppMode, LightEffect, MusicEffect, ScanMode # Import constants if needed
from utils import is_mac

# --- PRESETS DEFINITIONS ---

SCREEN_PRESETS = {
    "Movie":   {"saturation_boost": 1.8, "min_brightness": 10, "interpolation_ms": 150, "gamma": 1.3},
    "Gaming":  {"saturation_boost": 1.2, "min_brightness": 2,  "interpolation_ms": 30,  "gamma": 1.0},
    "Desktop": {"saturation_boost": 1.0, "min_brightness": 0,  "interpolation_ms": 80,  "gamma": 1.0}
}

MUSIC_PRESETS = {
    "Party":      {"bass_sensitivity": 80, "mid_sensitivity": 70, "high_sensitivity": 70},
    "Chill":      {"bass_sensitivity": 40, "mid_sensitivity": 40, "high_sensitivity": 40},
    "Bass Focus": {"bass_sensitivity": 90, "mid_sensitivity": 30, "high_sensitivity": 20},
    "Vocals":     {"bass_sensitivity": 40, "mid_sensitivity": 90, "high_sensitivity": 40}
}

# --- SUB-SETTINGS CLASSES ---

@dataclass
class LightModeSettings:
    """
    @brief Configuration for Static/Effect Light Mode.
    @details
    Controls the behavior of the LED strip when in 'Light' mode, including
    static colors and pre-programmed effects (breathing, rainbow, etc.).
    """
    color: Tuple[int, int, int] = (255, 200, 100) # Warm White default
    brightness: int = 200
    effect: str = "static" # static, breathing, rainbow, chase
    speed: int = 50 # 1-100
    extra: int = 50 # Generic parameter (Min Brightness, Trail, Saturation)
    custom_zones: List[dict] = field(default_factory=list) # List of zone definitions
    homekit_enabled: bool = False # Control via MQTT (HomeKit) overrides PC control


@dataclass
class DeviceSettings:
    """configuration for a single LED Controller (ESP32)"""
    id: str = field(default_factory=lambda: str(uuid.uuid4())[:8])
    name: str = "Primary Controller"
    type: str = "serial" # serial, wifi
    
    # Connection Details
    port: str = "" # Serial Port (empty = auto-detect)
    ip_address: str = "" # Wi-Fi IP
    udp_port: int = 4210 # Wi-Fi Port
    
    led_count: int = 66
    led_offset: int = 0 # Logical offset if creating a virtual span
    
    # Optional: If this device is dedicated to one monitor, we can help auto-wizard
    # But Segments are the ultimate source of truth.
    default_monitor: int = 1
    
    # NEW: Control via Home Assistant (disables sending from PC App)
    control_via_ha: bool = False


@dataclass
class GlobalSettings:
    """
    @brief Global Application Settings.
    @details
    Contains settings that apply application-wide, such as serial connection parameters,
    LED count, and startup behavior.
    """
    # Legacy Single-Port fields (Deprecated but kept for now)
    serial_port: str = "" # Empty = auto-detect
    baud_rate: int = 115200
    led_count: int = 66
    
    # NEW: Multi-Device Support
    devices: List[DeviceSettings] = field(default_factory=list)
    
    start_mode: str = "screen" # light, screen, music
    start_minimized: bool = False
    autostart: bool = False
    
    theme: str = "dark"
    
    # New Advanced Features
    capture_method: str = "mss" # mss, dxcam (gpu)
    hotkeys_enabled: bool = True
    hotkey_toggle: str = "ctrl+shift+l"
    hotkey_mode_light: str = ""
    hotkey_mode_screen: str = ""
    hotkey_mode_music: str = ""
    custom_hotkeys: List[Dict] = field(default_factory=list) # [{name, action, payload, key}]



@dataclass
class SpotifySettings:
    enabled: bool = False
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    use_album_colors: bool = True
    client_id: Optional[str] = None
    client_secret: Optional[str] = None

@dataclass
class MetricMapping:
    """Single metric visualization configuration"""
    metric: str = "cpu_usage"  # cpu_usage, cpu_temp, gpu_usage, gpu_temp, ram_usage
    zones: List[str] = field(default_factory=lambda: ["right"])  # left, right, top, bottom
    color_scale: str = "blue_green_red"  # blue_green_red, cool_warm, cyan_yellow, rainbow, custom
    
    # Custom Gradient Colors
    color_low: Tuple[int, int, int] = (0, 0, 255)    # Blue
    color_mid: Tuple[int, int, int] = (0, 255, 0)    # Green
    color_high: Tuple[int, int, int] = (255, 0, 0)   # Red
    
    min_value: float = 0.0
    max_value: float = 100.0
    
    # Brightness Control
    brightness_mode: str = "static" # static, dynamic
    brightness: int = 200 # Used for static
    brightness_min: int = 50 # Used for dynamic
    brightness_max: int = 255 # Used for dynamic
    
    enabled: bool = True



@dataclass
class PCHealthSettings:
    """PC Health monitoring mode configuration"""
    enabled: bool = False
    update_rate: int = 500  # milliseconds
    brightness: int = 200
    metrics: List[Dict] = field(default_factory=list)  # List of metric configs
    
    def get_default_metrics(self):
        """Returns default metric mappings"""
        return [
            {
                "metric": "cpu_temp",
                "zones": ["right"],
                "color_scale": "blue_green_red",
                "min_value": 30.0,
                "max_value": 90.0,
                "brightness": 200,
                "enabled": True
            },
            {
                "metric": "gpu_usage",
                "zones": ["top"],
                "color_scale": "blue_green_red",
                "min_value": 0.0,
                "max_value": 100.0,
                "brightness": 200,
                "enabled": True
            },
            {
                "metric": "ram_usage",
                "zones": ["left"],
                "color_scale": "cyan_yellow",
                "min_value": 0.0,
                "max_value": 100.0,
                "brightness": 150,
                "enabled": True
            }
        ]

# --- MAIN CONFIG CLASS ---

@dataclass
class LedSegment:
    led_start: int = 0
    led_end: int = 0
    monitor_idx: int = 0
    edge: str = "top"
    depth: int = 10
    reverse: bool = False
    
    # Multi-Device Mapping
    # If None, defaults to the first available device
    device_id: Optional[str] = None
    
    # Pixel coordinates for precise ROI extraction
    # For top/bottom edges: horizontal pixel range (x_start, x_end)
    # For left/right edges: vertical pixel range (y_start, y_end)
    pixel_start: int = 0
    pixel_end: int = 0
    
    # Reference Resolution (Monitor dimensions at time of creation)
    # Essential for scaling coordinates when monitor changes
    ref_width: int = 0
    ref_height: int = 0
    
    # Music Effect Override (default implies global setting)
    music_effect: str = "default" 
    
    # NEW: Frequency Role for Orchestrated Effects
    role: str = "auto" # auto, bass, mid, high, all
    
    @property
    def length(self):
        return abs(self.led_end - self.led_start) + 1
        
    def to_dict(self):
        return asdict(self)
        
    @staticmethod
    def from_dict(d):
        # Backward compatibility: old configs won't have pixel_start/pixel_end
        if 'pixel_start' not in d: d['pixel_start'] = 0
        if 'pixel_end' not in d: d['pixel_end'] = 0
        if 'music_effect' not in d: d['music_effect'] = "default"
        if 'role' not in d: d['role'] = "auto"
        # Backward compatibility: old configs won't have ref_width/ref_height
        if 'ref_width' not in d: d['ref_width'] = 0
        if 'ref_height' not in d: d['ref_height'] = 0
        return LedSegment(**d)

@dataclass
class ScreenModeSettings:
    monitor_index: int = 1
    scan_depth_percent: int = 10
    padding_percent: int = 5
    saturation_boost: float = 1.2
    ultra_saturation: bool = False  # NEW: Aggressive saturation boost for vibrant colors
    ultra_saturation_amount: float = 2.5  # How much to boost (1.0 = normal, 2.5 = very vibrant)
    min_brightness: int = 10
    interpolation_ms: int = 100
    gamma: float = 2.2
    active_preset: str = "Balanced"
    calibration_points: Optional[List[Dict]] = None
    brightness: int = 200
    
    # Color Calibration - ENHANCED with Profiles
    color_calibration: Optional[Dict] = None  # DEPRECATED - kept for backward compat
    calibration_profiles: Dict[str, Dict] = field(default_factory=dict)  # {"Day": {calibration}, "Night": {calibration}}
    active_calibration_profile: str = "Default"  # Which profile is currently active
    
    # NEW: Advanced Scan Zone Configuration
    scan_mode: str = "simple"  # "simple" or "advanced"
    
    # Per-edge padding (0-20%)
    padding_top: int = 0
    padding_bottom: int = 0
    padding_left: int = 0
    padding_right: int = 0
    
    # Per-edge scan depth (5-50%)
    scan_depth_top: int = 10
    scan_depth_bottom: int = 10
    scan_depth_left: int = 10
    scan_depth_right: int = 10
    
    # NEW: Segment List
    segments: List[LedSegment] = field(default_factory=list)

@dataclass
class MusicModeSettings:
    """
    @brief Configuration for Music Visualization Mode.
    @details
    Parameters controlling the audio reactive mode, including sensitivity, effects,
    frequency band colors, and audio source selection.
    """
    # Audio Source
    audio_device_index: Optional[int] = None # None = Default Loopback
    mic_enabled: bool = False
    
    # Visuals
    color_source: str = "fixed" # fixed, genre, monitor
    fixed_color: Tuple[int, int, int] = (255, 0, 0)
    brightness: int = 200
    
    # Logic
    beat_detection_enabled: bool = True
    beat_threshold: float = 1.5
    
    effect: str = "energy" # energy, spectrum, vumeter, strobe
    sensitivity: int = 50 # 1-100 gain
    bass_sensitivity: int = 50 # Added for reactive_bass
    mid_sensitivity: int = 50 # Added for missing attribute
    high_sensitivity: int = 50 # Added for reactive_bass
    global_sensitivity: int = 50 # 1-100 Global Gain Master
    
    # 7-Band Colors (Bass -> High)
    sub_bass_color: Tuple[int, int, int] = (255, 0, 0)
    bass_color: Tuple[int, int, int] = (255, 50, 0)
    low_mid_color: Tuple[int, int, int] = (255, 100, 0)
    mid_color: Tuple[int, int, int] = (0, 255, 0)
    high_mid_color: Tuple[int, int, int] = (0, 255, 255)
    presence_color: Tuple[int, int, int] = (0, 0, 255)
    brilliance_color: Tuple[int, int, int] = (255, 0, 255)

    # Decoupled UI: Fixed Color Store
    fixed_color: Tuple[int, int, int] = (255, 0, 255) # Default Magenta
    
    # Auto Gain / Strobe
    auto_gain: bool = False
    auto_mid: bool = False 
    auto_high: bool = False
    smoothing_ms: int = 70
    min_brightness: int = 0
    rotation_speed: int = 20
    active_preset: str = "Custom"

    # Extensions (Previously here, keeping them)
    # Note: Spotify/PCHealth were moved to AppConfig in my recent design,
    # but the Loading Logic in Step 921 seemed to load them into AppConfig.
    # However, the previous 'class MusicModeSettings' had them?
    # No, Step 944 showed them in MusicModeSettings by mistake?
    # Let's keep MusicModeSettings pure for music.
    # Spotify/PCHealth are in AppConfig.


# --- MAIN CONFIG CLASS ---

@dataclass
class AppConfig:
    """
    @brief Root Configuration Class.
    @details
    Aggregates all other configuration classes into a single structure.
    Handles loading (deserialization) and migration of configuration profiles.
    """
    global_settings: GlobalSettings = field(default_factory=GlobalSettings)
    light_mode: LightModeSettings = field(default_factory=LightModeSettings)
    screen_mode: ScreenModeSettings = field(default_factory=ScreenModeSettings)
    music_mode: MusicModeSettings = field(default_factory=MusicModeSettings)
    
    # New Extensions
    spotify: SpotifySettings = field(default_factory=SpotifySettings)
    pc_health: PCHealthSettings = field(default_factory=PCHealthSettings)
    
    # User Custom Presets
    user_screen_presets: Dict[str, dict] = field(default_factory=dict)
    user_music_presets: Dict[str, dict] = field(default_factory=dict)

    @staticmethod
    def load(profile_name: str = "default.json") -> 'AppConfig':
        """Load config with migration support from old flat format if needed"""
        
        def sanitize_calibration(calib_dict):
            """Replace NaN values with safe defaults to prevent JSON corruption issues"""
            import math
            if not isinstance(calib_dict, dict):
                return calib_dict
            
            # Fix gamma array NaN values
            if 'gamma' in calib_dict and isinstance(calib_dict['gamma'], list):
                calib_dict['gamma'] = [
                    1.0 if (isinstance(g, float) and math.isnan(g)) else (g if g is not None else 1.0)
                    for g in calib_dict['gamma']
                ]
            
            # Fix gain array NaN values
            if 'gain' in calib_dict and isinstance(calib_dict['gain'], list):
                calib_dict['gain'] = [
                    1.0 if (isinstance(g, float) and math.isnan(g)) else (g if g is not None else 1.0)
                    for g in calib_dict['gain']
                ]
            
            return calib_dict
        
        if not profile_name.endswith(".json"): 
            profile_name += ".json"
            
        path = f"config/{profile_name}"
        if not os.path.exists("config"):
            os.makedirs("config")
            
        if not os.path.exists(path):
            return AppConfig()
            
        try:
            with open(path, 'r') as f:
                data = json.load(f)
            
            # Check if it's new structure (has 'global_settings')
            if "global_settings" in data:
                cfg = AppConfig() # Initialize with defaults
                data_json = data # Renaming for clarity

                # Global
                g_data = data_json.get('global_settings', {})
                
                # Migration: Populate devices list if empty
                if "devices" in g_data:
                    # Deserialize objects
                    raw_devs = g_data.pop("devices", [])
                    dev_objs = [DeviceSettings(**d) for d in raw_devs]
                else:
                    # Legacy Migration: Create Default Device from top-level port
                    dev_objs = [DeviceSettings(
                        id="primary",
                        name="Primary Controller",
                        port=g_data.get("serial_port", ""),  # Empty = auto-detect
                        led_count=g_data.get("led_count", 66)
                    )]
                
                g_keys = {f.name for f in fields(GlobalSettings)}
                g_clean = {k: v for k, v in g_data.items() if k in g_keys}
                
                # Platform validation: DXCAM is Windows-only
                if is_mac() and g_clean.get("capture_method") == "dxcam":
                    print("⚠️  DXCAM is not available on macOS, switching to MSS")
                    g_clean["capture_method"] = "mss"
                
                cfg.global_settings = GlobalSettings(**g_clean)
                cfg.global_settings.devices = dev_objs # Assign manual list

                # Light
                light_data = data_json.get("light_mode", {})
                
                # Migration: animation_type -> effect
                if "animation_type" in light_data:
                    light_data["effect"] = light_data.pop("animation_type")
                
                # Migration: animation_speed -> speed
                if "animation_speed" in light_data:
                    light_data["speed"] = light_data.pop("animation_speed")
                
                # Light with Filtering
                light_keys = {f.name for f in fields(LightModeSettings)}
                light_clean = {k: v for k, v in light_data.items() if k in light_keys}
                cfg.light_mode = LightModeSettings(**light_clean)
                
                # Screen Logic (Structured)
                if "screen_mode" in data_json:
                    sm_data = data_json["screen_mode"]
                    if "monitor_index" not in sm_data: sm_data["monitor_index"] = 1
                    if "gamma" not in sm_data: sm_data["gamma"] = 1.0
                    
                    # CRITICAL: Force int conversion for fields used in numpy slicing
                    # These may be floats in JSON and cause TypeError in capture.py
                    if "scan_depth_percent" in sm_data:
                        sm_data["scan_depth_percent"] = int(sm_data["scan_depth_percent"])
                    if "padding_percent" in sm_data:
                        sm_data["padding_percent"] = int(sm_data["padding_percent"])
                    if "monitor_index" in sm_data:
                        sm_data["monitor_index"] = int(sm_data["monitor_index"])
                    
                    # CRITICAL: Sanitize calibration data to fix NaN corruption
                    if "color_calibration" in sm_data:
                        sm_data["color_calibration"] = sanitize_calibration(sm_data["color_calibration"])
                    
                    if "calibration_profiles" in sm_data and isinstance(sm_data["calibration_profiles"], dict):
                        for prof_name in list(sm_data["calibration_profiles"].keys()):
                            sm_data["calibration_profiles"][prof_name] = sanitize_calibration(
                                sm_data["calibration_profiles"][prof_name]
                            )
                    
                    # Extract Segments
                    segs = []
                    if "segments" in sm_data:
                        seg_list = sm_data.pop("segments")
                        for s in seg_list:
                            segs.append(LedSegment(**s))
                    
                    sm_keys = {f.name for f in fields(ScreenModeSettings)}
                    sm_clean = {k: v for k, v in sm_data.items() if k in sm_keys}
                    cfg.screen_mode = ScreenModeSettings(**sm_clean)
                    cfg.screen_mode.segments = segs # Assign back

                # Music Logic (Structured)
                if "music_mode" in data_json:
                    mm_data = data_json["music_mode"]
                    
                    # Migration: visualization_type -> effect
                    if "visualization_type" in mm_data:
                        legacy = mm_data.pop("visualization_type")
                        if "effect" not in mm_data:
                            mm_data["effect"] = legacy
                    
                    # Migration: 3-band colors -> 7-band colors
                    if "sub_bass_color" not in mm_data and "bass_color" in mm_data:
                        # Old 3-band system detected, migrate to 7-band
                        bass_c = mm_data.get("bass_color", (255, 0, 0))
                        mid_c = mm_data.get("mid_color", (0, 255, 0))
                        high_c = mm_data.get("high_color", (0, 0, 255))
                        
                        # Create gradient from bass -> mid -> high
                        mm_data["sub_bass_color"] = bass_c
                        mm_data["bass_color"] = bass_c  # Keep bass
                        mm_data["low_mid_color"] = tuple(int((bass_c[i] + mid_c[i]) / 2) for i in range(3))
                        mm_data["mid_color"] = mid_c  # Keep mid
                        mm_data["high_mid_color"] = tuple(int((mid_c[i] + high_c[i]) / 2) for i in range(3))
                        mm_data["presence_color"] = high_c  # Keep high
                        mm_data["brilliance_color"] = high_c
                        
                    mm_keys = {f.name for f in fields(MusicModeSettings)}
                    mm_clean = {k: v for k, v in mm_data.items() if k in mm_keys}
                    cfg.music_mode = MusicModeSettings(**mm_clean)
                    
                    # Load User Presets
                    cfg.user_screen_presets = data_json.get("user_screen_presets", {})
                    cfg.user_music_presets = data_json.get("user_music_presets", {})

                # New Extensions Loading

                    
                if "spotify" in data_json:
                    s_data = data_json["spotify"]
                    s_keys = {f.name for f in fields(SpotifySettings)}
                    s_clean = {k: v for k, v in s_data.items() if k in s_keys}
                    cfg.spotify = SpotifySettings(**s_clean)
                    
                if "pc_health" in data_json:
                    ph_data = data_json["pc_health"]
                    ph_keys = {f.name for f in fields(PCHealthSettings)}
                    ph_clean = {k: v for k, v in ph_data.items() if k in ph_keys}
                    cfg.pc_health = PCHealthSettings(**ph_clean)

                return cfg
                
        except Exception as e:
            print(f"✗ Error loading config: {e}")
            return AppConfig()

    def save(self, profile_name: str = "default.json"):
        if not profile_name.endswith(".json"): 
            profile_name += ".json"
            
        if not os.path.exists("config"):
            os.makedirs("config")
        path = f"config/{profile_name}"
        
        try:
            with open(path, 'w') as f:
                json.dump(asdict(self), f, indent=4)
            print(f"✓ Config saved to {path}")
        except Exception as e:
            print(f"✗ Error saving config: {e}")
