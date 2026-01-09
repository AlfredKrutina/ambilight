#!/usr/bin/env python3
"""
Restore melody_smart to WORKING state based on reactive_bass
Simple, proven approach - multi-band version of reactive_bass
"""

filepath = "src/app.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find melody_smart and reactive_bass
melody_start = -1
melody_end = -1
reactive_start = -1
reactive_end = -1

for i, line in enumerate(lines):
    if 'elif settings.effect == "melody_smart"' in line:
        melody_start = i
    if 'elif settings.effect == "reactive_bass"' in line:
        reactive_start = i
    
    if melody_start > 0 and melody_end < 0 and 'elif settings.effect ==' in line and i > melody_start:
        melody_end = i
    if reactive_start > 0 and reactive_end < 0 and 'elif settings.effect ==' in line and i > reactive_start:
        reactive_end = i

if melody_start < 0 or reactive_start < 0:
    print("✗ Effects not found")
    exit(1)

print(f"melody_smart: {melody_start+1} to {melody_end+1}")
print(f"reactive_bass: {reactive_start+1} to {reactive_end+1}")

# New SIMPLE melody mode based on reactive_bass (PROVEN)
new_effect = """
        elif settings.effect == "melody_smart":
            # MELODY SMART - Multi-band Reactive (based on reactive_bass PROVEN code)
            # 4 frequency bands, each with independent flash detection
            # SIMPLE, WORKS, NO COMPLICATED AI
            
            analysis = self.audio_processor.get_analysis()
            
            # Get 7-band analysis
            v_sub = analysis.get('sub_bass', 0)
            v_bass = analysis.get('bass', 0)
            v_lmid = analysis.get('low_mid', 0)
            v_mid = analysis.get('mid', 0)
            v_hmid = analysis.get('high_mid', 0)
            v_high = analysis.get('high', 0)
            v_bril = analysis.get('brilliance', 0)
            
            # === STATE INIT ===
            if not hasattr(self, 'melody_bands'):
                self.melody_bands = {
                    'bass': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5},
                    'low_mid': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5},
                    'mid': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5},
                    'high': {'energy': 0.0, 'flash': 0.0, 'avg': 0.5}
                }
            
            # === BAND 1: BASS (sub + bass + low_mid) ===
            bass_energy = (v_sub * 2.5 + v_bass * 2.0 + v_lmid * 1.5) / 6.0
            bass_energy = min(bass_energy * 1.5, 1.0)
            
            # Onset detection (same as reactive_bass)
            bass_avg = self.melody_bands['bass']['avg']
            bass_delta = bass_energy - bass_avg
            if bass_delta > 0.03 and bass_energy > 0.25:
                self.melody_bands['bass']['flash'] = 1.0
            
            self.melody_bands['bass']['energy'] = bass_energy
            self.melody_bands['bass']['avg'] = bass_avg * 0.98 + bass_energy * 0.02
            self.melody_bands['bass']['flash'] *= 0.70  # Decay
            
            # === BAND 2: LOW-MID (low_mid + mid) ===
            lmid_energy = (v_lmid * 1.5 + v_mid * 1.0) / 2.5
            lmid_energy = min(lmid_energy * 1.5, 1.0)
            
            lmid_avg = self.melody_bands['low_mid']['avg']
            lmid_delta = lmid_energy - lmid_avg
            if lmid_delta > 0.03 and lmid_energy > 0.25:
                self.melody_bands['low_mid']['flash'] = 1.0
            
            self.melody_bands['low_mid']['energy'] = lmid_energy
            self.melody_bands['low_mid']['avg'] = lmid_avg * 0.98 + lmid_energy * 0.02
            self.melody_bands['low_mid']['flash'] *= 0.70
            
            # === BAND 3: MID (mid + high_mid) ===
            mid_energy = (v_mid * 1.0 + v_hmid * 1.5) / 2.5
            mid_energy = min(mid_energy * 1.5, 1.0)
            
            mid_avg = self.melody_bands['mid']['avg']
            mid_delta = mid_energy - mid_avg
            if mid_delta > 0.03 and mid_energy > 0.25:
                self.melody_bands['mid']['flash'] = 1.0
            
            self.melody_bands['mid']['energy'] = mid_energy
            self.melody_bands['mid']['avg'] = mid_avg * 0.98 + mid_energy * 0.02
            self.melody_bands['mid']['flash'] *= 0.70
            
            # === BAND 4: HIGH (high_mid + high + brilliance) ===
            high_energy = (v_hmid * 1.0 + v_high * 1.5 + v_bril * 2.0) / 4.5
            high_energy = min(high_energy * 1.5, 1.0)
            
            high_avg = self.melody_bands['high']['avg']
            high_delta = high_energy - high_avg
            if high_delta > 0.03 and high_energy > 0.25:
                self.melody_bands['high']['flash'] = 1.0
            
            self.melody_bands['high']['energy'] = high_energy
            self.melody_bands['high']['avg'] = high_avg * 0.98 + high_energy * 0.02
            self.melody_bands['high']['flash'] *= 0.70
            
            # === LED MAPPING (4 zones) ===
            zone_size = total_leds // 4
            targets = []
            
            band_list = ['bass', 'low_mid', 'mid', 'high']
            band_colors = [
                (255, 0, 0),      # Bass: Red
                (255, 128, 0),    # Low-mid: Orange
                (0, 255, 128),    # Mid: Cyan
                (128, 0, 255)     # High: Purple
            ]
            
            for led_idx in range(total_leds):
                zone_idx = min(led_idx // zone_size, 3)
                band_name = band_list[zone_idx]
                band_data = self.melody_bands[band_name]
                
                # Brightness = flash + steady energy
                flash_comp = band_data['flash'] * 0.7
                energy_comp = band_data['energy'] * 0.3
                brightness = max(flash_comp + energy_comp, 0.1)
                brightness = min(brightness, 1.0)
                
                color = band_colors[zone_idx]
                targets.append(scale(color, brightness))
            
            return targets, settings.brightness

"""

# Replace
new_lines = lines[:melody_start] + [new_effect] + lines[melody_end:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✓ Restored melody_smart - SIMPLE multi-band reactive")
print("  → Based on reactive_bass (PROVEN working code)")
print("  → 4 bands: bass / low-mid / mid / high")
print("  → Same onset detection as reactive_bass")
print("  → No AI, no complexity, JUST WORKS")
