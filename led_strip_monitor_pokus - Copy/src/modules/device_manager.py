from typing import List, Dict, Tuple, Optional
import socket
import time
from serial_handler import SerialHandler
from app_config import DeviceSettings

class NetworkHandler:
    """Lightweight UDP Sender for Wi-Fi Devices"""
    def __init__(self, ip: str, port: int):
        self.ip = ip
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.connected = True # UDP is connectionless
    
    def send_colors(self, colors: List[Tuple[int, int, int]], brightness: int):
        try:
            # Protocol: 0x02 (Frame) + Brightness + RGB...
            packet = bytearray([0x02, brightness])
            
            # Simple Flatten
            # Optimized Packet Construction
            # Flatten list of tuples -> flat list of ints [r,g,b, r,g,b...]
            # Use clamping in list comp for speed or assume inputs are somewhat safe (clamp is safer)
            
            # Fast Clamp & Flatten
            flat_data = [max(0, min(255, c)) for tup in colors for c in tup]
            packet.extend(flat_data)
                
            self.sock.sendto(packet, (self.ip, self.port))
            self.connected = True
            
        except Exception as e:
            self.connected = False
            print(f"UDP Error: {e}")
            pass

    def is_connected(self):
        return True # Optimistic
        
    def stop(self):
        self.sock.close()
        
    def change_port(self, new_port):
        self.port = int(new_port)

    def send_pixel(self, idx: int, r: int, g: int, b: int):
        """Send single pixel update (Protocol 0x03)"""
        try:
            # Protocol: 0x03 (Single Pixel) + IdxHi + IdxLo + R + G + B
            # Total 6 bytes
            packet = bytearray([0x03, (idx >> 8) & 0xFF, idx & 0xFF, r, g, b])
            self.sock.sendto(packet, (self.ip, self.port))
            self.connected = True
        except Exception as e:
            print(f"UDP Pixel Error: {e}")
            self.connected = False

class DeviceManager:
    """
    Manages multiple Device Handlers (Serial or Network).
    Replaces SerialManager.
    """
    
    def __init__(self):
        # Map device_id -> Handler
        self.handlers = {}
        # Map device_id -> DeviceSettings
        self.configs: Dict[str, DeviceSettings] = {}
        
    def update_devices(self, new_configs: List[DeviceSettings]):
        """
        Reconcile active handlers with new configuration.
        """
        new_ids = {d.id for d in new_configs}
        current_ids = set(self.handlers.keys())
        
        # 1. REMOVE
        to_remove = current_ids - new_ids
        for did in to_remove:
            print(f"DeviceManager: Removing {did}")
            self.handlers[did].stop()
            del self.handlers[did]
            if did in self.configs: del self.configs[did]
            
        # 2. UPDATE/ADD
        for cfg in new_configs:
            self.configs[cfg.id] = cfg
            
            if cfg.id in self.handlers:
                # Existing - Check if type/param changed?
                # For simplicity, if critical params change, we might recreate or update.
                handler = self.handlers[cfg.id]
                
                if cfg.type == "serial":
                    if isinstance(handler, SerialHandler):
                        if handler.port != cfg.port:
                            handler.change_port(cfg.port)
                    else:
                        # Type changed! Recreate
                        handler.stop()
                        self._create_handler(cfg)
                        
                elif cfg.type == "wifi":
                    if isinstance(handler, NetworkHandler):
                        # Update IP/Port if needed?
                        if handler.ip != cfg.ip_address or handler.port != cfg.udp_port:
                            # NetworkHandler is cheap, just replace
                            handler.stop()
                            self._create_handler(cfg)
                    else:
                        # Type changed
                        handler.stop()
                        self._create_handler(cfg)
            else:
                # New
                self._create_handler(cfg)

    def _create_handler(self, cfg: DeviceSettings):
        print(f"DeviceManager: Creating handler for {cfg.name} ({cfg.type})")
        if cfg.type == "serial":
            # Avoid empty ports
            if not cfg.port or cfg.port == "COMx": return
            h = SerialHandler(port=cfg.port, baud_rate=115200)
            h.start()
            self.handlers[cfg.id] = h
        elif cfg.type == "wifi":
            if not cfg.ip_address: return
            # Sanitize IP (replace commas with dots if user entered common typo)
            safe_ip = cfg.ip_address.replace(',', '.')
            if safe_ip != cfg.ip_address:
                print(f"DeviceManager: Auto-correcting IP {cfg.ip_address} -> {safe_ip}")
            
            print(f"DeviceManager: Initializing UDP Handler for {cfg.name} -> {safe_ip}:{cfg.udp_port}")
            h = NetworkHandler(safe_ip, cfg.udp_port)
            self.handlers[cfg.id] = h

    def send_to_device(self, device_id: str, colors: List[Tuple[int,int,int]], brightness: int):
        if device_id in self.handlers and device_id in self.configs:
            # Check Control via HA flag
            if self.configs[device_id].control_via_ha:
                # User wants to control this specific device via HA/MQTT.
                # Do NOT send data from PC, so firmware switches to Wi-Fi.
                return
                
            self.handlers[device_id].send_colors(colors, brightness)

    def send_pixel(self, device_id: str, idx: int, r: int, g: int, b: int):
        if device_id in self.handlers:
            handler = self.handlers[device_id]
            if isinstance(handler, NetworkHandler):
                handler.send_pixel(idx, r, g, b)
            # SerialHandler doesn't support this direct method yet in this abstraction, 
            # but usually handled via raw serial if needed, or we can add it later.
            # For now, wizard uses send_to_device for Serial which works.
            
    def close_all(self):
        for h in self.handlers.values():
            h.stop()
        self.handlers.clear()
        
    def get_status(self) -> Dict[str, bool]:
        status = {}
        for did, h in self.handlers.items():
            name = self.configs[did].name if did in self.configs else did
            status[name] = h.is_connected()
        return status
