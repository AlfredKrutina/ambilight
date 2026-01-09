"""
Color Calibration Wizard
User-friendly wizard to automatically calibrate LED colors to match monitor.
"""

from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QWidget, QColorDialog, QProgressBar, QMessageBox
)
from PyQt6.QtCore import Qt, pyqtSignal, QTimer
from PyQt6.QtGui import QColor, QPalette, QIcon
from typing import Tuple, List, Dict


class FullscreenColorOverlay(QWidget):
    """Fullscreen overlay showing solid color for calibration"""
    
    def __init__(self, parent=None):
        super().__init__(parent, Qt.WindowType.WindowStaysOnTopHint | Qt.WindowType.FramelessWindowHint)
        self.setWindowTitle("Color Calibration")
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, False)
        
    def show_color(self, rgb: Tuple[int, int, int]):
        """Show fullscreen solid color"""
        r, g, b = rgb
        palette = self.palette()
        palette.setColor(QPalette.ColorRole.Window, QColor(r, g, b))
        self.setPalette(palette)
        self.setAutoFillBackground(True)
        self.showFullScreen()
        
    def hide_overlay(self):
        self.hide()


class ColorCalibrationWizard(QDialog):
    """
    4-Step Wizard to calibrate LED colors to match monitor.
    Shows test colors (Red, Green, Blue, White), user picks perceived LED color.
    """
    
    # Signal to light all LEDs with specific color
    set_all_leds_signal = pyqtSignal(int, int, int)  # (r, g, b)
    
    def __init__(self, config, profile_name="Default", parent=None):
        super().__init__(parent)
        self.config = config
        self.setWindowTitle("AmbiLight - Color Calibration")
        self.setWindowIcon(QIcon("resources/icon_calibration.png"))
        self.setWindowFlags(Qt.WindowType.Window | Qt.WindowType.WindowCloseButtonHint)
        self.setModal(True)
        self.resize(500, 400)
        
        # Test colors (name, RGB tuple)
        self.test_colors = [
            ("Red", (255, 0, 0)),
            ("Green", (0, 255, 0)),
            ("Blue", (0, 0, 255)),
            ("Cyan", (0, 255, 255)),
            ("Magenta", (255, 0, 255)),
            ("Yellow", (255, 255, 0)),
            ("Orange", (255, 165, 0)),
            ("Purple", (128, 0, 128)),
            ("Lime Green", (50, 205, 50)),
            ("White", (255, 255, 255)),
            ("Gray", (128, 128, 128)),
            ("Black", (0, 0, 0))
        ]
        
        self.current_step = 0
        self.test_results = []
        self.profile_name = profile_name if profile_name else "Default"  # Ensure never None
        
        self._init_ui()
        
    def _init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(20)
        
        # Title
        self.lbl_title = QLabel("Color Calibration Wizard")
        self.lbl_title.setStyleSheet("font-size: 18px; font-weight: bold;")
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.lbl_title)
        
        # Instructions
        self.lbl_instructions = QLabel()
        self.lbl_instructions.setWordWrap(True)
        self.lbl_instructions.setStyleSheet("font-size: 12px; padding: 10px;")
        layout.addWidget(self.lbl_instructions)
        
        # Progress
        self.progress = QProgressBar()
        self.progress.setMaximum(len(self.test_colors))
        self.progress.setValue(0)
        layout.addWidget(self.progress)
        
        # Color display area
        self.color_display = QWidget()
        self.color_display.setMinimumHeight(100)
        self.color_display.setStyleSheet("border: 2px solid #555; border-radius: 8px;")
        layout.addWidget(self.color_display)
        
        # Color display label
        self.lbl_color_name = QLabel()
        self.lbl_color_name.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_color_name.setStyleSheet("font-size: 24px; font-weight: bold; padding: 20px;")
        
        color_layout = QVBoxLayout()
        color_layout.addWidget(self.lbl_color_name)
        self.color_display.setLayout(color_layout)
        
        # Picker label
        self.lbl_picker = QLabel("What color do you SEE on your LEDs?")
        self.lbl_picker.setStyleSheet("font-size: 14px; font-weight: bold;")
        layout.addWidget(self.lbl_picker)
        
        # Selected color preview
        self.lbl_selected = QLabel("No color selected")
        self.lbl_selected.setMinimumHeight(40)
        self.lbl_selected.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_selected.setStyleSheet("border: 1px solid #777; border-radius: 4px; background-color: #333;")
        layout.addWidget(self.lbl_selected)
        
        # Buttons
        btn_layout = QHBoxLayout()
        
        self.btn_pick = QPushButton("Pick LED Color")
        self.btn_pick.setMinimumHeight(40)
        self.btn_pick.clicked.connect(self._on_pick_color)
        btn_layout.addWidget(self.btn_pick)
        
        self.btn_next = QPushButton("Next Step →")
        self.btn_next.setMinimumHeight(40)
        self.btn_next.setEnabled(False)
        self.btn_next.clicked.connect(self._on_next_step)
        btn_layout.addWidget(self.btn_next)
        
        layout.addLayout(btn_layout)
        
        # Cancel button
        btn_cancel = QPushButton("Cancel Calibration")
        btn_cancel.clicked.connect(self._on_cancel)
        layout.addWidget(btn_cancel)
        
        layout.addStretch()
        
        self.setLayout(layout)
        
        # Show intro
        self._show_intro()
    
    def _show_intro(self):
        """Show intro screen"""
        self.lbl_title.setText("Color Calibration Wizard")
        self.lbl_instructions.setText(
            "This wizard will help calibrate your LED colors to accurately match your monitor.\\n\\n"
            "📋 Process:\\n"
            "1. We'll show 4 test colors on your screen AND light your LEDs\\n"
            "2. For each color, use the color picker to match what you SEE on your LEDs\\n"
            "3. The system will automatically calculate corrections\\n\\n"
            "⏱️ Takes about 1 minute"
        )
        
        self.lbl_color_name.setText("Ready to start?")
        self.color_display.setStyleSheet("border: 2px solid #555; border-radius: 8px; background-color: #1a1a1a;")
        
        self.btn_pick.setText("Start Calibration")
        self.btn_next.setEnabled(False)
        self.btn_pick.disconnect()
        self.btn_pick.clicked.connect(self._start_calibration)
    
    def _start_calibration(self):
        """Start first test"""
        self.current_step = 0
        self.test_results = []
        self._run_test_step()
    
    def _run_test_step(self):
        """Run current test step"""
        if self.current_step >= len(self.test_colors):
            self._finish_calibration()
            return
        
        name, rgb = self.test_colors[self.current_step]
        
        # Update UI
        self.lbl_title.setText(f"Step {self.current_step + 1}/{len(self.test_colors)}: {name}")
        self.lbl_instructions.setText(
            f"Test Color: PURE {name.upper()}\\n\\n"
            f"1. Look at the color box below\\n"
            f"2. Look at your LED strip (should light up {name.lower()})\\n"
            f"3. Pick the color you SEE on your LEDs using the button"
        )
        
        self.progress.setValue(self.current_step)
        
        # Show color on display (LARGE BOX - no fullscreen needed)
        self.lbl_color_name.setText(f"{name.upper()} Test Color")
        r, g, b = rgb
        self.color_display.setStyleSheet(
            f"border: 3px solid #555; border-radius: 8px; "
            f"background-color: rgb({r},{g},{b}); "
            f"min-height: 200px;"  # Make it larger for visibility
        )
        
        # Light all LEDs (no overlay blocking UI!)
        self.set_all_leds_signal.emit(r, g, b)
        
        # Reset picker
        self.lbl_selected.setText("No color selected - click button to pick")
        self.lbl_selected.setStyleSheet("border: 1px solid #777; border-radius: 4px; background-color: #333;")
        self.btn_next.setEnabled(False)
        
        # Reconnect pick button
        try:
            self.btn_pick.disconnect()
        except:
            pass
        self.btn_pick.setText("Pick LED Color")
        self.btn_pick.clicked.connect(self._on_pick_color)
    
    def _on_pick_color(self):
        """Show color picker"""
        name, sent_rgb = self.test_colors[self.current_step]
        
        # Create color dialog
        dialog = QColorDialog(self)
        dialog.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, False)
        dialog.setCurrentColor(QColor(*sent_rgb))
        
        if dialog.exec():
            picked = dialog.selectedColor()
            perceived_rgb = (picked.red(), picked.green(), picked.blue())
            
            # Store result
            self.current_result = {
                "sent": sent_rgb,
                "perceived": perceived_rgb
            }
            
            # Update UI
            r, g, b = perceived_rgb
            self.lbl_selected.setText(f"Selected: RGB({r}, {g}, {b})")
            self.lbl_selected.setStyleSheet(
                f"border: 1px solid #777; border-radius: 4px; background-color: rgb({r},{g},{b}); "
                f"color: {'black' if (r+g+b) > 384 else 'white'};"
            )
            
            self.btn_next.setEnabled(True)
    
    def _on_next_step(self):
        """Move to next step"""
        # Save current result
        if hasattr(self, 'current_result'):
            self.test_results.append(self.current_result)
        
        # Clear LEDs
        self.set_all_leds_signal.emit(0, 0, 0)
        
        # Next step
        self.current_step += 1
        
        if self.current_step < len(self.test_colors):
            # Small delay before next test
            QTimer.singleShot(500, self._run_test_step)
        else:
            self._finish_calibration()
    
    def _finish_calibration(self):
        """Calculate and apply calibration"""
        from color_correction import calculate_calibration, validate_calibration
        
        # Calculate corrections
        calibration = calculate_calibration(self.test_results)
        
        # Validate
        if not validate_calibration(calibration):
            QMessageBox.warning(self, "Calibration Error", 
                "Calibration failed validation. Please try again.")
            self.reject()
            return
        
        # Show results
        self._show_results(calibration)
    
    def _show_results(self, calibration: Dict):
        """Show calibration results"""
        self.calibration = calibration
        
        self.lbl_title.setText("Calibration Complete!")
        self.lbl_instructions.setText(
            "Calculated color corrections:\\n\\n"
            f"Red Channel:   Gain {calibration['gain'][0]:.2f}, Gamma {calibration['gamma'][0]:.2f}\\n"
            f"Green Channel: Gain {calibration['gain'][1]:.2f}, Gamma {calibration['gamma'][1]:.2f}\\n"
            f"Blue Channel:  Gain {calibration['gain'][2]:.2f}, Gamma {calibration['gamma'][2]:.2f}\\n\\n"
            "These corrections will be applied to all screen colors."
        )
        
        self.color_display.setStyleSheet("border: 2px solid #555; border-radius: 8px; background-color: #1a1a1a;")
        self.lbl_color_name.setText("✓ Success")
        
        self.progress.setValue(len(self.test_colors))
        
        # Change buttons
        self.btn_pick.setText("Apply & Save")
        try:
            self.btn_pick.disconnect()
        except:
            pass
        self.btn_pick.clicked.connect(self._apply_calibration)
        
        self.btn_next.setText("Discard")
        try:
            self.btn_next.disconnect()
        except:
            pass
        self.btn_next.setEnabled(True)
        self.btn_next.clicked.connect(self.reject)
    
    def _apply_calibration(self):
        """Save calibration to specific profile"""
        # Save to profiles dict
        self.config.screen_mode.calibration_profiles[self.profile_name] = self.calibration
        self.config.screen_mode.active_calibration_profile = self.profile_name
        
        # Also save to old field for backward compat
        self.config.screen_mode.color_calibration = self.calibration
        
        self.config.save("default.json")
        
        QMessageBox.information(self, "Calibration Saved", 
            f"Color calibration profile '{self.profile_name}' has been saved!\\n\\n"
            "Your LEDs should now match your monitor colors more accurately.")
        
        self.accept()
    
    def _on_cancel(self):
        """Cancel calibrationwizard"""
        # Clear LEDs
        self.set_all_leds_signal.emit(0, 0, 0)
        
        self.reject()
    
    def closeEvent(self, event):
        """Clean up on close"""
        self.set_all_leds_signal.emit(0, 0, 0)
        super().closeEvent(event)
