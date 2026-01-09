#!/usr/bin/env python3
"""Fix syntax error in melody effect"""

filepath = "src/app.py"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the typo
content = content.replace("self.melody_color hue", "self.melody_color_hue")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ Fixed: self.melody_color hue → self.melody_color_hue")
