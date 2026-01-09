import sys
import time
import serial
import serial.tools.list_ports

def diagnose():
    print("=== D I A G N O S T I C   T O O L ===")
    
    ports = list(serial.tools.list_ports.comports())
    print(f"Found {len(ports)} ports:")
    for p in ports:
        print(f"  - {p.device} ({p.description})")

    if not ports:
        print("No ports found! Check USB cable.")
        return

    target_port = "COM5"
    if not any(p.device == target_port for p in ports):
        print(f"WARNING: {target_port} not found in list. Using first available port.")
        target_port = ports[0].device
    else:
        print(f"Targeting {target_port}...")

    try:
        ser = serial.Serial(target_port, 115200, timeout=0.1)
        print(f"Opened {target_port} successfully.")
    except Exception as e:
        print(f"ERROR calling serial.Serial: {e}")
        print("is another app (e.g. idf_monitor or main.py) using the port?")
        return

    print("\n--- STEP 1: Reset Board & Listen (3s) ---")
    # Toggle DTR/RTS to reset
    ser.dtr = False
    ser.rts = False
    time.sleep(0.1)
    ser.dtr = True
    ser.rts = True
    
    start = time.time()
    buffer = bytearray()
    
    while time.time() - start < 3.0:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting)
            buffer.extend(data)
            sys.stdout.write(".")
            sys.stdout.flush()
        time.sleep(0.05)
    print("\n")

    print(f"Received {len(buffer)} bytes during boot.")
    if len(buffer) > 0:
        print("Preview (Hex): " + buffer[:50].hex(" "))
        print("Preview (ASCII): " + buffer[:200].decode("ascii", errors="replace").replace("\n", " ").replace("\r", ""))
        
        if b"Ambilight ESP32-C3 STARTED" in buffer:
            print("\n✅ FIRMWARE MATCH: New firmware detected!")
        elif b"Init LED strip" in buffer:
            print("\n❌ FIRMWARE MISMATCH: Old firmware detected!")
        else:
            print("\n⚠️  FIRMWARE UNKNOWN: formatting mismatch or garbage data.")
    else:
        print("❌ NO DATA RECEIVED during boot. Dead board or bad cable?")

    print("\n--- STEP 2: Handshake Test ---")
    print(f"Sending PING (0xAA)...")
    ser.write(bytes([0xAA]))
    
    start = time.time()
    response_buffer = bytearray()
    found_pong = False
    
    while time.time() - start < 1.0:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting)
            response_buffer.extend(data)
            if b'\xBB' in response_buffer:
                found_pong = True
        time.sleep(0.05)
        
    print(f"Response: {response_buffer.hex(' ')}")
    if found_pong:
        print("✅ PONG RECEIVED! Handshake working.")
    else:
        print("❌ PONG MISSING. Handshake failed.")

    ser.close()

if __name__ == "__main__":
    diagnose()
