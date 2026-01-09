#!/usr/bin/env python3
"""
Auto-implement Melody Smart Mode
Adds melody detection to audio_processor.py, effect to app.py, UI dropdown
"""

def add_melody_to_audio_processor():
    """Add melody detection support to audio_processor.py"""
    filepath = "src/audio_processor.py"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Check if already added
    if any("self.melody_detector" in line for line in lines):
        print("✓ Melody detection already in audio_processor.py")
        return
    
    fixed_lines = []
    for i, line in enumerate(lines):
        fixed_lines.append(line)
        
        # After line with "self.paused = False" in __init__, add melody fields
        if "self.paused = False" in line and i < 50:
            fixed_lines.append("        \n")
            fixed_lines.append("        # Melody detection (lazy-init)\n")
            fixed_lines.append("        self.melody_detector = None\n")
            fixed_lines.append("        self.melody_enabled = False\n")
            fixed_lines.append("        self.latest_melody = {'onset': False, 'pitch': 0, 'beat': False, 'has_melody': False}\n")
        
        # After get_analysis() method, add new methods
        if "def get_analysis(self)" in line:
            # Will add methods after this method ends (find next empty line after return)
            pass
        
        # After return self.latest_analysis, add melody methods
        if i > 100 and "return self.latest_analysis" in line:
            found_next_def = False
            for j in range(i+1, min(i+10, len(lines))):
                if "def " in lines[j]:
                    found_next_def = True
                    break
            
            if not found_next_def:
                fixed_lines.append("\n")
                fixed_lines.append("    def enable_melody_detection(self, enabled: bool):\n")
                fixed_lines.append("        \"\"\"Enable/disable melody detection (resource optimization)\"\"\"\n")
                fixed_lines.append("        self.melody_enabled = enabled\n")
                fixed_lines.append("        \n")
                fixed_lines.append("        if enabled and self.melody_detector is None:\n")
                fixed_lines.append("            try:\n")
                fixed_lines.append("                from melody_detector import MelodyDetector\n")
                fixed_lines.append("                self.melody_detector = MelodyDetector(self.analyzer.sr)\n")
                fixed_lines.append("                print(\"✓ Melody detection enabled\")\n")
                fixed_lines.append("            except Exception as e:\n")
                fixed_lines.append("                print(f\"⚠ Melody detection unavailable: {e}\")\n")
                fixed_lines.append("                self.melody_enabled = False\n")
                fixed_lines.append("    \n")
                fixed_lines.append("    def get_melody_analysis(self) -> dict:\n")
                fixed_lines.append("        \"\"\"Get latest melody analysis\"\"\"\n")
                fixed_lines.append("        with self.lock:\n")
                fixed_lines.append("            return self.latest_melody\n")
        
        # In run() loop, after analyzer.process_audio_frame, add melody processing
        if "self.latest_analysis = analysis_result" in line and i > 180:
            fixed_lines.append("                        \n")
            fixed_lines.append("                        # Melody analysis (if enabled)\n")
            fixed_lines.append("                        if self.melody_enabled and self.melody_detector:\n")
            fixed_lines.append("                            melody_result = self.melody_detector.process_frame(audio_data)\n")
            fixed_lines.append("                            self.latest_melody = melody_result\n")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)
    
    print("✓ Added melody detection to audio_processor.py")


def add_melody_effect_to_app():
    """Add melody_smart effect to app.py"""
    filepath = "src/app.py"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if already added
    if "melody_smart" in content:
        print("✓ Melody Smart effect already in app.py")
        return
    
    lines = content.split('\n')
    fixed_lines = []
    
    for i, line in enumerate(lines):
        fixed_lines.append(line)
        
        # Find reactive_bass effect end, add melody_smart before spectrum_rotate
        if i > 1150 and '"reactive_bass"' in line and "elif settings.effect ==" in line:
            # Look ahead for end of reactive_bass block
            j = i + 1
            while j < len(lines) and "elif settings.effect ==" not in lines[j]:
                j += 1
            
            # Insert melody smart effect before next elif
            if j < len(lines):
                # Will insert at j (before next elif)
                pass
        
        # Better approach: insert before "spectrum_rotate"
        if i > 1190 and "elif settings.effect == \"spectrum_rotate\"" in line:
            # Insert before this line
            fixed_lines.insert(-1, "")
            fixed_lines.insert(-1, "        elif settings.effect == \"melody_smart\":")
            fixed_lines.insert(-1, "            # MELODY SMART - Intelligent melody recognition")
            fixed_lines.insert(-1, "            if not self.audio_processor.melody_enabled:")
            fixed_lines.insert(-1, "                self.audio_processor.enable_melody_detection(True)")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            melody = self.audio_processor.get_melody_analysis()")
            fixed_lines.insert(-1, "            analysis = self.audio_processor.get_analysis()")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            if not hasattr(self, 'melody_flash'):")
            fixed_lines.insert(-1, "                self.melody_flash = 0.0")
            fixed_lines.insert(-1, "                self.melody_color_hue = 180.0")
            fixed_lines.insert(-1, "                self.melody_brightness = 0.3")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            if melody.get('onset', False):")
            fixed_lines.insert(-1, "                self.melody_flash = 1.0")
            fixed_lines.insert(-1, "                pitch = melody.get('pitch', 0)")
            fixed_lines.insert(-1, "                if pitch > 80:")
            fixed_lines.insert(-1, "                    hue_normalized = min((pitch - 80) / (1000 - 80), 1.0)")
            fixed_lines.insert(-1, "                    self.melody_color hue = hue_normalized * 270")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            if melody.get('beat', False):")
            fixed_lines.insert(-1, "                self.melody_brightness = min(self.melody_brightness * 1.5, 1.0)")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            self.melody_flash *= 0.75")
            fixed_lines.insert(-1, "            self.melody_brightness *= 0.92")
            fixed_lines.insert(-1, "            self.melody_brightness = max(self.melody_brightness, 0.2)")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            melody_strength = melody.get('pitch_confidence', 0) * analysis.get('overall_loudness', 0.3)")
            fixed_lines.insert(-1, "            flash_component = self.melody_flash * 0.6")
            fixed_lines.insert(-1, "            steady_component = melody_strength * 0.4")
            fixed_lines.insert(-1, "            final_bright = max(flash_component + steady_component, 0.15) * self.melody_brightness")
            fixed_lines.insert(-1, "            final_bright = min(final_bright, 1.0)")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            import colorsys")
            fixed_lines.insert(-1, "            sat = 0.95 if melody.get('has_melody', False) else 0.6")
            fixed_lines.insert(-1, "            rgb_norm = colorsys.hsv_to_rgb(self.melody_color_hue / 360.0, sat, 1.0)")
            fixed_lines.insert(-1, "            color = tuple(int(c * 255) for c in rgb_norm)")
            fixed_lines.insert(-1, "            ")
            fixed_lines.insert(-1, "            targets = [scale(color, final_bright)] * total_leds")
            fixed_lines.insert(-1, "            return targets, settings.brightness")
            fixed_lines.insert(-1, "")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_lines))
    
    print("✓ Added Melody Smart effect to app.py")


if __name__ == "__main__":
    print("🎵 Auto-implementing Melody Smart Mode...")
    print()
    
    try:
        add_melody_to_audio_processor()
        add_melody_effect_to_app()
        
        print()
        print("✅ Melody Smart Mode implemented!")
        print()
        print("Manual step needed:")
        print("1. Open src/ui/settings_dialog.py")
        print("2. Find music effect dropdown (around line 900-920)")
        print("3. Add: self.cb_effect.addItem(\"Melody Smart 🎵\", \"melody_smart\")")
        print()
        print("Then restart app and select 'Melody Smart' effect!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
