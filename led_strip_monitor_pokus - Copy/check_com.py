import serial
import serial.tools.list_ports
import time

def check_com5():
    print("--- COM Port Diagnostic ---")
    ports = list(serial.tools.list_ports.comports())
    found = False
    for p in ports:
        print(f"Found: {p.device} - {p.description}")
        if "COM5" in p.device:
            found = True

    if not found:
        print("ERROR: COM5 not found in system!")
        return

    print("\nAttempting to open COM5...")
    try:
        ser = serial.Serial('COM5', 115200, timeout=1)
        print("SUCCESS: COM5 Opened!")
        print("Closing...")
        ser.close()
    except Exception as e:
        print(f"FAILURE: Could not open COM5.")
        print(f"Error details: {e}")
        print("Reason: This usually means another program (Monitor, Cura, VS Code) is using it.")

if __name__ == "__main__":
    check_com5()
