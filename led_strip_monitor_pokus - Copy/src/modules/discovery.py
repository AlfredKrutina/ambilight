import socket
import threading
import time
import uuid
from typing import Dict, Callable, Optional

class DiscoveryService(threading.Thread):
    """
    Background service that scans for ESP32 devices via UDP Broadcast.
    Listens on Port 4210.
    """
    
    def __init__(self, port: int = 4210):
        super().__init__(daemon=True)
        self.port = port
        self.running = True
        self.sock = None
        self.found_devices: Dict[str, dict] = {} # ip -> info
        self.on_device_found: Optional[Callable] = None
        
        self._init_socket()
        
    def clear_cache(self):
        """Clear found devices list to allow re-discovering"""
        self.found_devices.clear()
        
    def _init_socket(self):
        """Initialize SINGLE Global Socket"""
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            
            # Bind to 0.0.0.0 (Global) - Listening on ALL interfaces
            try:
                self.sock.bind(('', 0)) 
                addr = self.sock.getsockname()
                print(f"✓ DiscoveryService bound to {addr} (Global)")
            except Exception as e:
                print(f"⚠️ Discovery bind failed: {e}")
                self.sock = None
                return

            self.sock.settimeout(1.0)
        except Exception as e:
            print(f"✗ Discovery socket init error: {e}")
            self.sock = None

    def identify_device(self, ip_address: str, port: int = 4210):
        """Send logic-level unique Identify packet (Universal)"""
        try:
            print(f"🔍 Sending IDENTIFY to {ip_address}:{port}")
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.settimeout(0.5)
                s.sendto(b"IDENTIFY", (ip_address, port))
        except Exception as e:
            print(f"✗ Identify failed for {ip_address}: {e}")

    def reset_wifi_device(self, ip_address: str, port: int = 4210):
        """Send RESET_WIFI command to device"""
        try:
            print(f"⚠️ Sending RESET_WIFI to {ip_address}:{port}")
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.settimeout(0.5)
                s.sendto(b"RESET_WIFI", (ip_address, port))
        except Exception as e:
            print(f"✗ Reset WiFi failed for {ip_address}: {e}")

    def get_local_interfaces(self):
        """Returns list of (ip, broadcast_ip) tuples"""
        interfaces = []
        try:
            # Plan A: netifaces (if user installs it later)
            import netifaces
            for iface in netifaces.interfaces():
                addrs = netifaces.ifaddresses(iface)
                if netifaces.AF_INET in addrs:
                    for link in addrs[netifaces.AF_INET]:
                        ip = link.get('addr')
                        bcast = link.get('broadcast')
                        if ip and not ip.startswith('127.'):
                            if not bcast:
                                # Fallback guess
                                parts = ip.split('.')
                                parts[3] = '255'
                                bcast = ".".join(parts)
                            interfaces.append((ip, bcast))
        except ImportError:
            # Plan B: socket (Standard Lib)
            try:
                hostname = socket.gethostname()
                ips = socket.gethostbyname_ex(hostname)[2]
                for ip in ips:
                    if not ip.startswith('127.'):
                        # Assume /24 Class C
                        parts = ip.split('.')
                        parts[3] = '255'
                        bcast = ".".join(parts)
                        interfaces.append((ip, bcast))
            except Exception as e:
                print(f"Error enumerating interfaces: {e}")
        
        return list(set(interfaces)) # Dedup

    def scan(self, target_interface_ip: str = None):
        """
        Send broadcast discovery packet via routing logic.
        """
        if not self.sock: return
        
        msg = b"DISCOVER_ESP32"
        interfaces = self.get_local_interfaces()
        targets = []
        
        if target_interface_ip and target_interface_ip != "All":
            # 1. Target Specific Subnet Broadcast
            for ip, bcast in interfaces:
                if ip == target_interface_ip:
                    targets.append(bcast)
        else:
            # 2. Target All Subnet Broadcasts
            for ip, bcast in interfaces:
                targets.append(bcast)
            targets.append('255.255.255.255')
            
        targets = list(set(targets))
        
        # Run send logic in separate thread to prevent blocking Main Thread (UI)
        def _send_burst():
            # Burst send
            for _ in range(3):
                for t in targets:
                    try:
                        self.sock.sendto(msg, (t, self.port))
                        time.sleep(0.01)
                    except: pass
                time.sleep(0.1)
                
        threading.Thread(target=_send_burst, daemon=True).start()
            
    def run(self):
        while self.running:
            if not self.sock:
                time.sleep(2)
                self._init_socket()
                continue
                
            try:
                data, addr = self.sock.recvfrom(1024)
                ip = addr[0]
                
                text = data.decode('utf-8', errors='ignore')
                if text.startswith("ESP32_PONG"):
                    parts = text.split('|')
                    if len(parts) >= 4:
                        dev_id = parts[1]
                        name = parts[2]
                        leds = int(parts[3])
                        
                        info = {
                            "ip": ip,
                            "id": dev_id,
                            "name": name,
                            "led_count": leds,
                            "last_seen": time.time()
                        }
                        
                        # Re-notify logic
                        is_new = ip not in self.found_devices
                        self.found_devices[ip] = info
                        
                        if is_new:
                            print(f"✓ Found Device: {name} ({ip})")
                            if self.on_device_found:
                                self.on_device_found(info)
                                
            except socket.timeout:
                continue
            except Exception as e:
                # WinError 10038 = Socket closed
                if getattr(e, 'winerror', 0) == 10038 or e.args[0] == 10038:
                    break
                print(f"Discovery Loop Error: {e}")
                time.sleep(1)
                
    def stop(self):
        self.running = False
        if self.sock:
            try: self.sock.close()
            except: pass
