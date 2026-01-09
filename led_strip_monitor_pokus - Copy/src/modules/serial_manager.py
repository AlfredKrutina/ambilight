from typing import List, Dict, Tuple
from serial_handler import SerialHandler
from app_config import DeviceSettings
import time

class SerialManager:
    """
    Manages multiple SerialHandler instances corresponding to configured devices.
    """
    
    def __init__(self):
        # Map device_id -> SerialHandler
        self.handlers: Dict[str, SerialHandler] = {}
        # Map device_id -> DeviceSettings (cache)
        self.configs: Dict[str, DeviceSettings] = {}
        
    def update_devices(self, new_configs: List[DeviceSettings]):
        """
        Reconcile active handlers with new configuration.
        - Create handlers for new devices
        - Update ports for existing devices if changed
        - Remove handlers for deleted devices
        """
        new_ids = {d.id for d in new_configs}
        current_ids = set(self.handlers.keys())
        
        # 1. REMOVE deleted devices
        to_remove = current_ids - new_ids
        for did in to_remove:
            print(f"SerialManager: Removing device {did}")
            self.handlers[did].stop()
            del self.handlers[did]
            if did in self.configs: del self.configs[did]
            
        # 2. UPDATE or ADD devices
        for cfg in new_configs:
            self.configs[cfg.id] = cfg
            
            if cfg.id in self.handlers:
                # Update existing
                handler = self.handlers[cfg.id]
                if handler.port != cfg.port:
                    print(f"SerialManager: Updating port for {cfg.name} ({handler.port} -> {cfg.port})")
                    handler.change_port(cfg.port)
            else:
                # Create new
                print(f"SerialManager: Adding new device {cfg.name} on {cfg.port}")
                handler = SerialHandler(port=cfg.port, baud_rate=115200)
                handler.start()
                self.handlers[cfg.id] = handler

    def send_to_device(self, device_id: str, colors: List[Tuple[int,int,int]], brightness: int):
        """Send color frame to specific device"""
        if device_id in self.handlers:
            self.handlers[device_id].send_colors(colors, brightness)
            
    def close_all(self):
        print("SerialManager: Closing all devices...")
        for h in self.handlers.values():
            h.stop()
        self.handlers.clear()
        
    def get_status(self) -> Dict[str, bool]:
        """Return {device_name: is_connected}"""
        status = {}
        for did, h in self.handlers.items():
             name = self.configs[did].name if did in self.configs else did
             status[name] = h.is_connected()
        return status
