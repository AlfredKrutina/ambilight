import os
import shutil
import json
import logging
from dataclasses import asdict
from app_config import AppConfig

# Setup Logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("SettingsManager")

class SettingsManager:
    """
    Helper class for Robust Configuration Management.
    Handles:
    - Atomic Saving (write to temp -> rename)
    - Backups
    - Validation
    - Profile Presets
    """
    
    def __init__(self, config_dir: str = "config"):
        self.config_dir = config_dir
        if not os.path.exists(config_dir):
            os.makedirs(config_dir)
            
    def load_config(self, profile_name: str = "default") -> AppConfig:
        """Wrapper around AppConfig.load with additional validation logic"""
        cfg = AppConfig.load(profile_name)
        
        # Run Validation Hook
        warnings = self.validate_config(cfg)
        if warnings:
            for w in warnings:
                logger.warning(f"Config Validation: {w}")
                
        return cfg

    def save_config(self, config: AppConfig, profile_name: str = "default.json") -> bool:
        """Atomic Save with Backup"""
        if not profile_name.endswith(".json"):
            profile_name += ".json"
            
        final_path = os.path.join(self.config_dir, profile_name)
        temp_path = final_path + ".tmp"
        backup_path = final_path + ".bak"
        
        try:
            # 1. Create Backup if exists
            if os.path.exists(final_path):
                shutil.copy2(final_path, backup_path)
                
            # 2. Write to Temp
            with open(temp_path, 'w') as f:
                json.dump(asdict(config), f, indent=4)
                f.flush()
                os.fsync(f.fileno()) # Ensure write to disk
                
            # 3. Rename Temp to Final (Atomic on POSIX, usually safe on Windows)
            if os.path.exists(final_path):
                os.remove(final_path)
            os.rename(temp_path, final_path)
            
            logger.info("Settings saved successfully.")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save settings: {e}")
            if os.path.exists(temp_path):
                try: os.remove(temp_path)
                except: pass
            return False

    def validate_config(self, cfg: AppConfig) -> list:
        """Returns a list of warning strings if config has issues"""
        warnings = []
        
        # LED Count Sanity
        if cfg.global_settings.led_count <= 0:
            warnings.append("LED Count must be > 0. Resetting to 66.")
            cfg.global_settings.led_count = 66
            
        if cfg.global_settings.led_count > 400:
             warnings.append("LED count > 400 is high. Performance may degrade.")
             
        # Interval Sanity
        if cfg.auto_profile.detection_interval < 0.1:
            warnings.append("AutoProfile interval too low (<0.1s). Resetting to 2.0s.")
            cfg.auto_profile.detection_interval = 2.0
            
        # Screen Padding Sanity
        sm = cfg.screen_mode
        for field_name in ['padding_top', 'padding_bottom', 'padding_left', 'padding_right']:
            val = getattr(sm, field_name)
            if val < 0 or val > 100:
                warnings.append(f"{field_name} {val}% is invalid. Resetting to 0.")
                setattr(sm, field_name, 0)
                
        return warnings

    # --- PRESET MANAGEMENT ---
    
    def save_preset(self, config: AppConfig, start_name: str):
        """Saves current settings (Screen/Music/Light) as a new preset file"""
        # Logic to extract just the mode settings and save to specific preset file
        pass 
