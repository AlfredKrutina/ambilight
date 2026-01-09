#!/usr/bin/env python3
"""Fix melody dropdown - add to correct widget"""

filepath = "src/ui/settings_dialog.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed_lines = []
for i, line in enumerate(lines):
    # Skip the wrong line (996)
    if i == 995 and 'self.cb_effect.addItem("Melody Smart' in line:
        # Skip this line, it's wrong widget
        continue
    
    # Fix line 995 - add melody_smart to the list
    if i == 994 and 'self.cb_music_effect.addItems' in line:
        # Replace with version including melody_smart
        fixed_lines.append('        self.cb_music_effect.addItems(["energy", "spectrum", "spectrum_rotate", "spectrum_punchy", "reactive_bass", "vumeter", "strobe", "melody_smart"])\n')
        continue
    
    fixed_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(fixed_lines)

print("✓ Fixed: melody_smart added to cb_music_effect dropdown")
print("✓ Removed wrong line from cb_effect")
