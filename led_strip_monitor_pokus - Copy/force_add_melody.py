#!/usr/bin/env python3
"""FORCE add melody to audio_processor - proper this time"""

filepath = "src/audio_processor.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find key locations
init_end = -1
get_analysis_end = -1
run_analysis_line = -1

for i, line in enumerate(lines):
    if "self.paused = False" in line and i < 50:
        init_end = i
    if "return self.latest_analysis" in line and i > 100:
        get_analysis_end = i
    if "self.latest_analysis = analysis_result" in line and i > 180:
        run_analysis_line = i

print(f"Found: init_end={init_end}, get_analysis_end={get_analysis_end}, run_analysis={run_analysis_line}")

# Build new file
new_lines = []

for i, line in enumerate(lines):
    new_lines.append(line)
    
    # After paused field in __init__
    if i == init_end:
        new_lines.append("\n")
        new_lines.append("        # Melody detection (lazy-init)\n")
        new_lines.append("        self.melody_detector = None\n")
        new_lines.append("        self.melody_enabled = False\n")
        new_lines.append("        self.latest_melody = {'onset': False, 'pitch': 0, 'beat': False}\n")
    
    # After get_analysis method
    if i == get_analysis_end:
        new_lines.append("\n")
        new_lines.append("    def enable_melody_detection(self, enabled: bool):\n")
        new_lines.append("        self.melody_enabled = enabled\n")
        new_lines.append("        if enabled and self.melody_detector is None:\n")
        new_lines.append("            try:\n")
        new_lines.append("                from melody_detector import MelodyDetector\n")
        new_lines.append("                self.melody_detector = MelodyDetector(self.analyzer.sr)\n")
        new_lines.append("                print('✓ Melody detection enabled')\n")
        new_lines.append("            except Exception as e:\n")
        new_lines.append("                print(f'⚠ Melody unavailable: {e}')\n")
        new_lines.append("                self.melody_enabled = False\n")
        new_lines.append("\n")
        new_lines.append("    def get_melody_analysis(self):\n")
        new_lines.append("        with self.lock:\n")
        new_lines.append("            return self.latest_melody\n")
    
    # In run loop after analysis
    if i == run_analysis_line:
        new_lines.append("\n")
        new_lines.append("                        # Melody\n")
        new_lines.append("                        if self.melody_enabled and self.melody_detector:\n")
        new_lines.append("                            self.latest_melody = self.melody_detector.process_frame(audio_data)\n")

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✓ FORCE added melody detection to audio_processor.py")
