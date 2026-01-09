#!/usr/bin/env python3
"""
Integrate AI stem separation into melody_smart effect
- Lazy loads only when effect is active
- 4 LED zones for 4 stems (vocals, bass, drums, other)
- Fast decay 0.50
"""

filepath = "src/app.py"

# Read
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find melody_smart effect
start = -1
end = -1

for i, line in enumerate(lines):
    if 'elif settings.effect == "melody_smart"' in line:
        start = i
    if start > 0 and end < 0 and ('elif settings.effect ==' in line or 'elif settings.effect==' in line) and i > start:
        end = i
        break

if start < 0:
    print("✗ melody_smart not found")
    exit(1)

print(f"Found: lines {start+1} to {end+1}")

# New AI-powered effect
new_effect = """
        elif settings.effect == "melody_smart":
            # MELODY SMART v3 - AI Source Separation (Spleeter 4 stems)
            # Lazy-loads only when active - no CPU when not selected
            
            from stem_separator import get_stem_separator
            
            separator = get_stem_separator()
            
            # Enable on first use (lazy-load Spleeter model)
            if not separator.enabled:
                separator.enable()
            
            # Get audio for processing
            analysis = self.audio_processor.get_analysis()
            
            # Send audio chunk to background processor (non-blocking)
            if hasattr(self.audio_processor, 'latest_buffer'):
                audio_chunk = self.audio_processor.latest_buffer
                separator.process_audio_chunk(audio_chunk, 48000)
            
            # Get latest stem analysis (non-blocking)
            stems = separator.get_latest_stems()
            
            # === 4 LED ZONES for 4 STEMS ===
            # Zone mapping:
            # LEDs 0-16: Vocals (cyan)
            # LEDs 17-33: Bass (red)
            # LEDs 34-50: Drums (yellow)
            # LEDs 51-66: Other (purple)
            
            zone_stems = ['vocals', 'bass', 'drums', 'other']
            zone_colors = [
                (0, 255, 255),    # Vocals: Cyan
                (255, 50, 0),     # Bass: Red
                (255, 220, 0),    # Drums: Yellow
                (180, 0, 255)     # Other: Purple
            ]
            
            zone_size = total_leds // 4
            targets = []
            
            for led_idx in range(total_leds):
                zone_idx = min(led_idx // zone_size, 3)
                stem_name = zone_stems[zone_idx]
                stem_data = stems[stem_name]
                
                # Get zone color and brightness
                color = zone_colors[zone_idx]
                brightness = stem_data['brightness']
                
                # Onset flash boost
                if stem_data['onset']:
                    brightness = min(brightness * 1.3, 1.0)
                
                # Apply
                targets.append(scale(color, brightness))
            
            return targets, settings.brightness

"""

# Replace
new_lines = lines[:start] + [new_effect] + lines[end:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✓ Integrated AI stem separation into melody_smart")
print("  → Vocals: LEDs 0-16 (cyan)")
print("  → Bass: LEDs 17-33 (red)")
print("  → Drums: LEDs 34-50 (yellow)")
print("  → Other: LEDs 51-66 (purple)")
