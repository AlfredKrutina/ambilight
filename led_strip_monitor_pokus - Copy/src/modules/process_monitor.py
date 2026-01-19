import time
import os
import logging
from utils import is_windows, is_mac

logger = logging.getLogger("ProcessMonitor")

# Platform-specific imports
if is_windows():
    import ctypes
elif is_mac():
    try:
        from AppKit import NSWorkspace, NSRunningApplication
        APPKIT_AVAILABLE = True
    except ImportError:
        APPKIT_AVAILABLE = False
        logger.warning("AppKit not available - ProcessMonitor will use fallback on Mac")
else:
    # Linux - no native implementation yet
    pass

class ProcessMonitor:
    """
    @brief Active Window/Process Monitor.
    @details
    Monitors the active foreground window to support Auto-Profile switching (Game Mode detection).
    Platform-aware implementation:
    - Windows: Uses Win32 API (GetForegroundWindow, QueryFullProcessImageNameW)
    - macOS: Uses AppKit (NSWorkspace, NSRunningApplication)
    - Linux: Fallback (returns empty string)
    """
    def __init__(self):
        self.last_check = 0
        self.cached_process = None
        
        if is_windows():
            self.user32 = ctypes.windll.user32
            self.kernel32 = ctypes.windll.kernel32
        elif is_mac():
            if APPKIT_AVAILABLE:
                self.workspace = NSWorkspace.sharedWorkspace()
            else:
                self.workspace = None
        # Linux: no initialization needed

    def get_active_window_process(self) -> str:
        """
        @brief Get the executable name of the foreground window.
        @details
        Platform-specific implementation:
        - Windows: Uses Win32 API
        - macOS: Uses AppKit NSWorkspace
        - Linux: Returns empty string (not implemented)
        
        @return str: Lowercase executable name (e.g., "chrome.exe" or "Chrome.app") or empty string if failed.
        """
        if is_windows():
            return self._get_active_window_process_windows()
        elif is_mac():
            return self._get_active_window_process_mac()
        else:
            # Linux - not implemented yet
            return ""

    def _get_active_window_process_windows(self) -> str:
        """Windows implementation using Win32 API"""
        try:
            hwnd = self.user32.GetForegroundWindow()
            if not hwnd:
                return ""

            pid = ctypes.c_ulong()
            self.user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            
            # Open Process logic
            PROCESS_QUERY_INFORMATION = 0x0400
            PROCESS_VM_READ = 0x0010
            
            h_process = self.kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)
            if not h_process:
                return ""
                
            try:
                buf = ctypes.create_unicode_buffer(512)
                size = ctypes.c_ulong(512)
                ret = self.kernel32.QueryFullProcessImageNameW(h_process, 0, buf, ctypes.byref(size))
                if ret:
                    path = buf.value
                    return os.path.basename(path).lower()
            except:
                pass
            finally:
                self.kernel32.CloseHandle(h_process)
        except Exception as e:
            logger.debug(f"Windows process detection failed: {e}")
            
        return ""

    def _get_active_window_process_mac(self) -> str:
        """macOS implementation using AppKit"""
        try:
            if not APPKIT_AVAILABLE or self.workspace is None:
                return ""
            
            # Get active application
            active_app = NSWorkspace.sharedWorkspace().activeApplication()
            if not active_app:
                return ""
            
            # Get bundle identifier or process name
            bundle_id = active_app.get('NSApplicationBundleIdentifier', '')
            if bundle_id:
                # Extract app name from bundle ID (e.g., "com.google.Chrome" -> "Chrome")
                app_name = bundle_id.split('.')[-1]
                # For .app bundles, add .app extension for consistency
                return f"{app_name}.app".lower()
            
            # Fallback: try to get process name from NSRunningApplication
            running_apps = NSWorkspace.sharedWorkspace().runningApplications()
            for app in running_apps:
                if app.isActive():
                    bundle_path = app.bundleURL()
                    if bundle_path:
                        path_str = bundle_path.path()
                        if path_str:
                            # Extract app name from path (e.g., "/Applications/Chrome.app" -> "Chrome.app")
                            app_name = os.path.basename(path_str)
                            return app_name.lower()
                    # Fallback to localized name
                    localized_name = app.localizedName()
                    if localized_name:
                        return f"{localizedName}.app".lower()
                    break
        except Exception as e:
            logger.debug(f"macOS process detection failed: {e}")
            
        return ""

    def check_game_rules(self, rules: dict) -> str:
        """
        Checks if current active process matches any rule.
        rules: {"csgo.exe": {"profile": "Gaming_FPS"}, ...} or mapping
        Returns: Profile Name or None
        """
        active_exe = self.get_active_window_process()
        if not active_exe: return None
        
        # Simple exact match first
        if active_exe in rules:
            return rules[active_exe].get("profile")
            
        return None
