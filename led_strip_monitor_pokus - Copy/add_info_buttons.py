#!/usr/bin/env python3
"""
Quick script to add info buttons for PC Health and Melody Smart modes
"""

filepath = "src/ui/settings_dialog.py"

# Info button text content
pc_health_info = '''╔═══════════════════════════════════════════╗
║   💻 PC Health Monitor Mode               ║
╠═══════════════════════════════════════════╣
║ Visualizes your PC's performance metrics  ║
║ on the LED strip as colored gradients.    ║
║                                            ║
║ 📊 Metrics:                                ║
║  • CPU Usage (0-100%)                     ║
║  • GPU Usage (0-100%)                     ║
║  • RAM Usage (0-100%)                     ║
║  • CPU Temperature (°C)                   ║
║  • GPU Temperature (°C)                   ║
║                                            ║
║ 🎨 Color Scales:                           ║
║  Blue → Yellow → Red (low to high)        ║
║  Custom: Define your own 3-color gradient ║
║                                            ║
║ 🔧 Refresh Rate:                           ║
║  How often metrics update (seconds)       ║
║  Lower = more responsive, higher CPU      ║
║                                            ║
║ 💡 Tip: Use 'Custom' gradient to match    ║
║ your setup's RGB theme!                   ║
╚═══════════════════════════════════════════╝'''

melody_smart_info = '''╔═══════════════════════════════════════════╗
║   🎵 Melody Smart Mode                    ║
╠═══════════════════════════════════════════╣
║ Multi-band reactive visualization that    ║
║ splits the LED strip into 4 zones, each   ║
║ responding to different frequency ranges.  ║
║                                            ║
║ 🎨 LED Zones (66 LEDs):                    ║
║  ┌─────────────────────────────────────┐  ║
║  │ 0-16: 🔴 BASS (60-250 Hz)           │  ║
║  │ 17-33: 🟠 LOW-MID (250-800 Hz)      │  ║
║  │ 34-50: 🟢 MID-HIGH (800-3000 Hz)    │  ║
║  │ 51-66: 🟣 TREBLE (3000-8000 Hz)     │  ║
║  └─────────────────────────────────────┘  ║
║                                            ║
║ ⚡ Flash Detection:                        ║
║  Each zone independently flashes on        ║
║  onset detection (energy spike).           ║
║  Decay: 0.70x per frame (punchy!)         ║
║                                            ║
║ 🎚 Brightness = Flash (70%) + Energy (30%)║
║                                            ║
║ 💡 Tip: Works best with songs that have   ║
║ clear instrument separation!              ║
╚═══════════════════════════════════════════╝'''

# Info methods to add
info_methods = f'''
    def _show_pc_health_info(self):
        """Show PC Health monitor mode info"""
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.information(self, "PC Health Monitor", """{pc_health_info}""")
    
    def _show_melody_smart_info(self):
        """Show Melody Smart effect info"""
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.information(self, "Melody Smart Effect", """{melody_smart_info}""")
'''

# Read file
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Find insertion point (end of class, before last line)
# Add methods before the last method or at end of class
insert_marker = "    def _sync_ui_theme"  # Find a known method near the end

if insert_marker in content:
    parts = content.split(insert_marker)
    new_content = parts[0] + info_methods + "\n    def _sync_ui_theme" + parts[1]
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✓ Added info button methods to settings_dialog.py")
    print("  → _show_pc_health_info()")
    print("  → _show_melody_smart_info()")
else:
    print("⚠ Could not find insertion point")
    print("  Manual addition required")
