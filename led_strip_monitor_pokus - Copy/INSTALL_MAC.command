#!/bin/bash
cd "$(dirname "$0")"

echo "=========================================="
echo "      Installing AmbiLight for Mac (M1/Intel)"
echo "=========================================="

# 1. Check Python
if ! command -v python3 &> /dev/null; then
    echo "[ERROR] Python 3 is not installed."
    echo "Please install Python 3 (e.g. from python.org or 'brew install python')"
    exit 1
fi

# 2. Setup Virtual Env
echo "--> Setting up Python Environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

# 3. Install Dependencies
echo "--> Installing Dependencies..."
# Ensure pip is up to date
pip install --upgrade pip
# Install requirements
# Note: On M1, some libs might need specific flags.
# Exclude Windows-only libs
grep -v "pyaudiowpatch" requirements.txt | grep -v "dxcam" > requirements_mac.txt
pip install -r requirements_mac.txt
pip install pyaudio
rm requirements_mac.txt

# 4. Create Launch Agent (Autostart)
echo "--> Setting up Autostart..."
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.ambilight.plist"
PWD_PATH=$(pwd)
PYTHON_PATH="$PWD_PATH/venv/bin/python"
MAIN_PATH="$PWD_PATH/src/main.py"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.ambilight</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_PATH</string>
        <string>$MAIN_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$PWD_PATH</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ambilight.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/ambilight.out</string>
</dict>
</plist>
EOF

# Load the agent immediately
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "--> Creating Start Script..."
# Create a handy run script
cat > "Run_AmbiLight.command" << EOF
#!/bin/bash
cd "$PWD_PATH"
source venv/bin/activate
python src/main.py
EOF
chmod +x "Run_AmbiLight.command"

echo "=========================================="
echo "      Installation Complete!"
echo "=========================================="
echo "1. The app will now start automatically on login."
echo "2. You can manually run it using 'Run_AmbiLight.command'."
