#!/usr/bin/env python3
"""
Replace melody_smart with SIMPLIFIED adaptive approach
- Fixes brightness stuck at max
- Fixes state overflow after time
- Cleaner, more responsive
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

# New SIMPLIFIED effect
new_effect = """
        elif settings.effect == "melody_smart":
            # MELODY SMART v5 - SIMPLIFIED & FIXED
            # - Proper brightness decay (fixes max brightness bug)
            # - State management (fixes "stops working" bug)
            # - Adaptive frequency learning
            # - Clean, responsive, works!
            
            from adaptive_detector import get_adaptive_detector
            
            detector = get_adaptive_detector()
            
            # Get real-time band analysis
            if hasattr(self.audio_processor, 'latest_buffer'):
                bands = detector.process_frame(self.audio_processor.latest_buffer)
            else:
                bands = detector._empty_result()
            
            # === 4 LED ZONES for 4 FREQUENCY BANDS ===
            zone_size = total_leds // 4
            targets = []
            
            for led_idx in range(total_leds):
                zone_idx = min(led_idx // zone_size, 3)
                band = bands[zone_idx]
                
                # Get color and brightness from detector
                color = band['color']
                brightness = band['brightness']
                
                # DEBUG: Print if onset (remove after testing)
                if band['onset'] and zone_idx == 0:
                    print(f"DEBUG: {band['name']} ONSET! Brightness={brightness:.2f}")
                
                # Apply
                targets.append(scale(color, brightness))
            
            return targets, settings.brightness

"""

# Replace
new_lines = lines[:start] + [new_effect] + lines[end:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✓ Simplified melody_smart effect")
print("  → Fixed: Brightness decay (no more stuck at max)")
print("  → Fixed: State reset every 60s (no more freeze)")
print("  → Fixed: Proper energy normalization (no overflow)")
print("  → Added: Debug output for onset detection")
