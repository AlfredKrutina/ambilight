# Add audio buffer to audio_processor for stem separation

import sys

filepath = "src/audio_processor.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find where latest_analysis is updated
found = False
new_lines = []

for i, line in enumerate(lines):
    new_lines.append(line)
    
    # After storing latest_analysis, also store raw audio buffer
    if "self.latest_analysis = analysis_result" in line and not found:
        new_lines.append("                        self.latest_buffer = audio_data  # For AI stem separation\n")
        found = True

if found:
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print("✓ Added audio buffer storage to audio_processor")
else:
    print("⚠ Could not find insertion point")
