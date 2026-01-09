"""
Profile management helper methods for SettingsDialog
Add these methods to settings_dialog.py class
"""

def _populate_calibration_profiles(self):
    """Populate calibration profile dropdown"""
    current = self.cb_calib_profile.currentText() if hasattr(self, 'cb_calib_profile') else ""
    
    self.cb_calib_profile.blockSignals(True)
    self.cb_calib_profile.clear()
    
    # Add Default if no profiles exist
    if not self.config.screen_mode.calibration_profiles:
        self.cb_calib_profile.addItem("Default")
    else:
        # Add all saved profiles
        for profile_name in self.config.screen_mode.calibration_profiles.keys():
            self.cb_calib_profile.addItem(profile_name)
    
    # Restore selection or select active profile
    if current and self.cb_calib_profile.findText(current) >= 0:
        self.cb_calib_profile.setCurrentText(current)
    elif self.config.screen_mode.active_calibration_profile:
        idx = self.cb_calib_profile.findText(self.config.screen_mode.active_calibration_profile)
        if idx >= 0:
            self.cb_calib_profile.setCurrentIndex(idx)
    
    self.cb_calib_profile.blockSignals(False)
    
    # Enable/disable delete button
    can_delete = len(self.config.screen_mode.calibration_profiles) > 0
    self.btn_del_profile.setEnabled(can_delete)

def _on_calibration_profile_changed(self, profile_name):
    """Switch active calibration profile"""
    if not profile_name:
        return
    
    # Set as active profile
    self.config.screen_mode.active_calibration_profile = profile_name
    
    # Apply immediately (save and emit)
    self.config.save("default.json")
    self.settings_changed.emit(self.config)
    
    print(f"DEBUG: Switched to calibration profile '{profile_name}'")

def _create_calibration_profile(self):
    """Create new calibration profile"""
    from PyQt6.QtWidgets import QInputDialog
    
    name, ok = QInputDialog.getText(self, "New Calibration Profile", 
        "Profile Name (e.g., 'Night Shift', 'Day', 'HDR'):")
    
    if ok and name:
        # Check if exists
        if name in self.config.screen_mode.calibration_profiles:
            QMessageBox.warning(self, "Profile Exists", 
                f"Profile '{name}' already exists. Please choose a different name.")
            return
        
        # Add empty profile (wizard will populate it)
        self.config.screen_mode.calibration_profiles[name] = {
            'gain': [1.0, 1.0, 1.0],
            'gamma': [1.0, 1.0, 1.0],
            'offset': [0, 0, 0],
            'enabled': True
        }
        
        # Refresh dropdown and select new profile
        self._populate_calibration_profiles()
        self.cb_calib_profile.setCurrentText(name)
        
        # Prompt to run wizard
        reply = QMessageBox.question(self, "Run Wizard?",
            f"Profile '{name}' created!\\n\\nWould you like to run the color calibration wizard now?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        
        if reply == QMessageBox.StandardButton.Yes:
            self._run_color_calibration()

def _delete_calibration_profile(self):
    """Delete current calibration profile"""
    profile_name = self.cb_calib_profile.currentText()
    
    if not profile_name or profile_name not in self.config.screen_mode.calibration_profiles:
        return
    
    reply = QMessageBox.question(self, "Delete Profile",
        f"Are you sure you want to delete profile '{profile_name}'?",
        QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
    
    if reply == QMessageBox.StandardButton.Yes:
        del self.config.screen_mode.calibration_profiles[profile_name]
        
        # If was active, switch to Default
        if self.config.screen_mode.active_calibration_profile == profile_name:
            self.config.screen_mode.active_calibration_profile = "Default"
        
        # Save and refresh
        self.config.save("default.json")
        self._populate_calibration_profiles()
        self.settings_changed.emit(self.config)
        
        QMessageBox.information(self, "Profile Deleted",
            f"Calibration profile '{profile_name}' has been deleted.")
