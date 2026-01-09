#!/usr/bin/env python3
"""Replace melody_smart effect with enhanced version"""

filepath = "src/app.py"

# Read file
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find melody_smart effect start and end
start_line = -1
end_line = -1

for i, line in enumerate(lines):
    if 'elif settings.effect == "melody_smart"' in line:
        start_line = i
    if start_line > 0 and end_line < 0:
        if 'elif settings.effect ==' in line and i > start_line:
            end_line = i
            break

if start_line < 0:
    print("✗ melody_smart effect not found!")
    exit(1)

print(f"Found melody_smart: lines {start_line+1} to {end_line+1}")

# New enhanced effect code
new_effect = """
        elif settings.effect == "melody_smart":
            # MELODY SMART v2 - Enhanced multi-pitch, note-class mapping, punchy
            if not self.audio_processor.melody_enabled:
                self.audio_processor.enable_melody_detection(True)
            
            melody = self.audio_processor.get_melody_analysis()
            analysis = self.audio_processor.get_analysis()
            
            # State init
            if not hasattr(self, 'melody_state'):
                self.melody_state = {
                    'flash': 0.0,
                    'note_colors': {},  # note_class -> hue
                    'led_zones': [0] * total_leds,  # Per-LED values
                    'bass_pulse': 0.0
                }
            
            state = self.melody_state
            
            # === NOTE CLASS COLORS (ignore octaves) ===
            # C=red, C#=orange, D=yellow, D#=lime, E=green, F=cyan, 
            # F#=sky, G=blue, G#=purple, A=magenta, A#=pink, B=rose
            NOTE_HUES = {
                'C': 0, 'C#': 30, 'D': 60, 'D#': 90, 'E': 120, 'F': 150,
                'F#': 180, 'G': 210, 'G#': 240, 'A': 270, 'A#': 300, 'B': 330
            }
            
            # === ONSET FLASH (very punchy) ===
            if melody.get('onset', False):
                state['flash'] = 1.0
                
                # Update colors for all active notes
                note_classes = melody.get('note_classes', [])
                if note_classes:
                    for note_class, strength in note_classes:
                        if note_class in NOTE_HUES:
                            state['note_colors'][note_class] = NOTE_HUES[note_class]
            
            # === BEAT PULSE on bass ===
            if melody.get('beat', False):
                state['bass_pulse'] = 1.0
            
            # === DECAY ===
            state['flash'] *= 0.65  # Fast flash decay (punchy!)
            state['bass_pulse'] *= 0.80  # Bass pulse decay
            
            # === BRIGHTNESS DYNAMICS ===
            dynamics = melody.get('dynamics', 0.3)  # 0-1 from detector
            base_bright = 0.15 + (dynamics * 0.5)  # Floor + dynamic
            flash_bright = state['flash'] * 0.7  # Flash component
            beat_boost = state['bass_pulse'] * 0.3  # Beat boost
            
            final_bright = min(base_bright + flash_bright + beat_boost, 1.0)
            final_bright = max(final_bright, 0.1)  # Never fully off
            
            # === COLOR SELECTION ===
            # Use primary note class, fall back to average
            primary_note = melody.get('note_class')
            if primary_note and primary_note in NOTE_HUES:
                primary_hue = NOTE_HUES[primary_note]
            else:
                # Fallback: average of active note colors
                if state['note_colors']:
                    primary_hue = sum(state['note_colors'].values()) / len(state['note_colors'])
                else:
                    primary_hue = 180  # Default cyan
            
            # === MULTI-PITCH: Split LED strip for chords ===
            pitches = melody.get('pitches', [])
            note_classes = melody.get('note_classes', [])
            
            import colorsys
            
            if len(note_classes) > 1 and len(note_classes) <= 3:
                # CHORD MODE: Split strip into zones
                zone_size = total_leds // len(note_classes)
                targets = []
                
                for idx in range(total_leds):
                    zone = min(idx // zone_size, len(note_classes) - 1)
                    note_class, strength = note_classes[zone]
                    
                    if note_class in NOTE_HUES:
                        hue = NOTE_HUES[note_class]
                        sat = 0.95
                    else:
                        hue = primary_hue
                        sat = 0.7
                    
                    # Zone brightness varies
                    zone_bright = final_bright * (0.7 + strength * 0.3)
                    
                    rgb = colorsys.hsv_to_rgb(hue / 360.0, sat, 1.0)
                    color = tuple(int(c * 255) for c in rgb)
                    targets.append(scale(color, zone_bright))
            
            else:
                # SINGLE NOTE: Whole strip same color
                sat = 0.98 if melody.get('has_melody', False) else 0.6
                rgb = colorsys.hsv_to_rgb(primary_hue / 360.0, sat, 1.0)
                color = tuple(int(c * 255) for c in rgb)
                
                targets = [scale(color, final_bright)] * total_leds
            
            return targets, settings.brightness

"""

# Replace old effect with new one
new_lines = lines[:start_line] + [new_effect] + lines[end_line:]

# Write back
with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✓ Replaced melody_smart with enhanced v2!")
print("Changes:")
print("  - Note class mapping (ignore octaves)")
print("  - Multi-pitch chord visualization")  
print("  - Punchy flash decay (0.65)")
print("  - Dynamic brightness from detector")
print("  - Bass pulse on beats")
print("  - Spatial LED zones for chords")
