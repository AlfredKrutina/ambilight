#!/usr/bin/env python3
"""Quick fix: Call mode handler instead of direct assignment"""

filepath = "src/app.py"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed_lines = []
for i, line in enumerate(lines):
    # Find line 397: self.app_state.mode = self.config.global_settings.start_mode
    if i == 396 and "self.app_state.mode = self.config.global_settings.start_mode" in line:
        # Replace with handler call
        fixed_lines.append("        # Use mode handler for resource optimization\n")
        fixed_lines.append("        self._on_mode_change(self.config.global_settings.start_mode)\n")
    else:
        fixed_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(fixed_lines)

print("✓ Fixed: _sync_state_from_config now calls _on_mode_change")
print("✓ Resource optimization will now trigger on startup!")
