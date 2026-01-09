
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
        self.monitors = []
        
        # Cache for geometry
        self._cached_segments_ver = -1
        self._cached_map = {}
        
        print(f"✓ CaptureThread initialized (MSS, {capture_fps} FPS)")

    def run(self):
        try:
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
                    try:
                        # MODE-AWARE: Check if capture needed
                        current_mode = getattr(self.app_state, 'mode', 'screen')
                        
                        if current_mode != "screen":
                            # Not screen mode - check if music + monitor colors
                            if current_mode == "music":
                                music_color_source = getattr(self.app_state, 'music_color_source', None)
                                if music_color_source == "monitor":
                                    # Periodic scan every 10s
                                    if time.time() - last_monitor_scan < 10.0:
                                        time.sleep(0.2)
                                        continue
                                    last_monitor_scan = time.time()
                                    print("DEBUG: Music - monitor color scan")
                                else:
                                    # Music without monitor - idle
                                    time.sleep(0.2)
                                    continue
                            else:
                                # Light/PC mode - idle
                                time.sleep(0.2)
                                continue
                        start_time = time.time()
                        
                        # ... rest of capture logic continues normally ...
                        # (keeping all existing code from line 79 onwards)
                        
                    except KeyboardInterrupt:
                        print("DEBUG: Capture thread interrupted by user")
                        break
                    except Exception as frame_error:
                        # Single frame error - log but don't crash
                        print(f"ERROR: Frame processing failed: {frame_error}")
                        time.sleep(0.1)
                        continue
                        
        except KeyboardInterrupt:
            print("DEBUG: Capture thread shutting down (user interrupt)")
        except Exception as fatal_error:
            print(f"FATAL: Capture thread crashed: {fatal_error}")
            import traceback
            traceback.print_exc()
        finally:
            self.running = False
            print("DEBUG: Capture thread stopped")
        
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
                            # Periodic scan every 10s
                            if time.time() - last_monitor_scan < 10.0:
                                time.sleep(0.2)
                                continue
                            last_monitor_scan = time.time()
                            print("DEBUG: Music - monitor color scan")
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
                    for seg in segments:
                        mid = getattr(seg, 'monitor_idx', 0)
                        if mid not in self._cached_map: self._cached_map[mid] = []
                        self._cached_map[mid].append(seg)
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

                        # 4. Processing Phase
                        for seg in segs:
                            cnt = seg.length
                            if cnt <= 0: 
                                continue
                            
                            # Get monitor dimensions - CRITICAL: Force Python int (not numpy.int64)
                            mon_w, mon_h = int(w), int(h)
                            
                            # Determine segment pixel range
                            # New segments have pixel_start/pixel_end set by wizard
                            # Old segments (backward compat) have pixel_start=0, pixel_end=0
                            if seg.pixel_start == 0 and seg.pixel_end == 0:
                                # Fallback for old configs: use full edge (old behavior)
                                if seg.edge in ['top', 'bottom']:
                                    pixel_start, pixel_end = 0, mon_w
                                else:  # left, right
                                    pixel_start, pixel_end = 0, mon_h
                            else:
                                # Use segment's precise pixel coordinates
                                pixel_start, pixel_end = seg.pixel_start, seg.pixel_end
                            
                            # CRITICAL FIX: Force int conversion on segment coordinates
                            # These may be loaded as floats from JSON config!
                            pixel_start = int(pixel_start)
                            pixel_end = int(pixel_end)
                            
                            # Calculate dynamic depth from SEGMENT width, not monitor width
                            segment_dimension = pixel_end - pixel_start
                            if segment_dimension <= 0:
                                continue
                            
                            # CRITICAL FIX: Force int conversion on config values that may be floats
                            scan_depth_pct = int(getattr(self.app_state, 'scan_depth_percent', 15))
                            padding_pct = int(getattr(self.app_state, 'padding_percent', 0))
                            
                            if seg.edge in ['top', 'bottom']:
                                # Vertical depth (how far down/up from edge)
                                depth_px = int(max(10, mon_h * (scan_depth_pct / 100.0)))
                            else:  # left, right
                                # Horizontal depth (how far in from edge)
                                depth_px = int(max(10, mon_w * (scan_depth_pct / 100.0)))
                            
                            # FIXED: Apply padding to avoid screen borders
                            pad_h = int(mon_h * (padding_pct / 100.0))
                            pad_w = int(mon_w * (padding_pct / 100.0))
                            
                            # CRITICAL: Validate boundaries BEFORE extraction
                            # This prevents empty ROI and provides clear error messages
                            if seg.edge in ['top', 'bottom']:
                                roi_start = int(pad_h) if seg.edge == 'top' else int(mon_h - pad_h - depth_px)
                                roi_end = int(pad_h + depth_px) if seg.edge == 'top' else int(mon_h - pad_h)
                                
                                if roi_start >= roi_end or roi_start < 0 or roi_end > mon_h:
                                    print(f"ERROR: Invalid {seg.edge} ROI bounds: y[{roi_start}:{roi_end}] for monitor height {mon_h}")
                                    print(f"  → scan_depth: {scan_depth_pct}%, depth_px: {depth_px}, pad_h: {pad_h}")
                                    continue
                                    
                                if pixel_start >= pixel_end or pixel_start < 0 or pixel_end > mon_w:
                                    print(f"ERROR: Invalid pixel range: x[{pixel_start}:{pixel_end}] for monitor width {mon_w}")
                                    continue
                            else:  # left, right
                                roi_start = int(pad_w) if seg.edge == 'left' else int(mon_w - pad_w - depth_px)
                                roi_end = int(pad_w + depth_px) if seg.edge == 'left' else int(mon_w - pad_w)
                                
                                if roi_start >= roi_end or roi_start < 0 or roi_end > mon_w:
                                    print(f"ERROR: Invalid {seg.edge} ROI bounds: x[{roi_start}:{roi_end}] for monitor width {mon_w}")
                                    print(f"  → scan_depth: {scan_depth_pct}%, depth_px: {depth_px}, pad_w: {pad_w}")
                                    continue
                                    
                                if pixel_start >= pixel_end or pixel_start < 0 or pixel_end > mon_h:
                                    print(f"ERROR: Invalid pixel range: y[{pixel_start}:{pixel_end}] for monitor height {mon_h}")
                                    continue
                            
                            # Extract ROI with precise pixel range AND padding
                            # CRITICAL: Wrap ALL arithmetic in int() for numpy slicing
                            if seg.edge == 'top':
                                # Start pad_h pixels from top, scan depth_px deep
                                roi = pixels[int(pad_h):int(pad_h+depth_px), int(pixel_start):int(pixel_end), :]
                            elif seg.edge == 'bottom':
                                # End pad_h pixels before bottom, scan depth_px deep
                                roi = pixels[int(mon_h-pad_h-depth_px):int(mon_h-pad_h), int(pixel_start):int(pixel_end), :]
                            elif seg.edge == 'left':
                                # Start pad_w pixels from left, scan depth_px wide
                                roi = pixels[int(pixel_start):int(pixel_end), int(pad_w):int(pad_w+depth_px), :]
                            elif seg.edge == 'right':
                                # End pad_w pixels before right, scan depth_px wide
                                roi = pixels[int(pixel_start):int(pixel_end), int(mon_w-pad_w-depth_px):int(mon_w-pad_w), :]
                            else:
                                continue  # Invalid edge
                            
                            # Validate ROI is not empty before cv2.resize
                            if roi.size == 0 or roi.shape[0] == 0 or roi.shape[1] == 0:
                                print(f"WARNING: Empty ROI for segment {seg.edge} (LED {seg.led_start}-{seg.led_end})")
                                print(f"  → Monitor: {mon_w}x{mon_h}, Depth: {depth_px}px, Padding: h={pad_h}px w={pad_w}px")
                                print(f"  → Pixel range: {pixel_start}-{pixel_end}")
                                print(f"  → ROI shape: {roi.shape}")
                                print(f"  → Scan depth: {scan_depth_pct}%, Padding: {padding_pct}%")
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
                                    
                                if seg.reverse:
                                    colors = colors[::-1]
                                    
                                # Map to Global Indices (BGRA -> RGB) + Apply Color Correction
                                for i, c in enumerate(colors):
                                    rgb = (int(c[2]), int(c[1]), int(c[0]))  # BGRA -> RGB
                                    
                                    # BASELINE COLOR ENHANCEMENT (ALWAYS ACTIVE)
                                    # This ensures vibrant colors even without ultra_saturation
                                    r, g, b = rgb
                                    r_norm, g_norm, b_norm = r / 255.0, g / 255.0, b / 255.0
                                    
                                    # Step 1: Mild saturation boost (1.2x) for better color vibrancy
                                    h, s, v = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
                                    s = min(s * 1.2, 1.0)  # Conservative 20% boost
                                    r_new, g_new, b_new = colorsys.hsv_to_rgb(h, s, v)
                                    
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
                                        h, s, v = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
                                        
                                        boost = getattr(self.app_state.screen_mode, 'ultra_saturation_amount', 2.5)
                                        s = min(s * boost, 1.0)
                                        
                                        r_new, g_new, b_new = colorsys.hsv_to_rgb(h, s, v)
                                        
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
                                        
                                        # Map to global LED index
                                        global_idx = seg.led_start + i
                                        if seg.reverse:
                                            global_idx = seg.led_end - i
                                        
                                        # Store in captured LED map
                                        if 0 <= global_idx < 66:
                                            captured_leds[global_idx] = rgb
                                    
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

    def stop(self):
        self.running = False
        self.join(timeout=1.0)