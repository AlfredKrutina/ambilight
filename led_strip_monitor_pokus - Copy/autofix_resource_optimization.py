#!/usr/bin/env python3
"""
Auto-fix script for resource optimization bugs
Fixes indentation and adds missing code
"""

def fix_audio_processor():
    """Fix audio_processor.py indentation"""
    filepath = "src/audio_processor.py"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find the problematic section (around line 129-143)
    fixed_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Find "while self.running:" in run() method
        if i >= 128 and "while self.running:" in line:
            # Add the line
            fixed_lines.append(line)
            i += 1
            
            # Skip old broken code until we find "target_device = None"
            # and insert correct code
            fixed_lines.append("            # MODE-AWARE: Only process audio in music mode\n")
            fixed_lines.append("            current_mode = getattr(self, 'current_mode', 'music')\n")
            fixed_lines.append("            if current_mode != \"music\":\n")
            fixed_lines.append("                # Not music mode - pause to save CPU\n")
            fixed_lines.append("                if self.stream:\n")
            fixed_lines.append("                    with self.lock:\n")
            fixed_lines.append("                        try:\n")
            fixed_lines.append("                            self.stream.close()\n")
            fixed_lines.append("                        except: pass\n")
            fixed_lines.append("                        self.stream = None\n")
            fixed_lines.append("                time.sleep(0.5)\n")
            fixed_lines.append("                continue\n")
            fixed_lines.append("            \n")
            fixed_lines.append("            if self.paused:\n")
            fixed_lines.append("                time.sleep(0.5)\n")
            fixed_lines.append("                continue\n")
            fixed_lines.append("\n")
            
            # Skip existing broken code
            while i < len(lines) and "target_device = None" not in lines[i]:
                i += 1
            
            continue
        
        fixed_lines.append(line)
        i += 1
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)
    
    print("✓ Fixed audio_processor.py")


def fix_app_mode_init():
    """Fix app.py mode initialization"""
    filepath = "src/app.py"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    fixed_lines = []
    for i, line in enumerate(lines):
        fixed_lines.append(line)
        
        # After "self.audio_processor.start()" add mode init
        if i >= 110 and "self.audio_processor.start()" in line:
            # Check if next lines don't already have mode init
            if i+2 < len(lines) and "current_mode" not in lines[i+1] and "current_mode" not in lines[i+2]:
                fixed_lines.append("        \n")
                fixed_lines.append("        # Initialize mode tracking for resource optimization\n")
                fixed_lines.append("        self.audio_processor.current_mode = self.config.global_settings.start_mode\n")
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)
    
    print("✓ Fixed app.py mode init")


def fix_app_mode_handler():
    """Add _on_mode_change method to app.py"""
    filepath = "src/app.py"
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Check if method already exists
    has_method = any("def _on_mode_change" in line for line in lines)
    if has_method:
        print("✓ _on_mode_change already exists in app.py")
        return
    
    fixed_lines = []
    for i, line in enumerate(lines):
        fixed_lines.append(line)
        
        # Find "def _sync_state_from_config(self):" and add method before it
        if "def _sync_state_from_config(self):" in line:
            # Insert method before
            method_code = """
    def _on_mode_change(self, new_mode: str):
        \"\"\"Handle mode changes and optimize resources\"\"\"
        old_mode = getattr(self.app_state, 'mode', 'screen')
        print(f"⟳ Mode Change: {old_mode} → {new_mode}")
        
        self.app_state.mode = new_mode
        
        # Resource optimization
        if new_mode == "screen":
            print("  → Screen: ENABLED | Audio: PAUSED")
            if hasattr(self, 'audio_processor'):
                self.audio_processor.current_mode = new_mode
            
        elif new_mode == "music":
            print("  → Screen: PERIODIC | Audio: ENABLED")
            if hasattr(self, 'audio_processor'):
                self.audio_processor.current_mode = new_mode
            
        elif new_mode in ["light", "pc_health"]:
            print("  → Screen: IDLE | Audio: PAUSED")
            if hasattr(self, 'audio_processor'):
                self.audio_processor.current_mode = new_mode
        
        # Update config
        self.config.global_settings.start_mode = new_mode
        self.config.save()
        
        print(f"✓ Mode: {new_mode}")

"""
            # Insert before current line
            fixed_lines.insert(-1, method_code)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)
    
    print("✓ Added _on_mode_change to app.py")


if __name__ == "__main__":
    print("🔧 Auto-fixing resource optimization bugs...")
    print()
    
    try:
        fix_audio_processor()
        fix_app_mode_init()
        fix_app_mode_handler()
        
        print()
        print("✅ All fixes applied successfully!")
        print()
        print("Next steps:")
        print("1. Restart the application")
        print("2. Test mode switching (screen, music, light)")
        print("3. Monitor CPU usage in each mode")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
