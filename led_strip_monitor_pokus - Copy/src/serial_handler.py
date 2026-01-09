import threading
import time
import serial
import serial.tools.list_ports
import queue
from typing import Callable, List, Tuple, Optional

ColorTuple = Tuple[int, int, int]


class SerialHandler(threading.Thread):
    """
    @brief Serial Communication Handler (ESP32-C3).
    @details
    Manages the serial connection to the LED controller. 
    Implements a non-blocking architecture using a Thread and a Queue.
    """
    
    def __init__(
        self,
        port: str,
        baud_rate: int = 115200,
        on_connect: Callable = None,
        on_disconnect: Callable = None,
        on_error: Callable = None
    ):
        super().__init__(daemon=True)
        
        self.port = port
        self.baud_rate = baud_rate
        self.on_connect = on_connect or (lambda: None)
        self.on_disconnect = on_disconnect or (lambda: None)
        self.on_error = on_error or (lambda x: None)
        
        self.ser: Optional[serial.Serial] = None
        self.connected = False
        self.running = True
        
        # QUEUE for non-blocking UI
        # Maxsize 2 ensures we don't buffer too many frames (latency)
        self.queue = queue.Queue(maxsize=2)
        
        self.last_colors: List[ColorTuple] = [(0, 0, 0)] * 20
        self.reconnect_delay = 2.0
        self.last_connect_log = 0.0
        
        print(f"✓ SerialHandler initialized ({port} @ {baud_rate} baud)")
    
    def is_connected(self) -> bool:
        """
        @brief Check connection status.
        @return True if serial port is open and handshake was successful.
        """
        return self.connected and self.ser is not None

    def send_colors(self, colors: List[ColorTuple], brightness: int = 100):
        """
        @brief Send a frame of colors to the LED strip.
        @details
        This method is non-blocking. It pushes the frame data to a thread-safe Queue.
        If the queue is full (maxsize=2), it drops the oldest frame to maintain low latency.
        
        @param colors List of (R, G, B) tuples.
        @param brightness Global brightness modifier (0-255 or 0-100 depending on firmware).
        """
        try:
            # If queue is full, remove old item to keep latency low
            if self.queue.full():
                try:
                    self.queue.get_nowait()
                except queue.Empty:
                    pass
            
            self.queue.put_nowait((colors, brightness))
        except Exception:
            pass # Ignore full queue errors if they somehow happen

    def _write_packet(self, colors: List[ColorTuple], brightness: int):
        """
        @brief Write packet to Serial Port (Blocking IO).
        @details
        Constructs the binary protocol frame:
        [0xFF] [Index, R, G, B, Index, R, G, B ...] [0xFE]
        Executed by the internal thread.
        """
        if not self.connected or not self.ser:
            return
            
        try:
            # FRAME PROTOCOL:
            # Start: 0xFF
            # Data: 200 * [ID, R, G, B]
            # End: 0xFE
            
            TARGET_LEDS = 200
            packet = bytearray([0xFF]) # Start byte
            scale = brightness / 100.0
            
            # 1. Validate Length
            current_len = len(colors)
            if current_len != TARGET_LEDS:
                if current_len < TARGET_LEDS:
                    colors = colors + [(0,0,0)] * (TARGET_LEDS - current_len)
                else:
                    colors = colors[:TARGET_LEDS]
            
            # Optimization: Pre-calculate integers
            for i, (r, g, b) in enumerate(colors):
                r = int(r * scale)
                g = int(g * scale)
                b = int(b * scale)
                # PROTOCOL SAFETY:
                # 0xFF = Start Frame
                # 0xFE = End Frame
                # Max Data Value MUST be 253 (0xFD) to avoid collision!
                packet.append(i & 0xFF)
                packet.append(max(0, min(253, r)))
                packet.append(max(0, min(253, g)))
                packet.append(max(0, min(253, b)))
                
            packet.append(0xFE) # End byte
            
            self.ser.write(packet)
            self.last_colors = colors
            
        except Exception as e:
            print(f"✗ Send error: {e}")
            self.on_error(str(e))
            self.connected = False
            self.ser = None # Mark as dead

    def _disconnect(self):
        """Bezpečné odpojení portu"""
        try:
            if self.ser and self.ser.is_open:
                self.ser.close()
            self.ser = None
            self.connected = False
            print("✓ Serial Disconnected cleanly")
        except Exception as e:
            print(f"⚠ Serial disconnect error: {e}")

    def _handshake(self) -> bool:
        """Ověř, zda je na druhé straně náš ESP32 (Ping/Pong)"""
        try:
            self.ser.reset_input_buffer()
            self.ser.flush()
            print(f"  → Sending Handshake PING to {self.ser.port}...", flush=True)
            self.ser.write(bytes([0xAA]))
            self.ser.flush()
            
            start = time.time()
            time.sleep(0.1) 
            buffer = bytearray()
            
            # UPDATE: Increased to 5s because ESP32 takes ~3.6s to boot/scan Wi-Fi
            # and we might have triggered a reset.
            while time.time() - start < 5.0:
                if self.ser.in_waiting > 0:
                    chunk = self.ser.read(self.ser.in_waiting)
                    buffer.extend(chunk)
                    if b'\xBB' in buffer:
                        print("  ← Handshake PONG received!", flush=True)
                        return True
                    if len(buffer) > 1000: buffer = buffer[-1000:]
                time.sleep(0.05)
            
            print(f"  ✗ Handshake timeout", flush=True)
            return False
        except Exception as e:
            print(f"  ✗ Handshake error: {e}", flush=True)
            return False

    def _auto_detect_port(self) -> Optional[str]:
        """Prohledej dostupné porty a najdi ESP32"""
        available = list(serial.tools.list_ports.comports())
        print(f"🔍 Auto-detecting ESP32 (scanned {len(available)} ports)...")
        for p in available:
            print(f"  Checking {p.device} ({p.description})...")
            try:
                # Quick check
                test_ser = serial.Serial(p.device, self.baud_rate, timeout=1.0)
                time.sleep(1.5) # Wait for reboot
                test_ser.reset_input_buffer()
                test_ser.write(bytes([0xAA]))
                test_ser.flush()
                
                pong = False
                start = time.time()
                while time.time() - start < 1.5:
                    if test_ser.in_waiting:
                        if b'\xBB' in test_ser.read(test_ser.in_waiting):
                            pong = True
                            break
                    time.sleep(0.05)
                test_ser.close()
                if pong: return p.device
            except: continue
        return None

    def _connect(self) -> bool:
        """Pokus se připojit s handshake validací"""
        try:
            self.ser = serial.Serial(self.port, self.baud_rate, timeout=1.0)
            self.ser.rts = True
            self.ser.dtr = False
            
            print(f"⟳ Connecting to {self.port}...")
            time.sleep(0.1)
            
            if self._handshake():
                self.connected = True
                self.on_connect()
                return True
                
            # Hard Reset Strategy
            print("⚠ Hard Reset required...")
            self.ser.dtr = False
            self.ser.rts = True
            time.sleep(0.1)
            self.ser.dtr = True
            time.sleep(0.2)
            self.ser.dtr = False
            self.ser.rts = True
            time.sleep(1.2)
            self.ser.reset_input_buffer()
            
            if self._handshake():
                self.connected = True
                self.on_connect()
                return True
            else:
                self.ser.close()
                self.ser = None
                return False
        
        except serial.SerialException as e:
            if time.time() - self.last_connect_log > 5.0:
                 print(f"✗ Connection error: {e}")
                 self.last_connect_log = time.time()
            self.ser = None
            return False
            
    def change_port(self, new_port):
        """Bezpečně změnit port za běhu"""
        print(f"Changing port to {new_port}")
        self.port = new_port
        self.connected = False 
        if self.ser:
            try: self.ser.close()
            except: pass
            self.ser = None

    def run(self):
        """Main Loop: Reconnect + Consume Queue"""
        last_check = 0
        
        while self.running:
            # 1. MAINTENANCE (Connect/Reconnect)
            if not self.connected:
                if time.time() - last_check > self.reconnect_delay:
                    last_check = time.time()
                    print(f"⏳ Waiting for device on {self.port}...", end='\r')
                    # Try Connect
                    if not self._connect():
                         # If failed, try auto-detect
                         found = self._auto_detect_port()
                         if found:
                             self.port = found
                             self._connect()
            
            # 2. PROCESS QUEUE
            if self.connected:
                try:
                    # Wait constantly for data (blocking with timeout)
                    # Timeout allows us to check 'running' flag periodically
                    data = self.queue.get(timeout=0.5) 
                    colors, brightness = data
                    self._write_packet(colors, brightness)
                    self.queue.task_done()
                except queue.Empty:
                    pass
                except Exception as e:
                    print(f"Queue Error: {e}")
            else:
                time.sleep(0.5)

    def stop(self):
        self.running = False
        self._disconnect()

def get_available_ports() -> List[str]:
    ports = []
    for port, desc, hwid in serial.tools.list_ports.comports():
        ports.append(port)
    return ports