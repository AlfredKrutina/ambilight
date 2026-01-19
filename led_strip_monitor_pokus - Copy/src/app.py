import time
import traceback
import math
import colorsys
import copy
from typing import Tuple, List, Optional
from PyQt6.QtWidgets import QApplication, QMessageBox
from PyQt6.QtCore import QTimer
from utils import is_mac

# Try to import keyboard library with graceful degradation
KEYBOARD_AVAILABLE = False
try:
    import keyboard
    KEYBOARD_AVAILABLE = True
except ImportError:
    print("⚠️  Keyboard library not available - hotkeys will be disabled")
except Exception as e:
    print(f"⚠️  Keyboard library error: {e} - hotkeys will be disabled")

# Modules
from state import AppState
from app_config import AppConfig
from capture import CaptureThread
# from state import AppState # Removed duplicate
# from app_config import AppConfig # Removed duplicate 
# from capture import CaptureThread # Removed duplicate
from modules.device_manager import DeviceManager
from audio_processor import AudioProcessor
from ui.main_window import MainWindow, TrayIcon
from ui.settings_dialog import SettingsDialog
from modules.process_monitor import ProcessMonitor
from modules.system_monitor import SystemMonitor
from modules.spotify_client import SpotifyClient


class AmbiLightApplication:
    """Hlavní aplikace – orchestrace všech komponent (Architecture v2)"""
    
    def __init__(self, qt_app: QApplication, silent_start: bool = False, config_profile: str = "default.json"):
        self.qt_app = qt_app
        self.silent_start = silent_start
        self.config_profile = config_profile
        
        # 1. LOAD CONFIG
        self.config = AppConfig.load(config_profile)
        
        # 2. APPLY THEME
        from ui.themes import get_theme
        qt_app.setStyleSheet(get_theme(self.config.global_settings.theme))
        
        # 3. INITIALIZE STATE
        self.app_state = AppState()
        self.animation_tick = 0
        self.startup_frame = 0
        self.startup_active = True
        
        # Strobe state
        self.strobe_avg = 0.5
        self.strobe_cooldown = 0
        self.strobe_intensity = 0.0 # For fadeout
        
        # Energy state
        self.energy_val = 0.0
        
        # State sync moved after components init
        
        # 4. AUDIO PROCESSOR
        self.audio_processor = AudioProcessor(
            device_index=self.config.music_mode.audio_device_index
        )
        self.audio_processor.start()
        
        # Initialize mode tracking for resource optimization
        self.audio_processor.current_mode = self.config.global_settings.start_mode
        
        self._sync_state_from_config()
        
        # 4.1. NEW MONITORS
        self.process_monitor = ProcessMonitor()
        self.system_monitor = SystemMonitor()
        self.spotify_client = SpotifyClient(
            self.config.spotify.client_id,
            self.config.spotify.client_secret
        )

        
        # 5. DEVICE MANAGER (Multi-Device)
        self.serial_manager = DeviceManager()
        self.serial_manager.update_devices(self.config.global_settings.devices)
        # Old signal handlers need adaptation if we want global status, 
        # but for now SerialManager handles connection internally per device.
        
        # 6. CAPTURE THREAD
        self.capture_thread = CaptureThread(self.app_state)
        self.capture_thread.start()
        # print("DEBUG: Capture Thread START disabled for isolation")
        
        # 7. UI CONSTRUCTION
        self.main_window = MainWindow()
        self.tray_icon = TrayIcon(self.main_window)
        
        # Signals
        self.tray_icon.toggle_signal.connect(self._on_toggle_enabled)
        self.tray_icon.settings_signal.connect(self._on_show_settings)
        self.tray_icon.quit_signal.connect(self._on_quit)
        self.tray_icon.mode_signal.connect(self._on_tray_mode)
        self.tray_icon.preset_signal.connect(self._on_tray_preset)
        
        self.main_window.toggle_signal.connect(self._on_toggle_enabled)
        self.main_window.settings_signal.connect(self._on_show_settings)
        
        self.tray_icon.show()
        if not silent_start and not self.config.global_settings.start_minimized:
            self.main_window.show()
            
        self.main_window.set_status(f"Mode: {self.config.global_settings.start_mode.upper()}")
        
        # 8. UPDATE LOOP (30Hz)
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._on_update_loop)
        self.update_timer.start(33) 
        
        # State
        self.preview_override_color = None # For full strip preview
        self.preview_pixel_override = None # For single pixel wizard (index, r, g, b)
        self.preview_timer = 0
        self.calibration_active = None # Holds active calibration corner ("top_left", etc)
        
        # Music State
        self.agc_max = 0.5
        self.last_palette = None # Cache for Color Lock
        
        # 9. GLOBAL HOTKEYS
        self._init_hotkeys()
        
        print(f"✓ AmbiLight v2 started. Mode: {self.config.global_settings.start_mode}")

    @property
    def active_config(self):
        """Returns preview config if active, else real config"""
        if hasattr(self, 'config_preview') and self.config_preview:
            return self.config_preview
        return self.config

    def _init_hotkeys(self):
        """Setup Global Hotkeys with graceful degradation"""
        if not KEYBOARD_AVAILABLE:
            if self.config.global_settings.hotkeys_enabled:
                print("⚠️  Hotkeys are enabled in config but keyboard library is not available")
                if is_mac():
                    print("   On macOS, keyboard hotkeys require accessibility permissions.")
                    print("   Please grant accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility")
                # Show UI warning only once
                if not hasattr(self, '_hotkey_warning_shown'):
                    self._show_hotkey_warning()
                    self._hotkey_warning_shown = True
            return
        
        if not self.config.global_settings.hotkeys_enabled:
            return

        try:
            keyboard.unhook_all()
            
            # Helper
            def reg(key, func):
                if key and key != "<None>":
                    print(f"DEBUG: Registering hotkey '{key}'")
                    try: 
                        keyboard.add_hotkey(key, func)
                        print(f"DEBUG: Registered '{key}' successfully")
                    except Exception as e: 
                        print(f"✗ Invalid Hotkey '{key}': {e}")
                        # On Mac, this might be a permissions issue
                        if is_mac() and "permission" in str(e).lower():
                            if not hasattr(self, '_hotkey_warning_shown'):
                                self._show_hotkey_warning()
                                self._hotkey_warning_shown = True

            # Register
            reg(self.config.global_settings.hotkey_toggle, self._toggle_lights_hotkey)
            
            # Modes (Use lambda wrapper for thread safety dispatch)
            reg(self.config.global_settings.hotkey_mode_light, lambda: self._switch_mode_threadsafe("light"))
            reg(self.config.global_settings.hotkey_mode_screen, lambda: self._switch_mode_threadsafe("screen"))
            reg(self.config.global_settings.hotkey_mode_music, lambda: self._switch_mode_threadsafe("music"))
            
            # Custom Hotkeys
            for hk in self.config.global_settings.custom_hotkeys:
                # Capture Action/Payload in closure
                act = hk.get('action')
                pay = hk.get('payload')
                reg(hk.get('key'), lambda a=act, p=pay: self._execute_custom_action(a, p))
            
            print(f"✓ Hotkeys Initialized")
        except Exception as e:
            print(f"✗ Hotkey Error: {e}")
            if is_mac():
                if not hasattr(self, '_hotkey_warning_shown'):
                    self._show_hotkey_warning()
                    self._hotkey_warning_shown = True

    def _show_hotkey_warning(self):
        """Show UI warning about hotkey permissions"""
        try:
            msg = QMessageBox(self.main_window)
            msg.setIcon(QMessageBox.Icon.Warning)
            msg.setWindowTitle("Hotkeys Disabled")
            if is_mac():
                msg.setText("Keyboard hotkeys require accessibility permissions on macOS.")
                msg.setInformativeText(
                    "To enable hotkeys:\n"
                    "1. Open System Preferences\n"
                    "2. Go to Security & Privacy > Privacy > Accessibility\n"
                    "3. Add AmbiLight to the list and enable it\n"
                    "4. Restart the application"
                )
            else:
                msg.setText("Keyboard hotkeys are not available.")
                msg.setInformativeText("The keyboard library could not be initialized.")
            msg.setStandardButtons(QMessageBox.StandardButton.Ok)
            msg.exec()
        except Exception as e:
            print(f"Could not show hotkey warning dialog: {e}")

    def _switch_mode_threadsafe(self, mode):
        """Dispatch mode switch to Main Thread"""
        QTimer.singleShot(0, lambda: self._on_tray_mode(mode))

    def _execute_custom_action(self, action, payload):
        """Handle custom hotkeys"""
        print(f"DEBUG: _execute_custom_action called for {action}")
        # Dispatch to Main Thread
        QTimer.singleShot(0, lambda: self._handle_action_main_thread(action, payload))

    def _handle_action_main_thread(self, action, payload):
        """Execute logic in main thread"""
        print(f"Hotkey Action: {action}")
        
        # --- BRIGHTNESS ---
        if action == "bright_up":
            self._adjust_brightness(10) # +10% (approx 25 steps)
        elif action == "bright_down":
            self._adjust_brightness(-10)
        elif action == "bright_max":
            self._set_brightness_absolute(255)
        elif action == "bright_min":
            self._set_brightness_absolute(25)
            
        # --- POWER ---
        elif action == "toggle_power":
            self._on_toggle_enabled(not self.app_state.enabled)
            
        # --- MODES ---
        elif action.startswith("mode_"):
            target = None
            if action == "mode_music": target = "music"
            elif action == "mode_screen": target = "screen"
            elif action == "mode_light": target = "light"
            elif action == "mode_next":
                modes = ["screen", "music", "light"]
                curr = self.config.global_settings.start_mode
                try:
                    idx = modes.index(curr)
                    target = modes[(idx + 1) % len(modes)]
                except: target = "screen"
            
            if target:
                self._on_tray_mode(target)
                
        # --- PRESETS / EFFECTS ---
        elif action == "effect_next":
            self._cycle_effect()
        elif action == "preset_next":
            self._cycle_preset()
            
        # --- SPECIAL ---
        elif action == "calib_auto":
            # Just reset to full for now
            self.config.screen_mode.calibration_points = None
            self.config.save(self.config_profile)
            self._sync_state_from_config()
            print("Hotkey: Calibration Reset")

    def _set_brightness_absolute(self, val):
        """Helper to set exact brightness"""
        current = self._get_current_brightness()
        delta = val - current
        self._adjust_brightness(delta)

    def _get_current_brightness(self):
        mode = self.config.global_settings.start_mode
        if mode == "light": return self.config.light_mode.brightness
        elif mode == "music": return self.config.music_mode.brightness
        elif mode == "screen": return self.config.screen_mode.brightness
        return 100

    def _cycle_effect(self):
        mode = self.config.global_settings.start_mode
        if mode == "light":
            effs = ["rainbow", "chase", "breathing", "static"]
            curr = self.config.light_mode.effect
            try: next_eff = effs[(effs.index(curr) + 1) % len(effs)]
            except: next_eff = effs[0]
            self.config.light_mode.effect = next_eff
            print(f"Cycle Effect: {next_eff}")
        elif mode == "music":
            effs = ["spectrum", "energy", "strobe", "vumeter"]
            curr = self.config.music_mode.effect
            try: next_eff = effs[(effs.index(curr) + 1) % len(effs)]
            except: next_eff = effs[0]
            self.config.music_mode.effect = next_eff
            print(f"Cycle Effect: {next_eff}")
            
        self.config.save(self.config_profile)
        self._sync_state_from_config()
        self.main_window.set_status(f"Effect: {self.config.music_mode.effect.upper() if mode=='music' else self.config.light_mode.effect.upper()}")

    def _cycle_preset(self):
        # Placeholder for preset cycling
        pass

    def _adjust_brightness(self, delta):
        mode = self.config.global_settings.start_mode
        new_val = 0
        
        if mode == "light":
            self.config.light_mode.brightness = max(0, min(255, self.config.light_mode.brightness + delta))
            new_val = self.config.light_mode.brightness
        elif mode == "screen":
            self.config.screen_mode.brightness = max(0, min(255, self.config.screen_mode.brightness + delta))
            new_val = self.config.screen_mode.brightness
        elif mode == "music":
            self.config.music_mode.brightness = max(0, min(255, self.config.music_mode.brightness + delta))
            new_val = self.config.music_mode.brightness
            
        print(f"Brightness ({mode}): {new_val}")
        self.config.save(self.config_profile)
        self._sync_state_from_config()

    def _toggle_lights_hotkey(self):
        """Called from keyboard thread"""
        new_state = not self.app_state.enabled
        print(f"Hotkey: Lights {'ON' if new_state else 'OFF'}")
        # Dispatch to Main Thread
        QTimer.singleShot(0, lambda: self._on_toggle_enabled(new_state))

    def _on_settings_changed(self):
        """Reload configuration-dependent resources"""
        print("DEBUG: _on_settings_changed triggered")
        
        # 1. Sync AppState from Config (CRITICAL for music_color_source!)
        self._sync_state_from_config()
        
        # 2. Update App State limits
        self.app_state.target_fps = self.config.global_settings.refresh_rate
        # Sync Segments to AppState for CaptureThread
        self.app_state.segments = self.config.screen_mode.segments
        
        # 3. Re-init Capture Thread if needed (e.g. invalid segments?)
        # For now, just updating segments list is thread-safe enough if list is atomic swap.
        
        # 4. Audio Config Update
        if self.audio_processor:
            self.audio_processor.update_settings(self.config.music_mode)
            
        # 5. Brightness/Gamma (Handled in main loop usually)
        
        # 6. Serial logic?
        # If baud rate changed, might need reconnect.
        # But we don't have that in UI yet.


    def _on_mode_change(self, new_mode: str):
        """Handle mode changes and optimize resources"""
        old_mode = getattr(self.app_state, 'mode', 'screen')
        print(f"⟳ Mode Change: {old_mode} → {new_mode}")
        
        self.app_state.mode = new_mode
        
        # Resource optimization
        if new_mode == "screen":
            print("  → Screen: ENABLED | Audio: PAUSED")
            if hasattr(self, 'audio_processor'):
                self.audio_processor.current_mode = new_mode
            
        elif new_mode == "music":
            print("  → Screen: PERIODIC | Audio: ENABLED")
            if hasattr(self, 'audio_processor'):
                self.audio_processor.current_mode = new_mode
            
        elif new_mode in ["light", "pc_health"]:
            print("  → Screen: IDLE | Audio: PAUSED")
            if hasattr(self, 'audio_processor'):
                self.audio_processor.current_mode = new_mode
        
        # Update tray and main window icons
        if hasattr(self, 'tray_icon'):
            self.tray_icon.set_mode(new_mode)
        if hasattr(self, 'main_window'):
            self.main_window.set_mode(new_mode)
        
        # Update config
        self.config.global_settings.start_mode = new_mode
        self.config.save()
        
        print(f"✓ Mode: {new_mode}")

    def _sync_state_from_config(self):
        """Propagate generic config values to AppState"""
        # Use mode handler for resource optimization
        self._on_mode_change(self.config.global_settings.start_mode)
        
        # Optimization: Pause Audio Processor if not needed
        if hasattr(self, 'audio_processor') and self.audio_processor:
            is_music = (self.app_state.mode == "music")
            self.audio_processor.set_paused(not is_music)
        
        # LED count is fixed 66 for now in logic, but let's respect global if we make it dynamic later
        
        # Set scan params for capture
        self.app_state.segments = self.config.screen_mode.segments  # NOTE: Stored by reference (no deep copy)
        self.app_state.calibration_points = self.config.screen_mode.calibration_points
        
        # Legacy scan depth and padding (for backward compatibility)
        self.app_state.scan_depth_percent = self.config.screen_mode.scan_depth_percent
        self.app_state.padding_percent = self.config.screen_mode.padding_percent
        
        # Per-edge scan depth and padding (for advanced mode)
        self.app_state.scan_depth_top = getattr(self.config.screen_mode, 'scan_depth_top', self.config.screen_mode.scan_depth_percent)
        self.app_state.scan_depth_bottom = getattr(self.config.screen_mode, 'scan_depth_bottom', self.config.screen_mode.scan_depth_percent)
        self.app_state.scan_depth_left = getattr(self.config.screen_mode, 'scan_depth_left', self.config.screen_mode.scan_depth_percent)
        self.app_state.scan_depth_right = getattr(self.config.screen_mode, 'scan_depth_right', self.config.screen_mode.scan_depth_percent)
        
        self.app_state.padding_top = getattr(self.config.screen_mode, 'padding_top', self.config.screen_mode.padding_percent)
        self.app_state.padding_bottom = getattr(self.config.screen_mode, 'padding_bottom', self.config.screen_mode.padding_percent)
        self.app_state.padding_left = getattr(self.config.screen_mode, 'padding_left', self.config.screen_mode.padding_percent)
        self.app_state.padding_right = getattr(self.config.screen_mode, 'padding_right', self.config.screen_mode.padding_percent)
        
        self.app_state.color_sampling = getattr(self.config.screen_mode, 'color_sampling', 'median')  # NEW
        self.app_state.saturation_boost = self.config.screen_mode.saturation_boost
        self.app_state.min_brightness = self.config.screen_mode.min_brightness
        self.app_state.music_color_source = self.config.music_mode.color_source
        
        # Audio
        self.app_state.gamma = self.config.screen_mode.gamma
        self.app_state.monitor_index = self.config.screen_mode.monitor_index
        
        # Screen mode specific - sync to AppState for capture thread
        if self.app_state.mode == 'screen':
            self.app_state.screen_mode = self.config.screen_mode  # Full object for ultra_saturation
        
        # Hardware / Capture
        # Platform validation: DXCAM is Windows-only
        capture_method = self.config.global_settings.capture_method
        if is_mac() and capture_method == "dxcam":
            print("⚠️  DXCAM is not available on macOS, using MSS instead")
            capture_method = "mss"
        self.app_state.capture_method = capture_method

    def _on_update_loop(self):
        """
        @brief Main Application Update Loop.
        @details
        Called periodically (approx 30-60ms) by QTimer.
        Dispatch logic:
        1. Checks for startup animation.
        2. Routes execution to the active mode processor (Light, Screen, Music, PC Health).
        3. Updates application state (AppState).
        4. Sends final color frame to SerialHandler.
        
        Handles exceptions gracefully to prevent application crash on single frame errors.
        """
        # DEBUG TRACE
        # print(f"Loop Tick: {self.animation_tick}")
        
        self.animation_tick += 1
        
        # UI Status Update (1Hz)
        if self.animation_tick % 30 == 0:
            self._update_connection_status_ui()
        
        # 0. STARTUP ANIMATION
        if self.startup_active:
            if self.startup_frame > 60:
                print("DEBUG: Startup Done.")
                self.startup_active = False
            else:
                 colors = self._process_startup_animation()
                 self.startup_frame += 1
                 if self.serial_manager:
                     for dev in self.config.global_settings.devices:
                         self.serial_manager.send_to_device(dev.id, colors[:dev.led_count], 100)
            return

        # 0. SAFETY CHECK
        if not self.app_state.enabled:
            # Send black if not already black
            if self.app_state.target_colors[0] != (0,0,0):
                 self.app_state.update_targets([(0, 0, 0)] * 66)
                 # Send once to clear
                 if self.serial_manager:
                     for dev in self.config.global_settings.devices:
                         self.serial_manager.send_to_device(dev.id, [(0,0,0)] * dev.led_count, 0)
            return

        # 1. CALIBRATION OVERRIDE
        if self.calibration_active:
             targets = [(0,0,0)] * 66
             indices = []
             if self.calibration_active == "top_left": indices = [11, 12]
             elif self.calibration_active == "top_right": indices = [32, 33]
             elif self.calibration_active == "bottom_right": indices = [44, 45]
             elif self.calibration_active == "bottom_left": indices = [65, 0]
             
             for idx in indices:
                 targets[idx] = (0, 255, 0) # Green Marker
                 
             self.app_state.update_targets(targets)
             if self.serial_manager:
                 for dev in self.config.global_settings.devices:
                      # Note: Calibration overrides currently assume single strip logic mapping
                      # This maps global targets to device
                      # TODO: Better calibration for multi-device
                      dev_targets = targets[:dev.led_count] 
                      self.serial_manager.send_to_device(dev.id, dev_targets, 255)
             return

        # 2. LIVE PREVIEW OVERRIDE (For Color Picker)
        if self.preview_override_color:
            self.preview_timer -= 1
            if self.preview_timer <= 0:
                self.preview_override_color = None # Expire preview
            else:
                # Show preview color
                targets = [self.preview_override_color] * 66
                self.app_state.update_targets(targets)
                if self.serial_manager:
                     for dev in self.config.global_settings.devices:
                         self.serial_manager.send_to_device(dev.id, targets[:dev.led_count], 200)
                return

        # 3. SINGLE PIXEL PREVIEW (Wizard)
        # 3. SINGLE PIXEL PREVIEW (Wizard)
        if self.preview_pixel_override:
             # Tuple now contains (device_id, idx, r, g, b)
             try:
                 if len(self.preview_pixel_override) == 5:
                     dev_id, idx, r, g, b = self.preview_pixel_override
                     
                     if self.serial_manager:
                         for dev in self.config.global_settings.devices:
                             if dev.id == dev_id:
                                 # Target Device: Specific Pixel
                                 
                                 if dev.type == 'wifi':
                                     self.serial_manager.send_to_device(dev.id, [(0,0,0)], 0)
                                     self.serial_manager.send_pixel(dev.id, idx, r, g, b)
                                 else:
                                     # Ensure buffer is large enough for the preview index
                                     req_size = max(dev.led_count, idx + 1)
                                     buf = [(0,0,0)] * req_size
                                     
                                     if 0 <= idx < req_size:
                                         buf[idx] = (r, g, b)
                                     self.serial_manager.send_to_device(dev.id, buf, 255)
                                 
                                 # Only update global state targets for the first device just for app consistency, 
                                 # though it doesn't matter much as we return early.
                                 if dev == self.config.global_settings.devices[0]:
                                     self.app_state.update_targets([(0,0,0)]*66) # Dummy
                             else:
                                 # Other Devices: OFF
                                 self.serial_manager.send_to_device(dev.id, [(0,0,0)] * dev.led_count, 0)
                     return
             except Exception as e:
                 print(f"Error in Preview Pixel: {e}")
                 self.preview_pixel_override = None

        mapped_targets = []
        brightness = 200

        try:
            # 2. MODE SWITCHING
            current_mode = self.config.global_settings.start_mode
            
            if current_mode == "light":
                # Check HomeKit Toggle
                if self.config.light_mode.homekit_enabled:
                     # Stop sending data to allow MQTT fallback (5s timeout on ESP)
                     return 
                mapped_targets, brightness = self._process_light_mode()
                
            elif current_mode == "screen":
                mapped_targets, brightness = self._process_screen_mode()
                
            elif current_mode == "music":
                mapped_targets, brightness = self._process_music_mode()
            
            elif current_mode == "pchealth":
                mapped_targets, brightness = self._process_pchealth_mode()
                
            else:
                 mapped_targets = [(0,0,0)] * self.config.global_settings.led_count

        except Exception as e:
            # CRASH PROTECTION
            print(f"⚠ CRASH IN UPDATE LOOP: {e}")
            traceback.print_exc()
            mapped_targets = [(10, 0, 0)] * self.config.global_settings.led_count # Dim Red Error indicator

        # 3. UPDATE STATE & SEND
        
        final_device_buffers = {}
        
        if isinstance(mapped_targets, dict):
            # Optimised Path (Screen Mode): Already routed per-device
            final_device_buffers = mapped_targets
            
            # For preview aggregation (simple flatten for UI)
            preview_flat = []
            # Sort by device order in settings to maintain consistent preview
            for dev in self.config.global_settings.devices:
                if dev.id in final_device_buffers:
                    preview_flat.extend(final_device_buffers[dev.id])
            
            self.app_state.update_targets(preview_flat) 
            
        else:
             # Legacy Path (Light/Music): Flat List
             # We need to distribute this list to devices.
             # Strategy: Slice sequentially.
             # Dev1 gets 0..N, Dev2 gets N+1..M
             
             self.app_state.update_targets(mapped_targets)
             
             # Apply global interpolation for legacy modes (Music/Light)
             if current_mode != "light":
                 mapped_targets = self.app_state.interpolate_colors()
             
             offset = 0
             global_len = len(mapped_targets)
             
             for dev in self.config.global_settings.devices:
                  needed = dev.led_count
                  if offset < global_len:
                       chunk = mapped_targets[offset : offset + needed]
                       # Pad if short
                       if len(chunk) < needed:
                            chunk.extend([(0,0,0)] * (needed - len(chunk)))
                       final_device_buffers[dev.id] = chunk
                       offset += needed
                  else:
                       final_device_buffers[dev.id] = [(0,0,0)] * needed

        # 3.5 APPLY PREVIEWS / OVERRIDES
        # Global Color Preview (Color Picker)
        if hasattr(self, 'preview_override_color') and self.preview_override_color:
            # Force all devices to this color
            for dev_id in final_device_buffers:
                leds = len(final_device_buffers[dev_id])
                final_device_buffers[dev_id] = [self.preview_override_color] * leds

        # Single Pixel Preview (LED Wizard)
        if hasattr(self, 'preview_pixel_override') and self.preview_pixel_override:
            # (device_id, idx, r, g, b)
            p_dev_id, p_idx, pr, pg, pb = self.preview_pixel_override
            
            # If we are in Wizard, we want to BLACK OUT everything else on that device usually?
            # Or just overlay? 
            # The Wizard says "Move slider to light up LED".
            # Usually implies everything else is OFF for clear visibility.
            
            if p_dev_id in final_device_buffers:
                buf = final_device_buffers[p_dev_id]
                # Clear buffer first for clarity (Wizard Mode)
                buf = [(0,0,0)] * len(buf) 
                
                if 0 <= p_idx < len(buf):
                    buf[p_idx] = (pr, pg, pb)
                
                final_device_buffers[p_dev_id] = buf

        # 4. SEND TO DEVICES
        if self.serial_manager:
            for dev in self.config.global_settings.devices:
                buf = final_device_buffers.get(dev.id, [(0,0,0)] * dev.led_count)
                self.serial_manager.send_to_device(dev.id, buf, brightness)

                


    # --- MODES IMPLEMENTATION ---

    def _process_startup_animation(self) -> list:
        """Black Hold (Anti-Flicker)"""
        # Keep LEDs off for a moment to settle power/data
        count = self.config.global_settings.led_count
        return [(0,0,0)] * count

    def _process_light_mode(self) -> Tuple[list, int]:
        """
        @brief Process Light Mode (Static/Effects).
        @details
        Generates LED colors based on the selected effect (Static, Breathing, Rainbow, Chase).
        
        @return Tuple[list, int]: Returns (list_of_colors, brightness_value).
                  list_of_colors is a list of (R, G, B) tuples.
        """
        settings = self.config.light_mode
            # Získání barvy a jasu
        r, g, b = settings.color
        brightness = settings.brightness
            
            # Application Logic
        effect = settings.effect
            
        if effect == "custom_zones":
            total_leds = self.config.global_settings.led_count
            byte_array_data = self._process_light_custom_zones(total_leds, settings.custom_zones)
            # Convert bytearray to list of (R,G,B) tuples
            mapped_targets = []
            for i in range(0, len(byte_array_data), 3):
                # Assuming GRB order from _process_light_custom_zones, convert to RGB
                mapped_targets.append((byte_array_data[i+1], byte_array_data[i], byte_array_data[i+2]))
            return mapped_targets, settings.brightness
            
        if effect == "static":
            # Static Color
            pass # Use defaults
                
        elif effect == "breathing":
            # Breathing Effect
            # Speed 1..100 -> Period 0.5s..5s
            # speed=50 -> 2.0s
            period_sec = 5.0 - (settings.speed / 100.0 * 4.5)
            phase = (time.time() % period_sec) / period_sec
            # Sine wave 0..1
            factor = (math.sin(phase * 2 * math.pi) + 1) / 2
            # Min brightness?
            min_bright = getattr(settings, "extra", 0) / 255.0 # 0..255 -> 0..1
            # brightness is max
            br_factor = min_bright + (factor * (1.0 - min_bright))
            brightness = int(brightness * br_factor)
                
        elif effect == "rainbow":
            leds = []
            # Speed controls hue rotation
            speed_factor = settings.speed / 10.0
            hue_shift = (time.time() * speed_factor) % 1.0
            
            total_leds = self.config.global_settings.led_count
            for i in range(total_leds): 
                # Spatially distributed rainbow
                hue = (hue_shift + (i / total_leds)) % 1.0
                rr, gg, bb = colorsys.hsv_to_rgb(hue, 1.0, 1.0)
                # Apply master brightness
                br = brightness / 255.0
                leds.append((int(rr * 255 * br), int(gg * 255 * br), int(bb * 255 * br)))
            return leds, brightness

        elif effect == "chase":
            # Running dot/segment
            total_leds = self.config.global_settings.led_count
            leds = [(0,0,0)] * total_leds
            speed = settings.speed / 50.0 # 0.02 - 2.0 multiplier
            pos = int((self.animation_tick * speed * 0.5) % total_leds)
            for i in range(10): # Trail length
                idx = (pos - i) % total_leds
                fade = 1.0 - (i / 10.0)
                leds[idx] = (
                    int(r * fade), 
                    int(g * fade), 
                    int(b * fade)
                )
            return leds, brightness

        # Default: Apply Color & Brightness to all
        mapped_targets = []
        br_factor = brightness / 255.0
        r_final = int(r * br_factor)
        g_final = int(g * br_factor)
        b_final = int(b * br_factor)
            
        total_leds = self.config.global_settings.led_count
        for _ in range(total_leds):
            mapped_targets.append((r_final, g_final, b_final))
        return mapped_targets, brightness



    def _apply_preset_logic(self, mode, preset_name):
        # Helper to apply preset values without UI
        pass # Todo: Move logic from settings_dialog to settings_manager to avoid dupe

    def _process_light_custom_zones(self, led_count: int, zones: list) -> bytearray:
        """Process Custom Zones Logic"""
        led_data = bytearray(led_count * 3)
        # Initialize with black
        for i in range(led_count * 3):
            led_data[i] = 0
            
        current_time = time.time()
        
        for zone in zones:
            start_pct = zone.get("start", 0)
            end_pct = zone.get("end", 0)
            color = zone.get("color", (255, 255, 255))
            effect = zone.get("effect", "static")
            speed = zone.get("speed", 50)
            brightness = zone.get("brightness", 255)
            
            # Convert pct to indices
            start_idx = int((start_pct / 100.0) * led_count)
            end_idx = int((end_pct / 100.0) * led_count)
            
            if start_idx >= end_idx: continue
            if start_idx < 0: start_idx = 0
            if end_idx > led_count: end_idx = led_count
            
            # Effect Logic
            r, g, b = color
            br_factor = brightness / 255.0
            
            if effect == "static":
                pass
            elif effect == "pulse": # Breathing
                period = 2.0 - (speed / 100.0 * 1.5) # 0.5 - 2s
                if period <= 0: period = 0.1
                phase = (current_time % period) / period
                factor = (math.sin(phase * 2 * math.pi) + 1) / 2
                br_factor *= (0.2 + 0.8 * factor) # Min 20%
                
            elif effect == "blink":
                period = 1.0 - (speed / 100.0 * 0.9) # 0.1 - 1s
                if period <= 0: period = 0.1
                # 50% duty cycle
                if (current_time % period) < (period / 2):
                    br_factor = 0
            
            # Apply to LEDs in range
            r_final = int(r * br_factor)
            g_final = int(g * br_factor)
            b_final = int(b * br_factor)
            
            for i in range(start_idx, end_idx):
                # GRB
                led_data[i*3] = g_final
                led_data[i*3+1] = r_final
                led_data[i*3+2] = b_final
                
    def _get_gradient_color(self, value, min_val, max_val, scale_type):
        """Get RGB color based on value in gradient scale"""
        # Normalize to 0-1
        t = max(0.0, min(1.0, (value - min_val) / (max_val - min_val) if max_val != min_val else 0.5))
        
        if scale_type == "blue_green_red":
            # Blue (cold) → Green (medium) → Red (hot)
            if t < 0.5:
                return self._interpolate_rgb((0, 0, 255), (0, 255, 0), t * 2)
            else:
                return self._interpolate_rgb((0, 255, 0), (255, 0, 0), (t - 0.5) * 2)
        elif scale_type == "cool_warm":
            # Cyan (cold) → White (medium) → Orange (hot)
            if t < 0.5:
                return self._interpolate_rgb((0, 255, 255), (255, 255, 255), t * 2)
            else:
                return self._interpolate_rgb((255, 255, 255), (255, 128, 0), (t - 0.5) * 2)
        elif scale_type == "cyan_yellow":
            return self._interpolate_rgb((0, 255, 255), (255, 255, 0), t)
        elif scale_type == "rainbow":
            import colorsys
            r, g, b = colorsys.hsv_to_rgb(t, 1.0, 1.0)
            return (int(r * 255), int(g * 255), int(b * 255))
        else:
            return (255, 255, 255)
    
    
    def _interpolate_rgb(self, color1, color2, t):
        """Linear interpolation between two RGB colors"""
        r = int(color1[0] + (color2[0] - color1[0]) * t)
        g = int(color1[1] + (color2[1] - color1[1]) * t)
        b = int(color1[2] + (color2[2] - color1[2]) * t)
        return (r, g, b)

    def _get_gradient_color(self, value, min_val, max_val, scale_type, c_low=None, c_mid=None, c_high=None):
        """Get RGB color based on value in gradient scale"""
        # Normalize to 0-1
        t = max(0.0, min(1.0, (value - min_val) / (max_val - min_val) if max_val != min_val else 0.5))
        
        if scale_type == "custom":
            # Low -> Mid -> High
            if not c_low: c_low = (0,0,255)
            if not c_mid: c_mid = (0,255,0)
            if not c_high: c_high = (255,0,0)
            
            if t < 0.5:
                # 0.0 - 0.5 -> Low to Mid
                return self._interpolate_rgb(c_low, c_mid, t * 2)
            else:
                # 0.5 - 1.0 -> Mid to High
                return self._interpolate_rgb(c_mid, c_high, (t - 0.5) * 2)
        
        if scale_type == "blue_green_red":
            # Blue (cold) -> Green (medium) -> Red (hot)
            if t < 0.5:
                return self._interpolate_rgb((0, 0, 255), (0, 255, 0), t * 2)
            else:
                return self._interpolate_rgb((0, 255, 0), (255, 0, 0), (t - 0.5) * 2)
                
        elif scale_type == "cool_warm":
            # Blue -> Red
            return self._interpolate_rgb((0, 0, 255), (255, 0, 0), t)
            
        elif scale_type == "cyan_yellow":
            # Cyan -> Yellow
            return self._interpolate_rgb((0, 255, 255), (255, 255, 0), t)
            
        elif scale_type == "rainbow":
            # Simple Rainbow approx
            if t < 0.33: return self._interpolate_rgb((255,0,0), (0,255,0), t*3)
            elif t < 0.66: return self._interpolate_rgb((0,255,0), (0,0,255), (t-0.33)*3)
            else: return self._interpolate_rgb((0,0,255), (255,0,0), (t-0.66)*3)
            
        return (255, 255, 255)
    def _process_pchealth_mode(self):
        settings = self.config.pc_health
        led_count = self.config.global_settings.led_count
        
        # Lazy import
        import psutil
        
        # 1. Fetch System Metrics
        # simple cache or fetch fresh? 30-60ms loop is fast.
        # psutil.cpu_percent with interval=None is non-blocking but requires first call.
        # We assume App init called it once or SystemMonitor module is used.
        # Let's use direct psutil for simplicity here as we removed SystemMonitor usage in this snippet?
        # Actually better to use a map of values.
        
        system_values = {
            "cpu_usage": psutil.cpu_percent(interval=None),
            "ram_usage": psutil.virtual_memory().percent,
            "net_usage": 0, # Placeholder
        }
        
        # For Temps, we need sensors. psutil.sensors_temperatures() depends on OS/Hardware.
        # We'll skip complex temp logic for now or try-catch it.
        try:
             temps = psutil.sensors_temperatures()
             # Try to find a common CPU package
             if 'coretemp' in temps:
                 system_values["cpu_temp"] = temps['coretemp'][0].current
             elif 'k10temp' in temps: # AMD
                 system_values["cpu_temp"] = temps['k10temp'][0].current
             else:
                 system_values["cpu_temp"] = 0
        except:
             system_values["cpu_temp"] = 0
             
        # Mock GPU/Net if missing
        system_values["gpu_usage"] = 0 
        system_values["gpu_temp"] = 0
        
        # 2. Zone Buffers (Left, Right, Top, Bottom)
        # We will accumulate colors. Strategy: Max Brightness Wins? Or Average?
        # Let's use "Last enabled rule wins" for simplicity on same zone.
        # We initialize with Black.
        
        zone_colors = {
            "left": (0,0,0), "right": (0,0,0), "top": (0,0,0), "bottom": (0,0,0)
        }
        
        # To handle brightness, we need to return a 'Master Brightness'.
        # But each zone might have different brightness requirements (Dynamic!).
        # This is tricky because `send_colors` takes ONE global brightness.
        # SOLUTION: We will bake the brightness into the Color (R,G,B) itself!
        # And return brightness=255 (Max) to send_colors.
        
        # 3. Process Rules
        for metric_cfg in settings.metrics:
            if not metric_cfg.get("enabled", True): continue
            
            m_name = metric_cfg.get("metric", "cpu_usage")
            val = system_values.get(m_name, 0)
            
            # Clamp/Normalize
            min_v = float(metric_cfg.get("min_value", 0))
            max_v = float(metric_cfg.get("max_value", 100))
            
            # Get Base Gradient Color
            # (Pass custom colors if present)
            c_low = metric_cfg.get("color_low")
            c_mid = metric_cfg.get("color_mid")
            c_high = metric_cfg.get("color_high")
            
            grad_col = self._get_gradient_color(
                val, min_v, max_v, 
                metric_cfg.get("color_scale", "blue_green_red"),
                c_low, c_mid, c_high
            )
            
            # Calculate Brightness Scaling
            b_mode = metric_cfg.get("brightness_mode", "static")
            brightness_val = 255
            
            if b_mode == "static":
                brightness_val = int(metric_cfg.get("brightness", 200))
            else:
                # Dynamic Logic
                b_min = int(metric_cfg.get("brightness_min", 50))
                b_max = int(metric_cfg.get("brightness_max", 255))
                # Map val to b_min..b_max
                # Normalize t 0..1
                t = max(0.0, min(1.0, (val - min_v) / (max_v - min_v) if max_v != min_v else 0))
                brightness_val = int(b_min + (b_max - b_min) * t)
            
            # Apply brightness to color
            br_factor = brightness_val / 255.0
            final_col = (
                int(grad_col[0] * br_factor),
                int(grad_col[1] * br_factor),
                int(grad_col[2] * br_factor)
            )
            
            # Apply to configured zones
            for z in metric_cfg.get("zones", []):
                z = z.lower()
                if z in zone_colors:
                    zone_colors[z] = final_col
                    
        # 4. Map Zones to Segments
        # Similar to screen mode but simpler (Solid color per zone)
        
        screen_config = self.config.screen_mode
        targets = [(0,0,0)] * led_count
        
        if screen_config.segments:
            for seg in screen_config.segments:
                seg_len = abs(seg.led_end - seg.led_start) + 1
                step = 1 if seg.led_start <= seg.led_end else -1
                
                # Get color for this segment's edge
                col = zone_colors.get(seg.edge, (0,0,0))
                
                for i in range(seg_len):
                     idx = seg.led_start + (i * step)
                     if 0 <= idx < led_count:
                         targets[idx] = col
        else:
            # Fallback (Legacy)
            # Split strip into 4 parts roughly
            # Left (20%), Top (30%), Right (20%), Bottom (30%)
            c_left = int(led_count * 0.2)
            c_top = int(led_count * 0.3)
            c_right = int(led_count * 0.2)
            c_bottom = led_count - (c_left + c_top + c_right)
            
            idx = 0
            for _ in range(c_left): 
                if idx < led_count: targets[idx] = zone_colors["left"]; idx+=1
            for _ in range(c_top): 
                if idx < led_count: targets[idx] = zone_colors["top"]; idx+=1
            for _ in range(c_right):
                if idx < led_count: targets[idx] = zone_colors["right"]; idx+=1
            for _ in range(c_bottom):
                 if idx < led_count: targets[idx] = zone_colors["bottom"]; idx+=1
        
        # Return targets and ALWAYS 255 brightness (since we baked it in)
        return targets, 255



    def _get_gradient_color(self, value, min_val, max_val, scale_type, c_low=None, c_mid=None, c_high=None):
        """Get RGB color based on value in gradient scale"""
        # Normalize to 0-1
        t = max(0.0, min(1.0, (value - min_val) / (max_val - min_val) if max_val != min_val else 0.5))
        
        if scale_type == "custom":
            # Low -> Mid -> High
            if not c_low: c_low = (0,0,255)
            if not c_mid: c_mid = (0,255,0)
            if not c_high: c_high = (255,0,0)
            
            if t < 0.5:
                return self._interpolate_rgb(c_low, c_mid, t * 2)
            else:
                return self._interpolate_rgb(c_mid, c_high, (t - 0.5) * 2)
                
        if scale_type == "blue_green_red":
            # Blue (cold) → Green (medium) → Red (hot)
            if t < 0.5:
                return self._interpolate_rgb((0, 0, 255), (0, 255, 0), t * 2)
            else:
                return self._interpolate_rgb((0, 255, 0), (255, 0, 0), (t - 0.5) * 2)
        elif scale_type == "cool_warm":
             # Blue -> Red
             return self._interpolate_rgb((0, 0, 255), (255, 0, 0), t)
             
        elif scale_type == "cyan_yellow":
             # Cyan -> Yellow
             return self._interpolate_rgb((0, 255, 255), (255, 255, 0), t)
             
        elif scale_type == "rainbow":
             # Simple Rainbow approx
             if t < 0.33: return self._interpolate_rgb((255,0,0), (0,255,0), t*3)
             elif t < 0.66: return self._interpolate_rgb((0,255,0), (0,0,255), (t-0.33)*3)
             else: return self._interpolate_rgb((0,0,255), (255,0,0), (t-0.66)*3)
             
        return (255, 255, 255)



    def _process_screen_mode(self) -> Tuple[list, int]:
        """
        @brief Process Screen Capture Mode.
        @details
        Captures screen content using CaptureThread (MSS/DXCAM), aggregates color data
        for configured segments, and maps it to the physical LED strip logic.
        
        @return Tuple[list, int]: (color_data, brightness)
        """
        try:
            settings = self.config.screen_mode
            self.app_state.smooth_ms = settings.interpolation_ms
            
            # MIGRATION ON FLY: If no segments, create from legacy counts
            if not settings.segments:
                # print("DEBUG: No segments found!")
                return [(0,0,0)]*10, 0 # Return nothing if not set
                
            # Push segments to app_state for Thread
            self.app_state.segments = settings.segments
            
            # Get latest colors (Now returns Dict)
            colors_map = self.capture_thread.get_latest_colors() 
            # print(f"DEBUG: Got colors map size: {len(colors_map)}")
            
            # Prepare buffers for all devices
            device_buffers = {}
            for dev in self.config.global_settings.devices:
                device_buffers[dev.id] = [(0,0,0)] * dev.led_count
            
            # Populate buffers from captured data
            # Populate buffers from captured data
            for seg in settings.segments:
                raw_dev_id = seg.device_id
                target_dev_id = raw_dev_id
                
                # FALLBACK: Resolve 'primary' alias to actual device ID
                if target_dev_id == "primary" or not target_dev_id:
                    if len(self.config.global_settings.devices) > 0:
                        target_dev_id = self.config.global_settings.devices[0].id
                
                # skip if device not found in current config
                if target_dev_id not in device_buffers: continue
                
                # Length of this segment
                length = abs(seg.led_end - seg.led_start) + 1
                start_idx = seg.led_start
                
                for i in range(length):
                     # Logic must match CaptureThread
                     # Determine LED index relative to device
                     led_idx = start_idx + i 
                     
                     # Check bounds for device buffer
                     if 0 <= led_idx < len(device_buffers[target_dev_id]):
                         # CRITICAL FIX: CaptureThread uses the RAW ID (e.g. "primary") as key
                         # We must look it up by that, but store in the resolved device's buffer
                         c_val = colors_map.get((raw_dev_id, led_idx), (0,0,0))
                         device_buffers[target_dev_id][led_idx] = c_val
            
            return device_buffers, settings.brightness

        except Exception as e:
            print(f"ERROR in screen_mode: {e}")
            import traceback
            traceback.print_exc()
            return [(255, 0, 0)] * 10, 50 # Red Error indicator        


    def _process_music_mode(self) -> Tuple[list, int]:
        """
        @brief Process Music Visualization Mode.
        @return Tuple[list, int]: (color_data, brightness)
        """
        return self._process_granular_music_logic()

    def _legacy_process_music_mode(self) -> Tuple[list, int]:
        """Legacy Monolithic Implementation"""
        settings = self.config.music_mode
        analysis = self.audio_processor.get_analysis()
        self.app_state.smooth_ms = settings.smoothing_ms
        
        # Safe Extract 7 Bands
        def get_band(name):
            return analysis.get(name, {})
        
        sub = get_band('sub_bass')
        bass = get_band('bass')
        lmid = get_band('low_mid')
        mid = get_band('mid')
        hmid = get_band('high_mid')
        pres = get_band('presence')
        bril = get_band('brilliance')

        if not sub: # Fallback if analysis failed
             return [(0,0,0)] * 66, settings.brightness

        # --- SENSITIVITY FIX ---
        exponent = 1.0 - (settings.bass_sensitivity / 100.0) * 0.7
        
        # Auto Gain (AGC) Logic
        gain_factor = 1.0
        if self.app_state.auto_gain_enabled:
             # Check max of all bands
             vals = [b.get('smoothed',0) for b in [sub, bass, lmid, mid, hmid, pres, bril]]
             raw_max = max(vals)
             
             if raw_max > self.agc_max: 
                 self.agc_max = raw_max 
             else: 
                 self.agc_max = max(0.01, self.agc_max * 0.96)
             
             if self.agc_max < 0.10: self.agc_max = 0.10
             
             target = 1.0
             if self.agc_max > 0.001:
                 gain_factor = target / self.agc_max

        def apply_curve(val):
            v = val * gain_factor
            if v < 0.05: v = 0.0 # Noise gate
            v = max(0.0, min(1.0, v))
            return v ** exponent

        # Process 7 Bands
        v_sub  = apply_curve(sub.get('smoothed', 0))
        v_bass = apply_curve(bass.get('smoothed', 0))
        v_lmid = apply_curve(lmid.get('smoothed', 0))
        v_mid  = apply_curve(mid.get('smoothed', 0))
        v_hmid = apply_curve(hmid.get('smoothed', 0))
        v_pres = apply_curve(pres.get('smoothed', 0))
        v_bril = apply_curve(bril.get('smoothed', 0))

        # Get 7 Band Colors from Config
        c_sub_bass = settings.sub_bass_color
        c_bass = settings.bass_color
        c_low_mid = settings.low_mid_color
        c_mid = settings.mid_color
        c_high_mid = settings.high_mid_color
        c_presence = settings.presence_color
        c_brilliance = settings.brilliance_color

        # --- COLOR SOURCE LOGIC ---
        # Override colors based on color_source setting
        if settings.color_source == "fixed":
            # Use single fixed color for all bands
            c_sub_bass = c_bass = c_low_mid = c_mid = c_high_mid = c_presence = c_brilliance = settings.fixed_color
        elif settings.color_source == "monitor":
            # Use current screen color (from screen mode)
            if hasattr(self, 'last_screen_color') and self.last_screen_color:
                monitor_c = self.last_screen_color
            else:
                # Fallback: Sample center of screen
                try:
                    import mss
                    with mss.mss() as sct:
                        monitor = sct.monitors[1]
                        cx, cy = monitor['width'] // 2, monitor['height'] // 2
                        pixel = sct.grab({'left': cx, 'top': cy, 'width': 1, 'height': 1})
                        monitor_c = (pixel.pixel(0, 0)[2], pixel.pixel(0, 0)[1], pixel.pixel(0, 0)[0])
                except:
                    monitor_c = (128, 128, 128)  # Fallback gray
            c_sub_bass = c_bass = c_low_mid = c_mid = c_high_mid = c_presence = c_brilliance = monitor_c
        # else: color_source == "spectrum" -> use default 7-band colors

        def get_7band_mix_color(v_s, v_b, v_lm, v_m, v_hm, v_p, v_br):
             """Mix all 7 bands with their intensities and colors"""
             r, g, b = 0, 0, 0
             
             r += v_s * c_sub_bass[0]; g += v_s * c_sub_bass[1]; b += v_s * c_sub_bass[2]
             r += v_b * c_bass[0]; g += v_b * c_bass[1]; b += v_b * c_bass[2]
             r += v_lm * c_low_mid[0]; g += v_lm * c_low_mid[1]; b += v_lm * c_low_mid[2]
             r += v_m * c_mid[0]; g += v_m * c_mid[1]; b += v_m * c_mid[2]
             r += v_hm * c_high_mid[0]; g += v_hm * c_high_mid[1]; b += v_hm * c_high_mid[2]
             r += v_p * c_presence[0]; g += v_p * c_presence[1]; b += v_p * c_presence[2]
             r += v_br * c_brilliance[0]; g += v_br * c_brilliance[1]; b += v_br * c_brilliance[2]
             
             return (min(255, int(r)), min(255, int(g)), min(255, int(b)))

        def scale(c, intensity):
             return (int(c[0]*intensity), int(c[1]*intensity), int(c[2]*intensity))

        settings = self.config.music_mode
        screen_config = self.config.screen_mode
        
        # Calculate Zone Counts dynamically from Segments
        # Default to 0 if no segments with that area exist
        c_left = sum(abs(s.led_end - s.led_start) + 1 for s in screen_config.segments if s.edge == 'left')
        c_right = sum(abs(s.led_end - s.led_start) + 1 for s in screen_config.segments if s.edge == 'right')
        c_top = sum(abs(s.led_end - s.led_start) + 1 for s in screen_config.segments if s.edge == 'top')
        c_bottom = sum(abs(s.led_end - s.led_start) + 1 for s in screen_config.segments if s.edge == 'bottom')
        
        # Fallback if no segments defined (e.g. fresh install) -> Use global count evenly?
        total_leds = self.config.global_settings.led_count
        if not screen_config.segments:
             # Rough fallback logic
             c_left = c_right = int(total_leds * 0.2)
             c_top = c_bottom = int(total_leds * 0.3)
             
        # Effect Processing
        targets = [(0,0,0)] * total_leds
        min_br_val = getattr(settings, 'min_brightness', 0) / 255.0

        # --- EFFECTS ---

        if settings.effect == "reactive_bass":
            # REACTIVE BASS - Flash colors on bass hits
            # Simple and effective: detect bass energy and flash bright colors
            
            # Calculate bass energy (sub-bass + bass frequencies)
            bass_energy = (v_sub * 2.0 + v_bass * 2.5 + v_lmid * 1.5) / 6.0
            
            # Apply sensitivity
            sens = (settings.bass_sensitivity / 100.0) * 2.5
            bass_energy = min(bass_energy * sens, 1.0)
            
            # Detect bass hit using delta (change detection)
            if not hasattr(self.app_state, 'prev_bass_reactive'):
                self.app_state.prev_bass_reactive = 0.0
            
            delta = bass_energy - self.app_state.prev_bass_reactive
            self.app_state.prev_bass_reactive = bass_energy
            
            # Flash intensity state
            if not hasattr(self, 'bass_flash'):
                self.bass_flash = 0.0
            
            # Trigger on significant bass jump
            if delta > 0.03 and bass_energy > 0.25:
                # Bass hit! Flash bright
                self.bass_flash = 1.0
            else:
                # Decay
                self.bass_flash *= 0.70
            
            # Calculate final brightness
            floor = (settings.high_sensitivity / 100.0) * 0.3
            floor = max(floor, min_br_val)
            final_bright = floor + (self.bass_flash * 0.7)
            final_bright = min(1.0, max(0.0, final_bright))
            
            # Color: Mix of bass frequencies
            targets = [(0,0,0)] * total_leds
            
            # Use bass colors (red/orange for sub-bass, purple for bass)
            if self.bass_flash > 0.5:
                # Bright flash - use bass color
                color = c_bass
            else:
                # Subtle - mix colors
                color = get_7band_mix_color(v_sub, v_bass, v_lmid*0.3, v_mid*0.2, 0, 0, 0)
            
            # Apply brightness to color
            final_color = scale(color, final_bright)
            
            # Fill all LEDs
            for i in range(total_leds):
                targets[i] = final_color
            
            return targets, settings.brightness






        elif settings.effect == "melody_smart":
            # MELODY SMART - Multi-band Reactive (based on reactive_bass PROVEN code)
            # 4 frequency bands, each with independent flash detection
            # SIMPLE, WORKS, NO COMPLICATED AI
            
            analysis = self.audio_processor.get_analysis()
            
            # Use same extraction pattern as reactive_bass (WORKING!)
            def get_band(name):
                return analysis.get(name, {})
            
            sub = get_band('sub_bass')
            bass = get_band('bass')
            lmid = get_band('low_mid')
            mid = get_band('mid')
            hmid = get_band('high_mid')
            high = get_band('high')
            bril = get_band('brilliance')
            
            # Apply gain (sensitivity) - simplified, no brightness_curve
            gain_factor = (settings.high_sensitivity / 100.0) * 2.5
            
            def apply_curve(val):
                v = val * gain_factor
                if v < 0.05: v = 0.0  # Noise gate
                v = max(0.0, min(1.0, v))
                return v ** 1.0  # Linear for now
            
            v_sub = apply_curve(sub.get('smoothed', 0))
            v_bass = apply_curve(bass.get('smoothed', 0))
            v_lmid = apply_curve(lmid.get('smoothed', 0))
            v_mid = apply_curve(mid.get('smoothed', 0))
            v_hmid = apply_curve(hmid.get('smoothed', 0))
            v_high = apply_curve(high.get('smoothed', 0))
            v_bril = apply_curve(bril.get('smoothed', 0))
            
            # === STATE INIT ===
            if not hasattr(self, 'melody_bands'):
                self.melody_bands = {
                    'bass': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5},
                    'low_mid': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5},
                    'mid': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5},
                    'high': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5}
                }
            
            # === BAND 1: BASS (sub + bass + low_mid) ===
            bass_energy = (v_sub * 2.5 + v_bass * 2.0 + v_lmid * 1.5) / 6.0
            bass_energy = min(bass_energy * 1.5, 1.0)
            
            # Onset detection (same as reactive_bass)
            bass_avg = self.melody_bands['bass']['avg']
            bass_delta = bass_energy - bass_avg
            
            # DEBUG OUTPUT (remove after testing)
            if not hasattr(self, 'melody_debug_frame'):
                self.melody_debug_frame = 0
            self.melody_debug_frame += 1
            
            if self.melody_debug_frame % 30 == 0:  # Every 30 frames (~1 second)
                print(f"MELODY DEBUG: bass_energy={bass_energy:.3f}, bass_avg={bass_avg:.3f}, delta={bass_delta:.3f}, flash={self.melody_bands['bass']['flash']:.3f}")
            
            # FIXED: Lower threshold and slower avg adaptation
            if bass_delta > 0.02 and bass_energy > 0.20:  # Lower thresholds for better sensitivity
                self.melody_bands['bass']['flash'] = 1.0
                print(f"🔴 BASS ONSET! energy={bass_energy:.3f} delta={bass_delta:.3f}")
            
            self.melody_bands['bass']['energy'] = bass_energy
            # FIXED: Much slower adaptation (0.995 instead of 0.98) to prevent avg catching up
            self.melody_bands['bass']['avg'] = bass_avg * 0.995 + bass_energy * 0.005
            self.melody_bands['bass']['flash'] *= 0.70  # Decay
            
            # === BAND 2: LOW-MID (low_mid + mid) ===
            lmid_energy = (v_lmid * 1.5 + v_mid * 1.0) / 2.5
            lmid_energy = min(lmid_energy * 1.5, 1.0)
            
            lmid_avg = self.melody_bands['low_mid']['avg']
            lmid_delta = lmid_energy - lmid_avg
            if lmid_delta > 0.02 and lmid_energy > 0.20:
                self.melody_bands['low_mid']['flash'] = 1.0
            
            self.melody_bands['low_mid']['energy'] = lmid_energy
            self.melody_bands['low_mid']['avg'] = lmid_avg * 0.995 + lmid_energy * 0.005
            self.melody_bands['low_mid']['flash'] *= 0.70
            
            # === BAND 3: MID (mid + high_mid) ===
            mid_energy = (v_mid * 1.0 + v_hmid * 1.5) / 2.5
            mid_energy = min(mid_energy * 1.5, 1.0)
            
            mid_avg = self.melody_bands['mid']['avg']
            mid_delta = mid_energy - mid_avg
            if mid_delta > 0.02 and mid_energy > 0.20:
                self.melody_bands['mid']['flash'] = 1.0
            
            self.melody_bands['mid']['energy'] = mid_energy
            self.melody_bands['mid']['avg'] = mid_avg * 0.995 + mid_energy * 0.005
            self.melody_bands['mid']['flash'] *= 0.70
            
            # === BAND 4: HIGH (high_mid + high + brilliance) ===
            high_energy = (v_hmid * 1.0 + v_high * 1.5 + v_bril * 2.0) / 4.5
            high_energy = min(high_energy * 1.5, 1.0)
            
            high_avg = self.melody_bands['high']['avg']
            high_delta = high_energy - high_avg
            if high_delta > 0.02 and high_energy > 0.20:
                self.melody_bands['high']['flash'] = 1.0
            
            self.melody_bands['high']['energy'] = high_energy
            self.melody_bands['high']['avg'] = high_avg * 0.995 + high_energy * 0.005
            self.melody_bands['high']['flash'] *= 0.70
            
            # === LED MAPPING (4 zones) ===
            zone_size = total_leds // 4
            targets = []
            
            band_list = ['bass', 'low_mid', 'mid', 'high']
            band_colors = [
                (255, 0, 0),      # Bass: Red
                (255, 128, 0),    # Low-mid: Orange
                (0, 255, 128),    # Mid: Cyan
                (128, 0, 255)     # High: Purple
            ]
            
            for led_idx in range(total_leds):
                zone_idx = min(led_idx // zone_size, 3)
                band_name = band_list[zone_idx]
                band_data = self.melody_bands[band_name]
                
                # Brightness = flash + steady energy
                flash_comp = band_data['flash'] * 0.7
                energy_comp = band_data['energy'] * 0.3
                brightness = max(flash_comp + energy_comp, 0.1)
                brightness = min(brightness, 1.0)
                
                color = band_colors[zone_idx]
                targets.append(scale(color, brightness))
            
            return targets, settings.brightness

            # MELODY SMART v5 - SIMPLIFIED & FIXED
            # - Proper brightness decay (fixes max brightness bug)
            # - State management (fixes "stops working" bug)
            # - Adaptive frequency learning
            # - Clean, responsive, works!
            
            from adaptive_detector import get_adaptive_detector
            
            detector = get_adaptive_detector()
            
            # Get real-time band analysis
            if hasattr(self.audio_processor, 'latest_buffer'):
                bands = detector.process_frame(self.audio_processor.latest_buffer)
            else:
                bands = detector._empty_result()
            
            # === 4 LED ZONES for 4 FREQUENCY BANDS ===
            zone_size = total_leds // 4
            targets = []
            
            for led_idx in range(total_leds):
                zone_idx = min(led_idx // zone_size, 3)
                band = bands[zone_idx]
                
                # Get color and brightness from detector
                color = band['color']
                brightness = band['brightness']
                
                # DEBUG: Print if onset (remove after testing)
                if band['onset'] and zone_idx == 0:
                    print(f"DEBUG: {band['name']} ONSET! Brightness={brightness:.2f}")
                
                # Apply
                targets.append(scale(color, brightness))
            
            return targets, settings.brightness

        elif settings.effect == "spectrum_rotate":
            # ROTATING SPECTRUM
            # Mapping 7 bands to a virtual circle and rotating it.
            
            # 1. Create a virtual buffer of colors (e.g. 100 points) representing Sub->Brilliance->Sub
            # 2. Shift the read index based on time.
            
            import time
            t = time.time()
            speed = getattr(settings, 'rotation_speed', 20)
            offset = int(t * speed * 2) % total_leds # Direct rotation on LEDs is easier?
            
            # Let's map 7 bands to the LED strip geometry, then rotate the array.
            # Base Layout (Static):
            # [Sub][Bass][LowMid][Mid][HighMid][Pres][Bril] stretched across strip
            
            # Bands Array
            bands_ordered = [v_sub, v_bass, v_lmid, v_mid, v_hmid, v_pres, v_bril]
            colors_ordered = [
                c_sub_bass,
                c_bass,
                c_low_mid,
                c_mid,
                c_high_mid,
                c_presence,
                c_brilliance
            ]
            
            pixels = []
            segment_len = total_leds / 7.0
            
            for i in range(total_leds):
                # Which band does this pixel belong to?
                band_idx = int(i / segment_len)
                if band_idx >= 7: band_idx = 6
                
                # Interpolate for smoothness?
                # Simple: Just take value
                val = bands_ordered[band_idx]
                col = colors_ordered[band_idx]
                
                # Apply Min Brightness
                val = max(val, min_br_val)
                
                final_c = scale(col, val ** 1.5)
                pixels.append(final_c)
            
            # Apply Rotation
            from collections import deque
            d_pixels = deque(pixels)
            d_pixels.rotate(offset)
            
            return list(d_pixels), settings.brightness

        elif settings.effect == "energy":
            # ENERGY (Combined 7-band avg)
            avg = (v_sub + v_bass + v_lmid + v_mid + v_hmid + v_pres + v_bril) / 7.0
            retention = 0.95 - (settings.mid_sensitivity / 100.0) * 0.45
            self.energy_val = max(avg ** 2.0, self.energy_val * retention)
            
            base_floor = (settings.high_sensitivity / 100.0) * 0.2
            floor = max(base_floor, min_br_val)
            
            sens_mult = (settings.bass_sensitivity / 100.0) * 1.2
            final_val = min(1.0, floor + (self.energy_val * sens_mult))
            
            c_mix = get_7band_mix_color(0.2,0.2,0.2,0.2,0.2,0.2,0.2)
            return [scale(c_mix, final_val)] * total_leds, settings.brightness

        elif settings.effect == "vumeter":
            # VU METER - Vertical bar graph visualization
            # Bottom LEDs = bass, Top LEDs = highs
            # Brightness increases with audio level
            
            # Calculate average levels for different frequency ranges
            low_level = (v_sub + v_bass) / 2.0  # Bass
            mid_level = (v_lmid + v_mid + v_hmid) / 3.0  # Mids
            high_level = (v_pres + v_bril) / 2.0  # Highs
            
            # Apply gamma for punchiness
            gamma = 1.8
            low_level = max(low_level, min_br_val) ** gamma
            mid_level = max(mid_level, min_br_val) ** gamma
            high_level = max(high_level, min_br_val) ** gamma
            
            # Create VU meter bars
            targets = [(0,0,0)] * total_leds
            
            # Split LEDs into 3 zones
            third = total_leds // 3
            
            # Bottom third: Bass (Red-ish)
            for i in range(third):
                brightness = low_level * (i / third)  # Gradient
                targets[i] = scale((255, 50, 0), brightness)
            
            # Middle third: Mids (Green-ish)
            for i in range(third, third * 2):
                brightness = mid_level * ((i - third) / third)
                targets[i] = scale((50, 255, 50), brightness)
            
            # Top third: Highs (Blue-ish)
            for i in range(third * 2, total_leds):
                brightness = high_level * ((i - third * 2) / (total_leds - third * 2))
                targets[i] = scale((50, 150, 255), brightness)
            

            
        elif settings.effect == "vumeter_spectrum":
            # VU SPECTRUM - Hybrid Mode
            # Bottom: Bass Reactive (Flash/Glow)
            # Sides: VU Meters (Low-Mid -> Left, High-Mid -> Right)
            
            # 1. Identify Zones based on Segments
            # We need precise counts for Left/Right/Bottom
            # Assuming standard layout or segment definitions
            
            # Dynamic Zone Calculation
            leds_left = []
            leds_right = []
            leds_bottom = []
            leds_top = [] # Optional, maybe mirror bottom or just flow?
            
            # Map indices to physical location
            # If segments exist, use them. If not, fallback.
            if screen_config.segments:
                for seg in screen_config.segments:
                    indices = []
                    length = abs(seg.led_end - seg.led_start) + 1
                    step = 1 if seg.led_start <= seg.led_end else -1
                    for i in range(length):
                        indices.append(seg.led_start + i * step)
                    
                    if seg.edge == "left": leds_left.extend(indices)
                    elif seg.edge == "right": leds_right.extend(indices)
                    elif seg.edge == "bottom": leds_bottom.extend(indices)
                    elif seg.edge == "top": leds_top.extend(indices)
            else:
                # Fallback Fallback
                # L/R/T/B split
                c_side = int(total_leds * 0.2)
                c_tb = int(total_leds * 0.3)
                # This fallback is tricky because we don't know start index easily without assumption 
                # usually starts bottom-left or bottom-right.
                pass

            # 2. Process Audio (Unified Volume)
            # Use max(bass, mid, high) or weighted avg to get a solid 'Loudness' metric
            # User wants "Quiet -> Bottom off/dim, Louder -> Bottom Bright -> Sides Rise"
            
            # Weighted Volume
            v_mix = (v_sub * 0.5 + v_bass * 0.8 + v_lmid + v_mid + v_hmid + v_pres * 0.5) / 4.3
            
            # Master Gain (Mid Slider)
            gain = (settings.mid_sensitivity / 50.0) * 1.8 
            vol = min(1.0, v_mix * gain)
            
            # Decay (High Slider)
            vu_decay = 0.92 - (settings.high_sensitivity / 100.0) * 0.2
            
            # Store Smoothed Volume
            if not hasattr(self.app_state, 'vu_level'):
                self.app_state.vu_level = 0.0
                
            if vol > self.app_state.vu_level:
                # Instant rise (or slight smooth?)
                self.app_state.vu_level = vol
            else:
                self.app_state.vu_level *= vu_decay
                
            eff_vol = self.app_state.vu_level
            
            # Thresholds
            # 0% - 15%: Bottom "Wakes up" (Brightness 0-100%)
            # 15% - 90%: Sides Rise (0-100% Height)
            # 90% - 100%: Top "Overdrive" (Brightness 10-100%)
            
            th_bot_end = 0.15
            th_side_end = 0.90
            
            # Phase 1: Bottom Brightness
            if eff_vol < th_bot_end:
                # 0.0 to 0.15 -> 0.0 to 1.0
                b_bright = eff_vol / th_bot_end
                side_h = 0.0
                t_bright = 0.0
            elif eff_vol < th_side_end:
                # 0.15 to 0.90
                b_bright = 1.0 # Bottom fully lit
                # Map 0.15..0.90 -> 0.0..1.0
                side_h = (eff_vol - th_bot_end) / (th_side_end - th_bot_end)
                t_bright = 0.0
            else:
                # 0.90 to 1.0
                b_bright = 1.0
                side_h = 1.0
                # Map 0.90..1.0 -> 0.1..1.0
                ovf = (eff_vol - th_side_end) / (1.0 - th_side_end) # 0..1
                t_bright = 0.1 + (ovf * 0.9)
            
            # Colors
            # Bottom: Bass Color (or settings.bass_color)
            # Sides: Gradient (Green->Yel->Red)
            # Top: Overdrive (Red/White)
            
            if min_br_val > 0.01 and b_bright < min_br_val: b_bright = min_br_val # Floor
            
            # Apply Gamma for better perceptual brightness
            b_bright = b_bright ** 2
            
            col_bot = scale(c_bass, b_bright)
            
            # 3. Render
            targets = [(0,0,0)] * total_leds
            
            # Render Bottom
            if leds_bottom:
                # Full fill or Center-Out? "Bottom Shines" -> Full fill usually better for "Base"
                for idx in leds_bottom:
                    targets[idx] = col_bot
            
            # Render Sides (Bottom-Up)
            def draw_bar(indices, level, is_reversed=False):
                bar_len = len(indices)
                fill_h = int(bar_len * level)
                for i in range(bar_len):
                    pos = i / bar_len # 0..1 relative to height
                    real_idx = indices[i] if not is_reversed else indices[bar_len - 1 - i]
                    
                    if i < fill_h:
                        # Gradient relative to GLOBAL volume idea? 
                        # Or just Green->Red for the side bar?
                        # Let's do Green->Red
                        if pos < 0.6:
                            c = self._interpolate_rgb((0,255,0), (255,255,0), pos / 0.6)
                        else:
                            c = self._interpolate_rgb((255,255,0), (255,0,0), (pos - 0.6) / 0.4)
                        targets[real_idx] = c
                    else:
                         # Ensure side isn't pitch black if bottom is lit?
                         # Maybe faint glow if bottom is full?
                         # User said "gradually rise", implies emptiness above.
                         targets[real_idx] = scale((20,20,20), min_br_val)

            if leds_left:
                draw_bar(leds_left, side_h, is_reversed=True)
            if leds_right:
                draw_bar(leds_right, side_h, is_reversed=False)

            # Render Top
            if leds_top and t_bright > 0.01:
                # Flash Color (High Color or Red)
                c_top_base = (255, 50, 50) # Reddish
                c_top = scale(c_top_base, t_bright)
                for idx in leds_top:
                    targets[idx] = c_top
            elif leds_top:
                for idx in leds_top:
                    targets[idx] = scale((50,0,0), min_br_val)

            return targets, settings.brightness

        elif settings.effect == "strobe":
            # STROBE - Flash on bass hits
            # Fast flash effect synchronized to bass beats
            
            # Detect bass hit (threshold-based)
            bass_energy = (v_sub * 1.5 + v_bass) / 2.5
            
            # Store previous energy for delta detection
            if not hasattr(self.app_state, 'prev_strobe_energy'):
                self.app_state.prev_strobe_energy = 0.0
            
            delta = bass_energy - self.app_state.prev_strobe_energy
            self.app_state.prev_strobe_energy = bass_energy
            
            # Trigger strobe on significant energy jump
            threshold = 0.08
            if delta > threshold and bass_energy > 0.3:
                # Bass hit detected - FLASH WHITE
                self.strobe_intensity = 1.0
            else:
                # Fast decay
                self.strobe_intensity = getattr(self, 'strobe_intensity', 0.0) * 0.7
            
            # Strobe color (white flash)
            if self.strobe_intensity > 0.5:
                # Bright flash
                color = (255, 255, 255)
                brightness = self.strobe_intensity
            else:
                # Subtle glow with color from spectrum
                color = get_7band_mix_color(v_sub, v_bass, v_lmid, v_mid, v_hmid, v_pres, v_bril)
                brightness = max(self.strobe_intensity * 0.3, min_br_val)
            
            return [color] * total_leds, brightness

        else: 
            # SPECTRUM (Standard & Punchy)
            # Layout: Sub(Bot) -> Bass(Bot) -> LMid(Right) -> Mid(Top) -> HMid(Left) ?? 
            # Improved: Symmetric
            # Bottom: Sub + Bass
            # Sides Lower: LMid
            # Sides Upper: Mid + HMid
            # Top: Pres + Bril
            
            # Gamma
            g = 1.5 if "punchy" not in settings.effect else 2.5
            
            vs = max(v_sub, min_br_val) ** g
            vb = max(v_bass, min_br_val) ** g
            vlm = max(v_lmid, min_br_val) ** g
            vm = max(v_mid, min_br_val) ** g
            vhm = max(v_hmid, min_br_val) ** g
            vp = max(v_pres, min_br_val) ** g
            vbr = max(v_bril, min_br_val) ** g
            
            # Colors (using individual band colors)
            # Bottom: Mix Sub + Bass
            col_bot_r = int((c_sub_bass[0] * vs + c_bass[0] * vb) / 2.0)
            col_bot_g = int((c_sub_bass[1] * vs + c_bass[1] * vb) / 2.0)
            col_bot_b = int((c_sub_bass[2] * vs + c_bass[2] * vb) / 2.0)
            col_bot = (min(255, col_bot_r), min(255,col_bot_g), min(255, col_bot_b))
            
            # Sides Low: Low-Mid
            col_low_side = scale(c_low_mid, vlm)
            
            # Sides Upper: Mid + High-Mid
            col_up_r = int((c_mid[0] * vm + c_high_mid[0] * vhm) / 2.0)
            col_up_g = int((c_mid[1] * vm + c_high_mid[1] * vhm) / 2.0)
            col_up_b = int((c_mid[2] * vm + c_high_mid[2] * vhm) / 2.0)
            col_up_side = (min(255, col_up_r), min(255, col_up_g), min(255, col_up_b))
            
            # Top: Presence + Brilliance
            col_top_r = int((c_presence[0] * vp + c_brilliance[0] * vbr) / 2.0)
            col_top_g = int((c_presence[1] * vp + c_brilliance[1] * vbr) / 2.0)
            col_top_b = int((c_presence[2] * vp + c_brilliance[2] * vbr) / 2.0)
            col_top = (min(255, col_top_r), min(255, col_top_g), min(255, col_top_b))
            
            # Construction
            # Create Buffers (Virtual Zones)
            buf_bottom = [col_bot] * c_bottom
            buf_top = [col_top] * c_top
            
            # Helper for side gradients
            def make_side_buf(cnt):
                 p = []
                 half = cnt // 2
                 for i in range(cnt):
                      if i < half: p.append(col_up_side)
                      else: p.append(col_low_side)
                 return p
            
            buf_right = make_side_buf(c_right)
            buf_left = make_side_buf(c_left)
            
            # --- MAPPING TO PHYSICAL STRIP ---
            targets = [(0,0,0)] * total_leds
            
            # Iterators to consume buffers
            it_l = iter(buf_left)
            it_r = iter(buf_right)
            it_t = iter(buf_top)
            it_b = iter(buf_bottom)
            
            if screen_config.segments:
                current_led_idx = 0
                for seg in screen_config.segments:
                    source = None
                    if seg.edge == 'left': source = it_l
                    elif seg.edge == 'right': source = it_r
                    elif seg.edge == 'top': source = it_t
                    elif seg.edge == 'bottom': source = it_b
                    
                    if source:
                        length = abs(seg.led_end - seg.led_start) + 1
                        # We fill the 'physically ordered' output buffer sequentially 
                        # because 'screen_config.segments' IS the physical order description.
                        # Wait, 'targets' index is physical index.
                        
                        # BUT, 'seg.led_start' tells us where on the strip this segment sits.
                        # Since segments are usually stored in order 0..N, we can blindly fill?
                        # Safer to use seg.led_start/end indices.
                        
                        # Determine direction of filling based on segment indices
                        step = 1 if seg.led_start <= seg.led_end else -1
                        
                        for i in range(length):
                             try:
                                 col = next(source)
                                 idx = seg.led_start + (i * step)
                                 if 0 <= idx < total_leds:
                                     targets[idx] = col
                             except StopIteration:
                                 break # Buffer exhausted (should match count)
            else:
                 # Fallback (Legacy)
                 targets = buf_left + buf_top + buf_right + buf_bottom
                 # Pad or trim
                 targets = targets[:total_leds] + [(0,0,0)] * max(0, total_leds - len(targets))
            
            return targets, settings.brightness

    # --- HELPERS ---

    def show_calibration_led(self, corner_name):
        """Called from Settings to highlight strip corners"""
        print(f"Calibration requested: {corner_name}")
        if corner_name == "off":
            self.calibration_active = None
        else:
            self.calibration_active = corner_name

    def preview_color(self, r, g, b, duration=2):
        """Show color temporarily (called from Settings)"""
        if duration == 0:
            self.preview_override_color = None
            return

        self.preview_override_color = (r, g, b)
        self.preview_timer = duration # Show for 5 frames (~150ms) -> constant refresh needed from UI

    def on_preview_pixel(self, device_id, idx, r, g, b):
        """Show single pixel (called from Wizard via Settings)"""
        # If r=g=b=0, turn off override
        # ALSO turn off if idx is negative (cleanup signal)
        if (r==0 and g==0 and b==0) or idx < 0:
             self.preview_pixel_override = None
        else:
             self.preview_pixel_override = (device_id, idx, r, g, b)



    def _remap_screen_zones(self, segments_20: list) -> list:
        """Helper to remap 20 zones to actual LEDs using config geometry"""
        total = self.config.global_settings.led_count
        if len(segments_20) != 20: return [(0,0,0)] * total
        
        # Simple upsampling helper
        def up(src, count):
            res = []
            l = len(src)
            if count <= 0: return []
            
            for i in range(count):
                idx = min(int((i/count)*l), l-1)
                res.append(src[idx])
            return res

        # 0-4 Top, 5-9 Right, 10-14 Bottom, 15-19 Left
        # LED Order: Left -> Top -> Right -> Bottom
        
        c_left = self.config.screen_mode.led_count_left
        c_top = self.config.screen_mode.led_count_top
        c_right = self.config.screen_mode.led_count_right
        c_bottom = self.config.screen_mode.led_count_bottom
        
        # 1. Left (0-11) <-- Capture Left (15-19)
        l = up(segments_20[15:20], c_left)
        # 2. Top (12-32) <-- Capture Top (0-4)
        t = up(segments_20[0:5], c_top)
        # 3. Right (33-44) <-- Capture Right (5-9)
        r = up(segments_20[5:10], c_right)
        # 4. Bottom (45-65) <-- Capture Bottom (10-14)
        b = up(segments_20[10:15], c_bottom)
        
        return l + t + r + b

    # --- SIGNALS ---

    def _on_toggle_enabled(self, enabled: bool):
        self.app_state.enabled = enabled
        self.tray_icon.set_enabled(enabled)
        self.main_window.set_enabled(enabled)
        print(f"State: {'Enabled' if enabled else 'Disabled'}")

    def _on_show_settings(self):
        # Check if dialog is already open
        if hasattr(self, 'settings_dialog') and self.settings_dialog is not None:
            if self.settings_dialog.isVisible():
                print("DEBUG: Settings Dialog already open - bringing to front")
                # Ensure any overlays stay behind settings dialog
                if hasattr(self.settings_dialog, '_ensure_overlay_behind_dialog'):
                    self.settings_dialog._ensure_overlay_behind_dialog()
                else:
                    self.settings_dialog.raise_()
                    self.settings_dialog.activateWindow()
                return

        devices = self.audio_processor.get_devices()
        monitors = self.capture_thread.get_monitors_info()
        # Initialize Dialog WITHOUT parent for independence
        self.settings_dialog = SettingsDialog(self.config, devices, monitors, self.main_window, parent=None)
        # Connect real-time signals
        self.settings_dialog.preview_color_signal.connect(self.preview_color)
        self.settings_dialog.preview_color_signal.connect(self.preview_color)
        self.settings_dialog.preview_pixel_signal.connect(self.on_preview_pixel)
        self.settings_dialog.calibration_led_signal.connect(self.show_calibration_led)
        self.settings_dialog.identify_requested.connect(self._handle_identify)
        self.settings_dialog.settings_preview.connect(self._on_settings_preview)
        self.settings_dialog.settings_changed.connect(self._on_settings_finalized)
        self.settings_dialog.rejected.connect(self._on_settings_cancel)
        
        # Connect cleanup on close
        self.settings_dialog.finished.connect(self._on_settings_closed)
        
        # NON-BLOCKING: Show instead of exec()
        self.settings_dialog.show()
        # Ensure any overlays stay behind settings dialog
        from PyQt6.QtCore import QTimer
        QTimer.singleShot(10, lambda: self.settings_dialog._ensure_overlay_behind_dialog() if hasattr(self.settings_dialog, '_ensure_overlay_behind_dialog') else None)
        self.settings_dialog.raise_()
        self.settings_dialog.activateWindow()
    
    def _on_settings_closed(self):
        """Cleanup when settings dialog is closed"""
        print("DEBUG: Settings dialog closed")
        self.settings_dialog = None

    def _on_settings_finalized(self, new_config: AppConfig):
        """
        @brief Handler for Settings Dialog Save.
        @details
        Persists the new configuration to disk, updates internal state components 
        (Audio, Serial, Theme), and refreshes the UI status.
        
        @param new_config The updated AppConfig object returned from UI.
        """
        self.preview_override_color = None # Cancel preview
        self.config = new_config
        self.config.save(self.config_profile)
        
        # Update components
        self._sync_state_from_config()
        self.main_window.set_status(f"Mode: {self.config.global_settings.start_mode.upper()}")
        
        # Audio Device
        new_idx = self.config.music_mode.audio_device_index
        if new_idx != self.audio_processor.device_index:
             self.audio_processor.set_device(new_idx)
             
        # Serial (Update Manager with new config)
        self.serial_manager.update_devices(self.config.global_settings.devices)
             
        # Hotkeys
        self._init_hotkeys()
        
        # Theme
        from ui.themes import get_theme
        self.qt_app.setStyleSheet(get_theme(self.config.global_settings.theme))
        
        # Clear preview to ensure saved state is used
        self.config_preview = None
        
        # Reload triggers
        # self.reload_config() # Removed
        print("✓ Settings Applied & Saved (Hotkeys: {} custom)".format(len(new_config.global_settings.custom_hotkeys)))

    def _on_settings_preview(self, preview_config: AppConfig):
        """Live Apply of settings without saving"""
        self.config_preview = preview_config
        
        # Audio Hot-Swap Logic
        if hasattr(preview_config, 'music_mode') and self.audio_processor:
            p_audio = preview_config.music_mode.audio_device_index
            if p_audio != self.audio_processor.device_index:
                 self.audio_processor.set_device(p_audio)

    def _on_settings_cancel(self):
        """Revert preview on Cancel"""
        self.config_preview = None
        
        # Revert Audio
        if self.config and hasattr(self.config, 'music_mode') and self.audio_processor:
            orig_audio = self.config.music_mode.audio_device_index
            if orig_audio != self.audio_processor.device_index:
                 self.audio_processor.set_device(orig_audio)
                 
        print("DEBUG: Settings Cancelled - Reverting Preview")

    def _on_serial_connected(self):
        self.main_window.set_serial_status(True)
        self.app_state.serial_connected = True
        # Clear LEDs immediately to prevent flicker
        if self.serial_manager:
            for dev in self.config.global_settings.devices:
                self.serial_manager.send_to_device(dev.id, [(0,0,0)]*dev.led_count, 0)
        
    def _on_serial_disconnected(self):
        """Handle disconnection (Runs in Serial Thread -> Dispatch to Main)"""
        def task():
            print("Event: Serial Disconnected (UI Update)")
            if hasattr(self, 'main_window'):
                self.main_window.set_status("Disconnected")
        
        QTimer.singleShot(0, task)
            
    def _on_serial_error(self, error_msg):
        """Handle error (Runs in Serial Thread -> Dispatch to Main)"""
        def task():
           print(f"Event: Serial Error: {error_msg}")
           if hasattr(self, 'main_window'):
               self.main_window.set_status(f"Error: {error_msg}")
               
        QTimer.singleShot(0, task)

    def _on_tray_mode(self, mode_name: str):
        """Switch mode from Tray"""
        print(f"Tray: Switching to {mode_name}")
        self.config.global_settings.start_mode = mode_name
        self.config.save(self.config_profile)
        self._sync_state_from_config()
        self.main_window.set_status(f"Mode: {mode_name.upper()}")

    def _on_tray_preset(self, cat: str, name: str):
        """Apply preset from Tray"""
        from app_config import SCREEN_PRESETS, MUSIC_PRESETS
        print(f"Tray: Applying {cat} preset '{name}'")
        
        if cat == "screen":
            if name in SCREEN_PRESETS:
                p = SCREEN_PRESETS[name]
                s = self.config.screen_mode
                s.saturation_boost = p.get("saturation_boost", s.saturation_boost)
                s.min_brightness = p.get("min_brightness", s.min_brightness)
                s.interpolation_ms = p.get("interpolation_ms", s.interpolation_ms)
                s.gamma = p.get("gamma", s.gamma)
                
                # Switch to screen mode if not already
                if self.config.global_settings.start_mode != "screen":
                    self.config.global_settings.start_mode = "screen"
                    self.main_window.set_status(f"Mode: SCREEN ({name})")
        
        elif cat == "music":
            if name in MUSIC_PRESETS:
                p = MUSIC_PRESETS[name]
                m = self.config.music_mode
                m.bass_sensitivity = p.get("bass_sensitivity", m.bass_sensitivity)
                m.mid_sensitivity = p.get("mid_sensitivity", m.mid_sensitivity)
                m.high_sensitivity = p.get("high_sensitivity", m.high_sensitivity)
                
                 # Switch to music mode if not already
                if self.config.global_settings.start_mode != "music":
                    self.config.global_settings.start_mode = "music"
                    self.main_window.set_status(f"Mode: MUSIC ({name})")
        
        self.config.save(self.config_profile)
        self._sync_state_from_config()
        
    def _on_quit(self):
        print("Shutting down...")
        print("Shutting down...")
        self.app_state.enabled = False
        if hasattr(self, 'serial_manager') and self.serial_manager:
            self.serial_manager.close_all()
        # Stop Threads
        if hasattr(self, 'capture_thread') and self.capture_thread.is_alive():
             try:
                self.capture_thread.stop()
             except:
                pass
        if hasattr(self, 'audio_processor'):
            self.audio_processor.stop()
            
        self.qt_app.quit()

    def _update_connection_status_ui(self):
        """Build detailed connection status string and update UI"""
        if not hasattr(self, 'main_window') or not self.main_window: return
        
        if not self.serial_manager:
            self.main_window.set_serial_status(False)
            return

        # Build status text
        parts = []
        all_connected = True
        any_connected = False
        
        # Sort by Name
        sorted_ids = sorted(self.serial_manager.handlers.keys(), 
                          key=lambda k: self.serial_manager.configs[k].name if k in self.serial_manager.configs else k)
        
        # Use HTML for rich formatting
        html = "<html><body style='margin:0; padding:0;'>"
        
        if not sorted_ids:
            html += "<span style='color:#888;'>No Devices Configured</span>"
            all_connected = False
        else:
            for did in sorted_ids:
                if did not in self.serial_manager.handlers: continue
                h = self.serial_manager.handlers[did]
                name = self.serial_manager.configs[did].name if did in self.serial_manager.configs else did
                port = h.port
                is_conn = h.is_connected()
                
                if is_conn:
                    status_color = "#34C759" # Green
                    status_icon = "✓"
                    any_connected = True
                else:
                    status_color = "#FF3B30" # Red
                    status_icon = "✗"
                    all_connected = False
                    
                html += f"<div style='margin-bottom:2px;'><span style='font-weight:bold;'>{name}</span> <span style='color:#888;'>({port})</span>: <span style='color:{status_color}; font-weight:bold;'>{status_icon}</span></div>"
        
        html += "</body></html>"
        
        self.main_window.set_serial_status(html)

    def _handle_identify(self, device):
        """Handle Identify Request (Universal)"""
        if not device: return
        
        print(f"Identify Requested for: {device.name} ({device.type})")
        
         # 1. VISUAL: Flash LEDs on the device
        # If type is EXPLICITLY serial, use serial.
        # If type is EXPLICITLY wifi, use wifi.
        # If unknown, try both or prefer based on availability.
        
        identified = False
        
        if device.type == "serial" and self.serial_manager:
             # Serial Only
             print("-> Sending Serial Flash")
             blue = [(0, 0, 255)] * device.led_count
             black = [(0, 0, 0)] * device.led_count
             self.serial_manager.send_to_device(device.id, blue, 255)
             QTimer.singleShot(1000, lambda: self.serial_manager.send_to_device(device.id, black, 0))
             identified = True
             
        elif device.type == "wifi" and device.ip_address:
             # WiFi Only
             from modules.discovery import DiscoveryService
             print(f"-> Sending UDP Packet to {device.ip_address}")
             ds = DiscoveryService()
             ds.identify_device(device.ip_address, device.udp_port or 4210)
             ds.stop()
             identified = True
             
        # Fallback for legacy/auto (Logic: Try Serial first, if not connected, try UDP)
        if not identified:
             if self.serial_manager and device.id in self.serial_manager.handlers and self.serial_manager.handlers[device.id].is_connected():
                  print("-> Fallback: Sending Serial Flash")
                  blue = [(0, 255, 0)] * device.led_count # Green for fallback
                  black = [(0, 0, 0)] * device.led_count
                  self.serial_manager.send_to_device(device.id, blue, 255)
                  QTimer.singleShot(1000, lambda: self.serial_manager.send_to_device(device.id, black, 0))
             elif device.ip_address:
                  from modules.discovery import DiscoveryService
                  print(f"-> Fallback: Sending UDP Packet to {device.ip_address}")
                  ds = DiscoveryService()
                  ds.identify_device(device.ip_address, device.udp_port or 4210)
                  ds.stop()
                 

             
    def _process_granular_music_logic(self) -> Tuple[list, int]:
        """
        New Granular Music Engine.
        Renders effects per-segment based on 'music_effect' property.
        """
        settings = self.active_config.music_mode
        analysis = self.audio_processor.get_analysis()
        
        # 1. Prepare Device Buffers
        device_buffers = {}
        for dev in self.active_config.global_settings.devices:
            device_buffers[dev.id] = [(0,0,0)] * dev.led_count
            
        # 2. Get Segments (Screen Mode segments define the geometry)
        segments = self.active_config.screen_mode.segments
        
        # Fallback if no segments: Create virtual full-strip segments for each device
        if not segments:
             pass # TODO: Handle fallback better? For now, silence.
             
        # 3. Render Each Segment
        for seg in segments:
            # Resolve Device
            dev_id = seg.device_id
            if not dev_id or dev_id == "primary":
                if self.active_config.global_settings.devices:
                    dev_id = self.active_config.global_settings.devices[0].id
            
            if dev_id not in device_buffers: continue
            
            # Resolve Effect
            # Resolve Effect (Uses Global Effect always, orchestrated by Segment Role)
            eff_name = settings.effect
            
            # Calc Length
            num_leds = abs(seg.led_end - seg.led_start) + 1
            if num_leds <= 0: continue
            
            # Render with Segment Context
            pixels = self._render_segment_effect(eff_name, num_leds, settings, analysis, seg)
            
            # Reverse?
            if seg.reverse: pixels.reverse()
            
            # Write to Buffer
            buf = device_buffers[dev_id]
            start = seg.led_start
            
            # Safety Copy
            count = min(num_leds, len(pixels))
            for i in range(count):
                idx = start + i
                if 0 <= idx < len(buf):
                    buf[idx] = pixels[i]
                    
        return device_buffers, settings.brightness

    def _render_segment_effect(self, effect, num_leds, settings, analysis, seg=None) -> list:
        """Render a music effect for a specific number of LEDs with Role support"""
        
        # 0. DETERMINE ROLE & ORIENTATION
        role = "all"
        edge = "unknown"
        if seg:
            role = getattr(seg, "role", "auto")
            edge = getattr(seg, "edge", "bottom")
            if role == "auto":
                if edge == "bottom": role = "bass"
                elif edge == "top": role = "high"
                elif edge in ["left", "right"]: role = "mid"
                else: role = "all"

        # 1. ANALYSIS DATA & SENSITIVITY
        # Apply Sensitivity Sliders (Default 50 maps to 1.0x, 100 to 2.0x)
        # Global Master Gain (Default 50 maps to 1.0x)
        global_gain = getattr(settings, 'global_sensitivity', 50) / 50.0
        
        sens_bass = (getattr(settings, 'bass_sensitivity', 50) / 50.0) * global_gain
        sens_mid  = (getattr(settings, 'mid_sensitivity', 50) / 50.0) * global_gain
        sens_high = (getattr(settings, 'high_sensitivity', 50) / 50.0) * global_gain
        
        def get_band(name, multiplier): 
            raw = analysis.get(name, {}).get('smoothed', 0.0)
            return min(1.0, raw * multiplier)
            
        v_sub = get_band('sub_bass', sens_bass)    
        v_bass = get_band('bass', sens_bass)       
        v_mid = get_band('mid', sens_mid)         
        v_high = get_band('high', sens_high)       
        
        # 2. COLOR PALETTE LOGIC
        # Respect "Color Source" setting: "spectrum", "monitor" (simplified), "fixed"
        col_source = getattr(settings, 'color_source', 'spectrum')
        c_bass = c_mid = c_high = (255, 255, 255) # default fallback

        if col_source == "fixed":
            # [FIXED MODE] Use Single Global Color
            # Fallback to Magenta if missing
            fc = getattr(settings, 'fixed_color', (255, 0, 255))
            c_bass = c_mid = c_high = fc
            
        elif col_source == "monitor":
            # [MONITOR MODE] Intelligent Dominant Color Extraction
            # We fetch 3 dominant colors from the whole screen
            
            # Default fallback (e.g. current Presence color)
            c_bass = c_mid = c_high = settings.presence_color 
            
            if hasattr(self, 'capture_thread') and self.capture_thread.running:
                 doms = self.capture_thread.get_dominant_colors(3)
                 if doms and len(doms) >= 3:
                     # Map: [0]=Bass(Darkest/MostCommon?), [1]=Mid, [2]=High
                     # Actually scan_dominant_colors returns most frequent first.
                     # We usually want the "Vibrant" ones.
                     # For now, map 1:1
                     c_bass = doms[0]
                     c_mid = doms[1]
                     c_high = doms[2]
        
        else:
             # [SPECTRUM MODE] Use Manual Band Colors
             c_bass = settings.bass_color
             c_mid = settings.mid_color
             c_high = settings.presence_color
        
        # 3. HELPERS
        def clamp(val): return max(0, min(255, int(val)))
        
        def val_scale(c, v): 
            return (clamp(c[0]*v), clamp(c[1]*v), clamp(c[2]*v))
            
        def interpolate(c1, c2, t):
            t = max(0.0, min(1.0, t))
            return (
                clamp(c1[0] + (c2[0] - c1[0]) * t),
                clamp(c1[1] + (c2[1] - c1[1]) * t),
                clamp(c1[2] + (c2[2] - c1[2]) * t)
            )

        targets = [(0,0,0)] * num_leds
        
        # 4. EFFECTS LOGIC
        
        # --- SPECTRUM FAMILY ---
        if "spectrum" in effect:
            # "spectrum", "spectrum_rotate", "spectrum_punchy"
            
            # Rotation
            hue_offset = 0.0
            if "rotate" in effect:
                speed = getattr(settings, 'rotation_speed', 20) / 100.0
                hue_offset = (time.time() * speed) % 1.0
                
            # Punchy Contrast / Logic
            contrast = 1.0
            pre_gain = 1.0
            
            if "punchy" in effect:
                contrast = 2.0 
                pre_gain = 1.5 # Boost input before squaring
                
            # Frequency Window based on Role
            start_f = 0.0
            end_f = 1.0
            
            if role == "bass": end_f = 0.4     
            elif role == "mid": start_f = 0.3; end_f = 0.8
            elif role == "high": start_f = 0.6
            
            range_f = end_f - start_f
            
            for i in range(num_leds):
                # Mapping
                rel_pos = i / max(1, num_leds - 1) 
                abs_pos = start_f + (rel_pos * range_f) 
                
                # Color Calculation
                eff_pos = (abs_pos + hue_offset) % 1.0
                
                if eff_pos < 0.5:
                    base_c = interpolate(c_bass, c_mid, eff_pos * 2.0)
                else:
                    base_c = interpolate(c_mid, c_high, (eff_pos - 0.5) * 2.0)
                
                # Intensity Calculation
                w_bass = max(0, 1.0 - abs(abs_pos - 0.0) * 3.0)
                w_mid  = max(0, 1.0 - abs(abs_pos - 0.5) * 3.0)
                w_high = max(0, 1.0 - abs(abs_pos - 1.0) * 3.0)
                
                raw_intensity = (v_bass * w_bass + v_mid * w_mid + v_high * w_high) * pre_gain
                raw_intensity = min(1.0, raw_intensity)
                
                # Apply Contrast
                intensity = pow(raw_intensity, contrast)
                
                targets[i] = val_scale(base_c, intensity)

        # --- VU METER FAMILY ---
        elif "vumeter" in effect:
            # FIX: User wants "bottom to have bass" and sides to "run up".
            
            # 1. Determine Volume & Gradient
            target_vol = 0.0
            grad_start = c_bass
            grad_end = c_high
            
            if role == "bass":
                target_vol = max(v_sub, v_bass)
                grad_end = c_mid 
            elif role == "mid":
                # Side Segments (Mid) - User wants Bass at bottom of VU
                target_vol = v_mid
                grad_start = c_bass # Force start color to Bass
                grad_end = c_high
            elif role == "high":
                target_vol = v_high
                grad_start = c_high
                grad_end = (255,255,255)
            else:
                target_vol = max(v_bass, v_mid, v_high)

            target_vol = min(1.0, target_vol * 1.5)
            fill = int(target_vol * num_leds)
            
            # 2. Rendering Direction Logic
            # "Sides are inverted" -> Assume Right runs Down physically, so needs Invert logic to look "Up".
            invert_order = False
            if edge == "right": invert_order = True
            
            for i in range(num_leds):
                logical_idx = i
                if invert_order: logical_idx = num_leds - 1 - i
                
                if logical_idx < fill:
                    pos = logical_idx / max(1, num_leds - 1)
                    if "spectrum" in effect:
                        if pos < 0.5: c = interpolate(c_bass, c_mid, pos*2)
                        else: c = interpolate(c_mid, c_high, (pos-0.5)*2)
                        targets[i] = c
                    else:
                        c = interpolate(grad_start, grad_end, pos)
                        targets[i] = c
                else:
                    targets[i] = (0,0,0)

        # --- REACTIVE BASS (Shockwave) ---
        elif effect == "reactive_bass":
            # Center-Out Shockwave Logic
            # IMPROVED: Boost signal significantly.
            
            intensity = v_bass * 2.0 # Double sensitivity
            if intensity > 1.0: intensity = 1.0
            
            # Gentle curve
            intensity = pow(intensity, 1.5)
            
            # Role Damping
            if role == "mid": intensity *= 0.7
            elif role == "high": intensity *= 0.4
            
            # Width - Ensure good visibility
            min_width_pct = 0.15 # 15% always visible if triggered
            width = (min_width_pct + (intensity * (1.0 - min_width_pct))) * (num_leds / 2)
            center = num_leds / 2
            
            c_shock = c_bass
            # Overdrive Color on heavy bass
            if v_bass > 0.7: 
                c_shock = interpolate(c_bass, (255,255,255), (v_bass-0.7)*3)
            
            final_c = val_scale(c_shock, min(1.0, intensity * 2.0))

            for i in range(num_leds):
                dist = abs(i - center)
                if dist < width:
                    rel_dist = dist / width
                    falloff = 1.0 - (rel_dist * rel_dist) # Parabolic
                    targets[i] = val_scale(final_c, falloff)
                else:
                    targets[i] = (0,0,0)

        # --- STROBE ---
        elif effect == "strobe":
            # Binary Flash
            thresh = 0.60 
            val = 0.0
            strobe_color = (255,255,255)
            
            if role == "bass":
                val = v_bass
                strobe_color = c_bass
            elif role == "mid":
                val = v_mid
                strobe_color = c_mid
            elif role == "high":
                val = v_high
                strobe_color = c_high
            else:
                val = max(v_bass, v_high)
            
            if val > thresh:
                targets = [strobe_color] * num_leds
            else:
                targets = [(0,0,0)] * num_leds
                
        # --- PULSE (Volume) ---
        elif effect == "pulse":
            # Aggressive Volume Pulse
            # Bass Slider = Sensitivity Gain
            # Mid Slider = Gamma/Aggression (Sharpness)
            # High Slider = Minimum Brightness
            
            # 1. Master Volume
            vol = max(v_bass, v_mid, v_high)
            
            # 2. Apply Gain (Bass Slider)
            # sens_bass is 0.0 to 2.0 (default 1.0)
            vol *= (sens_bass * 1.5) # Default 1.5x gain
            vol = min(1.0, vol)
            
            # 3. Apply Gamma (Mid Slider)
            # sens_mid is 0.0 to 2.0. Map to 1.0 -> 5.0
            gamma = 1.0 + (sens_mid * 2.5)
            intensity = pow(vol, gamma)
            
            # 4. Apply Min Brightness (High Slider)
            # sens_high 0.0 to 2.0. Map 0.0 -> 0.4
            min_brite = min(0.4, sens_high * 0.2)
            intensity = min_brite + (intensity * (1.0 - min_brite))
            
            # 5. Render
            targets = [val_scale(c_bass, intensity)] * num_leds

        # --- ENERGY (New "Flowing Plasma") ---
        else:
            # "Energy" - Redesigned to be dynamic flowing plasma
            # Instead of solid pulse, use Perlin-like Sine waves moving
            
            t = time.time()
            
            for i in range(num_leds):
                # Spatial coordinate (0.0 to 1.0) across segment
                pos = i / max(1, num_leds)
                
                # 3 Moving Waves
                # Wave 1 (Bass-ish): Slow, heavy
                w1 = math.sin((pos * 3.0) + (t * 1.0)) * 0.5 + 0.5
                # Wave 2 (Mid-ish): Faster
                w2 = math.sin((pos * 5.0) - (t * 2.0)) * 0.5 + 0.5
                # Wave 3 (High-ish): Fast jitter
                w3 = math.sin((pos * 10.0) + (t * 4.0)) * 0.5 + 0.5
                
                # Combine with Audio analysis
                # Energy Brightness
                energy_bass = v_bass * 2.0 * w1
                energy_mid  = v_mid  * 1.5 * w2
                energy_high = v_high * 1.5 * w3
                
                # Composite Color
                # Start with black
                r, g, b = 0, 0, 0
                
                # Add Bass Comp
                bc = val_scale(c_bass, energy_bass)
                r += bc[0]; g += bc[1]; b += bc[2]
                
                # Add Mid Comp
                mc = val_scale(c_mid, energy_mid)
                r += mc[0]; g += mc[1]; b += mc[2]
                
                # Add High Comp
                hc = val_scale(c_high, energy_high)
                r += hc[0]; g += hc[1]; b += hc[2]
                
                # Clamp
                targets[i] = (clamp(r), clamp(g), clamp(b))
            
        return targets