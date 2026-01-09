import serial
import time
import sys

def test_safe_reset():
    port = "COM5"
    print(f"Opening {port} (Strategy 2)...")
    
    try:
        ser = serial.Serial(port, 115200, timeout=0.5)
    except Exception as e:
        print(f"Failed to open: {e}")
        return

    # STRATEGY 2: Native USB often uses DTR for Reset and RTS for Boot.
    # To Reset into Run:
    # 1. Assert Reset (DTR=1)
    # 2. Deassert Boot (RTS=0 / High-Z)
    
    # Wait, previous attempt (DTR=1, RTS=0) failed.
    # Maybe logic is inverted? 
    # Let's try setting RTS=1 (Active) which might pull IO9 High if inverted circuit?
    # Or just NOT touching DTR at all?
    
    # Let's try: No Toggle. Just close and open.
    # If standard open resets it, we need to find what state 'open' leaves it in.
    
    print("Testing RTS=True (maybe inverted?)...")
    ser.dtr = False
    ser.rts = True  # Try asserting RTS (maybe this releases Boot?)
    time.sleep(0.1)
    
    ser.dtr = True  # Reset
    time.sleep(0.2)
    
    ser.dtr = False # Release Reset
    ser.rts = True  # Keep RTS asserted
    
    print("Waiting for boot logs...")
    start = time.time()
    buffer = bytearray()
    
    while time.time() - start < 3.0:
        if ser.in_waiting:
            buffer.extend(ser.read(ser.in_waiting))
        time.sleep(0.05)
        
    print(f"\nReceived {len(buffer)} bytes.")
    content = buffer.decode("ascii", errors="replace")
    print(content)
    
    if "waiting for download" in content:
        print("\n❌ FAILED: Still in DOWNLOAD mode.")
    elif "STARTED" in content or "ESP-ROM" in content:
        print("\n✅ SUCCESS: Booted into RUN mode!")
        # If this works, we know RTS=True is needed to keep Boot Pin High
    else:
        print("\n⚠️  UNKNOWN: No clear boot message.")
        
    ser.close()

if __name__ == "__main__":
    test_safe_reset()
