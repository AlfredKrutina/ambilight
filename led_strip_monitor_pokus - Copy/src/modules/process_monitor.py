import time
import ctypes
import os
import logging

logger = logging.getLogger("ProcessMonitor")

class ProcessMonitor:
    """
    @brief Active Window/Process Monitor.
    @details
    Monitors the active foreground window to support Auto-Profile switching (Game Mode detection).
    Uses `ctypes` to make Windows API calls for high performance and low overhead.
    """
    def __init__(self):
        self.user32 = ctypes.windll.user32
        self.kernel32 = ctypes.windll.kernel32
        self.last_check = 0
        self.cached_process = None

    def get_active_window_process(self) -> str:
        """
        @brief Get the executable name of the foreground window.
        @details
        Uses `GetForegroundWindow` and `QueryFullProcessImageNameW` (Win32 API).
        
        @return str: Lowercase executable name definition (e.g., "chrome.exe") or empty string if failed.
        """
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
            # GetModuleFileNameExW (Need psapi usually, or QueryFullProcessImageNameW)
            # Using ctypes simplistic approach or psutil if available is easier.
            # Let's try QueryFullProcessImageNameW (Kernel32)
            
            size = ctypes.c_ulong(512)
            ret = self.kernel32.QueryFullProcessImageNameW(h_process, 0, buf, ctypes.byref(size))
            if ret:
                path = buf.value
                return os.path.basename(path).lower()
        except:
            pass
        finally:
            self.kernel32.CloseHandle(h_process)
            
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
