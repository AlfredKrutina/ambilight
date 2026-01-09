#!/usr/bin/env python3
"""
Update melody_smart to use hybrid approach:
- AI stems for routing (which instruments where)
- FFT for immediate onset/brightness response
"""

filepath = "src/app.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find melody_smart
start = -1
end = -1

for i, line in enumerate(lines):
    if 'elif settings.effect == "melody_smart"' in line:
        start = i
    if start > 0 and end < 0 and 'elif settings.effect ==' in line and i > start:
        end = i
        break

if start < 0:
    print("✗ Not found")
    exit(1)

print(f"Found: {start+1} to {end+1}")

# New hybrid effect
new_effect = """
        elif settings.effect == "melody_smart":
            # MELODY SMART v4 - HYBRID (AI routing + FFT response)
            # AI stems determine WHICH instruments
            # FFT determines WHEN they flash (immediate!)
            
            from stem_separator import get_stem_separator
            from hybrid_detector import get_hybrid_detector
            
            separator = get_stem_separator()
            hybrid = get_hybrid_detector()
            
            # Enable AI (lazy-load)
            if not separator.enabled:
                separator.enable()
            
            # Send audio to AI processor (background, slow)
            if hasattr(self.audio_processor, 'latest_buffer'):
                separator.process_audio_chunk(self.audio_processor.latest_buffer, 48000)
            
            # Get AI routing hints (updates ~every 300ms)
            ai_stems = separator.get_latest_stems()
            hybrid.update_ai_routing(ai_stems)
            
            # Get REAL-TIME analysis (instant onset detection!)
            if hasattr(self.audio_processor, 'latest_buffer'):
                zones = hybrid.process_frame_realtime(self.audio_processor.latest_buffer)
            else:
                zones = hybrid._empty_zones()
            
            # === LED MAPPING ===
            # Map zones to LED segments based on stem type
            stem_colors = {
                'vocals': (0, 255, 255),    # Cyan
                'bass': (255, 50, 0),       # Red
                'drums': (255, 220, 0),     # Yellow
                'other': (180, 0, 255)      # Purple
            }
            
            zone_size = total_leds // 4
            targets = []
            
            for led_idx in range(total_leds):
                zone_idx = led_idx // zone_size
                zone_data = zones[zone_idx]
                
                # Get color from stem type (AI-determined)
                stem_type = zone_data['stem_type']
                color = stem_colors.get(stem_type, (128, 128, 128))
                
                # Get brightness from FFT (instant!)
                brightness = zone_data['brightness']
                
                # Onset boost (immediate flash!)
                if zone_data['onset']:
                    brightness = min(brightness * 1.5, 1.0)
                
                targets.append(scale(color, brightness))
            
            return targets, settings.brightness

"""

# Replace
new_lines = lines[:start] + [new_effect] + lines[end:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✓ Updated to HYBRID mode")
print("  → AI: Determines instrument zones (slow, accurate)")
print("  → FFT: Immediate onset/brightness (fast, responsive)")
print("  → Result: Best of both worlds!")
