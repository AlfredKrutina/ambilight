import time
import psutil
import logging

class SystemMonitor:
    """
    @brief System Metrics Collector.
    @details
    Collects real-time system statistics (CPU, RAM, Network) using `psutil`.
    Provides normalized (0-100%) values suitable for LED visualization.
    """
    def __init__(self):
        self.last_net_io = psutil.net_io_counters()
        self.last_time = time.time()
        
    def get_stats(self) -> dict:
        """
        Returns normalized 0-100 values for CPU, RAM, GPU (Mock needed), Net.
        """
        # CPU
        cpu = psutil.cpu_percent(interval=None) # Non-blocking
        
        # RAM
        ram_obj = psutil.virtual_memory()
        ram = ram_obj.percent
        
        # Network Load (Relative to roughly 10MB/s for visualization scaling)
        net_now = psutil.net_io_counters()
        t_now = time.time()
        dt = t_now - self.last_time
        download_speed = 0
        if dt > 0:
            bytes_down = net_now.bytes_recv - self.last_net_io.bytes_recv
            download_speed = (bytes_down / dt) / (1024 * 1024) # MB/s
        
        # Update trackers
        self.last_net_io = net_now
        self.last_time = t_now
        
        # Scaling Network: 0MB/s -> 0%, 10MB/s -> 100%
        net_percent = min(100, (download_speed / 10.0) * 100)
        
        # GPU (Hard without widespread libraries like GPUtil or nvidia-ml-py)
        # Mocking or omitting for now.
        gpu = 0 
        
        return {
            "cpu": cpu,
            "ram": ram,
            "gpu": gpu,
            "net": net_percent
        }
