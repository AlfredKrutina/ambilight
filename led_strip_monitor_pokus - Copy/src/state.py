# src/state.py

from dataclasses import dataclass, field
from typing import List, Tuple
import time

ColorTuple = Tuple[int, int, int]  # (R, G, B)


@dataclass
class AppState:
    """Global application state"""
    
    # User settings
    enabled: bool = True
    brightness: int = 80          # 0-100%
    sensitivity: int = 80         # 0-100%
    color_mode: str = "normal"    # "normal", "inverted", "saturated"
    smooth_ms: int = 100          # 0-500ms
    
    # Screen Mode
    scan_depth_percent: int = 15  # 10-50% (Legacy - used in simple mode)
    padding_percent: int = 0      # 0-10% (Legacy - used in simple mode)
    
    # Per-edge padding (0-20%)
    padding_top: int = 0
    padding_bottom: int = 0
    padding_left: int = 0
    padding_right: int = 0
    
    # Per-edge scan depth (5-50%)
    scan_depth_top: int = 15
    scan_depth_bottom: int = 15
    scan_depth_left: int = 15
    scan_depth_right: int = 15
    
    saturation_boost: float = 1.0 # 1.0 - 2.0
    min_brightness: int = 5       # 0-50
    gamma: float = 1.0
    monitor_index: int = 1
    calibration_points: list = None # [TL, TR, BR, BL]
    capture_method: str = "mss" # "mss", "dxcam"
    
    profile: str = "gaming"
    
    # Serial
    serial_port: str = "COM3"
    autostart: bool = False

    # Music Mode
    mode: str = "screen"          # "screen", "music"
    music_color_source: str = "fixed" # "fixed", "monitor"
    music_color_lock: bool = False # Feature: Lock Palette
    auto_gain_enabled: bool = False # Feature: AGC
    fixed_color: Tuple[int, int, int] = (255, 0, 0)
    audio_device_index: int = None
    
    # Runtime
    # Runtime
    TOTAL_LEDS = 200
    
    current_colors: List[ColorTuple] = field(default_factory=lambda: [(0, 0, 0)] * 66)
    target_colors: List[ColorTuple] = field(default_factory=lambda: [(0, 0, 0)] * 66)
    last_update_time: float = 0.0
    last_interpolate_time: float = 0.0
    
    # Status
    serial_connected: bool = False
    capture_running: bool = False
    
    def update_targets(self, colors: List[ColorTuple]):
        """Nastav cílové barvy (Strict Validation)"""
        if len(colors) != self.TOTAL_LEDS:
            # print(f"DEBUG: update_targets got {len(colors)}, resizing to {self.TOTAL_LEDS}")
            if len(colors) < self.TOTAL_LEDS:
                colors.extend([(0,0,0)] * (self.TOTAL_LEDS - len(colors)))
            else:
                colors = colors[:self.TOTAL_LEDS]
                
        self.target_colors = colors
        # Note: We don't verify time here for interpolation, EMA handles it
    
    def interpolate_colors(self) -> List[ColorTuple]:
        """Vrátí interpolované barvy (Exponential Moving Average)"""
        now = time.time()
        if self.last_interpolate_time == 0:
            self.last_interpolate_time = now 
            
        dt_ms = (now - self.last_interpolate_time) * 1000
        self.last_interpolate_time = now
        
        # Calculate alpha
        if self.smooth_ms <= 0:
            alpha = 1.0
        else:
            # Alpha ~ how much of the gap to cover in this step
            # If dt_ms = 33ms and smooth_ms = 100ms, alpha = 0.33
            alpha = min(1.0, dt_ms / float(self.smooth_ms))
        
        smoothed = []
        for i in range(len(self.current_colors)):
            c = self.current_colors[i]
            t = self.target_colors[i]
            
            # Simple EMA
            r = c[0] + (t[0] - c[0]) * alpha
            g = c[1] + (t[1] - c[1]) * alpha
            b = c[2] + (t[2] - c[2]) * alpha
            
            smoothed.append((r, g, b))
        
        # Ulož float hodnoty (pro přesnost příště) nebo int?
        # Pro jednoduchost zde ukládáme zaokrouhlené, 
        # ale pro super-smooth by to chtělo držet float state.
        # Tady to stačí takto:
        
        self.current_colors = smoothed # Update state!
        
        return [(int(c[0]), int(c[1]), int(c[2])) for c in smoothed]