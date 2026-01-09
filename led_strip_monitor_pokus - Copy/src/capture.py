
import threading
import time
import colorsys
from collections import deque
from typing import List, Tuple, Dict
import mss
import numpy as np
import cv2
from PyQt6.QtCore import QMutex
from state import AppState
from geometry import compute_segments, compute_calibrated_segments
from color_correction import apply_color_correction

ColorTuple = Tuple[int, int, int]

class CaptureThread(threading.Thread):
    """Screen Capture via MSS with Numpy optimization"""
    
    def __init__(self, app_state: AppState, capture_fps: int = 30):
        super().__init__(daemon=True)
        self.app_state = app_state
        self.capture_fps = capture_fps
        self.running = True
        self.sct = None
        
        # State
        self.mutex = QMutex()
        self.latest_colors = {}
        self.dominant_colors = [] # Cache for music mode
        self.monitors = []
        
        # Cache for geometry
        self._cached_segments_ver = -1
        self._cached_map = {}
        
        print(f"✓ CaptureThread initialized (MSS, {capture_fps} FPS)")

    def _recalc_geometry_cache(self, monitors):
        """Pre-calculate slice objects for all segments based on current monitor layout"""
        self._geom_cache = {}
        
        # Get per-edge scan depth values (with fallback to legacy scan_depth_percent)
        scan_depth_top = int(getattr(self.app_state, 'scan_depth_top', getattr(self.app_state, 'scan_depth_percent', 15)))
        scan_depth_bottom = int(getattr(self.app_state, 'scan_depth_bottom', getattr(self.app_state, 'scan_depth_percent', 15)))
        scan_depth_left = int(getattr(self.app_state, 'scan_depth_left', getattr(self.app_state, 'scan_depth_percent', 15)))
        scan_depth_right = int(getattr(self.app_state, 'scan_depth_right', getattr(self.app_state, 'scan_depth_percent', 15)))
        
        # Get per-edge padding values (with fallback to legacy padding_percent)
        padding_top = int(getattr(self.app_state, 'padding_top', getattr(self.app_state, 'padding_percent', 0)))
        padding_bottom = int(getattr(self.app_state, 'padding_bottom', getattr(self.app_state, 'padding_percent', 0)))
        padding_left = int(getattr(self.app_state, 'padding_left', getattr(self.app_state, 'padding_percent', 0)))
        padding_right = int(getattr(self.app_state, 'padding_right', getattr(self.app_state, 'padding_percent', 0)))
        
        for mon_idx, segs in self._cached_map.items():
            # Get Monitor Dimensions
            # MSS monitors include 'all' at 0, so mapping is mon_idx + 1 usually
            idx = mon_idx + 1
            if idx >= len(monitors): idx = 1 if len(monitors) > 1 else 0
            
            mon = monitors[idx]
            mon_w, mon_h = mon['width'], mon['height']
            
            # Calculate per-edge padding in pixels
            pad_top_px = int(mon_h * (padding_top / 100.0))
            pad_bottom_px = int(mon_h * (padding_bottom / 100.0))
            pad_left_px = int(mon_w * (padding_left / 100.0))
            pad_right_px = int(mon_w * (padding_right / 100.0))
            
            for seg in segs:
                # 1. Determine Pixel Range
                if seg.pixel_start == 0 and seg.pixel_end == 0:
                    # Legacy full edge
                    if seg.edge in ['top', 'bottom']: p_s, p_e = 0, mon_w
                    else: p_s, p_e = 0, mon_h
                else:
                    p_s, p_e = int(seg.pixel_start), int(seg.pixel_end)
                    
                # Scaling Logic
                if getattr(seg, 'ref_width', 0) > 0:
                    scale = mon_w / float(seg.ref_width)
                    p_s = int(p_s * scale)
                    p_e = int(p_e * scale)
                    
                # 2. Determine Depth / ROI with per-edge scan depth and padding
                if seg.edge == 'top':
                    depth = int(max(10, mon_h * (scan_depth_top / 100.0)))
                    roi_s = pad_top_px
                    roi_e = pad_top_px + depth
                    
                    # Clamp Y
                    roi_s = max(0, min(roi_s, mon_h - 1))
                    roi_e = max(roi_s + 1, min(roi_e, mon_h))
                    
                    # Clamp X (apply left/right padding)
                    p_s = max(pad_left_px, min(p_s, mon_w - pad_right_px - 1))
                    p_e = max(p_s + 1, min(p_e, mon_w - pad_right_px))
                    
                    roi_slice = (slice(roi_s, roi_e), slice(p_s, p_e))
                    
                elif seg.edge == 'bottom':
                    depth = int(max(10, mon_h * (scan_depth_bottom / 100.0)))
                    roi_s = mon_h - pad_bottom_px - depth
                    roi_e = mon_h - pad_bottom_px
                    
                    # Clamp Y
                    roi_s = max(0, min(roi_s, mon_h - 1))
                    roi_e = max(roi_s + 1, min(roi_e, mon_h))
                    
                    # Clamp X (apply left/right padding)
                    p_s = max(pad_left_px, min(p_s, mon_w - pad_right_px - 1))
                    p_e = max(p_s + 1, min(p_e, mon_w - pad_right_px))
                    
                    roi_slice = (slice(roi_s, roi_e), slice(p_s, p_e))
                    
                elif seg.edge == 'left':
                    depth = int(max(10, mon_w * (scan_depth_left / 100.0)))
                    roi_s = pad_left_px
                    roi_e = pad_left_px + depth
                    
                    # Clamp X
                    roi_s = max(0, min(roi_s, mon_w - 1))
                    roi_e = max(roi_s + 1, min(roi_e, mon_w))
                    
                    # Clamp Y (apply top/bottom padding)
                    p_s = max(pad_top_px, min(p_s, mon_h - pad_bottom_px - 1))
                    p_e = max(p_s + 1, min(p_e, mon_h - pad_bottom_px))
                    
                    roi_slice = (slice(p_s, p_e), slice(roi_s, roi_e))
                    
                else:  # right
                    depth = int(max(10, mon_w * (scan_depth_right / 100.0)))
                    roi_s = mon_w - pad_right_px - depth
                    roi_e = mon_w - pad_right_px
                    
                    # Clamp X
                    roi_s = max(0, min(roi_s, mon_w - 1))
                    roi_e = max(roi_s + 1, min(roi_e, mon_w))
                    
                    # Clamp Y (apply top/bottom padding)
                    p_s = max(pad_top_px, min(p_s, mon_h - pad_bottom_px - 1))
                    p_e = max(p_s + 1, min(p_e, mon_h - pad_bottom_px))
                    
                    roi_slice = (slice(p_s, p_e), slice(roi_s, roi_e))
                
                # Store
                self._geom_cache[id(seg)] = roi_slice

    def run(self):
        print("DEBUG: Capture Thread started (Waiting 2s warmup)...")
        time.sleep(2.0)
        
        # Initialize MSS
        with mss.mss() as sct:
            print(f"DEBUG: MSS Initialized. Monitors: {len(sct.monitors)}")
            self.sct = sct
            
            # Cache monitors for GUI
            self.mutex.lock()
            self.monitors = list(sct.monitors)
            self.mutex.unlock()
            
            frame_interval = 1.0 / self.capture_fps
            last_monitor_scan = 0  # For music mode periodic scan

            while self.running:
                # MODE-AWARE: Check if capture needed
                current_mode = getattr(self.app_state, 'mode', 'screen')
                
                if current_mode != "screen":
                    # Not screen mode - check if music + monitor colors
                    if current_mode == "music":
                        music_color_source = getattr(self.app_state, 'music_color_source', None)
                        if music_color_source == "monitor":
                            # Periodic scan every 2s (User Request)
                            if time.time() - last_monitor_scan < 2.0:
                                time.sleep(0.1)
                                continue
                            last_monitor_scan = time.time()
                            
                            # Perform background analysis
                            self._scan_dominant_colors()
                            # print("DEBUG: Music - monitor color scan done")
                        else:
                            # Music without monitor - idle
                            time.sleep(0.2)
                            continue
                    else:
                        # Light/PC mode - idle
                        time.sleep(0.2)
                        continue
                start_time = time.time()
                
                # 1. Get Segments
                segments = getattr(self.app_state, 'segments', [])
                if not segments:
                    time.sleep(0.1)
                    continue

                # 2. Update Cache if segments changed
                if id(segments) != self._cached_segments_ver:
                    self._cached_map = {}
                    # Group by Monitor
                    for seg in segments:
                        mid = getattr(seg, 'monitor_idx', 0)
                        if mid not in self._cached_map: self._cached_map[mid] = []
                        self._cached_map[mid].append(seg)
                    
                    # Pre-calculate Geometry Caches for all segments
                    # Structure: self._geom_cache[id(seg)] = (roi_slice, pixel_slice, width)
                    self._geom_cache = {} 
                    
                    # We need access to monitor dimensions. 
                    # We'll calculate lazy or just grab from current sct.monitors if available.
                    # Since we are in the loop, sct is available.
                    if self.sct:
                        self._recalc_geometry_cache(self.sct.monitors)
                        
                    self._cached_segments_ver = id(segments)
                
                captured_leds = {} # led_idx -> (r,g,b)

                try:
                    # 3. Capture Phase
                    for mon_idx, segs in self._cached_map.items():
                        # Map user monitor index to MSS index (MSS[0]=All, MSS[1]=Primary)
                        target_mss_idx = mon_idx + 1
                        if target_mss_idx >= len(sct.monitors):
                            target_mss_idx = 1 if len(sct.monitors) > 1 else 0
                            
                        monitor_def = sct.monitors[target_mss_idx]
                        sct_img = sct.grab(monitor_def)
                        
                        if sct_img is None: continue

                        # Raw Buffer -> Numpy (Zero Copy optimized)
                        pixels_raw = np.frombuffer(sct_img.bgra, dtype=np.uint8)
                        
                        # Reshape: H, W, 4 (BGRA)
                        # CRITICAL: Only proceed if buffer size matches expected dimensions
                        expected_size = sct_img.width * sct_img.height * 4
                        if len(pixels_raw) != expected_size:
                            print(f"WARNING: Malformed frame - buffer size {len(pixels_raw)} != expected {expected_size}")
                            continue  # Skip malformed frames
                        
                        # Reshape to 3D array (height, width, channels)
                        try:
                            pixels = pixels_raw.reshape((sct_img.height, sct_img.width, 4))
                        except ValueError as e:
                            print(f"ERROR: Failed to reshape pixels: {e}")
                            continue

                        h, w, _ = pixels.shape
                        
                        # Sanity check - dimensions should match monitor
                        if h == 0 or w == 0:
                            print(f"ERROR: Invalid pixel dimensions: {w}x{h}")
                            continue

                        # 4. Processing Phase (Optimized)
                        for seg in segs:
                            cnt = seg.length
                            if cnt <= 0: 
                                continue
                            
                            # Retrieve Pre-calculated Geometry
                            # We use id(seg) as key.
                            geom = self._geom_cache.get(id(seg))
                            if not geom: 
                                continue
                            
                            y_slice, x_slice = geom
                            
                            # Extract ROI directly
                            roi = pixels[y_slice, x_slice]
                            
                            # Sanity check for empty slice
                            if roi.size == 0: 
                                continue
                            
                            # Resize to match LED count (RESTORED original method)
                            try:
                                if seg.edge in ['top', 'bottom']:
                                    # Horizontal strip: Resize Width
                                    res = cv2.resize(roi, (cnt, 1), interpolation=cv2.INTER_AREA)
                                    colors = res[0] # (cnt, 4)
                                else:
                                    # Vertical strip: Resize Height
                                    res = cv2.resize(roi, (1, cnt), interpolation=cv2.INTER_AREA)
                                    colors = res[:, 0] # (cnt, 4)
                                    
                                # Map to Global Indices (BGRA -> RGB) + Apply Color Correction
                                for i, c in enumerate(colors):
                                    rgb = (int(c[2]), int(c[1]), int(c[0]))  # BGRA -> RGB
                                    
                                    # BASELINE COLOR ENHANCEMENT (ALWAYS ACTIVE)
                                    # This ensures vibrant colors even without ultra_saturation
                                    r, g, b = rgb
                                    r_norm, g_norm, b_norm = r / 255.0, g / 255.0, b / 255.0
                                    
                                    # Step 1: Mild saturation boost (1.2x) for better color vibrancy
                                    hue, sat, val = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
                                    sat = min(sat * 1.2, 1.0)  # Conservative 20% boost
                                    r_new, g_new, b_new = colorsys.hsv_to_rgb(hue, sat, val)
                                    
                                    # Step 2: Apply perceptual gamma correction (2.2)
                                    # LEDs appear brighter than monitors, so we slightly dim
                                    gamma = 2.2
                                    r_new = r_new ** (1.0 / gamma) if r_new > 0 else 0
                                    g_new = g_new ** (1.0 / gamma) if g_new > 0 else 0
                                    b_new = b_new ** (1.0 / gamma) if b_new > 0 else 0
                                    
                                    rgb = (int(r_new * 255), int(g_new * 255), int(b_new * 255))
                                    
                                    # ULTRA SATURATION (OPTIONAL AGGRESSIVE BOOST)
                                    # Apply ultra saturation if enabled (prevents washed-out colors)
                                    if hasattr(self.app_state, 'screen_mode') and \
                                       getattr(self.app_state.screen_mode, 'ultra_saturation', False):
                                        r, g, b = rgb
                                        
                                        # Step 1: HSV saturation boost
                                        r_norm, g_norm, b_norm = r / 255.0, g / 255.0, b / 255.0
                                        hue, sat, val = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
                                        
                                        boost = getattr(self.app_state.screen_mode, 'ultra_saturation_amount', 2.5)
                                        sat = min(sat * boost, 1.0)
                                        
                                        r_new, g_new, b_new = colorsys.hsv_to_rgb(hue, sat, val)
                                        
                                        # Step 2: ENHANCED - Amplify dominant channel, suppress weaker ones
                                        # This creates more distinct colors by increasing RGB channel contrast
                                        channels = [r_new, g_new, b_new]
                                        max_channel = max(channels)
                                        min_channel = min(channels)
                                        
                                        if max_channel > 0.1:  # Only if not too dark
                                            # Calculate contrast enhancement factor (higher = more aggressive)
                                            contrast_factor = min(boost / 10.0, 0.8)  # 0-0.8 range
                                            
                                            enhanced = []
                                            for ch in channels:
                                                if ch == max_channel:
                                                    # Boost dominant channel towards 1.0
                                                    enhanced_ch = ch + (1.0 - ch) * contrast_factor * 0.5
                                                else:
                                                    # Suppress weaker channels towards 0
                                                    enhanced_ch = ch * (1.0 - contrast_factor)
                                                
                                                enhanced.append(min(max(enhanced_ch, 0.0), 1.0))
                                            
                                            r_new, g_new, b_new = enhanced
                                        
                                        rgb = (int(r_new * 255), int(g_new * 255), int(b_new * 255))
                                    
                                    # Apply color calibration if enabled
                                    if hasattr(self.app_state, 'screen_mode'):
                                        try:
                                            rgb = apply_color_correction(rgb, self.app_state.screen_mode)
                                        except Exception as corr_err:
                                            # Fail silently - continue with uncorrected color
                                            pass
                                        
                                        # Map to led index
                                        led_idx = seg.led_start + i
                                        if seg.reverse:
                                            led_idx = seg.led_end - i
                                        
                                        # Store in captured LED map using (device_id, led_idx) key
                                        # This supports multiple devices with overlapping indices (e.g. both start at 0)
                                        dev_id = getattr(seg, 'device_id', None)
                                        captured_leds[(dev_id, led_idx)] = rgb
                                    
                            except Exception as e:
                                # Catch any per-segment processing errors
                                import traceback
                                print(f"ERROR processing segment {seg.edge}: {e}")
                                print(f"FULL TRACEBACK:")
                                traceback.print_exc()
                                continue

                    # 5. Push Results
                    self.mutex.lock()
                    self.latest_colors = captured_leds
                    self.mutex.unlock()

                except Exception as e:
                    import traceback
                    print(f"Capture Loop Error: {e}")
                    print("=== FULL TRACEBACK ===")
                    traceback.print_exc()
                    print("======================")
                    # Re-init attempt could go here if needed
                    time.sleep(1.0)

                # FPS Control
                elapsed = time.time() - start_time
                wait = max(0.001, frame_interval - elapsed)
                time.sleep(wait)

    def get_latest_colors(self) -> Dict[int, Tuple[int, int, int]]:
        self.mutex.lock()
        try:
            return self.latest_colors.copy()
        finally:
            self.mutex.unlock()

    def get_monitors_info(self):
        self.mutex.lock()
        try:
            return self.monitors if self.monitors else []
        finally:
            self.mutex.unlock()

    def _scan_dominant_colors(self, count=3):
        """
        Internal: Performs the heavy lifting of screen capture and analysis.
        Updates self.dominant_colors.
        """
        if not self.sct: return
        
        # Determine Monitor
        # AppState stores monitor index (0-based from UI)
        # MSS stores [All, Mon1, Mon2...] -> So +1 offset normally
        user_idx = getattr(self.app_state, 'monitor_index', 0)
        target_idx = user_idx + 1
        
        if target_idx >= len(self.sct.monitors):
            target_idx = 1 if len(self.sct.monitors) > 1 else 0
            
        monitor = self.sct.monitors[target_idx]
        
        try:
            sct_img = self.sct.grab(monitor)
            if not sct_img: return
            
            # Convert to numpy / BGRA
            pixels_raw = np.frombuffer(sct_img.bgra, dtype=np.uint8)
            img = pixels_raw.reshape((sct_img.height, sct_img.width, 4))
            
            # Downscale (100x100)
            small = cv2.resize(img, (100, 100), interpolation=cv2.INTER_AREA)
            pixels = small.reshape(-1, 4)
            
            from collections import Counter
            c = Counter()
            
            for p in pixels:
                b, g, r, a = p
                
                # Filter Black/White (Luminance)
                lum = 0.299*r + 0.587*g + 0.114*b
                if lum < 15: continue 
                if lum > 240: continue 
                
                # Filter Grays (Saturation)
                mx = max(r, g, b)
                mn = min(r, g, b)
                if (mx - mn) < 15: continue 
                
                # Quantize
                q = 32
                rq = int(r / q) * q
                gq = int(g / q) * q
                bq = int(b / q) * q
                
                c[(rq, gq, bq)] += 1
                
            # Top N
            common = c.most_common(count)
            results = [col for col, freq in common]
                
            # Fallbacks
            if not results:
                results = [(0, 0, 255), (0, 255, 0), (255, 0, 0)]
                
            while len(results) < count:
                results.append(results[0] if results else (0,0,255))
            
            # Update State safely
            self.mutex.lock()
            self.dominant_colors = results
            self.mutex.unlock()
            
        except Exception as e:
            print(f"Error in dominant color scan: {e}")

    def get_dominant_colors(self, count=3) -> List[Tuple[int, int, int]]:
        """Public fast getter"""
        self.mutex.lock()
        try:
            return self.dominant_colors.copy() if self.dominant_colors else []
        finally:
            self.mutex.unlock()

    def stop(self):
        self.running = False
        self.join(timeout=1.0)