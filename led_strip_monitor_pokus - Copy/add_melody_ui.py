#!/usr/bin/env python3
"""Add Melody Smart to UI dropdown"""

filepath = "src/ui/settings_dialog.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find last cb_effect.addItem and add melody after it
fixed_lines = []
added = False

for i, line in enumerate(lines):
    fixed_lines.append(line)
    
    # After last addItem for music effects, add melody smart
    if not added and '"strobe"' in line and 'addItem' in line:
        # Add after this line
        fixed_lines.append('        self.cb_effect.addItem("Melody Smart 🎵", "melody_smart")\n')
        added = True
        print(f"Added at line {i+1}")

if added:
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)
    print("✓ Added Melody Smart to UI dropdown")
else:
    print("⚠ Could not find insertion point")
