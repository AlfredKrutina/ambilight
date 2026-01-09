import serial
import time
import struct

PORT = 'COM5'
BAUD = 115200

def debug_jtag():
    print(f"--- JTAG DIAGNOSTIC TOOL ({PORT}) ---")
    
    try:
        # 1. OPEN PORT
        print(f"[1] Opening {PORT}...")
        ser = serial.Serial(PORT, BAUD, timeout=2.0)
        ser.dtr = False # Try to prevent reset?
        ser.rts = False
        print("    SUCCESS: Port Opened.")
        
        # 2. HANDSHAKE
        print("[2] Sending Handshake (0xAA)...")
        ser.reset_input_buffer()
        ser.write(bytes([0xAA]))
        ser.flush()
        
        start = time.time()
        ack = None
        while time.time() - start < 3.0:
            if ser.in_waiting:
                data = ser.read(ser.in_waiting)
                print(f"    Rx Raw: {data}")
                if b'\xBB' in data:
                    ack = True
                    break
            time.sleep(0.1)
            
        if ack:
            print("    SUCCESS: Handshake ACK (0xBB) received!")
        else:
            print("    FAILURE: No 0xBB received. (Make sure Firmware is RUNNING and not in Bootloader)")
            print("    Attempting to continue anyway...")

        # 3. SEND RED FRAME
        print("\n[3] Sending RED Frame...")
        # Frame: 0xFF (Start), 200x [Idx, R, G, B], 0xFE (End)
        frame = bytearray([0xFF])
        for i in range(200):
            # Idx, R, G, B
            # Pixel 0-9: RED
            r = 250 if i < 10 else 0
            g = 0
            b = 0
            frame.extend([i, r, g, b])
        frame.append(0xFE)
        
        print(f"    Sending {len(frame)} bytes...")
        ser.write(frame)
        ser.flush()
        print("    Sent.")
        
        print("\n[4] VERIFICATION")
        print("CHECK LEDS NOW. Do you see RED lights?")
        
        ser.close()
        
    except Exception as e:
        print(f"\nCRITICAL ERROR: {e}")

if __name__ == "__main__":
    debug_jtag()
