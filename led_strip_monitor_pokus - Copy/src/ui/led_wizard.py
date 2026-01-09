from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QWidget,
                             QLabel, QSlider, QPushButton, QProgressBar, QMessageBox, QSpinBox, QComboBox, QCheckBox, QGroupBox)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QIcon

class LedWizardDialog(QDialog):
    """
    Interactive Wizard to determine LED strip geometry.
    User moves a slider to light up specific pixels on the physical strip.
    """
    # Signal to request lighting up a specific pixel (device_id, index, r, g, b)
    preview_pixel_request = pyqtSignal(str, int, int, int, int)
    
    def __init__(self, config, target_device_id: str, parent=None, override_monitor_index=-1, append_mode=False):
        super().__init__(parent)
        self.config = config
        self.target_device_id = target_device_id
        self.override_monitor_index = override_monitor_index
        self.append_mode = append_mode
        self.selected_sides = []

        # Look up device name for title
        dev_name = "Unknown Device"
        for d in config.global_settings.devices:
            if d.id == target_device_id:
                dev_name = d.name
                break
                
        self.setWindowTitle(f"AmbiLight - LED Setup: {dev_name}")
        self.setWindowIcon(QIcon("resources/icon_led_wizard.png"))
        self.setWindowFlags(Qt.WindowType.Window | Qt.WindowType.WindowCloseButtonHint)
        self.resize(600, 500)
        
        # Initial Definition of All Potential Steps
        self.all_side_steps = {
            "left": [
                {"id": "left_start", "side": "left", "type": "point", "text": "Left - Start", "desc": "Move the slider until the **GREEN LED** is at the **START** (Bottom) of the Left side."},
                {"id": "left_end",   "side": "left", "type": "point", "text": "Left - End", "desc": "Move the slider until the **GREEN LED** is at the **END** (Top) of the Left side."}
            ],
            "top": [
                {"id": "top_start", "side": "top", "type": "point", "text": "Top - Start", "desc": "Move the slider until the **GREEN LED** is at the **START** (Left) of the Top side."},
                {"id": "top_end",   "side": "top", "type": "point", "text": "Top - End", "desc": "Move the slider until the **GREEN LED** is at the **END** (Right) of the Top side."}
            ],
            "right": [
                {"id": "right_start", "side": "right", "type": "point", "text": "Right - Start", "desc": "Move the slider until the **GREEN LED** is at the **START** (Top) of the Right side."},
                {"id": "right_end",   "side": "right", "type": "point", "text": "Right - End", "desc": "Move the slider until the **GREEN LED** is at the **END** (Bottom) of the Right side."}
            ],
            "bottom": [
                {"id": "bottom_start", "side": "bottom", "type": "point", "text": "Bottom - Start", "desc": "Move the slider until the **GREEN LED** is at the **START** (Right) of the Bottom side."},
                {"id": "bottom_end",   "side": "bottom", "type": "point", "text": "Bottom - End", "desc": "Move the slider until the **GREEN LED** is at the **END** (Left) of the Bottom side."}
            ]
        }
        
        # Initialize Steps (Will be populated after Config Step)
        self.steps = [
            {"id": "intro", "type": "config", "text": "Device Configuration", "desc": "Select which sides this LED controller covers."}
        ]
        
        # State
        self.current_step = 0
        self.captured_indices = {} # "start", "tl", "tr", "br", "end"
        
        # UI
        wrapper = QVBoxLayout()
        self.setLayout(wrapper)
        
        # Help / Info Params
        info_layout = QHBoxLayout()
        if override_monitor_index >= 0:
            lbl_mon = QLabel(f"<b>Target Monitor:</b> Monitor {override_monitor_index}")
            lbl_mon.setStyleSheet("color: #4CAF50;")
            info_layout.addWidget(lbl_mon)
            
        if append_mode:
            lbl_app = QLabel("<b>Mode:</b> Append (Multi-Monitor Setup)")
            lbl_app.setStyleSheet("color: #2196F3;")
            info_layout.addWidget(lbl_app)
            lbl_hint = QLabel("(Existing segments preserved)")
            lbl_hint.setStyleSheet("color: #888; font-style: italic;")
            info_layout.addWidget(lbl_hint)
        
        info_layout.addStretch()
        wrapper.addLayout(info_layout)

        layout = QVBoxLayout()
        wrapper.addLayout(layout)
        
        # Header
        self.lbl_step = QLabel("Step 1/x")
        self.lbl_step.setStyleSheet("font-weight: bold; color: #888;")
        layout.addWidget(self.lbl_step)
        
        self.progress = QProgressBar()
        layout.addWidget(self.progress)
        
        # Main Content
        self.lbl_main = QLabel("Welcome")
        self.lbl_main.setStyleSheet("font-size: 18px; font-weight: bold; margin-top: 10px;")
        self.lbl_main.setWordWrap(True)
        layout.addWidget(self.lbl_main)
        
        self.lbl_desc = QLabel("Instructions...")
        self.lbl_desc.setWordWrap(True)
        self.lbl_desc.setStyleSheet("margin-bottom: 20px;")
        layout.addWidget(self.lbl_desc)
        
        # Reference Monitor Selection (Always visible in Config step, maybe moved?)
        self.cb_wiz_monitor = QComboBox()
        # Populated later
        
        # CONFIG WIDGETS (For Step 0)
        self.config_widget = QWidget()
        lay_conf = QVBoxLayout(self.config_widget)
        lay_conf.setContentsMargins(0,0,0,0)
        
        grp_sides = QGroupBox("Select Active Sides")
        lay_sides = QVBoxLayout()
        
        self.chk_left = QCheckBox("Left Side"); self.chk_left.setChecked(True)
        self.chk_top = QCheckBox("Top Side"); self.chk_top.setChecked(True)
        self.chk_right = QCheckBox("Right Side"); self.chk_right.setChecked(True)
        self.chk_bottom = QCheckBox("Bottom Side"); self.chk_bottom.setChecked(False) # Usually 3-sided default
        
        lay_sides.addWidget(self.chk_left)
        lay_sides.addWidget(self.chk_top)
        lay_sides.addWidget(self.chk_right)
        lay_sides.addWidget(self.chk_bottom)
        grp_sides.setLayout(lay_sides)
        lay_conf.addWidget(grp_sides)
        
        # Add Reference Monitor here for Config Step
        lay_conf.addWidget(QLabel("Reference Monitor:"))
        lay_conf.addWidget(self.cb_wiz_monitor)
        
        layout.addWidget(self.config_widget)
        
        # SLIDER WIDGETS (For Calibration Steps)
        self.slider_widget = QWidget()
        lay_slide = QVBoxLayout(self.slider_widget)
        lay_slide.setContentsMargins(0,0,0,0)
        
        self.slider = QSlider(Qt.Orientation.Horizontal)
        self.slider.setRange(0, 1024) 
        self.slider.valueChanged.connect(self._on_slider_change)
        lay_slide.addWidget(self.slider)
        
        h_tune = QHBoxLayout()
        btn_minus = QPushButton("-")
        btn_minus.setFixedWidth(40)
        btn_minus.clicked.connect(lambda: self.slider.setValue(self.slider.value() - 1))
        btn_plus = QPushButton("+")
        btn_plus.setFixedWidth(40)
        btn_plus.clicked.connect(lambda: self.slider.setValue(self.slider.value() + 1))
        h_tune.addStretch()
        h_tune.addWidget(btn_minus)
        h_tune.addWidget(btn_plus)
        h_tune.addStretch()
        lay_slide.addLayout(h_tune)
        
        self.lbl_val = QLabel("Pixel Index: 0")
        self.lbl_val.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay_slide.addWidget(self.lbl_val)
        
        layout.addWidget(self.slider_widget)
        
        # Controls
        btn_layout = QHBoxLayout()
        self.btn_next = QPushButton("Next >")
        self.btn_next.clicked.connect(self._on_next)
        self.btn_next.setStyleSheet("padding: 8px 20px; font-weight: bold;")
        
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_next)
        layout.addLayout(btn_layout)

        # Init MSS Monitors
        try:
            import mss
            with mss.mss() as sct:
                self.cb_wiz_monitor.clear()
                for i, m in enumerate(sct.monitors[1:], 1):
                    self.cb_wiz_monitor.addItem(f"Monitor {i} ({m['width']}x{m['height']}) @ {m['left']},{m['top']}", i-1)
                
                if self.override_monitor_index >= 0:
                     idx = self.cb_wiz_monitor.findData(self.override_monitor_index)
                     if idx >= 0: self.cb_wiz_monitor.setCurrentIndex(idx)
                     self.cb_wiz_monitor.setEnabled(False) # Locked
        except: pass

        self._update_ui_state()

    def _update_ui_state(self):
        if self.current_step >= len(self.steps): return # Should not happen
        
        step = self.steps[self.current_step]
        self.lbl_step.setText(f"Step {self.current_step + 1}/{len(self.steps)}")
        self.progress.setMaximum(len(self.steps))
        self.progress.setValue(self.current_step)
        self.lbl_main.setText(step["text"])
        self.lbl_desc.setText(step["desc"])
        
        # Visibility Logic
        if step["type"] == "config":
            self.config_widget.setVisible(True)
            self.slider_widget.setVisible(False)
            self.btn_next.setText("Start Calibration >")
        elif step["type"] == "end":
            self.config_widget.setVisible(False)
            self.slider_widget.setVisible(False)
            self.btn_next.setText("Finish & Save")
        else:
            self.config_widget.setVisible(False)
            self.slider_widget.setVisible(True)
            self.btn_next.setText("Next >")
            self.slider.setEnabled(True)

    def _on_slider_change(self, val):
        self.lbl_val.setText(f"Pixel Index: {val} (LED #{val+1})")
        # Send request to Light UP this pixel (Green)
        self.preview_pixel_request.emit(self.target_device_id, val, 0, 255, 0)

    def _on_next(self):
        step_data = self.steps[self.current_step]
        
        # 1. CONFIG STEP LOGIC
        if step_data["type"] == "config":
            self.selected_sides = []
            if self.chk_left.isChecked(): self.selected_sides.append("left")
            if self.chk_top.isChecked(): self.selected_sides.append("top")
            if self.chk_right.isChecked(): self.selected_sides.append("right")
            if self.chk_bottom.isChecked(): self.selected_sides.append("bottom")
            
            if not self.selected_sides:
                QMessageBox.warning(self, "Selection Required", "Please select at least one side.")
                return

            # Build Steps Dynamically
            new_steps = []
            new_steps.append(step_data) # Keep config as step 0? Or remove it? Let's keep it for "Back" support if implemented.
            
            # Add selected sides in order
            # Order: Left -> Top -> Right -> Bottom (Standard Clockwise)
            order = ["left", "top", "right", "bottom"]
            
            # But we must respect the physical wiring order assumed (Clockwise from Bottom Left usually?)
            # Or assume user wires them in the order selected? 
            # The current wizard assumes Left->Top->Right->Bottom.
            # If user selects only "Right", we ask "Right Start" and "Right End".
            
            for side in order:
                if side in self.selected_sides:
                    new_steps.extend(self.all_side_steps[side])
            
            new_steps.append({"id": "finish", "type": "end", "text": "Configuration Complete", "desc": "Setup finished.\nClick **Finish & Save**."})
            
            self.steps = new_steps
            # Advance
            self.current_step += 1
            self._update_ui_state()
            return

        # 2. CALIBRATION LOGIC
        if step_data["type"] == "point":
             val = self.slider.value()
             self.captured_indices[step_data["id"]] = val
             
             # Validation (Start <= End)
             if "_end" in step_data["id"]:
                 start_id = step_data["id"].replace("_end", "_start")
                 start_val = self.captured_indices.get(start_id, 0)
                 # Allow reverse wiring? Usually End > Start. 
                 # If reversed, length is abs(), but user needs guidance.
                 # Let's trust user visually. But warn if weird.
                 pass

        # Next
        if self.current_step < len(self.steps) - 1:
            self.current_step += 1
            self._update_ui_state()
        else:
            self._calculate_and_finish()

    def _calculate_and_finish(self):
        from app_config import LedSegment
        self.result_segments = []
        
        # Resolution
        try:
            import mss
            with mss.mss() as sct:
                wiz_mon_idx = self.cb_wiz_monitor.currentData()
                if wiz_mon_idx is None: wiz_mon_idx = 0
                mon_idx = wiz_mon_idx
                mss_idx = mon_idx + 1
                if mss_idx >= len(sct.monitors): mss_idx = 1
                monitor = sct.monitors[mss_idx]
                mon_w, mon_h = monitor['width'], monitor['height']
        except:
            mon_w, mon_h = 1920, 1080
        
        padding_pct = getattr(self.config.screen_mode, 'padding_percent', 0) / 100.0
        pad_left = int(mon_w * padding_pct)
        pad_right = int(mon_w * padding_pct)
        pad_top = int(mon_h * padding_pct)
        pad_bottom = int(mon_h * padding_pct)
        eff_w = mon_w - pad_left - pad_right
        eff_h = mon_h - pad_top - pad_bottom
        
        total_leds_max = 0
        
        # Iterate only selected sides
        for side in self.selected_sides:
            s_key = f"{side}_start"
            e_key = f"{side}_end"
            
            s = self.captured_indices.get(s_key, 0)
            e = self.captured_indices.get(e_key, 0)
            
            length = abs(e - s) + 1
            total_leds_max = max(total_leds_max, s, e)
            
            if side in ['top', 'bottom']:
                pixel_start = pad_left
                pixel_end = pad_left + eff_w
            else:
                pixel_start = pad_top
                pixel_end = pad_top + eff_h
            
            auto_reverse = (side == 'bottom' or side == 'left')
            
            seg = LedSegment(
                led_start=s,
                led_end=e,
                edge=side,
                depth=10,
                monitor_idx=mon_idx,
                pixel_start=pixel_start,
                pixel_end=pixel_end,
                reverse=auto_reverse,
                device_id=self.target_device_id,
                ref_width=mon_w,
                ref_height=mon_h
            )
            self.result_segments.append(seg)

        # Merge Logic
        if self.append_mode:
            current_segments = list(self.config.screen_mode.segments)
        else:
            current_segments = [s for s in self.config.screen_mode.segments if s.device_id != self.target_device_id]
        
        current_segments.extend(self.result_segments)
        self.config.screen_mode.segments = current_segments
        
        # Update device led count
        new_count = total_leds_max + 1
        for d in self.config.global_settings.devices:
            if d.id == self.target_device_id:
                if new_count > d.led_count: # Only increase? Or set exactly?
                    d.led_count = new_count # Set exactly based on max index seen
                break
                
        QMessageBox.information(self, "Setup Complete", 
            f"Created {len(self.result_segments)} segments.\n"
            f"Total LEDs used: {new_count}")
            
        self._cleanup_preview()
        self.accept()

    def closeEvent(self, event):
        self._cleanup_preview()
        super().closeEvent(event)

    def reject(self):
        self._cleanup_preview()
        super().reject()

    def _cleanup_preview(self):
        self.preview_pixel_request.emit(self.target_device_id, -1, 0, 0, 0)
