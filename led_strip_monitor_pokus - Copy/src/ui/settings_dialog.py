from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, 
    QComboBox, QSpinBox, QCheckBox, QGroupBox, 
    QPushButton, QSlider, QWidget, QTabWidget, QColorDialog,
    QApplication, QFormLayout, QInputDialog, QMessageBox,
    QScrollArea, QFrame, QTableWidget, QHeaderView, QTableWidgetItem, QListWidget
)
from PyQt6.QtCore import Qt, pyqtSignal, QTimer
from PyQt6.QtGui import QColor, QIcon
import serial.tools.list_ports
import copy

from app_config import AppConfig, GlobalSettings, LightModeSettings, ScreenModeSettings, MusicModeSettings, DeviceSettings
from startup import enable_autostart, disable_autostart
from ui.themes import get_theme
from ui.calibration import CalibrationOverlay
from ui.custom_widgets import ColorPickerButton, CollapsibleBox, DraggableList, NoScrollFilter
from ui.led_wizard import LedWizardDialog
from ui.zone_editor import ZoneEditorWidget
from ui.scan_overlay import ScanningAreaOverlay
from ui.discovery_dialog import DiscoveryDialog
from modules.discovery import DiscoveryService
from ui.metric_editor import MetricEditorWidget
from ui.metric_editor import MetricEditorWidget
from PyQt6.QtWidgets import QScrollArea, QFrame, QLineEdit, QProgressBar
from modules.discovery import DiscoveryService

class SettingsDialog(QDialog):
    settings_changed = pyqtSignal(object) # Emits AppConfig
    preview_color_signal = pyqtSignal(int, int, int, int) # R, G, B, DurationTicks
    preview_pixel_signal = pyqtSignal(str, int, int, int, int) # device_id, index, r, g, b
    calibration_led_signal = pyqtSignal(str) # Request App to light up specific LED
    identify_requested = pyqtSignal(object) # Request App to identify device (Universal)
    settings_preview = pyqtSignal(object) # Live Preview (AppConfig)

    def create_help_label(self, tooltip: str) -> QLabel:
        lbl = QLabel("ⓘ")
        lbl.setToolTip(tooltip)
        lbl.setStyleSheet("color: #0A84FF; font-weight: bold; font-size: 16px;")
        lbl.setCursor(Qt.CursorShape.PointingHandCursor)
        return lbl

    def __init__(self, config: AppConfig, audio_devices: list, monitors: list, main_window_ref=None, parent=None):
        super().__init__(parent)
        self.applying_preset = False # Initialize flag early
        # FORCE RELOAD FROM DISK to ensure fresh state
        try:
            config = AppConfig.load("default.json")
            print("DEBUG: Force-reloaded config from disk")
        except Exception as e:
            print(f"DEBUG: Failed to reload config: {e}")
            
        self.setWindowTitle("AmbiLight - Settings")
        self.setWindowIcon(QIcon("resources/icon_settings.png"))
        
        # Enable taskbar icon and maximize button
        self.setWindowFlags(
            Qt.WindowType.Window |  # Show as independent window
            Qt.WindowType.WindowMaximizeButtonHint |  # Enable maximize
            Qt.WindowType.WindowMinimizeButtonHint |  # Enable minimize
            Qt.WindowType.WindowCloseButtonHint  # Enable close
        )
        
        self.resize(900, 700)
        self.setMinimumSize(900, 600)
        self.monitors = monitors
        self.main_window_ref = main_window_ref
        
        # Scan Overlay for Screen tab - MULTI-MONITOR SUPPORT
        self.scan_overlays = []
        # Initialize temp_calibration_points EARLY to avoid Preview Error during UI init
        self.temp_calibration_points = getattr(config.screen_mode, 'calibration_points', [])
        
        screens = QApplication.screens()
        for i, screen in enumerate(screens):
            overlay = ScanningAreaOverlay()
            overlay.monitor_idx = i # Set index
            self.scan_overlays.append(overlay)
            
        # Overlay for Scanning Visualization (CalibrationOverlay) - Kept single as it moves? 
        # Actually CalibrationOverlay might need similar treatment, but focusing on Scan Area first.
        self.scan_overlay = CalibrationOverlay(monitor_idx=0)
        self.scan_overlay_timer = QTimer()
        self.scan_overlay_timer.setSingleShot(True)
        self.scan_overlay_timer.setInterval(1500) # 1.5s auto-hide
        self.scan_overlay_timer.timeout.connect(self.scan_overlay.hide_regions)
        
        # Clone config to avoid modifying original until Save
        # Minimal deep copy via dataclasses
        self.original_config = config
        self.config = config # Current working copy
        self.audio_devices = audio_devices

        # Initialize temp colors EARLY to avoid Preview Error during UI init
        # (Map to 7-band structure)
        self.temp_bass_color = self.config.music_mode.bass_color
        self.temp_mid_color = self.config.music_mode.mid_color
        self.temp_high_color = self.config.music_mode.presence_color
        
        # Use Apple-like styling
        self.setStyleSheet(get_theme(config.global_settings.theme))

        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        
        # --- TABS ---
        self.tabs = QTabWidget()
        self.tabs.setDocumentMode(True) # Cleaner look on Mac/Win10
        
        self.tab_devices = QWidget()
        self.tab_global = QWidget()
        self.tab_light = QWidget()
        self.tab_screen = QWidget()
        self.tab_music = QWidget()
        
        # New Tabs
        self.tab_pchealth = QWidget()
        
        self._init_tab_devices()
        self._init_tab_global()
        self._init_tab_light()
        self._init_tab_screen()
        self._init_tab_music()
        self._init_tab_pchealth()
        
        layout.addWidget(self.tabs)
        
        # Add Tabs (Devices first for setup)
        self.tabs.addTab(self.tab_devices, "Devices")
        self.tabs.addTab(self.tab_global, "Global")
        self.tabs.addTab(self.tab_light, "Light")
        self.tabs.addTab(self.tab_screen, "Screen")
        self.tabs.addTab(self.tab_music, "Music")
        self.tabs.addTab(self.tab_pchealth, "PC Health")
        
        # Connect listeners for "Custom" preset logic
        for sl in [self.sl_gamma, self.sl_sat, self.sl_black, self.sl_interp]:
            sl.valueChanged.connect(self._on_screen_val_change)
        for sl in [self.sl_bass, self.sl_mid, self.sl_high]:
            sl.valueChanged.connect(self._on_music_val_change)
        
        # --- BUTTONS ---
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(20, 10, 20, 20)
        
        self.btn_cancel = QPushButton("Cancel")
        self.btn_cancel.clicked.connect(self.reject)
        
        self.btn_save = QPushButton("Save & Apply")
        self.btn_save.setObjectName("primaryButton") # Highlighted
        self.btn_save.clicked.connect(self._on_save)
        
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_cancel)
        btn_layout.addWidget(self.btn_save)
        
        layout.addLayout(btn_layout)
        self.setLayout(layout)
        
        # Initial Population
        self.loading_config = True
        self.config = config
        self._load_from_config(self.config)
        self.loading_config = False

        # Initialize temp colors for music mode (Map to 7-band structure)
        # MOVED to top of __init__ to fix AttributeError
        # self.temp_bass_color = self.config.music_mode.bass_color
        # self.temp_mid_color = self.config.music_mode.mid_color
        # self.temp_high_color = self.config.music_mode.presence_color  # Map High -> Presence

        # Apply Scroll Safety
        self._apply_scroll_safety()

    def closeEvent(self, event):
        """Hide scanning overlay when dialog closes"""
        if hasattr(self, 'scan_overlays'):
            for overlay in self.scan_overlays:
                overlay.hide()
        super().closeEvent(event)


    def _update_color_btn(self, btn, color):
        if not color: return
        r, g, b = color
        style = f"background-color: rgb({r},{g},{b}); border: 1px solid #777; border-radius: 4px;"
        btn.setStyleSheet(style)

    def _pick_color_bass(self):
        d = QColorDialog(self)
        d.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, False)
        d.setWindowTitle("Bass Color - Realtime Preview")
        c_curr = self.temp_bass_color
        d.setCurrentColor(QColor(c_curr[0], c_curr[1], c_curr[2]))
        
        d.currentColorChanged.connect(self._on_live_color_change)
        
        if d.exec():
            c = d.selectedColor()
            self.temp_bass_color = (c.red(), c.green(), c.blue())
            self._update_color_btn(self.btn_bass_color, self.temp_bass_color)
            
        if d.exec():
            c = d.selectedColor()
            self.temp_bass_color = (c.red(), c.green(), c.blue())
            self._update_color_btn(self.btn_bass_color, self.temp_bass_color)
            
        self.preview_color_signal.emit(0, 0, 0, 0)

    # --- CALIBRATION WIZARD ---
    def _start_calibration(self):
        """Start the interactive screen mapping"""
        # Connect finished signal if not already connected?
        # Better to do it in __init__, but here is safe too if unique
        try:
            self.scan_overlay.finished.disconnect()
        except:
            pass
        self.scan_overlay.finished.connect(self._on_calibration_finished)
        self.scan_overlay.light_led_request.connect(self.calibration_led_signal.emit)
        
        self.scan_overlay.start()

    def _on_calibration_finished(self, points):
        """Handle calibration results"""
        print(f"Calibration Finished: {points}")
        # Save points to config
        # Assuming we store them in screen_mode.calibration_points (list of tuples)
        # However, AppConfig structure might need verification.
        # If attribute doesn't verify, we'll store it in extra or custom
        # For now, assumes dynamic attribute adding is okay or it exists.
        
        # We need to normalize points? No, CalibrationOverlay returns global coords.
        # But we need them relative to the monitor usually? 
        # Actually overlay handles geometry logic.
        
        # Let's save to config.screen_mode.calibration_points if it exists
        if not hasattr(self.config.screen_mode, 'calibration_points'):
             # Create it? Dataclass won't like that unless we use dynamic
             # But wait, original code must have saved it somewhere.
             pass 
        
        # Re-using led_count fields as generic storage? No.
        # Let's simple check if we can setattr
        try:
            # We treat it as a list of lists/tuples
            setattr(self.config.screen_mode, 'calibration_points', points)
            self.config.save("default.json")
            QMessageBox.information(self, "Success", "Screen mapping saved.")
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Could not save calibration: {e}")

    def _reset_calibration(self):
        self.config.screen_mode.calibration_points = []
        self.config.save("default.json")
        QMessageBox.information(self, "Reset", "Mapping reset to full screen.")

    def _pick_color_mid(self):
        d = QColorDialog(self)
        d.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, False)
        d.setWindowTitle("Mid Color - Realtime Preview")
        c_curr = self.temp_mid_color
        d.setCurrentColor(QColor(c_curr[0], c_curr[1], c_curr[2]))
        
        d.currentColorChanged.connect(self._on_live_color_change)
        
        if d.exec():
            c = d.selectedColor()
            self.temp_mid_color = (c.red(), c.green(), c.blue())
            self._update_color_btn(self.btn_mid_color, self.temp_mid_color)
            
        self.preview_color_signal.emit(0, 0, 0, 0)

    def _pick_color_high(self):
        d = QColorDialog(self)
        d.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, False)
        d.setWindowTitle("High Color - Realtime Preview")
        c_curr = self.temp_high_color
        d.setCurrentColor(QColor(c_curr[0], c_curr[1], c_curr[2]))
        
        d.currentColorChanged.connect(self._on_live_color_change)
        
        if d.exec():
            c = d.selectedColor()
            self.temp_high_color = (c.red(), c.green(), c.blue())
            self._update_color_btn(self.btn_high_color, self.temp_high_color)
            
        self.preview_color_signal.emit(0, 0, 0, 0)

    def _init_tab_devices(self):
        """Device Manager Tab"""
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Info Header
        lbl_info = QLabel("Configure connected LED controllers (ESP32). Supports Serial (USB) and Wi-Fi (UDP).")
        lbl_info.setWordWrap(True)
        lbl_info.setStyleSheet("color: #888; margin-bottom: 10px;")
        layout.addWidget(lbl_info)
        
        # ACTION BAR
        h_actions = QHBoxLayout()
        
        btn_add = QPushButton("➕ Add Device")
        btn_add.clicked.connect(self._add_new_device)
        h_actions.addWidget(btn_add)
        
        self.btn_scan = QPushButton("🔍 Scan Network")
        self.btn_scan.clicked.connect(self._start_discovery)
        h_actions.addWidget(self.btn_scan)
        
        h_actions.addStretch()
        layout.addLayout(h_actions)
        
        # PROGRESS BAR (Hidden)
        self.progress_scan = QProgressBar()
        self.progress_scan.setRange(0, 0) # Indeterminate
        self.progress_scan.setVisible(False)
        self.progress_scan.setStyleSheet("QProgressBar { height: 4px; }")
        layout.addWidget(self.progress_scan)

        # TABLE (List of Devices)
        self.tbl_devices = QTableWidget()
        self.tbl_devices.setColumnCount(7) # Name, Type, Connection, LEDs, Identify, Setup, Del
        self.tbl_devices.setHorizontalHeaderLabels(["Name", "Type", "Connection (Port/IP)", "LED Count", "ID", "Setup", "Del"])
        
        # Improved Layout
        header = self.tbl_devices.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch) # Name
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed) # Type
        header.resizeSection(1, 80)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch) # Connection
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents) # LEDs
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed) # Identify
        header.setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed) # Setup
        header.setSectionResizeMode(6, QHeaderView.ResizeMode.Fixed) # Del
        
        header.resizeSection(4, 40)
        header.resizeSection(5, 80)
        header.resizeSection(6, 50)  
        
        self.tbl_devices.verticalHeader().setVisible(False)
        self.tbl_devices.setAlternatingRowColors(True)
        self.tbl_devices.setStyleSheet("QTableWidget { background-color: #1e1e1e; border: 1px solid #333; } QHeaderView::section { background-color: #2d2d2d; padding: 4px; border: 1px solid #333; }")
        
        layout.addWidget(self.tbl_devices)
        
        # Populate
        self._refresh_device_table()
        
        main_layout = QVBoxLayout(self.tab_devices)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addLayout(layout)

    def _start_discovery(self):
        """Open Discovery Dialog"""
        # Stop any existing (legacy)
        if hasattr(self, 'discovery') and self.discovery:
            self.discovery.stop()
            
        dlg = DiscoveryDialog(self)
        dlg.device_selected.connect(self._on_device_found)
        dlg.exec()

    # Legacy _stop_discovery removed as dialog handles it independently
            
    def _on_device_found(self, info):
        """Callback from Discovery Service"""
        print(f"UI found device: {info}")
        # Check if already exists by ID
        existing = next((d for d in self.config.global_settings.devices if d.id == info['id']), None)
        
        if existing:
            # Update IP if changed
            if existing.ip_address != info['ip']:
                existing.ip_address = info['ip']
                # existing.type = "wifi" # Should we force type? Maybe user wants manual control.
                print(f"Updated IP for {existing.name}")
        else:
            # Suggest Adding?
            # For now, let's just create it directly because "Scan" implies intent to add.
            new_dev = DeviceSettings(
                id=info['id'],
                name=info['name'],
                type="wifi",
                ip_address=info['ip'],
                led_count=info['led_count']
            )
            self.config.global_settings.devices.append(new_dev)
            
        # Refresh UI (Need to signal main thread? Qt signals are thread safe if emitted correctly, 
        # but this callback runs in Discovery Thread. We should use QTimer.singleShot for safety)
        # However, to keep it simple without creating custom signals for now:
        QTimer.singleShot(0, self._refresh_device_table)

    def _run_device_led_wizard(self, device: DeviceSettings):
        """Launch wizard for specific device"""
        # Ensure we have monitor info
        if not self.monitors and not self.cb_monitor.count():
             QMessageBox.warning(self, "Error", "No monitors detected. Cannot run wizard.")
             return
        
        # UX: Ask user for intent
        msg = QMessageBox(self)
        msg.setWindowTitle("Device Configuration")
        msg.setText(f"How do you want to configure <b>{device.name}</b>?")
        msg.setInformativeText("You can set up a single monitor or add multiple monitors to one LED strip.")
        
        btn_fresh = msg.addButton("Start Fresh (Single Monitor)", QMessageBox.ButtonRole.ActionRole)
        btn_append = msg.addButton("Add Another Monitor (Multi-Monitor)", QMessageBox.ButtonRole.ActionRole)
        
        # New Reset Wifi Option
        btn_reset_wifi = None
        if device.type == "wifi" and device.ip_address:
             btn_reset_wifi = msg.addButton("Forget Wi-Fi (Reset Device)", QMessageBox.ButtonRole.DestructiveRole)
        
        msg.addButton(QMessageBox.StandardButton.Cancel)
        
        msg.exec()
        
        if btn_reset_wifi and msg.clickedButton() == btn_reset_wifi:
            confirm = QMessageBox.warning(self, "Confirm Reset", 
                                          f"Are you sure you want to force '{device.name}' to forget its Wi-Fi credentials?\n\nThe device will reboot into AP Mode (Ambilight_Setup).",
                                          QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
            if confirm == QMessageBox.StandardButton.Yes:
                self._reset_device_wifi(device)
            return

        if msg.clickedButton() == btn_fresh:
            append_mode = False
            # interactive monitor select in wizard
            override_mon = -1 
        elif msg.clickedButton() == btn_append:
            append_mode = True
            override_mon = -1 # Let user pick which NEW monitor to add
        else:
            return

        # Create Wizard
        wiz = LedWizardDialog(self.config, target_device_id=device.id, parent=self,
                              override_monitor_index=override_mon,
                              append_mode=append_mode)
        
        # Connect Signals for Real-Time Preview
        # wiz emits (device_id, idx, r, g, b) -> Settings emits same -> App handles
        wiz.preview_pixel_request.connect(self.preview_pixel_signal.emit)
        
        # Run
        result = wiz.exec()
        
        if result == QDialog.DialogCode.Accepted:
            # Wizard ALREADY updated config.screen_mode.segments and device.led_count
            # We just need to refresh UI
            
            # Recalculate total global count (sum of all devices)
            # Actually global_settings.led_count is legacy single-strip.
            # But let's keep it updated as max(segments) or sum? 
            # AppConfig logic usually relies on segments list now.
            
            # Refresh our tables
            self._refresh_device_table() # LED count might have changed
            self._populate_segment_table()
            
            # Notify user
            QMessageBox.information(self, "Device Updated", 
                f"Configuration for '{device.name}' updated.\nNew LED Count: {device.led_count}")
            
            self.settings_changed.emit(self.config)

    def _refresh_device_table(self):
        """Re-draw device table from config"""
        self.tbl_devices.setRowCount(0)
        devices = self.config.global_settings.devices
        
        # Cache available ports
        available_ports = [p.device for p in serial.tools.list_ports.comports()]
        
        for idx, dev in enumerate(devices):
            self.tbl_devices.insertRow(idx)
            
            # 1. NAME (Editable)
            item_name = QTableWidgetItem(dev.name)
            self.tbl_devices.setItem(idx, 0, item_name)
            
            # 2. TYPE (Combobox)
            cb_type = QComboBox()
            cb_type.addItem("Serial (USB)", "serial")
            cb_type.addItem("Wi-Fi (UDP)", "wifi")
            # Select current
            curr_idx = cb_type.findData(dev.type)
            if curr_idx >= 0: cb_type.setCurrentIndex(curr_idx)
            
            # Change Type Logic
            cb_type.currentIndexChanged.connect(lambda i, d=dev, cb=cb_type: self._on_device_type_changed(d, cb.currentData()))
            self.tbl_devices.setCellWidget(idx, 1, cb_type)
            
            # 3. CONNECTION (Context Sensitive)
            conn_widget = QWidget()
            conn_layout = QHBoxLayout(conn_widget)
            conn_layout.setContentsMargins(0,0,0,0)
            conn_layout.setSpacing(5)
            
            if dev.type == "serial":
                cb_port = QComboBox()
                if not available_ports:
                    cb_port.addItem("No Ports", "none")
                else:
                    for p in available_ports:
                        cb_port.addItem(p, p)
                
                # Find current
                curr_port_idx = cb_port.findText(dev.port)
                if curr_port_idx >= 0: cb_port.setCurrentIndex(curr_port_idx)
                else: 
                     if dev.port:
                         cb_port.addItem(f"{dev.port} (?)", dev.port)
                         cb_port.setCurrentIndex(cb_port.count()-1)
                
                cb_port.currentIndexChanged.connect(lambda i, d=dev, cb=cb_port: setattr(d, 'port', cb.currentData() if cb.currentData() else cb.currentText()))
                conn_layout.addWidget(cb_port)
                
            else: # Wi-Fi
                txt_ip = QLineEdit(dev.ip_address)
                txt_ip.setPlaceholderText("192.168.x.x")
                txt_ip.textChanged.connect(lambda t, d=dev: setattr(d, 'ip_address', t))
                conn_layout.addWidget(txt_ip)
                
                # Port (Optional, maybe hidden or small?)
                # txt_port = QLineEdit(str(dev.udp_port))
                # txt_port.setFixedWidth(50)
                # txt_port.textChanged.connect(lambda t, d=dev: setattr(d, 'udp_port', int(t) if t.isdigit() else 4210))
                # conn_layout.addWidget(txt_port)
            
            self.tbl_devices.setCellWidget(idx, 2, conn_widget)
            
            # 4. LED COUNT (Spinbox)
            sb_leds = QSpinBox()
            sb_leds.setRange(1, 1024)
            sb_leds.setValue(dev.led_count)
            sb_leds.valueChanged.connect(lambda v, d=dev: setattr(d, 'led_count', v))
            self.tbl_devices.setCellWidget(idx, 3, sb_leds)
            
            # 5. IDENTIFY BUTTON
            # Allow for both Wi-Fi and Serial (JTAG/USB)
            btn_id = QPushButton("👁")
            btn_id.setToolTip("Identify Device (Flash LEDs)")
            btn_id.setStyleSheet("background-color: #0A84FF; color: white; border-radius: 3px; font-weight: bold;")
            btn_id.clicked.connect(lambda _, d=dev: self._identify_device(d))
            self.tbl_devices.setCellWidget(idx, 4, btn_id)
            
            # 6. SETUP BUTTON
            btn_setup = QPushButton("Config")
            btn_setup.setToolTip("Run LED Wizard for this device")
            btn_setup.setStyleSheet("background-color: #5856d6; color: white; border-radius: 3px; font-size: 11px;")
            btn_setup.clicked.connect(lambda _, d=dev: self._run_device_led_wizard(d))
            self.tbl_devices.setCellWidget(idx, 5, btn_setup)

            # 7. DELETE BUTTON
            btn_del = QPushButton("Del")
            btn_del.setStyleSheet("background-color: #FF453A; color: white; border-radius: 3px;")
            btn_del.clicked.connect(lambda _, d=dev: self._delete_device(d))
            self.tbl_devices.setCellWidget(idx, 6, btn_del)
            
            # Connect Name Change
            # TableWidget doesn't verify on typing, only on focus loss.
            # We need to capture ItemChanged but only for name col
            
        self.tbl_devices.itemChanged.connect(self._on_device_name_changed)

    def _identify_device(self, device):
        """Send Identify signal to Main App (Universal)"""
        # Delegated to Main App to handle both Serial (Main Thread) and Wi-Fi (UDP)
        self.identify_requested.emit(device)
        # Small visual feedback
        print(f"DEBUG: Identify Requested for {device.name}")

    def _reset_device_wifi(self, device):
        """Send Reset Wi-Fi command"""
        if not device.ip_address: return
        
        # Use DiscoveryService directly or emit signal?
        # Since we are in UI thread, creating a temporary DiscoveryService is okay for a one-off UDP
        try:
            self.discovery = DiscoveryService() # Re-use or new? 
            # Note: DiscoveryService init binds port 0 (ephemeral), so it's safe to spawn.
            self.discovery.reset_wifi_device(device.ip_address, device.udp_port or 4210)
            self.discovery.reset_wifi_device(device.ip_address, device.udp_port or 4210)
            self.discovery.stop() # Immediately close
            self.discovery = None
            
            QMessageBox.information(self, "Reset Sent", 
                                    f"Reset command sent to {device.name}.\n\nIt should restart in AP Mode (Ambilight_Setup) shortly.")
        except Exception as e:
             QMessageBox.critical(self, "Error", f"Failed to send reset: {e}")

    def _on_device_type_changed(self, device, new_type):
        device.type = new_type
        self._refresh_device_table()
        
    def _on_device_name_changed(self, item):
        row = item.row()
        col = item.column()
        if col == 0: # Name
             new_name = item.text()
             if row < len(self.config.global_settings.devices):
                 self.config.global_settings.devices[row].name = new_name

    def _add_new_device(self):
        new_dev = DeviceSettings(name="New Controller", port="COMx", led_count=60)
        self.config.global_settings.devices.append(new_dev)
        self._refresh_device_table()
        
    def _delete_device(self, dev):
        reply = QMessageBox.question(self, "Remove Device", f"Remove '{dev.name}'?", QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        if reply == QMessageBox.StandardButton.Yes:
            if dev in self.config.global_settings.devices:
                self.config.global_settings.devices.remove(dev)
                self._refresh_device_table()

    def _init_tab_global(self):
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # HARDWARE - MOVED TO DEVICES TAB
        # We keep "Startup Logic" here though
        
        grp_startup = QGroupBox("Startup & Behavior")
        l_startup = QVBoxLayout()
        
        row2 = QHBoxLayout()
        row2.addWidget(QLabel("Start Mode:"))
        row2.addWidget(self.create_help_label("Which mode to activate when the application launches."))
        self.cb_start_mode = QComboBox()
        self.cb_start_mode.addItems(["light", "screen", "music", "pchealth"])
        row2.addWidget(self.cb_start_mode)
        l_startup.addLayout(row2)
        
        row_auto = QHBoxLayout()
        self.cb_autostart = QCheckBox("Start with Windows")
        self.cb_autostart.toggled.connect(self._on_autostart_change)
        row_auto.addWidget(self.cb_autostart)
        row_auto.addWidget(self.create_help_label("Automatically launch AmbiLight when you log in to Windows."))
        row_auto.addStretch()
        l_startup.addLayout(row_auto)
        
        grp_startup.setLayout(l_startup)
        layout.addWidget(grp_startup)
        
        # APPEARANCE
        grp_app = QGroupBox("Appearance")
        l_app = QVBoxLayout()
        
        row3 = QHBoxLayout()
        row3.addWidget(QLabel("Theme:"))
        row3.addWidget(self.create_help_label("Choose application visual style."))
        self.cb_theme = QComboBox()
        self.cb_theme.addItem("Dark (Premium)", "dark")
        self.cb_theme.addItem("Light (Clean)", "light")
        self.cb_theme.addItem("SnowRunner (Game)", "snowrunner")
        self.cb_theme.addItem("Coffee (Warm)", "brown")
        self.cb_theme.addItem("Ocean (Blue)", "blue")
        
        # Select current
        idx = self.cb_theme.findData(self.config.global_settings.theme)
        if idx >= 0: self.cb_theme.setCurrentIndex(idx)
        
        self.cb_theme.currentIndexChanged.connect(lambda i: self._on_theme_change(self.cb_theme.currentData()))
        row3.addWidget(self.cb_theme)
        l_app.addLayout(row3)
        
        # --- WIZARDS & SETUP ---
        grp_setup = QGroupBox("Setup Wizards")
        l_setup = QVBoxLayout()
        
        # 1. LED Wizard (Moved to Devices Tab)
        # We can keep a label pointing there
        lbl_hint = QLabel("💡 To configure LEDs (Count/Position), go to the 'Devices' tab.")
        lbl_hint.setStyleSheet("color: #888; font-style: italic;")
        l_setup.addWidget(lbl_hint)
        
        # 2. Color Calibration Profile Selector
        h_prof = QHBoxLayout()
        h_prof.addWidget(QLabel("Calibration Profile:"))
        
        self.cb_calib_profile = QComboBox()
        self._populate_calibration_profiles()
        self.cb_calib_profile.currentTextChanged.connect(self._on_calibration_profile_changed)
        h_prof.addWidget(self.cb_calib_profile, 2)
        
        btn_new_profile = QPushButton("➕ New")
        btn_new_profile.clicked.connect(self._create_calibration_profile)
        h_prof.addWidget(btn_new_profile)
        
        self.btn_del_profile = QPushButton("❌ Delete")
        self.btn_del_profile.clicked.connect(self._delete_calibration_profile)
        h_prof.addWidget(self.btn_del_profile)
        
        l_setup.addLayout(h_prof)
        
        # 3. Color Calibration Wizard
        btn_color_calib = QPushButton("🎨 Run Calibration Wizard (12 Test Colors)")
        btn_color_calib.clicked.connect(self._run_color_calibration)
        btn_color_calib.setStyleSheet("background-color: #5856d6; color: white; font-weight: bold;")
        l_setup.addWidget(btn_color_calib)
        
        # 4. Screen Mapping
        h_cal = QHBoxLayout()
        btn_calib = QPushButton("Run Screen Mapping Wizard (Click Corners)")
        btn_calib.clicked.connect(self._start_calibration)
        btn_reset_cal = QPushButton("Reset Mapping")
        btn_reset_cal.clicked.connect(self._reset_calibration)
        h_cal.addWidget(btn_calib)
        h_cal.addWidget(btn_reset_cal)
        l_setup.addLayout(h_cal)
        
        grp_setup.setLayout(l_setup)
        
        # Add to main layout (before Advanced)
        layout.addWidget(grp_setup)
        
        grp_app.setLayout(l_app)
        layout.addWidget(grp_app)
        
        # ADVANCED
        grp_adv = QGroupBox("Advanced Features")
        l_adv = QVBoxLayout()
        
        # Capture Method
        row4 = QHBoxLayout()
        row4.addWidget(QLabel("Capture Engine:"))
        row4.addWidget(self.create_help_label("• MSS: Standard CPU capture. Compatible with everything.\n• DXCam: High-speed GPU capture (NVIDIA/AMD/Intel). Recommended for gaming."))
        self.cb_capture = QComboBox()
        self.cb_capture.addItem("MSS (CPU - Compatible)", "mss")
        self.cb_capture.addItem("DXCam (GPU - High Performance)", "dxcam")
        row4.addWidget(self.cb_capture)
        l_adv.addLayout(row4)
        
        # Hotkeys
        box_hk = QGroupBox("Global Hotkeys")
        layout_hk = QFormLayout()
        
        self.chk_hotkeys = QCheckBox("Enable Hotkeys")
        self.chk_hotkeys.setChecked(self.config.global_settings.hotkeys_enabled) # Use self.config here
        layout_hk.addRow(self.chk_hotkeys)
        
        self.txt_hotkey = self._create_hk_btn(self.config.global_settings.hotkey_toggle)
        self.txt_hotkey.clicked.connect(lambda: self._start_record_hotkey(self.txt_hotkey, self.txt_hotkey.text()))
        layout_hk.addRow("Toggle Power:", self.txt_hotkey)
        
        self.btn_hk_light = self._create_hk_btn(self.config.global_settings.hotkey_mode_light)
        self.btn_hk_light.clicked.connect(lambda: self._start_record_hotkey(self.btn_hk_light, self.btn_hk_light.text()))
        layout_hk.addRow("Mode: Light:", self.btn_hk_light)
        
        self.btn_hk_screen = self._create_hk_btn(self.config.global_settings.hotkey_mode_screen)
        self.btn_hk_screen.clicked.connect(lambda: self._start_record_hotkey(self.btn_hk_screen, self.btn_hk_screen.text()))
        layout_hk.addRow("Mode: Screen:", self.btn_hk_screen)
        
        self.btn_hk_music = self._create_hk_btn(self.config.global_settings.hotkey_mode_music)
        self.btn_hk_music.clicked.connect(lambda: self._start_record_hotkey(self.btn_hk_music, self.btn_hk_music.text()))
        layout_hk.addRow("Mode: Music:", self.btn_hk_music)
        
        # --- CUSTOM SHORTCUTS ---
        layout_hk.addRow(QLabel("<b>Custom Shortcuts:</b>"))
        
        self.hk_container = QWidget()
        self.hk_container_layout = QVBoxLayout(self.hk_container)
        self.hk_container_layout.setContentsMargins(0,0,0,0)
        layout_hk.addRow(self.hk_container)
        
        self.hk_widgets = []
        for hk in self.config.global_settings.custom_hotkeys:
             self._add_hk_row(hk)
             
        # Big Add Button
        self.btn_add_custom = QPushButton("➕ Add Custom Shortcut")
        self.btn_add_custom.setMinimumHeight(32)
        self.btn_add_custom.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_add_custom.clicked.connect(lambda: self._add_hk_row({"action": "bright_up", "key": ""}))
        layout_hk.addRow(self.btn_add_custom)
        
        box_hk.setLayout(layout_hk) # <--- CRITICAL FIX
        
        self.recording_hotkey = False
        l_adv.addWidget(box_hk) # Add the hotkey group box to the advanced layout
        
        grp_adv.setLayout(l_adv)
        layout.addWidget(grp_adv)
        
        # === LED SEGMENT CONFIGURATION ===
        # from PyQt6.QtWidgets import QTableWidget, QTableWidgetItem, QHeaderView (Moved to top)
        grp_segments = QGroupBox("LED Segment Configuration")
        l_seg = QVBoxLayout()
        
        h_seg_hdr = QHBoxLayout()
        h_seg_hdr.addWidget(QLabel("View and configure LED segments:"))
        h_seg_hdr.addWidget(self.create_help_label(
            "• Edge: Screen edge\n"
            "• LED Range: Physical LED indices\n"
            "• Monitor: Which screen to capture\n"
            "• Reverse: Flip direction if backwards\n"
            "• Auto-updates after running Wizard"
        ))
        h_seg_hdr.addStretch()
        l_seg.addLayout(h_seg_hdr)
        
        # Segment Table - COMPACT for no scrolling
        self.tbl_segments = QTableWidget()
        self.tbl_segments.setColumnCount(8)
        self.tbl_segments.setHorizontalHeaderLabels(["Edge", "LEDs", "Monitor", "Device", "Frequency Role", "Rev", "Pixels", "Del"])
        
        # Compact row height
        self.tbl_segments.verticalHeader().setDefaultSectionSize(32)
        self.tbl_segments.verticalHeader().setVisible(False)
        
        # Compact column sizing
        self.tbl_segments.horizontalHeader().setStretchLastSection(False)
        self.tbl_segments.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)  # Edge
        self.tbl_segments.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)  # LEDs
        self.tbl_segments.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)  # Monitor
        self.tbl_segments.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)  # Device
        self.tbl_segments.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)  # Music (NEW)
        self.tbl_segments.horizontalHeader().setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed)  # Reverse
        self.tbl_segments.horizontalHeader().resizeSection(5, 50)  # Reverse checkbox width
        self.tbl_segments.horizontalHeader().setSectionResizeMode(6, QHeaderView.ResizeMode.Stretch)  # Pixels
        self.tbl_segments.horizontalHeader().setSectionResizeMode(7, QHeaderView.ResizeMode.Fixed)  # Delete
        self.tbl_segments.horizontalHeader().resizeSection(7, 45)  # Delete button width
        
        # Set maximum height based on content - REDUCED to prevent scroll-in-scroll
        # Auto-height is handled in _populate_segment_table
        # self.tbl_segments.setMaximumHeight(200)
        # self.tbl_segments.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        
        self._populate_segment_table()
        
        l_seg.addWidget(self.tbl_segments)
        
        # Add Segment Button
        btn_add_seg = QPushButton("+ Add Segment")
        btn_add_seg.clicked.connect(self._add_segment)
        l_seg.addWidget(btn_add_seg)
        
        grp_segments.setLayout(l_seg)
        layout.addWidget(grp_segments)
        
        layout.addStretch()
        
        scroll = self._make_scrollable(layout)
        main_layout = QVBoxLayout(self.tab_global)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addWidget(scroll)

    def _init_tab_light(self):
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Color Picking
        grp_color = QGroupBox("Color & Brightness")
        l_col = QVBoxLayout()
        
        # Header Help
        h_head = QHBoxLayout()
        h_head.addWidget(QLabel("Set a static color or pattern."))
        h_head.addWidget(self.create_help_label("Light Mode is for ambient lighting without screen synchronization.\nGreat for reading or mood lighting."))
        h_head.addStretch()
        l_col.addLayout(h_head)

        # --- NEW: HomeKit Toggle ---
        self.chk_homekit = QCheckBox("Control via Apple Home (MQTT)")
        self.chk_homekit.setToolTip("If checked, the app stops sending data to let Apple Home control the light.")
        self.chk_homekit.setChecked(self.config.light_mode.homekit_enabled)
        l_col.addWidget(self.chk_homekit)
        
        # Color Button
        self.btn_color_pick = QPushButton("Pick Color")
        self.btn_color_pick.clicked.connect(self._pick_color_light)
        self.lbl_color_preview = QLabel("   ")
        self.lbl_color_preview.setStyleSheet("background-color: #FFC864; border: 1px solid #555; border-radius: 4px;")
        self.lbl_color_preview.setFixedSize(50, 25)
        
        row_c = QHBoxLayout()
        row_c.addWidget(self.lbl_color_preview)
        row_c.addWidget(self.btn_color_pick)
        l_col.addLayout(row_c)
        
        # Brightness
        h_br = QHBoxLayout()
        h_br.addWidget(QLabel("Brightness:"))
        h_br.addWidget(self.create_help_label("Master brightness for Light Mode (0-100%)."))
        h_br.addStretch()
        l_col.addLayout(h_br)
        
        self.sl_light_bright = QSlider(Qt.Orientation.Horizontal)
        self.sl_light_bright.setRange(0, 255)
        l_col.addWidget(self.sl_light_bright)
        
        grp_color.setLayout(l_col)
        layout.addWidget(grp_color)
        
        # Animations
        grp_anim = QGroupBox("Effects")
        l_anim = QVBoxLayout()
        
        h_eff = QHBoxLayout()
        h_eff.addWidget(QLabel("Effect Type:"))
        h_eff.addWidget(self.create_help_label("• Static: Solid color.\n• Breathing: Pulses fading in/out.\n• Rainbow: Cycles all colors.\n• Chase: Moving light segments."))
        h_eff.addStretch()
        l_anim.addLayout(h_eff)
        
        self.cb_effect = QComboBox()
        self.cb_effect.addItems(["static", "breathing", "rainbow", "chase", "custom_zones"])
        self.cb_effect.currentTextChanged.connect(self._on_light_effect_changed)
        l_anim.addWidget(self.cb_effect)
        
        h_spd = QHBoxLayout()
        h_spd.addWidget(QLabel("Effect Speed:"))
        h_spd.addWidget(self.create_help_label("Controls how fast the animation plays."))
        h_spd.addStretch()
        l_anim.addLayout(h_spd)
        
        self.sl_speed = QSlider(Qt.Orientation.Horizontal)
        self.sl_speed.setRange(1, 100)
        l_anim.addWidget(self.sl_speed)
        
        grp_anim.setLayout(l_anim)
        layout.addWidget(grp_anim)
        
        # Zone Editor (Initially Hidden)
        self.zone_editor = ZoneEditorWidget()
        self.zone_editor.setVisible(False)
        # Connect signal: explicit update to config
        self.zone_editor.zones_changed.connect(lambda zones: setattr(self.config.light_mode, 'custom_zones', zones))
        # Pre-load zones if any
        if self.config.light_mode.custom_zones:
             self.zone_editor.set_zones(self.config.light_mode.custom_zones)
        layout.addWidget(self.zone_editor)
        
        self.stored_light_color = (255, 255, 255) # Temp storage
        
        layout.addStretch()
        
        scroll = self._make_scrollable(layout)
        main_layout = QVBoxLayout(self.tab_light)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addWidget(scroll)

    def _init_tab_screen(self):
        layout = QVBoxLayout()
        layout.setSpacing(20) # More breathing room
        layout.setContentsMargins(20, 20, 20, 20)
        
        # --- PRESETS ---
        grp_pre = QGroupBox("Quick Presets")
        l_pre = QVBoxLayout()
        l_pre.setSpacing(12)
        
        h_ph = QHBoxLayout()
        h_ph.addWidget(QLabel("Select a preset or save your own."))
        h_ph.addWidget(self.create_help_label("Presets allow you to quickly switch between different styles.\n• Movie: Optimized for immersion (vivid, smooth).\n• Gaming: Optimized for reaction speed (bright, fast).\n• Desktop: Gentle background lighting."))
        h_ph.addStretch()
        l_pre.addLayout(h_ph)
        
        h_pre = QHBoxLayout()
        self.cb_screen_preset = QComboBox()
        self.cb_screen_preset.currentIndexChanged.connect(self._apply_screen_preset)
        h_pre.addWidget(self.cb_screen_preset, 2)
        
        btn_save_pre = QPushButton("Save New")
        btn_save_pre.setToolTip("Save current settings as a new preset")
        btn_save_pre.clicked.connect(self._save_screen_preset)
        h_pre.addWidget(btn_save_pre)
        
        self.btn_del_screen_pre = QPushButton("Delete")
        self.btn_del_screen_pre.setToolTip("Delete selected custom preset")
        self.btn_del_screen_pre.clicked.connect(self._delete_screen_preset)
        self.btn_del_screen_pre.setEnabled(False) # Default disabled until custom selected
        h_pre.addWidget(self.btn_del_screen_pre)
        
        l_pre.addLayout(h_pre)
        grp_pre.setLayout(l_pre)
        layout.addWidget(grp_pre)
        
        # --- MONITOR ---
        # --- MONITOR ---
        grp_mon = QGroupBox("Display Configuration")
        l_mon = QVBoxLayout()
        
        # Detected Monitors List
        l_mon.addWidget(QLabel("Detected Monitors:"))
        self.list_monitors = QListWidget()
        self.list_monitors.setMaximumHeight(80)
        
        # Populate List
        if self.monitors:
            for i, mon in enumerate(self.monitors):
                if i == 0: continue # Skip Combined
                self.list_monitors.addItem(f"Monitor {i}: {mon['width']}x{mon['height']} @ {mon['left']},{mon['top']}")
        else:
            self.list_monitors.addItem("No monitors detected via MSS.")
            
        l_mon.addWidget(self.list_monitors)

        l_mon.addSpacing(10)

        # Primary Monitor Selector
        h_mon = QHBoxLayout()
        h_mon.addWidget(QLabel("Primary Source:"))
        h_mon.addWidget(self.create_help_label("Default monitor for capture if not overridden by specific LED segments."))
        h_mon.addStretch()
        l_mon.addLayout(h_mon)
        
        self.cb_monitor = QComboBox()
        # MSS monitors: 0=All, 1=Prim, 2=Sec...
        # We skip 0 (All) usually, or allow it? Start from index 1.
        print(f"DEBUG: Monitors in SettingsDialog: {self.monitors}")
        if self.monitors and len(self.monitors) > 0:
            for i, mon in enumerate(self.monitors):
                if i == 0:
                    self.cb_monitor.addItem(f"Combined (All Screens): {mon['width']}x{mon['height']}", i)
                else:
                    self.cb_monitor.addItem(f"Monitor {i}: {mon['width']}x{mon['height']} @ {mon['left']},{mon['top']}", i)
        else:
            # Fallback: Try to fetch monitors via MSS if not passed
            try:
                import mss
                with mss.mss() as sct:
                    mss_monitors = list(sct.monitors)
                    # MSS[0] is All, MSS[1] is Primary. We want individual monitors.
                    if len(mss_monitors) > 1:
                        print(f"DEBUG: Recovered {len(mss_monitors)-1} monitors via MSS")
                        for i, mon in enumerate(mss_monitors):
                            if i == 0:
                                self.cb_monitor.addItem(f"Combined (All Screens): {mon['width']}x{mon['height']}", i)
                            else:
                                self.cb_monitor.addItem(f"Monitor {i}: {mon['width']}x{mon['height']} @ {mon['left']},{mon['top']}", i)
                    else:
                        raise Exception("No monitors found")
            except Exception as e:
                print(f"WARNING: Monitor detection failed: {e}. Adding fallback.")
                self.cb_monitor.addItem("Primary Monitor (1920x1080)", 1)
        self.cb_monitor.currentIndexChanged.connect(self._on_monitor_changed)
        l_mon.addWidget(self.cb_monitor)
        
        # Monitor Helper Note
        lbl_hint = QLabel("Note: You can map specific LED segments to different monitors in the 'Devices' tab wizard.")
        lbl_hint.setWordWrap(True)
        lbl_hint.setStyleSheet("font-size: 11px; color: #888; margin-top: 5px;")
        l_mon.addWidget(lbl_hint)
        
        grp_mon.setLayout(l_mon)
        layout.addWidget(grp_mon)
        
        # Calibration moved to Global
        # l_calib.addWidget(QLabel("Click 'Wizard' to manually map corners, or 'Auto Set' for default."))
        # grp_calib.setLayout(l_calib)
        # layout.addWidget(grp_calib)
        
        # --- SCANNING AREA ---
        grp_scan = QGroupBox("Scanning Area (Edge Detection)")
        l_scan = QVBoxLayout()
        
        # Toggle Preview Button
        self.btn_preview_scan = QPushButton("👁 Show Preview")
        self.btn_preview_scan.setCheckable(True)
        self.btn_preview_scan.setChecked(False)
        self.btn_preview_scan.clicked.connect(self._toggle_scan_preview)
        self.btn_preview_scan.setToolTip("Show/Hide scanning area overlay on monitor")
        self.btn_preview_scan.setStyleSheet("""
            QPushButton {
                background-color: #0A84FF;
                color: white;
                border: none;
                border-radius: 6px;
                padding: 8px 16px;
                font-weight: bold;
            }
            QPushButton:checked {
                background-color: #FF453A;
            }
            QPushButton:hover {
                background-color: #0A70DB;
            }
            QPushButton:checked:hover {
                background-color: #E03428;
            }
        """)
        l_scan.addWidget(self.btn_preview_scan)
        
        # --- MODE TOGGLE (Simple / Advanced) ---
        h_mode_toggle = QHBoxLayout()
        h_mode_toggle.addWidget(QLabel("Scan Zone Mode:"))
        h_mode_toggle.addWidget(self.create_help_label(
            "Simple: One setting for scan depth and padding on all edges.\n"
            "Advanced: Configure scan depth and padding for each edge (Top/Bottom/Left/Right) independently."))
        
        # Segmented Control Style Toggle
        self.btn_mode_simple = QPushButton("Simple")
        self.btn_mode_simple.setCheckable(True)
        self.btn_mode_simple.setChecked(True)
        self.btn_mode_simple.clicked.connect(lambda: self._on_scan_mode_toggle("simple"))
        
        self.btn_mode_advanced = QPushButton("Advanced")
        self.btn_mode_advanced.setCheckable(True)
        self.btn_mode_advanced.setChecked(False)
        self.btn_mode_advanced.clicked.connect(lambda: self._on_scan_mode_toggle("advanced"))
        
        # Style for segmented control
        toggle_style = """
            QPushButton {
                background-color: #2d2d2d;
                color: #888;
                border: 1px solid #444;
                padding: 6px 16px;
                font-weight: bold;
                min-width: 80px;
            }
            QPushButton:checked {
                background-color: #0A84FF;
                color: white;
                border: 1px solid #0A84FF;
            }
            QPushButton:hover {
                background-color: #3d3d3d;
            }
            QPushButton:checked:hover {
                background-color: #0A70DB;
            }
        """
        self.btn_mode_simple.setStyleSheet(toggle_style)
        self.btn_mode_advanced.setStyleSheet(toggle_style)
        
        h_mode_toggle.addWidget(self.btn_mode_simple)
        h_mode_toggle.addWidget(self.btn_mode_advanced)
        h_mode_toggle.addStretch()
        l_scan.addLayout(h_mode_toggle)
        
        # --- SIMPLE MODE CONTAINER ---
        self.simple_scan_container = QWidget()
        simple_scan_layout = QVBoxLayout(self.simple_scan_container)
        simple_scan_layout.setContentsMargins(0, 10, 0, 0)
        
        # Scan Depth
        h_sd = QHBoxLayout()
        h_sd.addWidget(QLabel("Scan Depth (How far from edge):"))
        h_sd.addWidget(self.create_help_label("Determines how far into the screen to capture colors.\n• 5%: Very edge focused (precise).\n• 20%+: Averaged colors (softer)."))
        h_sd.addStretch()
        simple_scan_layout.addLayout(h_sd)
        
        h1 = QHBoxLayout()
        self.sl_scan_depth = QSlider(Qt.Orientation.Horizontal)
        self.sl_scan_depth.setRange(5, 50) # 5% to 50%
        self.lbl_scan_depth = QLabel("15%")
        
        # Connect to visualizer (show while dragging)
        self.sl_scan_depth.valueChanged.connect(self._on_scan_slider_change)
        
        self.sl_scan_depth.setToolTip("Determines how far into the screen to capture colors.\nHigher values capture more average color; Lower values are more precise to the edge.")
        h1.addWidget(self.sl_scan_depth)
        h1.addWidget(self.lbl_scan_depth)
        simple_scan_layout.addLayout(h1)
        
        l_scan.addWidget(self.simple_scan_container)
        
        # --- ADVANCED MODE CONTAINER ---
        self.advanced_scan_container = QWidget()
        advanced_scan_layout = QVBoxLayout(self.advanced_scan_container)
        advanced_scan_layout.setContentsMargins(0, 10, 0, 0)
        
        h_adv_scan_label = QHBoxLayout()
        h_adv_scan_label.addWidget(QLabel("Scan Depth (Per Edge):"))
        h_adv_scan_label.addWidget(self.create_help_label("Configure scan depth for each edge independently.\nUseful for asymmetric content or multi-monitor setups."))
        h_adv_scan_label.addStretch()
        advanced_scan_layout.addLayout(h_adv_scan_label)
        
        # Create 2x2 grid for per-edge scan depth sliders
        from PyQt6.QtWidgets import QGridLayout
        grid_scan_depth = QGridLayout()
        grid_scan_depth.setSpacing(10)
        
        # Top
        lbl_depth_top = QLabel("Top:")
        self.sl_scan_depth_top = QSlider(Qt.Orientation.Horizontal)
        self.sl_scan_depth_top.setRange(5, 50)
        self.lbl_scan_depth_top = QLabel("15%")
        self.sl_scan_depth_top.valueChanged.connect(self._on_scan_slider_change)
        grid_scan_depth.addWidget(lbl_depth_top, 0, 0)
        grid_scan_depth.addWidget(self.sl_scan_depth_top, 0, 1)
        grid_scan_depth.addWidget(self.lbl_scan_depth_top, 0, 2)
        
        # Bottom
        lbl_depth_bottom = QLabel("Bottom:")
        self.sl_scan_depth_bottom = QSlider(Qt.Orientation.Horizontal)
        self.sl_scan_depth_bottom.setRange(5, 50)
        self.lbl_scan_depth_bottom = QLabel("15%")
        self.sl_scan_depth_bottom.valueChanged.connect(self._on_scan_slider_change)
        grid_scan_depth.addWidget(lbl_depth_bottom, 1, 0)
        grid_scan_depth.addWidget(self.sl_scan_depth_bottom, 1, 1)
        grid_scan_depth.addWidget(self.lbl_scan_depth_bottom, 1, 2)
        
        # Left
        lbl_depth_left = QLabel("Left:")
        self.sl_scan_depth_left = QSlider(Qt.Orientation.Horizontal)
        self.sl_scan_depth_left.setRange(5, 50)
        self.lbl_scan_depth_left = QLabel("15%")
        self.sl_scan_depth_left.valueChanged.connect(self._on_scan_slider_change)
        grid_scan_depth.addWidget(lbl_depth_left, 2, 0)
        grid_scan_depth.addWidget(self.sl_scan_depth_left, 2, 1)
        grid_scan_depth.addWidget(self.lbl_scan_depth_left, 2, 2)
        
        # Right
        lbl_depth_right = QLabel("Right:")
        self.sl_scan_depth_right = QSlider(Qt.Orientation.Horizontal)
        self.sl_scan_depth_right.setRange(5, 50)
        self.lbl_scan_depth_right = QLabel("15%")
        self.sl_scan_depth_right.valueChanged.connect(self._on_scan_slider_change)
        grid_scan_depth.addWidget(lbl_depth_right, 3, 0)
        grid_scan_depth.addWidget(self.sl_scan_depth_right, 3, 1)
        grid_scan_depth.addWidget(self.lbl_scan_depth_right, 3, 2)
        
        advanced_scan_layout.addLayout(grid_scan_depth)
        
        l_scan.addWidget(self.advanced_scan_container)
        
        # Initially hide advanced mode
        self.advanced_scan_container.setVisible(False)
        
        # Color Sampling Method
        h_sampling = QHBoxLayout()
        h_sampling.addWidget(QLabel("Color Sampling:"))
        h_sampling.addWidget(self.create_help_label(
            "Median: Eliminates outliers (white text on colored backgrounds) → purer colors, no whitening.\n"
            "Average: Traditional mean averaging → faster but can whiten colors with mixed content."))
        self.cb_color_sampling = QComboBox()
        self.cb_color_sampling.addItems(["median", "average"])
        h_sampling.addWidget(self.cb_color_sampling)
        h_sampling.addStretch()
        l_scan.addLayout(h_sampling)
        
        # --- ADD PADDING TO SIMPLE CONTAINER ---
        h_pad_simple = QHBoxLayout()
        h_pad_simple.addWidget(QLabel("Edge Padding (Ignore Black Bars):"))
        h_pad_simple.addWidget(self.create_help_label("Skips pixels at the very edge of the screen.\nUse this if you have cinematic black bars or scrolling bars visible."))
        h_pad_simple.addStretch()
        simple_scan_layout.addLayout(h_pad_simple)
        
        h_pad_slider = QHBoxLayout()
        self.sl_padding = QSlider(Qt.Orientation.Horizontal)
        self.sl_padding.setRange(0, 20) # 0% to 20%
        self.lbl_padding = QLabel("0%")
        self.sl_padding.valueChanged.connect(self._on_scan_slider_change)
        self.sl_padding.setToolTip("Ignores the outer edge of the screen.\nUseful if you have black bars or wants to ignore scrollbars.")
        h_pad_slider.addWidget(self.sl_padding)
        h_pad_slider.addWidget(self.lbl_padding)
        simple_scan_layout.addLayout(h_pad_slider)
        
        # --- ADD PADDING TO ADVANCED CONTAINER ---
        h_adv_pad_label = QHBoxLayout()
        h_adv_pad_label.addWidget(QLabel("Edge Padding (Per Edge):"))
        h_adv_pad_label.addWidget(self.create_help_label("Configure padding for each edge independently.\nUseful for asymmetric black bars or multi-monitor setups."))
        h_adv_pad_label.addStretch()
        advanced_scan_layout.addLayout(h_adv_pad_label)
        
        # Create 2x2 grid for per-edge padding sliders
        grid_padding = QGridLayout()
        grid_padding.setSpacing(10)
        
        # Top
        lbl_pad_top = QLabel("Top:")
        self.sl_padding_top = QSlider(Qt.Orientation.Horizontal)
        self.sl_padding_top.setRange(0, 20)
        self.lbl_padding_top = QLabel("0%")
        self.sl_padding_top.valueChanged.connect(self._on_scan_slider_change)
        grid_padding.addWidget(lbl_pad_top, 0, 0)
        grid_padding.addWidget(self.sl_padding_top, 0, 1)
        grid_padding.addWidget(self.lbl_padding_top, 0, 2)
        
        # Bottom
        lbl_pad_bottom = QLabel("Bottom:")
        self.sl_padding_bottom = QSlider(Qt.Orientation.Horizontal)
        self.sl_padding_bottom.setRange(0, 20)
        self.lbl_padding_bottom = QLabel("0%")
        self.sl_padding_bottom.valueChanged.connect(self._on_scan_slider_change)
        grid_padding.addWidget(lbl_pad_bottom, 1, 0)
        grid_padding.addWidget(self.sl_padding_bottom, 1, 1)
        grid_padding.addWidget(self.lbl_padding_bottom, 1, 2)
        
        # Left
        lbl_pad_left = QLabel("Left:")
        self.sl_padding_left = QSlider(Qt.Orientation.Horizontal)
        self.sl_padding_left.setRange(0, 20)
        self.lbl_padding_left = QLabel("0%")
        self.sl_padding_left.valueChanged.connect(self._on_scan_slider_change)
        grid_padding.addWidget(lbl_pad_left, 2, 0)
        grid_padding.addWidget(self.sl_padding_left, 2, 1)
        grid_padding.addWidget(self.lbl_padding_left, 2, 2)
        
        # Right
        lbl_pad_right = QLabel("Right:")
        self.sl_padding_right = QSlider(Qt.Orientation.Horizontal)
        self.sl_padding_right.setRange(0, 20)
        self.lbl_padding_right = QLabel("0%")
        self.sl_padding_right.valueChanged.connect(self._on_scan_slider_change)
        grid_padding.addWidget(lbl_pad_right, 3, 0)
        grid_padding.addWidget(self.sl_padding_right, 3, 1)
        grid_padding.addWidget(self.lbl_padding_right, 3, 2)
        
        advanced_scan_layout.addLayout(grid_padding)
        
        grp_scan.setLayout(l_scan)
        layout.addWidget(grp_scan)
        
        # --- PICTURE ---
        grp_pic = QGroupBox("Picture Quality")
        l_pic = QVBoxLayout()
        
        # Gamma
        h_g = QHBoxLayout()
        h_g.addWidget(QLabel("Gamma Correction (Contrast):"))
        h_g.addWidget(self.create_help_label("Adjusts the darkness curve.\n• 1.0: Linear (Neutral).\n• 2.2: Standard (Darker blacks, richer colors).\nIncrease this if dark scenes look too washed out."))
        h_g.addStretch()
        l_pic.addLayout(h_g)
        
        h_gamma = QHBoxLayout()
        self.sl_gamma = QSlider(Qt.Orientation.Horizontal)
        self.sl_gamma.setRange(5, 30) # 0.5 to 3.0 (divide by 10)
        self.lbl_gamma = QLabel("1.0")
        self.sl_gamma.valueChanged.connect(lambda v: self.lbl_gamma.setText(f"{v/10.0}"))
        self.sl_gamma.setToolTip("Adjusts contrast/brightness curve.\nHigher values (2.2+) make dark scenes deeper. 1.0 is neutral.")
        h_gamma.addWidget(self.sl_gamma)
        h_gamma.addWidget(self.lbl_gamma)
        l_pic.addLayout(h_gamma)
        
        # Ultra Saturation (NEW) - Checkbox to enable aggressive saturation
        self.chk_ultra_sat = QCheckBox("🎨 Ultra Saturation (Prevent Washed Colors)")
        self.chk_ultra_sat.setToolTip("Enable aggressive saturation boost to prevent washed-out whites.\\nExample: Green grass will stay green instead of appearing white.")
        self.chk_ultra_sat.toggled.connect(self._on_ultra_sat_toggle)
        l_pic.addWidget(self.chk_ultra_sat)
        
        # Saturation
        h_s = QHBoxLayout()
        h_s.addWidget(QLabel("Vibrancy (Saturation Boost):"))
        h_s.addWidget(self.create_help_label("Boosts color intensity.\\n• Normal mode: 1.0x-5.0x\\n• Ultra mode: 1.0x-100.0x (when checkbox checked)"))
        h_s.addStretch()
        l_pic.addLayout(h_s)
        
        h3 = QHBoxLayout()
        self.sl_sat = QSlider(Qt.Orientation.Horizontal)
        self.sl_sat.setRange(10, 50) # 1.0 to 5.0 (divide by 10) - dynamically changes with checkbox
        self.lbl_sat = QLabel("1.0x")
        self.sl_sat.valueChanged.connect(lambda v: self.lbl_sat.setText(f"{v/10.0}x"))
        self.sl_sat.setToolTip("Boosts color saturation.\\n1.0x is original; Higher values make colors more vivid.")
        h3.addWidget(self.sl_sat)
        h3.addWidget(self.lbl_sat)
        l_pic.addLayout(h3)
        
        # Min Brightness
        h_b = QHBoxLayout()
        h_b.addWidget(QLabel("Black Level (Minimum Brightness):"))
        h_b.addWidget(self.create_help_label("Ensures the LEDs never turn fully off.\nSet to ~5 if you want a faint glow even in total darkness."))
        h_b.addStretch()
        l_pic.addLayout(h_b)
        
        h4 = QHBoxLayout()
        self.sl_black = QSlider(Qt.Orientation.Horizontal)
        self.sl_black.setRange(0, 50) # 0 to 50 (8-bit)
        self.lbl_black = QLabel("5")
        self.sl_black.valueChanged.connect(lambda v: self.lbl_black.setText(f"{v}"))
        self.sl_black.setToolTip("Minimum brightness level.\nPrevents LEDs from turning completely off in dark scenes if set higher than 0.")
        h4.addWidget(self.sl_black)
        h4.addWidget(self.lbl_black)
        l_pic.addLayout(h4)
        
        grp_pic.setLayout(l_pic)
        layout.addWidget(grp_pic)
        
        # --- MOTION ---
        grp_motion = QGroupBox("Motion")
        l_mot = QVBoxLayout()
        
        h_m = QHBoxLayout()
        h_m.addWidget(QLabel("Smoothness (Transition Speed):"))
        h_m.addWidget(self.create_help_label("How fast the lights react to changes.\n• 0ms: Instant (Gaming).\n• 200ms+: Cinematic/Slow (Movies)."))
        h_m.addStretch()
        l_mot.addLayout(h_m)
        
        h5 = QHBoxLayout()
        self.sl_interp = QSlider(Qt.Orientation.Horizontal)
        self.sl_interp.setRange(0, 500) # ms
        self.lbl_interp = QLabel("50ms")
        self.sl_interp.valueChanged.connect(lambda v: self.lbl_interp.setText(f"{v}ms"))
        self.sl_interp.setToolTip("Time to transition between colors.\nHigher = Smoother/Slower; 0 = Instant/Responsive.")
        h5.addWidget(self.sl_interp)
        h5.addWidget(self.lbl_interp)
        l_mot.addLayout(h5)
        
        grp_motion.setLayout(l_mot)
        layout.addWidget(grp_motion)
        
        layout.addStretch()
        
        scroll = self._make_scrollable(layout)
        main_layout = QVBoxLayout(self.tab_screen)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addWidget(scroll)

    def _init_tab_music(self):
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # --- PRESETS ---
        grp_pre = QGroupBox("Music Genres")
        l_pre = QVBoxLayout()
        
        h_hdr = QHBoxLayout()
        h_hdr.addWidget(QLabel("Select a genre or save your own."))
        h_hdr.addWidget(self.create_help_label("• Party: Aggressive, bright, fast.\n• Chill: Smooth, relaxing response.\n• Bass: Focuses purely on the beat."))
        h_hdr.addStretch()
        l_pre.addLayout(h_hdr)
        
        h_pre = QHBoxLayout()
        self.cb_music_preset = QComboBox()
        self.cb_music_preset.currentIndexChanged.connect(self._apply_music_preset)
        h_pre.addWidget(self.cb_music_preset, 2)

        btn_save_pre = QPushButton("Save New")
        btn_save_pre.clicked.connect(self._save_music_preset)
        h_pre.addWidget(btn_save_pre)
        
        self.btn_del_music_pre = QPushButton("Delete")
        self.btn_del_music_pre.clicked.connect(self._delete_music_preset)
        self.btn_del_music_pre.setEnabled(False)
        h_pre.addWidget(self.btn_del_music_pre)
        
        l_pre.addLayout(h_pre)
        grp_pre.setLayout(l_pre)
        layout.addWidget(grp_pre)
        
        # Audio Source
        grp_src = QGroupBox("Audio Source")
        l_src = QVBoxLayout()
        
        h_as = QHBoxLayout()
        h_as.addWidget(QLabel("Input Device:"))
        h_as.addWidget(self.create_help_label("Choose 'Auto-Detect Loopback' to capture what you hear on PC.\nOr select a specific microphone/input."))
        h_as.addStretch()
        l_src.addLayout(h_as)
        
        self.cb_audio_device = QComboBox()
        l_src.addWidget(self.cb_audio_device)
        
        # Auto Gain moved to Bass row
        
        grp_src.setLayout(l_src)
        layout.addWidget(grp_src)
        
        # General Settings
        grp_gen = QGroupBox("General Settings")
        l_gen = QVBoxLayout()
        
        h_mb = QHBoxLayout()
        h_mb.addWidget(QLabel("Min Brightness (Floor):"))
        h_mb.addWidget(self.create_help_label("Ensures lights never go completely black.\nUseful for maintaining atmosphere."))
        h_mb.addStretch()
        l_gen.addLayout(h_mb)
        
        h_mb_s = QHBoxLayout()
        self.sl_music_min_bright = QSlider(Qt.Orientation.Horizontal)
        self.sl_music_min_bright.setRange(0, 50) # 0-50 is plenty for floor
        self.lbl_music_min_bright = QLabel("0")
        self.sl_music_min_bright.valueChanged.connect(lambda v: self.lbl_music_min_bright.setText(f"{v}"))
        h_mb_s.addWidget(self.sl_music_min_bright)
        h_mb_s.addWidget(self.lbl_music_min_bright)
        l_gen.addLayout(h_mb_s)
        
        grp_gen.setLayout(l_gen)
        layout.addWidget(grp_gen)
        
        # Bands
        grp_bands = QGroupBox("Frequency Bands & Colors")
        l_bands = QVBoxLayout()
        
        # GLOBAL SENSITIVITY (MASTER GAIN)
        h_glob = QHBoxLayout()
        h_glob.addWidget(QLabel("Global Sensitivity:"))
        h_glob.addWidget(self.create_help_label("Master Gain controls the overall strength of all bands.\nUse this to quickly adjust for volume changes."))
        
        self.sl_global_sens = QSlider(Qt.Orientation.Horizontal)
        self.sl_global_sens.setRange(1, 500) # 1% to 1000%
        self.sl_global_sens.setValue(50) # Default
        
        lbl_glob_val = QLabel("100%")
        self.sl_global_sens.valueChanged.connect(lambda v: lbl_glob_val.setText(f"{v * 2}%"))
        
        h_glob.addWidget(self.sl_global_sens)
        h_glob.addWidget(lbl_glob_val)
        l_bands.addLayout(h_glob)

        # Helper to create band rows (MOTION CONTROLS ONLY - NO COLORS)
        def make_band_row(label_txt, help_txt, lbl_attr, help_attr, slider_attr, check_attr=None):
            # Row 1: Label + Help
            h_lbl = QHBoxLayout()
            lbl = QLabel(label_txt)
            lbl.setStyleSheet("font-weight: bold;")
            setattr(self, lbl_attr, lbl)
            h_lbl.addWidget(lbl)
            
            help_btn = self.create_help_label(help_txt)
            setattr(self, help_attr, help_btn)
            h_lbl.addWidget(help_btn)
            h_lbl.addStretch()
            
            if check_attr:
                chk = QCheckBox("Auto")
                chk.setToolTip("Enable automatic adjustment for this setting.")
                setattr(self, check_attr, chk)
                h_lbl.addWidget(chk)
            
            l_bands.addLayout(h_lbl)
            
            # Row 2: Slider ONLY (no color button)
            h_ctl = QHBoxLayout()
            slider = QSlider(Qt.Orientation.Horizontal)
            slider.setRange(0, 100)
            slider.setValue(50)
            setattr(self, slider_attr, slider)
            h_ctl.addWidget(slider)
            
            l_bands.addLayout(h_ctl)

        # ROTATION CONTROL (Hidden by default)
        h_rot = QHBoxLayout()
        self.lbl_rot = QLabel("Rotation Speed:")
        self.lbl_rot.setVisible(False)
        self.sl_rot = QSlider(Qt.Orientation.Horizontal)
        self.sl_rot.setRange(-100, 100) # Negative for reverse
        self.sl_rot.setValue(20)
        self.sl_rot.setVisible(False)
        
        self.lbl_rot_val = QLabel("20")
        self.lbl_rot_val.setVisible(False)
        self.sl_rot.valueChanged.connect(lambda v: self.lbl_rot_val.setText(f"{v}"))
        
        h_rot.addWidget(self.lbl_rot)
        h_rot.addWidget(self.sl_rot)
        h_rot.addWidget(self.lbl_rot_val)
        l_bands.addLayout(h_rot)

        make_band_row("Bass (Low Freq / Kick)", 
                      "Thump thump! 🔊 Controls how strongly the lights react to Bass.", 
                      "lbl_bass", "help_bass", "sl_bass", "chk_auto_bass")

        make_band_row("Mid (Vocals / Guitar)", 
                      "The soul of the music. 🎸 Keep this distinct from Bass.", 
                      "lbl_mid", "help_mid", "sl_mid", "chk_auto_mid")

        make_band_row("High (Cymbals / Snares)", 
                      "Sparkle and shine! ✨ Adds details to the visualization.", 
                      "lbl_high", "help_high", "sl_high", "chk_auto_high")
        
        grp_bands.setLayout(l_bands)
        layout.addWidget(grp_bands)
        
        # === DYNAMIC COLOR ZONE ===
        # This section changes based on Color Source
        self.grp_colors = QGroupBox("Colors")
        self.color_zone_layout = QVBoxLayout()
        
        # Initialize temp color storage
        self.temp_bass_color = (255, 0, 0)
        self.temp_mid_color = (0, 255, 0)
        self.temp_high_color = (0, 0, 255)
        self.temp_fixed_color = (255, 0, 255)
        
        # Create color buttons (will be shown/hidden dynamically)
        # Spectrum Mode: 3 buttons
        self.spectrum_color_widget = QWidget()
        h_spectrum = QHBoxLayout(self.spectrum_color_widget)
        h_spectrum.setContentsMargins(0, 0, 0, 0)
        
        self.btn_bass_color = QPushButton("Bass")
        self.btn_bass_color.setFixedSize(80, 30)
        self.btn_bass_color.clicked.connect(self._pick_color_bass)
        h_spectrum.addWidget(self.btn_bass_color)
        
        self.btn_mid_color = QPushButton("Mid")
        self.btn_mid_color.setFixedSize(80, 30)
        self.btn_mid_color.clicked.connect(self._pick_color_mid)
        h_spectrum.addWidget(self.btn_mid_color)
        
        self.btn_high_color = QPushButton("High")
        self.btn_high_color.setFixedSize(80, 30)
        self.btn_high_color.clicked.connect(self._pick_color_high)
        h_spectrum.addWidget(self.btn_high_color)
        h_spectrum.addStretch()
        
        # Fixed Mode: 1 button
        self.fixed_color_widget = QWidget()
        h_fixed = QHBoxLayout(self.fixed_color_widget)
        h_fixed.setContentsMargins(0, 0, 0, 0)
        
        self.btn_fixed_color = QPushButton("Main Color")
        self.btn_fixed_color.setFixedSize(120, 40)
        self.btn_fixed_color.clicked.connect(self._pick_color_fixed)
        h_fixed.addWidget(self.btn_fixed_color)
        h_fixed.addStretch()
        
        # Monitor Mode: Info label
        self.monitor_color_widget = QWidget()
        h_monitor = QHBoxLayout(self.monitor_color_widget)
        h_monitor.setContentsMargins(0, 0, 0, 0)
        
        lbl_monitor_info = QLabel("ℹ️ Colors are automatically detected from your screen content.")
        lbl_monitor_info.setWordWrap(True)
        lbl_monitor_info.setStyleSheet("color: #888; font-style: italic;")
        h_monitor.addWidget(lbl_monitor_info)
        
        # Add all widgets to color zone (will show/hide based on source)
        self.color_zone_layout.addWidget(self.spectrum_color_widget)
        self.color_zone_layout.addWidget(self.fixed_color_widget)
        self.color_zone_layout.addWidget(self.monitor_color_widget)
        
        self.grp_colors.setLayout(self.color_zone_layout)
        layout.addWidget(self.grp_colors)
        
        # Color Source
        grp_col = QGroupBox("Visualization Style")
        l_col = QVBoxLayout()
        
        # Source
        h_src = QHBoxLayout()
        h_src.addWidget(QLabel("Color Source:"))
        h_src.addWidget(self.create_help_label("Where do the colors come from?\n\n• Spectrum: Uses your custom Bass/Mid/High colors.\n• Monitor: Uses colors from your screen (pulsing to music).\n• Fixed: Uses one single color for everything."))
        h_src.addStretch()
        l_col.addLayout(h_src)
        
        self.cb_music_color = QComboBox()
        self.cb_music_color.addItems(["spectrum", "fixed", "monitor"])
        self.cb_music_color.currentTextChanged.connect(self._update_color_zone)
        l_col.addWidget(self.cb_music_color)
        
        # Effect
        h_eff = QHBoxLayout()
        h_eff.addWidget(QLabel("Effect Type:"))
        h_eff.addWidget(self.create_help_label("How the lights move:\n\n• Energy: Whole strip pulses together.\n• Spectrum: Zones (Bass=Bottom, Mid=Top...)\n• VuMeter: Expands from center.\n• Strobe: Flashes White on drops."))
        h_eff.addStretch()
        l_col.addLayout(h_eff)
        
        # Effect dropdown with info button
        h_effect_row = QHBoxLayout()
        self.cb_music_effect = QComboBox()
        self.cb_music_effect.addItems(["energy", "pulse", "spectrum", "spectrum_rotate", "spectrum_punchy", "reactive_bass", "vumeter", "vumeter_spectrum", "strobe", "melody_smart"])
        self.cb_music_effect.currentTextChanged.connect(self._update_dynamic_music_ui)
        h_effect_row.addWidget(self.cb_music_effect)
        
        # Info button for Melody Smart
        btn_melody_info = QPushButton("ℹ️")
        btn_melody_info.setMaximumWidth(40)
        btn_melody_info.setToolTip("Show info about Melody Smart effect")
        btn_melody_info.clicked.connect(self._show_melody_smart_info)
        h_effect_row.addWidget(btn_melody_info)
        
        l_col.addLayout(h_effect_row)
        
        grp_col.setLayout(l_col)
        layout.addWidget(grp_col)
        
        layout.addStretch()
        
        scroll = self._make_scrollable(layout)
        main_layout = QVBoxLayout(self.tab_music)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addWidget(scroll)
        
        # Trigger initial updates
        self._update_color_zone(self.cb_music_color.currentText())
        self._update_dynamic_music_ui(self.cb_music_effect.currentText())
        
    def _update_dynamic_music_ui(self, effect):
        """Updates UI labels and visibility based on selected effect"""
        # Trigger Preview for instant feedback
        if hasattr(self, '_trigger_preview'):
            self._trigger_preview()
            
        map_ui = {
            "bass": {"label": "Bass (Low Freq / Kick)", "help": "Control Bass reaction strength.", "viz": True},
            "mid":  {"label": "Mid (Vocals / Guitar)", "help": "Control Mid reaction strength.", "viz": True},
            "high": {"label": "High (Cymbals / Snares)", "help": "Control High reaction strength.", "viz": True}
        }
        
        if effect == "strobe":
            map_ui["bass"] = {"label": "Trigger Sensitivity", "help": "Lower = Flashes more easily. Higher = Only hard hits.", "viz": True}
            map_ui["mid"]  = {"label": "Max Speed (Cooldown)", "help": "Higher = Faster strobing allowed.", "viz": True}
            map_ui["high"] = {"label": "Flash Duration", "help": "Higher = Shorter, excessive flash. Lower = Longer fade out.", "viz": True}
            
            # Hide rotation
            self.lbl_rot.setVisible(False)
            self.sl_rot.setVisible(False)
            self.lbl_rot_val.setVisible(False)
            
        elif effect == "energy":
            # Energy is master pulse
            map_ui["bass"] = {"label": "Bass Influence", "help": "How much the Kick affects the color mix.", "viz": True}
            map_ui["mid"]  = {"label": "Mid Influence", "help": "How much Vocals affect the color mix.", "viz": True}
            map_ui["high"] = {"label": "High Influence", "help": "How much Cymbals affect the color mix.", "viz": True}
            
        elif effect == "pulse":
            # Aggressive Volume Pulse
            map_ui["bass"] = {"label": "Sensitivity", "help": "Gain multiplier for volume.", "viz": True}
            map_ui["mid"]  = {"label": "Aggression", "help": "Higher = Snappier pulse (Higher Gamma).", "viz": True}
            map_ui["high"] = {"label": "Min Brightness", "help": "Floor brightness.", "viz": True}
            
        elif effect == "spectrum_punchy":
            map_ui["bass"] = {"label": "Bass Punch", "help": "Exponential Bass boost.", "viz": True}
            map_ui["mid"]  = {"label": "Mid Presence", "help": "Mid range intensity.", "viz": True}
            map_ui["high"] = {"label": "High Clarity", "help": "High range intensity.", "viz": True}
            
        elif effect == "reactive_bass":
            map_ui["bass"] = {"label": "Shockwave Intensity", "help": "Size and brightness of the bass shockwave.", "viz": True}
            map_ui["mid"]  = {"label": "Damping factor", "help": "Reduces effect on non-bass segments.", "viz": True}
            map_ui["high"] = {"label": "Floor Brightness", "help": "Minimum light level.", "viz": True}

        elif "vumeter" in effect:
            map_ui["bass"] = {"label": "Input Sensitivity", "help": "Adjusts how easily the bar fills up.", "viz": True}
            map_ui["mid"]  = {"label": "Smoothness", "help": "Higher = Slower bar movement.", "viz": True}
            map_ui["high"] = {"label": "Peak Decay", "help": "How fast the peak dot falls back.", "viz": True}
            
        elif effect == "spectrum_rotate":
             # Spectrum Rotate - Show Rotation Controls
             self.lbl_rot.setVisible(True)
             self.sl_rot.setVisible(True)
             self.lbl_rot_val.setVisible(True)
             
        # Normalize Rotation Visibility for non-rotate modes
        if "rotate" not in effect:
            self.lbl_rot.setVisible(False)
            self.sl_rot.setVisible(False)
            self.lbl_rot_val.setVisible(False)
            
        # Apply
        def apply(p_name, cfg):
            getattr(self, f"lbl_{p_name}").setText(cfg["label"])
            getattr(self, f"help_{p_name}").setToolTip(cfg["help"])
            
            viz = cfg["viz"]
            getattr(self, f"lbl_{p_name}").setVisible(viz)
            getattr(self, f"help_{p_name}").setVisible(viz)
            getattr(self, f"sl_{p_name}").setVisible(viz)

        apply("bass", map_ui["bass"])
        apply("mid", map_ui["mid"])
        apply("high", map_ui["high"])
    
    def _update_color_zone(self, source):
        """Show/hide color widgets based on selected color source"""
        # Hide all first
        self.spectrum_color_widget.setVisible(False)
        self.fixed_color_widget.setVisible(False)
        self.monitor_color_widget.setVisible(False)
        
        # Show appropriate widget
        if source == "spectrum":
            self.spectrum_color_widget.setVisible(True)
        elif source == "fixed":
            self.fixed_color_widget.setVisible(True)
        elif source == "monitor":
            self.monitor_color_widget.setVisible(True)
        
        # Trigger preview update
        if hasattr(self, '_trigger_preview'):
            self._trigger_preview()

    def _apply_screen_preset(self):
        txt = self.cb_screen_preset.currentText()
        self._check_preset_buttons("screen")
        
        if "Custom" in txt: return
        
        self.applying_preset = True # LOCK
        try:
            if "(User)" in txt:
                name = txt.replace(" (User)", "")
                if name in self.config.user_screen_presets:
                    p = self.config.user_screen_presets[name]
                    self.sl_sat.setValue(int(p["saturation_boost"] * 10))
                    self.sl_black.setValue(p["min_brightness"])
                    self.sl_interp.setValue(p["interpolation_ms"])
                    self.sl_gamma.setValue(int(p.get("gamma", 1.0) * 10))
                    # Load scan area settings if present
                    if "scan_depth_percent" in p:
                        self.sl_scan_depth.setValue(p["scan_depth_percent"])
                    if "padding" in p:
                        self.sl_padding.setValue(p["padding"])
            else:
                from app_config import SCREEN_PRESETS
                key = txt.split(' ')[0]
                if key in SCREEN_PRESETS:
                    p = SCREEN_PRESETS[key]
                    self.sl_sat.setValue(int(p["saturation_boost"] * 10))
                    self.sl_black.setValue(p["min_brightness"])
                    self.sl_interp.setValue(p["interpolation_ms"])
                    self.sl_gamma.setValue(int(p.get("gamma", 1.0) * 10))
                    # Load scan area settings if present (backward compat)
                    if "scan_depth_percent" in p:
                        self.sl_scan_depth.setValue(p["scan_depth_percent"])
                    if "padding" in p:
                        self.sl_padding.setValue(p["padding"])
        finally:
            self.applying_preset = False # UNLOCK

    def _apply_music_preset(self):
        txt = self.cb_music_preset.currentText()
        self._check_preset_buttons("music")
        
        if "Custom" in txt: return
        
        self.applying_preset = True # LOCK
        try:
            if "(User)" in txt:
                name = txt.replace(" (User)", "")
                if name in self.config.user_music_presets:
                    p = self.config.user_music_presets[name]
                    self.sl_bass.setValue(p["bass_sensitivity"])
                    self.sl_mid.setValue(p["mid_sensitivity"])
                    self.sl_high.setValue(p["high_sensitivity"])
            else:
                from app_config import MUSIC_PRESETS
                key = txt.split(' ')[0]
                if "Bass" in txt: key = "Bass Focus"
                
                if key in MUSIC_PRESETS:
                    p = MUSIC_PRESETS[key]
                    self.sl_bass.setValue(p["bass_sensitivity"])
                    self.sl_mid.setValue(p["mid_sensitivity"])
                    self.sl_high.setValue(p["high_sensitivity"])
        finally:
            self.applying_preset = False # UNLOCK
            
    def _on_screen_val_change(self, _):
        if not self.applying_preset:
            self.cb_screen_preset.blockSignals(True)
            self.cb_screen_preset.setCurrentIndex(0) # Assume 0 is Custom
            self.cb_screen_preset.blockSignals(False)

    def _on_music_val_change(self, _):
        if not self.applying_preset:
            self.cb_music_preset.blockSignals(True)
            self.cb_music_preset.setCurrentIndex(0) # Assume 0 is Custom
            self.cb_music_preset.blockSignals(False)

        


    def _apply_scroll_safety(self):
        """Disable scroll wheel on inputs unless focused"""
        self.scroll_filter = NoScrollFilter(self)
        # Apply to all ComboBoxes and Sliders
        for widget in self.findChildren(QComboBox):
            widget.installEventFilter(self.scroll_filter)
            widget.setFocusPolicy(Qt.FocusPolicy.StrongFocus) # Ensure they can get focus to scroll
            
        for widget in self.findChildren(QSlider):
            widget.installEventFilter(self.scroll_filter)

    def _load_from_config(self, cfg: AppConfig):
        try:
            # Global
            # Serial Port is now managed in Devices Tab. Legacy field is ignored or updated via syncing.
            
            if hasattr(self, 'cb_start_mode'):
                idx = self.cb_start_mode.findText(cfg.global_settings.start_mode)
                if idx >= 0: self.cb_start_mode.setCurrentIndex(idx)
            
            if hasattr(self, 'cb_autostart'):
                self.cb_autostart.setChecked(cfg.global_settings.autostart)
            self.cb_theme.setCurrentText(cfg.global_settings.theme)
            # Advanced
            idx_cap = self.cb_capture.findData(cfg.global_settings.capture_method)
            if idx_cap >= 0: self.cb_capture.setCurrentIndex(idx_cap)
            self.chk_hotkeys.setChecked(cfg.global_settings.hotkeys_enabled)
            self.txt_hotkey.setText(cfg.global_settings.hotkey_toggle)
            print("DEBUG: Global Loaded")
            
            # Light
            print(f"DEBUG LOAD: Light Effect: '{cfg.light_mode.effect}'")
            self.sl_light_bright.setValue(cfg.light_mode.brightness)
            self.stored_light_color = cfg.light_mode.color
            self._update_color_preview(cfg.light_mode.color)
            self.cb_effect.setCurrentText(cfg.light_mode.effect)
            self.sl_speed.setValue(cfg.light_mode.speed)
            print("DEBUG: Light Loaded")
            
            # Screen
            self.temp_calibration_points = cfg.screen_mode.calibration_points
            
            # Load Scan Mode and configure UI
            scan_mode = getattr(cfg.screen_mode, 'scan_mode', 'simple')
            if scan_mode == "advanced":
                self.btn_mode_advanced.setChecked(True)
                self.btn_mode_simple.setChecked(False)
                self.simple_scan_container.setVisible(False)
                self.advanced_scan_container.setVisible(True)
                
                # Load per-edge scan depth values
                self.sl_scan_depth_top.setValue(getattr(cfg.screen_mode, 'scan_depth_top', 15))
                self.sl_scan_depth_bottom.setValue(getattr(cfg.screen_mode, 'scan_depth_bottom', 15))
                self.sl_scan_depth_left.setValue(getattr(cfg.screen_mode, 'scan_depth_left', 15))
                self.sl_scan_depth_right.setValue(getattr(cfg.screen_mode, 'scan_depth_right', 15))
                
                # Load per-edge padding values
                self.sl_padding_top.setValue(getattr(cfg.screen_mode, 'padding_top', 0))
                self.sl_padding_bottom.setValue(getattr(cfg.screen_mode, 'padding_bottom', 0))
                self.sl_padding_left.setValue(getattr(cfg.screen_mode, 'padding_left', 0))
                self.sl_padding_right.setValue(getattr(cfg.screen_mode, 'padding_right', 0))
            else:
                self.btn_mode_simple.setChecked(True)
                self.btn_mode_advanced.setChecked(False)
                self.simple_scan_container.setVisible(True)
                self.advanced_scan_container.setVisible(False)
                
                # Load simple scan depth value
                self.sl_scan_depth.setValue(cfg.screen_mode.scan_depth_percent)
                
                # Load simple padding value
                self.sl_padding.setValue(cfg.screen_mode.padding_percent)
            
            # Color Sampling (with fallback for old configs)
            color_sampling = getattr(cfg.screen_mode, 'color_sampling', 'median')
            sampling_idx = self.cb_color_sampling.findText(color_sampling)
            if sampling_idx >= 0:
                self.cb_color_sampling.setCurrentIndex(sampling_idx)
            
            self.sl_sat.setValue(int(cfg.screen_mode.saturation_boost * 10))
            self.sl_black.setValue(cfg.screen_mode.min_brightness)
            self.sl_interp.setValue(cfg.screen_mode.interpolation_ms)
            self.sl_gamma.setValue(int(cfg.screen_mode.gamma * 10))
            
            # Ultra Saturation - Load
            if hasattr(cfg.screen_mode, 'ultra_saturation'):
                self.chk_ultra_sat.setChecked(cfg.screen_mode.ultra_saturation)
                self._on_ultra_sat_toggle(cfg.screen_mode.ultra_saturation)
            
            # Preset
            self._populate_screen_presets()
            idx = self.cb_screen_preset.findText(cfg.screen_mode.active_preset)
            if idx >= 0: self.cb_screen_preset.setCurrentIndex(idx)
            print("DEBUG: Screen Loaded")
            
            # Monitor
            idx_mon = self.cb_monitor.findData(cfg.screen_mode.monitor_index)
            if idx_mon >= 0: self.cb_monitor.setCurrentIndex(idx_mon)
            print("DEBUG: Monitor Loaded")
            
            # Update Labels
            self.lbl_scan_depth.setText(f"{cfg.screen_mode.scan_depth_percent}%")
            self.lbl_padding.setText(f"{cfg.screen_mode.padding_percent}%")
            self.lbl_sat.setText(f"{cfg.screen_mode.saturation_boost}x")
            self.lbl_black.setText(f"{cfg.screen_mode.min_brightness}")
            self.lbl_interp.setText(f"{cfg.screen_mode.interpolation_ms}ms")
            self.lbl_gamma.setText(f"{cfg.screen_mode.gamma}")
            
            # Music - Devices
            self.cb_audio_device.clear()
            self.cb_audio_device.addItem("Auto-Detect Loopback", None)
            idx_to_select = 0
            for i, dev in enumerate(self.audio_devices):
                name = dev['name']
                if len(name) > 40: name = name[:37] + "..."
                self.cb_audio_device.addItem(f"{dev['index']}: {name}", dev['index'])
                if dev['index'] == cfg.music_mode.audio_device_index:
                    idx_to_select = i + 1
            self.cb_audio_device.setCurrentIndex(idx_to_select)
            
            self.sl_bass.setValue(getattr(cfg.music_mode, 'bass_sensitivity', 50))
            self.sl_mid.setValue(getattr(cfg.music_mode, 'mid_sensitivity', 50))
            self.sl_high.setValue(getattr(cfg.music_mode, 'high_sensitivity', 50))
            self.sl_music_min_bright.setValue(getattr(cfg.music_mode, 'min_brightness', 0))
            self.sl_rot.setValue(getattr(cfg.music_mode, 'rotation_speed', 20))
            
            # Load Global Sensitivity
            gs_val = getattr(cfg.music_mode, 'global_sensitivity', 50)
            self.sl_global_sens.setValue(gs_val)
            # Label update handles itself via signal
            
            # Colors (Map to 7-band structure)
            self.temp_bass_color = cfg.music_mode.bass_color
            self.temp_mid_color = cfg.music_mode.mid_color
            self.temp_high_color = cfg.music_mode.presence_color  # Map High -> Presence
            self.temp_fixed_color = getattr(cfg.music_mode, 'fixed_color', (255, 0, 255))
            
            self._update_color_btn(self.btn_bass_color, self.temp_bass_color)
            self._update_color_btn(self.btn_mid_color, self.temp_mid_color)
            self._update_color_btn(self.btn_high_color, self.temp_high_color)
            self._update_color_btn(self.btn_fixed_color, self.temp_fixed_color)
            
            self.cb_music_color.setCurrentText(cfg.music_mode.color_source)
            self.cb_music_effect.setCurrentText(cfg.music_mode.effect)
            if hasattr(self, 'chk_auto_bass'):
                self.chk_auto_bass.setChecked(self.config.music_mode.auto_gain) # Feature: AGC
            if hasattr(self, 'chk_auto_mid'):
                self.chk_auto_mid.setChecked(self.config.music_mode.auto_mid)
            if hasattr(self, 'chk_auto_high'):
                self.chk_auto_high.setChecked(self.config.music_mode.auto_high)
            # Preset
            self._populate_music_presets()
            idx = self.cb_music_preset.findText(cfg.music_mode.active_preset)
            if idx >= 0: self.cb_music_preset.setCurrentIndex(idx)
            print("DEBUG: Music Loaded")

        except Exception as e:
            print(f"!!! CRITICAL UI LOAD ERROR: {e}")
            import traceback
            traceback.print_exc()

    def _update_color_preview(self, color_tuple):
        r, g, b = color_tuple
        self.lbl_color_preview.setStyleSheet(f"background-color: rgb({r},{g},{b}); border: 1px solid #555; border-radius: 4px;")

    def _pick_color_light(self):
        d = QColorDialog(self)
        d.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, False)
        # Handle current color
        c = self.stored_light_color
        d.setCurrentColor(QColor(c[0], c[1], c[2]))
        
        d.currentColorChanged.connect(self._on_live_color_change)
        
        # Blocking Exec
        if d.exec():
            c = d.selectedColor()
            self.stored_light_color = (c.red(), c.green(), c.blue())
            self._update_color_preview(self.stored_light_color)
            
        # Clear preview when done
        self.preview_color_signal.emit(0, 0, 0, 0)
            
    def _on_live_color_change(self, color):
        # Send with long duration (e.g. 5000 ticks) so it stays while valid
        self.preview_color_signal.emit(color.red(), color.green(), color.blue(), 5000)
    
    def _pick_color_fixed(self):
        """Pick the fixed color for Fixed mode"""
        self.temp_fixed_color = self._pick_color_generic(self.temp_fixed_color)
        self._update_color_btn(self.btn_fixed_color, self.temp_fixed_color)

    def _pick_color_generic(self, current_color):
        d = QColorDialog(self)
        d.setOption(QColorDialog.ColorDialogOption.ShowAlphaChannel, False)
        c = current_color
        d.setCurrentColor(QColor(c[0], c[1], c[2]))
        
        # Live Preview
        d.currentColorChanged.connect(self._on_live_color_change)
        
        if d.exec():
            c = d.selectedColor()
            # Clear preview
            self.preview_color_signal.emit(0, 0, 0, 0)
            return (c.red(), c.green(), c.blue())
            
        self.preview_color_signal.emit(0, 0, 0, 0)
        return current_color

    def _on_theme_change(self, theme):
        from PyQt6.QtWidgets import QApplication
        app = QApplication.instance()
        # Update Global app theme
        if app:
            app.setStyleSheet(get_theme(theme))
        
        # Update Dialog's own theme (since it was set in __init__)
        self.setStyleSheet(get_theme(theme))
        
        print(f"DEBUG: Theme selected: {theme}")
        self.config.global_settings.theme = theme
    
    def _on_ultra_sat_toggle(self, checked):
        """Toggle ultra saturation mode - changes slider range dynamically"""
        if checked:
            # Ultra mode: 1.0x to 100.0x (EXTREME boost)
            current_val = self.sl_sat.value()
            self.sl_sat.setRange(10, 1000)  # 1.0 to 100.0
            # Keep current value if possible
            if current_val <= 1000:
                self.sl_sat.setValue(current_val)
            else:
                self.sl_sat.setValue(50)  # Default to 5.0x
            self.config.screen_mode.ultra_saturation = True
        else:
            # Normal mode: 1.0x to 5.0x
            current_val = self.sl_sat.value()
            self.sl_sat.setRange(10, 50)  # 1.0 to 5.0
            # Clamp value to new range
            if current_val > 50:
                self.sl_sat.setValue(50)
            self.config.screen_mode.ultra_saturation = False
        
        print(f"DEBUG: Ultra Saturation {'enabled' if checked else 'disabled'}, slider range: {self.sl_sat.minimum()}-{self.sl_sat.maximum()}")
    
    def _on_autostart_change(self, checked):
        if checked: enable_autostart()
        else: disable_autostart()

    # ... (rest of methods)

    def _build_config_from_ui(self):
        """Constructs a Config object from current UI state (without saving)"""
        new_cfg = copy.deepcopy(self.original_config)
        
        # Global
        if hasattr(self, 'cb_start_mode'):
            new_cfg.global_settings.start_mode = self.cb_start_mode.currentText()
        new_cfg.global_settings.theme = self.cb_theme.currentData()
        new_cfg.global_settings.autostart = self.cb_autostart.isChecked()
        
        # Advanced
        new_cfg.global_settings.capture_method = self.cb_capture.currentData()
        new_cfg.global_settings.hotkeys_enabled = self.chk_hotkeys.isChecked()
        
        # Save Hotkeys (Handle <None>)
        def clean_hk(txt): return "" if txt == "<None>" else txt
        
        new_cfg.global_settings.hotkey_toggle = clean_hk(self.txt_hotkey.text())
        new_cfg.global_settings.hotkey_mode_light = clean_hk(self.btn_hk_light.text())
        new_cfg.global_settings.hotkey_mode_screen = clean_hk(self.btn_hk_screen.text())
        new_cfg.global_settings.hotkey_mode_music = clean_hk(self.btn_hk_music.text())

        # Custom Hotkeys
        custom_saved = []
        if hasattr(self, 'hk_widgets'):
            for cb, btn in self.hk_widgets:
                key_txt = clean_hk(btn.text())
                if key_txt:
                    custom_saved.append({
                        "action": cb.currentData(),
                        "payload": None,
                        "key": key_txt
                    })
        new_cfg.global_settings.custom_hotkeys = custom_saved

        # Auto-Switch Mode logic (Active Tab determines start mode if saved)
        # Note: For Preview, we might want to respect active tab?
        curr_tab = self.tabs.currentWidget()
        if curr_tab == self.tab_light:
            new_cfg.global_settings.start_mode = "light"
        elif curr_tab == self.tab_screen:
            new_cfg.global_settings.start_mode = "screen"
        elif curr_tab == self.tab_music:
            new_cfg.global_settings.start_mode = "music"
        elif curr_tab == self.tab_pchealth:
            new_cfg.global_settings.start_mode = "pchealth"
        
        # Light
        new_cfg.light_mode.brightness = self.sl_light_bright.value()
        new_cfg.light_mode.color = self.stored_light_color
        new_cfg.light_mode.effect = self.cb_effect.currentText()
        new_cfg.light_mode.speed = self.sl_speed.value()
        
        # Screen
        new_cfg.screen_mode.calibration_points = self.temp_calibration_points
        
        # Scan Mode, Depth, and Padding
        if self.btn_mode_simple.isChecked():
            new_cfg.screen_mode.scan_mode = "simple"
            
            # Scan Depth
            depth_val = self.sl_scan_depth.value()
            new_cfg.screen_mode.scan_depth_percent = depth_val
            new_cfg.screen_mode.scan_depth_top = depth_val
            new_cfg.screen_mode.scan_depth_bottom = depth_val
            new_cfg.screen_mode.scan_depth_left = depth_val
            new_cfg.screen_mode.scan_depth_right = depth_val
            
            # Padding
            pad_val = self.sl_padding.value()
            new_cfg.screen_mode.padding_percent = pad_val
            new_cfg.screen_mode.padding_top = pad_val
            new_cfg.screen_mode.padding_bottom = pad_val
            new_cfg.screen_mode.padding_left = pad_val
            new_cfg.screen_mode.padding_right = pad_val
        else:
            new_cfg.screen_mode.scan_mode = "advanced"
            
            # Per-edge Scan Depth
            new_cfg.screen_mode.scan_depth_top = self.sl_scan_depth_top.value()
            new_cfg.screen_mode.scan_depth_bottom = self.sl_scan_depth_bottom.value()
            new_cfg.screen_mode.scan_depth_left = self.sl_scan_depth_left.value()
            new_cfg.screen_mode.scan_depth_right = self.sl_scan_depth_right.value()
            # Keep scan_depth_percent for backward compat (use average)
            new_cfg.screen_mode.scan_depth_percent = int((
                new_cfg.screen_mode.scan_depth_top + 
                new_cfg.screen_mode.scan_depth_bottom + 
                new_cfg.screen_mode.scan_depth_left + 
                new_cfg.screen_mode.scan_depth_right
            ) / 4)
            
            # Per-edge Padding
            new_cfg.screen_mode.padding_top = self.sl_padding_top.value()
            new_cfg.screen_mode.padding_bottom = self.sl_padding_bottom.value()
            new_cfg.screen_mode.padding_left = self.sl_padding_left.value()
            new_cfg.screen_mode.padding_right = self.sl_padding_right.value()
            # Keep padding_percent for backward compat (use average)
            new_cfg.screen_mode.padding_percent = int((
                new_cfg.screen_mode.padding_top + 
                new_cfg.screen_mode.padding_bottom + 
                new_cfg.screen_mode.padding_left + 
                new_cfg.screen_mode.padding_right
            ) / 4)
        
        new_cfg.screen_mode.color_sampling = self.cb_color_sampling.currentText()
        new_cfg.screen_mode.saturation_boost = self.sl_sat.value() / 10.0
        new_cfg.screen_mode.min_brightness = self.sl_black.value()
        new_cfg.screen_mode.interpolation_ms = self.sl_interp.value()
        new_cfg.screen_mode.gamma = self.sl_gamma.value() / 10.0
        
        # Monitor
        mon_idx = self.cb_monitor.currentData()
        if mon_idx is None: mon_idx = 1
        new_cfg.screen_mode.monitor_index = mon_idx
        
        # PROPAGATE TO SEGMENTS (Fix for Live Preview)
        # We assume if user changes global monitor, they want all segments on that monitor
        # unless we support multi-monitor configuration in wizard (future).
        if new_cfg.screen_mode.segments:
            for seg in new_cfg.screen_mode.segments:
                seg.monitor_idx = mon_idx # API uses 0-based, UI uses 1-based usually? 
                # Wait, capture.py: target_mss_idx = mon_idx + 1
                # UI cb_monitor data is typically 0, 1, 2... representing index in self.monitors list.
                # CaptureThread logic: `mon_idx` key in `_cached_map`.
                # `mid = getattr(seg, 'monitor_idx', 0)`
                # Then `for mon_idx, segs in ...`
                # And `target_mss_idx = mon_idx + 1`.
                # So if I set seg.monitor_idx = 0, it captures Monitor 1.
                # If I set seg.monitor_idx = 1, it captures Monitor 2.
                # My UI cb_monitor.currentData() returns the index (0, 1...).
                # So direct assignment is correct.
                seg.monitor_idx = mon_idx
        
        # Presets
        new_cfg.screen_mode.active_preset = self.cb_screen_preset.currentText()
        new_cfg.music_mode.active_preset = self.cb_music_preset.currentText()
        
        # Music
        new_cfg.music_mode.audio_device_index = self.cb_audio_device.currentData()
        new_cfg.music_mode.bass_sensitivity = self.sl_bass.value()
        new_cfg.music_mode.mid_sensitivity = self.sl_mid.value()
        new_cfg.music_mode.high_sensitivity = self.sl_high.value()
        new_cfg.music_mode.min_brightness = self.sl_music_min_bright.value()
        new_cfg.music_mode.rotation_speed = self.sl_rot.value()
        new_cfg.music_mode.global_sensitivity = self.sl_global_sens.value()
        
        # Colors
        new_cfg.music_mode.bass_color = self.temp_bass_color
        new_cfg.music_mode.mid_color = self.temp_mid_color
        new_cfg.music_mode.presence_color = self.temp_high_color
        new_cfg.music_mode.fixed_color = self.temp_fixed_color
        
        new_cfg.music_mode.color_source = self.cb_music_color.currentText()
        new_cfg.music_mode.effect = self.cb_music_effect.currentText()
        
        if hasattr(self, 'chk_agc'):
            new_cfg.music_mode.auto_gain = self.chk_agc.isChecked()
        
        # PC Health
        if hasattr(self, 'sl_pc_update'):
            new_cfg.pc_health.update_rate = self.sl_pc_update.value()
            
        # Metrics
        if hasattr(self, 'metric_editor'):
            new_cfg.pc_health.metrics = self.metric_editor.metrics
            
        return new_cfg

    def _trigger_preview(self):
        """Send current UI state as a preview configuration"""
        # Rate limit preview updates? (Not strictly needed for local UI but good practice)
        try:
            cfg = self._build_config_from_ui()
            self.settings_preview.emit(cfg)
        except Exception as e:
            print(f"Preview Error: {e}")

    def _on_save(self):
        new_cfg = self._build_config_from_ui()
        
        print("DEBUG: Emitting settings_changed signal...")
        try:
            self.settings_changed.emit(new_cfg)
            print("DEBUG: Signal emitted.")
            
            # Force Theme Update (Just in case)
            self._on_theme_change(new_cfg.global_settings.theme)
            
            # Visual Feedback
            orig_style = self.btn_save.styleSheet()
            self.btn_save.setStyleSheet("background-color: #30D158; color: white; border: 1px solid #28a745; font-weight: bold;")
            self.btn_save.setText("Saved! ✓")
            QTimer.singleShot(1000, lambda: (self.btn_save.setStyleSheet(""), self.btn_save.setText("Save & Apply")))
            
            # Auto-Hide Overlay if open
            if hasattr(self, 'btn_preview_scan') and self.btn_preview_scan.isChecked():
                 self.btn_preview_scan.setChecked(False)
                 self._toggle_scan_preview(False)
            
        except Exception as e:
            print(f"ERROR Saving: {e}")
            import traceback
            traceback.print_exc()

    def _start_calibration(self):
        # Determine target monitor
        target_idx = 0
        current_val = self.cb_monitor.currentData()
        if isinstance(current_val, int):
             # MSS starts at 1, Qt starts at 0
             target_idx = max(0, current_val - 1)
        
        self.calib_win = CalibrationOverlay(monitor_idx=target_idx)
        self.calib_win.finished.connect(self._on_calib_finished)
        self.calib_win.cancelled.connect(self._on_calib_cancelled)
        self.calib_win.light_led_request.connect(self._on_calib_led_req)
        
        self.hide() # Hide this dialog to allow interaction with fullscreen overlay
        self.calib_win.start()

    def _on_calib_led_req(self, corner_name):
        self.calibration_led_signal.emit(corner_name)

    def _on_calib_finished(self, points):
        self.show() # Restore settings dialog
        self.temp_calibration_points = points
        self.calibration_led_signal.emit("off")
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.information(self, "Calibration", "Calibration points captured! Don't forget to click 'Save Settings' to apply.")

    def _on_calib_cancelled(self):
        self.show() # Restore settings dialog
        self.calibration_led_signal.emit("off")

    def _reset_calibration(self):
        self.temp_calibration_points = None
        QMessageBox.information(self, "Auto Set", "Mapping reset to full screen default.\nClick 'Save Settings' to apply.")

    # --- PRESET MANAGEMENT ---

    def _populate_screen_presets(self):
        """Re-fill screen preset combo"""
        current = self.cb_screen_preset.currentText()
        self.cb_screen_preset.blockSignals(True)
        self.cb_screen_preset.clear()
        
        # Built-in
        self.cb_screen_preset.addItem("Custom")
        self.cb_screen_preset.addItems(["Movie (Vivid & Smooth)", "Gaming (Fast & Bright)", "Desktop (Neutral)"])
        
        # User
        if self.config.user_screen_presets:
            self.cb_screen_preset.insertSeparator(self.cb_screen_preset.count())
            for name in self.config.user_screen_presets.keys():
                self.cb_screen_preset.addItem(f"{name} (User)")
        
        # Restore selection
        idx = self.cb_screen_preset.findText(current)
        if idx >= 0: self.cb_screen_preset.setCurrentIndex(idx)
        else: self.cb_screen_preset.setCurrentIndex(0) # Default to Custom
            
        self.cb_screen_preset.blockSignals(False)
        self._check_preset_buttons("screen")

    def _populate_music_presets(self):
        """Re-fill music preset combo"""
        current = self.cb_music_preset.currentText()
        self.cb_music_preset.blockSignals(True)
        self.cb_music_preset.clear()
        
        # Built-in
        self.cb_music_preset.addItem("Custom")
        self.cb_music_preset.addItems(["Party (Fast & Bright)", "Chill (Smooth)", "Bass Focus", "Vocals"])
        
        # User
        if self.config.user_music_presets:
            self.cb_music_preset.insertSeparator(self.cb_music_preset.count())
            for name in self.config.user_music_presets.keys():
                self.cb_music_preset.addItem(f"{name} (User)")
                
        # Restore selection
        idx = self.cb_music_preset.findText(current)
        if idx >= 0: self.cb_music_preset.setCurrentIndex(idx)
        else: self.cb_music_preset.setCurrentIndex(0)
            
        self.cb_music_preset.blockSignals(False)
        self._check_preset_buttons("music")

    def _check_preset_buttons(self, mode):
        if mode == "screen":
            txt = self.cb_screen_preset.currentText()
            is_user = "(User)" in txt
            self.btn_del_screen_pre.setEnabled(is_user)
        elif mode == "music":
            txt = self.cb_music_preset.currentText()
            is_user = "(User)" in txt
            self.btn_del_music_pre.setEnabled(is_user)

    def _save_screen_preset(self):
        name, ok = QInputDialog.getText(self, "New Preset", "Preset Name:")
        if ok and name:
            # Capture ALL screen settings
            p = {
                "saturation_boost": self.sl_sat.value() / 10.0,
                "min_brightness": self.sl_black.value(),
                "interpolation_ms": self.sl_interp.value(),
                "gamma": self.sl_gamma.value() / 10.0,
                "scan_depth_percent": self.sl_scan_depth.value(),
                "padding": self.sl_padding.value()
            }
            self.config.user_screen_presets[name] = p
            self._populate_screen_presets()
            # Select it
            self.cb_screen_preset.setCurrentText(f"{name} (User)")
            QMessageBox.information(self, "Saved", f"Screen preset '{name}' saved.")

    def _delete_screen_preset(self):
        txt = self.cb_screen_preset.currentText()
        if "(User)" not in txt: return
        
        name = txt.replace(" (User)", "")
        if name in self.config.user_screen_presets:
            del self.config.user_screen_presets[name]
            self.config.save_to_file()
            self.app.on_settings_signal.emit()
            self._populate_screen_presets()
            QMessageBox.information(self, "Deleted", f"Preset '{name}' deleted.")

    def _save_music_preset(self):
        name, ok = QInputDialog.getText(self, "New Preset", "Preset Name:")
        if ok and name:
            p = {
                "bass_sensitivity": self.sl_bass.value(),
                "mid_sensitivity": self.sl_mid.value(),
                "high_sensitivity": self.sl_high.value()
            }
            self.config.user_music_presets[name] = p
            self._populate_music_presets()
            self.cb_music_preset.setCurrentText(f"{name} (User)")
            QMessageBox.information(self, "Saved", f"Music preset '{name}' saved.")

    def _delete_music_preset(self):
        txt = self.cb_music_preset.currentText()
        if "(User)" not in txt: return
        
        name = txt.replace(" (User)", "")
        if name in self.config.user_music_presets:
            del self.config.user_music_presets[name]
            self._populate_music_presets()
            QMessageBox.information(self, "Deleted", f"Preset '{name}' deleted.")

    # --- HOTKEY RECORDING ---

    def _create_hk_btn(self, initial_text):
        btn = QPushButton(initial_text if initial_text else "<None>")
        btn.setCheckable(True)
        btn.setToolTip("Click to record. Press 'Backspace' while recording to clear.")
        return btn

    def _add_hk_row(self, data):
        row_widget = QWidget()
        row = QHBoxLayout(row_widget)
        row.setContentsMargins(0, 2, 0, 2)
        
        cb = QComboBox()
        # Brightness
        cb.addItem("Brightness +10%", "bright_up")
        cb.addItem("Brightness -10%", "bright_down")
        cb.addItem("Brightness MAX (100%)", "bright_max")
        cb.addItem("Brightness MIN (10%)", "bright_min")
        # Power
        cb.addItem("Toggle Power On/Off", "toggle_power")
        # Modes
        cb.addItem("Switch to Music Mode", "mode_music")
        cb.addItem("Switch to Screen Mode", "mode_screen")
        cb.addItem("Switch to Light Mode", "mode_light")
        cb.addItem("Cycle Modes", "mode_next")
        # General
        cb.addItem("Cycle Effects (Current Mode)", "effect_next")
        cb.addItem("Cycle Presets (Current Mode)", "preset_next")
        cb.addItem("Recalibrate Screen (Auto)", "calib_auto")
        
        idx = cb.findData(data.get("action"))
        if idx >= 0: cb.setCurrentIndex(idx)
        
        btn = self._create_hk_btn(data.get("key"))
        btn.clicked.connect(lambda: self._start_record_hotkey(btn, btn.text()))
        
        btn_del = QPushButton("Delete")
        btn_del.setFixedWidth(60)
        btn_del.setStyleSheet("color: #ff4444; font-weight: bold;")
        btn_del.clicked.connect(lambda: self._delete_hk_row(row_widget, cb, btn))
        
        row.addWidget(cb, 2) 
        row.addWidget(btn, 2)
        row.addWidget(btn_del, 0)
        
        self.hk_container_layout.addWidget(row_widget)
        self.hk_widgets.append((cb, btn))

    def _delete_hk_row(self, widget, cb, btn):
        # Stop recording if we are deleting the active button
        if self.recording_hotkey and hasattr(self, 'active_hotkey_btn') and self.active_hotkey_btn == btn:
            self._stop_recording_hotkey(restore=True)
            
        layout = self.hk_container_layout
        layout.removeWidget(widget)
        widget.deleteLater()
        if (cb, btn) in self.hk_widgets:
            self.hk_widgets.remove((cb, btn))

    def keyPressEvent(self, event):
        if not self.recording_hotkey or not hasattr(self, 'active_hotkey_btn'):
            super().keyPressEvent(event)
            return
            
        key = event.key()
        
        # 1. Cancel on Escape
        if key == Qt.Key.Key_Escape:
            self._stop_recording_hotkey(restore=True)
            return

        # 1b. Clear on Delete/Backspace
        if key == Qt.Key.Key_Delete or key == Qt.Key.Key_Backspace:
            self.active_hotkey_btn.setText("<None>")
            self._stop_recording_hotkey(restore=False)
            return
            
        # 2. Ignore Modifier-only presses
        if key in [Qt.Key.Key_Control, Qt.Key.Key_Shift, Qt.Key.Key_Alt, Qt.Key.Key_Meta]:
            return

        # 3. Capture Full Combination
        from PyQt6.QtGui import QKeySequence
        seq = QKeySequence(event.keyCombination())
        text = seq.toString().lower()
        
        print(f"Recorded Hotkey: {text}")
        self.active_hotkey_btn.setText(text)
        self._stop_recording_hotkey(restore=False)

    def _stop_recording_hotkey(self, restore=False):
        self.recording_hotkey = False
        self.releaseKeyboard()
        
        if hasattr(self, 'active_hotkey_btn') and self.active_hotkey_btn:
            self.active_hotkey_btn.setChecked(False)
            if restore:
                self.active_hotkey_btn.setText(self.active_hotkey_backup)
            self.active_hotkey_btn = None
        self.releaseKeyboard()

    # --- NEW UI HELPERS ---

    def _make_scrollable(self, content_layout: QVBoxLayout) -> QScrollArea:
        """Wraps a layout in a smooth scroll area"""
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        # scroll.setStyleSheet("background: transparent;") # Removed for better visibility
        
        # Wrapper
        wrapper = QWidget()
        # wrapper.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground) # Removed
        wrapper.setLayout(content_layout)
        scroll.setWidget(wrapper)
        
        return scroll

    # --- VISUALIZATION HELPERS ---
    
    def _on_scan_slider_change(self):
        """Update labels and restart visualization timer"""
        if getattr(self, 'loading_config', False):
            return

        d_pct = self.sl_scan_depth.value()
        pad = self.sl_padding.value()
        
        # Update Labels
        self.lbl_scan_depth.setText(f"{d_pct}%")
        self.lbl_padding.setText(f"{pad}%")
        
        # Show/Update Overlay ONLY if preview button is checked
        if not hasattr(self, 'btn_preview_scan') or not self.btn_preview_scan.isChecked():
            return
        
        print(f"DEBUG: Updating scan overlays - Depth: {d_pct}%, Padding: {pad}%")
        
        if hasattr(self, 'scan_overlays'):
            screens = QApplication.screens()
            for i, overlay in enumerate(self.scan_overlays):
                if i < len(screens):
                    size = screens[i].size()
                    w, h = size.width(), size.height()
                    
                    if not overlay.isVisible():
                        overlay.show_regions(
                            w, h, 
                            d_pct, 
                            pad_top=pad, pad_bottom=pad, pad_left=pad, pad_right=pad
                        )
                    else:
                        overlay.update_params(depth_pct=d_pct, pad_top=pad, pad_bottom=pad, pad_left=pad, pad_right=pad)
        
        # Keep Settings dialog focused and on top
        self.raise_()
        self.activateWindow()

    def _toggle_scan_preview(self, checked):
        """Toggle scan area preview overlay on/off"""
        if checked:
            # Show overlay
            self.btn_preview_scan.setText("👁 Hide Preview")
            # Trigger slider change to show with current values
            self._on_scan_slider_change()
        else:
            # Hide overlay
            self.btn_preview_scan.setText("👁 Show Preview")
            self._hide_scan_overlay()

    def _hide_scan_overlay(self):
        """Hide scanning area overlay when slider is released"""
        print("DEBUG: Hiding scan overlays (slider released)")
        if hasattr(self, 'scan_overlays'):
            for overlay in self.scan_overlays:
                overlay.hide()
            print("DEBUG: Overlays hidden")
        else:
            print("DEBUG: No scan_overlays list")

    def _on_monitor_changed(self, index):
        """Update overlay when monitor selection changes"""
        # index matches the combo box index
        # Data item holds the actual monitor index for the backend
        mon_idx = self.cb_monitor.currentData()
        if mon_idx is None: mon_idx = 0
        
        print(f"DEBUG: Monitor changed to {mon_idx}")
        
        # 1. Update Config Immediately (Crucial for Wizards)
        self.config.screen_mode.monitor_index = mon_idx
        
        # 2. Update Calibration Overlay Target
        if hasattr(self, 'scan_overlay'):
             self.scan_overlay.monitor_idx = mon_idx

        # 3. Update Scanning Area Overlays
        # If preview is enabled, refreshing will update all overlays
        if hasattr(self, 'btn_preview_scan') and self.btn_preview_scan.isChecked():
            self._on_scan_slider_change()

    def _init_tab_auto_profile(self):
        """Auto Profile Tab"""
        layout = QVBoxLayout()
        layout.setSpacing(15)
        
        # Header
        lbl = QLabel("Auto-Profile Switching")
        lbl.setStyleSheet("font-size: 18px; font-weight: bold; color: #0A84FF;")
        layout.addWidget(lbl)
        
        # Toggles
        self.cb_auto_profile = QCheckBox("Enable Auto-Profile Switching")
        self.cb_auto_profile.setChecked(self.config.auto_profile.enabled)
        self.cb_auto_profile.toggled.connect(lambda v: setattr(self.config.auto_profile, 'enabled', v))
        self.cb_auto_profile.toggled.connect(lambda: self.settings_changed.emit(self.config))
        layout.addWidget(self.cb_auto_profile)
        
        # Detection Interval
        h_inter = QHBoxLayout()
        h_inter.addWidget(QLabel("Detection Interval (s):"))
        sb_inter = QSpinBox()
        sb_inter.setRange(1, 60)
        sb_inter.setValue(int(self.config.auto_profile.detection_interval))
        sb_inter.valueChanged.connect(lambda v: setattr(self.config.auto_profile, 'detection_interval', float(v)))
        h_inter.addWidget(sb_inter)
        layout.addLayout(h_inter)
        
        layout.addStretch()
        
        # Wrap
        scroll = self._make_scrollable(layout)
        main_layout = QVBoxLayout(self.tab_auto_profile)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addWidget(scroll)

    def _init_tab_game(self):
        """Game Profiles Tab"""
        layout = QVBoxLayout()
        layout.setSpacing(15)
        
        lbl = QLabel("Game Profiles")
        lbl.setStyleSheet("font-size: 18px; font-weight: bold; color: #FF3B30;")
        layout.addWidget(lbl)
        
        self.cb_game_mode = QCheckBox("Enable Game Detection")
        self.cb_game_mode.setChecked(self.config.game_profiles.enabled)
        self.cb_game_mode.toggled.connect(lambda v: setattr(self.config.game_profiles, 'enabled', v))
        layout.addWidget(self.cb_game_mode)
        
        layout.addStretch()
        
        scroll = self._make_scrollable(layout)
        main_layout = QVBoxLayout(self.tab_game)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addWidget(scroll)


    def _init_tab_pchealth(self):
        """PC Health Tab - Advanced Configuration"""
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Header with info button
        h_head = QHBoxLayout()
        lbl = QLabel("PC Health Monitor")
        lbl.setStyleSheet("font-size: 18px; font-weight: bold; color: #FF9500;")
        h_head.addWidget(lbl)
        
        btn_info = QPushButton("ℹ️ Info")
        btn_info.setMaximumWidth(80)
        btn_info.clicked.connect(self._show_pc_health_info)
        h_head.addWidget(btn_info)
        
        h_head.addStretch()
        layout.addLayout(h_head)
        
        info = QLabel("Map system metrics (CPU, GPU, RAM) to specific LED zones with custom color gradients.")
        info.setStyleSheet("color: #8E8E93; font-size: 12px;")
        info.setWordWrap(True)
        layout.addWidget(info)
        
        # General Settings
        grp_gen = QGroupBox("General")
        l_gen = QHBoxLayout()
        l_gen.addWidget(QLabel("Update Rate:"))
        self.sl_pc_update = QSlider(Qt.Orientation.Horizontal)
        self.sl_pc_update.setRange(100, 2000)
        self.lbl_pc_update = QLabel("500ms")
        self.sl_pc_update.valueChanged.connect(lambda v: self.lbl_pc_update.setText(f"{v}ms"))
        # Set initial value
        self.sl_pc_update.setValue(self.config.pc_health.update_rate)
        
        l_gen.addWidget(self.sl_pc_update)
        l_gen.addWidget(self.lbl_pc_update)
        grp_gen.setLayout(l_gen)
        layout.addWidget(grp_gen)
        
        # --- NEW MASTER-DETAIL EDITOR ---
        metrics_data = self.config.pc_health.metrics 
        if not metrics_data:
             metrics_data = [] # Allow empty start
             
        self.metric_editor = MetricEditorWidget(metrics_data)
        # Connect: When editor changes, update our local config object immediately (or on save)
        # We'll update on Save usually, but here we can keep a reference or update dynamic prop
        # Let's trust logic in _on_save to pull from self.metric_editor.metrics
        
        layout.addWidget(self.metric_editor)
        
        main_layout = QVBoxLayout(self.tab_pchealth)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.addLayout(layout) # Adjusted to addLayout
        
    
    # === SEGMENT TABLE METHODS ===
    
    def _populate_segment_table(self):
        """Populate segment configuration table"""
        # from PyQt6.QtWidgets import QTableWidgetItem (Moved to top)
        
        segments = self.config.screen_mode.segments
        self.tbl_segments.setRowCount(len(segments))
        
        # FIX: Disable Scrolling (Auto-Height)
        self.tbl_segments.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        total_h = 35 + (len(segments) * 32) # Header + Rows
        self.tbl_segments.setMinimumHeight(total_h)
        self.tbl_segments.setMaximumHeight(total_h)
        
        for row, seg in enumerate(segments):
            # Edge Dropdown
            cb_edge = QComboBox()
            cb_edge.addItems(["left", "right", "top", "bottom"])
            cb_edge.setCurrentText(seg.edge)
            cb_edge.currentTextChanged.connect(lambda txt, s=seg: self._on_segment_edge_change(s, txt))
            self.tbl_segments.setCellWidget(row, 0, cb_edge)
            
            # LED Range
            item_range = QTableWidgetItem(f"{seg.led_start} - {seg.led_end}")
            item_range.setFlags(item_range.flags() ^ Qt.ItemFlag.ItemIsEditable)
            self.tbl_segments.setItem(row, 1, item_range)
            
            # Monitor Dropdown
            cb_mon = QComboBox()
            if self.monitors and len(self.monitors) > 0:
                for i, mon in enumerate(self.monitors):
                    if i == 0:
                        cb_mon.addItem(f"All Screens", i)
                    else:
                        cb_mon.addItem(f"Monitor {i}", i)
                cb_mon.setCurrentIndex(seg.monitor_idx if seg.monitor_idx < len(self.monitors) else 0)
            else:
                cb_mon.addItem(f"Monitor {seg.monitor_idx}", seg.monitor_idx)
                cb_mon.setCurrentIndex(0)
            
            cb_mon.currentIndexChanged.connect(lambda idx, s=seg, cb=cb_mon: self._on_segment_monitor_change(s, cb.currentData()))
            self.tbl_segments.setCellWidget(row, 2, cb_mon)
            
            # Device Dropdown
            cb_dev = QComboBox()
            # Populate with available devices
            curr_sel_idx = 0
            dev_idx_offset = 0
            
            # "Auto" option
            cb_dev.addItem("Auto (First)", None)
            
            if self.config.global_settings.devices:
                for i, d in enumerate(self.config.global_settings.devices):
                    cb_dev.addItem(d.name, d.id)
                    if d.id == seg.device_id:
                        curr_sel_idx = i + 1 # +1 for Auto
            
            cb_dev.setCurrentIndex(curr_sel_idx)
            cb_dev.currentIndexChanged.connect(lambda idx, s=seg, cb=cb_dev: setattr(s, 'device_id', cb.currentData()))
            self.tbl_segments.setCellWidget(row, 3, cb_dev)
            
            # 4. FREQUENCY ROLE (Repl. Music Effect)
            cb_role = QComboBox()
            
            # Map Display to Code
            role_map = [
                ("Auto (Position)", "auto"),
                ("Bass (Low)", "bass"),
                ("Mid (Vocals)", "mid"),
                ("High (Treble)", "high"),
                ("All (Full)", "all")
            ]
            
            for disp, val in role_map:
                cb_role.addItem(disp, val)
                
            curr_role = getattr(seg, "role", "auto")
            idx_role = cb_role.findData(curr_role)
            if idx_role >= 0: cb_role.setCurrentIndex(idx_role)
            else: cb_role.setCurrentIndex(0)
            
            cb_role.currentIndexChanged.connect(lambda i, s=seg, cb=cb_role: setattr(s, 'role', cb.currentData()))
            
            self.tbl_segments.setCellWidget(row, 4, cb_role)

            # 5. Reverse Checkbox
            chk_rev = QCheckBox()
            # Center checkbox
            w_rev = QWidget()
            l_rev = QHBoxLayout(w_rev); l_rev.setAlignment(Qt.AlignmentFlag.AlignCenter); l_rev.setContentsMargins(0,0,0,0)
            l_rev.addWidget(chk_rev)
            
            chk_rev.setChecked(seg.reverse)
            chk_rev.toggled.connect(lambda c, s=seg: setattr(s, 'reverse', c))
            self.tbl_segments.setCellWidget(row, 5, w_rev)
            
            # 6. Pixels (Info only)
            info_px = "-"
            if hasattr(seg, 'ref_width') and seg.ref_width > 0:
                 if seg.edge in ['left', 'right']:
                     info_px = f"Y: {seg.pixel_start}-{seg.pixel_end}"
                 else:
                     info_px = f"X: {seg.pixel_start}-{seg.pixel_end}"
            item_px = QTableWidgetItem(info_px)
            item_px.setFlags(Qt.ItemFlag.ItemIsEnabled) # Read only
            self.tbl_segments.setItem(row, 6, item_px)
            
            # 7. Delete Button
            btn_del = QPushButton("X")
            btn_del.setStyleSheet("color: red; font-weight: bold;")
            btn_del.setFixedWidth(30)
            btn_del.clicked.connect(lambda _, s=seg: self._delete_segment(s))
            self.tbl_segments.setCellWidget(row, 7, btn_del)
    
    def _on_segment_reverse_toggle(self, segment, checked):
        """Toggle reverse flag for a segment"""
        segment.reverse = checked
        print(f"DEBUG: Segment {segment.edge} reverse = {checked}")
    
    def _on_segment_monitor_change(self, segment, monitor_idx):
        """Change monitor assignment for a segment"""
        segment.monitor_idx = monitor_idx
        print(f"DEBUG: Segment {segment.edge} monitor = {monitor_idx}")
    
    def _on_segment_edge_change(self, segment, new_edge):
        """Update segment edge"""
        segment.edge = new_edge
        print(f"DEBUG: Segment edge updated to {new_edge}")

    def _on_segment_device_change(self, segment, device_id):
        """Update segment device"""
        segment.device_id = device_id
        print(f"DEBUG: Segment device updated to {device_id}")

    def _delete_segment(self, segment):
        """Delete a segment from the configuration"""
        if len(self.config.screen_mode.segments) <= 1:
            QMessageBox.warning(self, "Cannot Delete", "You must have at least one segment.")
            return
        
        reply = QMessageBox.question(self, "Delete Segment", 
            "Are you sure you want to delete this segment?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        
        if reply == QMessageBox.StandardButton.Yes:
            if segment in self.config.screen_mode.segments:
                self.config.screen_mode.segments.remove(segment)
                self._populate_segment_table()
    
    def _add_segment(self):
        """Add a new segment (placeholder implementation)"""
        from app_config import LedSegment
        
        # Simple default segment
        last_led = 0
        if self.config.screen_mode.segments:
            last_led = max([s.led_end for s in self.config.screen_mode.segments]) + 1
        
        new_seg = LedSegment(
            led_start=last_led,
            led_end=last_led + 9,  # Default 10 LEDs
            edge="top",
            depth=10,
            monitor_idx=self.config.screen_mode.monitor_index, # Use currently selected monitor
            pixel_start=0,
            pixel_end=0,
            reverse=False
        )
        
        self.config.screen_mode.segments.append(new_seg)
        self._populate_segment_table()
        
        
        # Confirmation Removed as per user request
        # QMessageBox.information(self, "Segment Added", 
        #    f"New segment added with LEDs {last_led}-{last_led+9}.\\n"
        #    "Adjust properties in the table and click Save.")
    
    # === END SEGMENT TABLE METHODS ===
    
    def _run_led_wizard(self):
        """Launches the step-by-step LED setup wizard (8-Point Segment Logic)"""
        wiz = LedWizardDialog(self.config, self)
        # Connect preview signal
        wiz.preview_pixel_request.connect(self.preview_pixel_signal.emit)
        
        result = wiz.exec()
        
        # CLEAR PREVIEW (Turn off the green wizard LED)
        self.preview_pixel_signal.emit(0, 0, 0, 0)
        
        if result == QDialog.DialogCode.Accepted:
            # RETRIEVE AND SAVE WIZARD RESULTS
            if hasattr(wiz, 'result_segments'):
                segs = wiz.result_segments
                print(f"Wizard Results: {len(segs)} segments created.")
                self.config.screen_mode.segments = segs
                
                # Auto-Update Total Count
                total = sum([s.length for s in segs])
                self.config.global_settings.led_count = total
                
                # Save immediately
                self.config.save("default.json")
                
                QMessageBox.information(self, "Setup Complete", 
                    f"Geometry Saved!\n\nSegments: {len(segs)}\nTotal LEDs: {total}")
                
                # Refresh segment table to show new segments
                if hasattr(self, 'tbl_segments'):
                    self._populate_segment_table()
                
                self.settings_changed.emit(self.config)
            else:
                QMessageBox.warning(self, "Warning", "Wizard finished but no segments returned.")
        # Verify UI update (Scan depth etc might have changed)
        self.sl_scan_depth.setValue(self.config.screen_mode.scan_depth_percent)
    
    # === CALIBRATION PROFILE MANAGEMENT ===
    
    def _populate_calibration_profiles(self):
        """Populate calibration profile dropdown"""
        if not hasattr(self, 'cb_calib_profile'):
            return
        
        # Ensure calibration_profiles exists
        if not hasattr(self.config.screen_mode, 'calibration_profiles'):
            self.config.screen_mode.calibration_profiles = {}
        
        current = self.cb_calib_profile.currentText()
        
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
        elif hasattr(self.config.screen_mode, 'active_calibration_profile') and self.config.screen_mode.active_calibration_profile:
            idx = self.cb_calib_profile.findText(self.config.screen_mode.active_calibration_profile)
            if idx >= 0:
                self.cb_calib_profile.setCurrentIndex(idx)
        
        self.cb_calib_profile.blockSignals(False)
        
        # Enable/disable delete button
        if hasattr(self, 'btn_del_profile'):
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
        if not hasattr(self, 'cb_calib_profile'):
            return
        
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
    
    # === END CALIBRATION PROFILE MANAGEMENT ===
    
    def _run_color_calibration(self):
        """Launch color calibration wizard for current profile"""
        from ui.color_calibration_wizard import ColorCalibrationWizard
        
        # Get current profile name
        profile_name = self.cb_calib_profile.currentText() if hasattr(self, 'cb_calib_profile') else "Default"
        
        wizard = ColorCalibrationWizard(self.config, profile_name, self)
        
        # Connect LED control signal
        wizard.set_all_leds_signal.connect(self._set_all_leds_preview)
        
        result = wizard.exec()
        
        if result == QDialog.DialogCode.Accepted:
            # Refresh profile dropdown
            self._populate_calibration_profiles()
            
            # Select the just-calibrated profile
            idx = self.cb_calib_profile.findText(profile_name)
            if idx >= 0:
                self.cb_calib_profile.setCurrentIndex(idx)
            
            # Reload config to get new calibration
            self.settings_changed.emit(self.config)
    
    def _set_all_leds_preview(self, r, g, b):
        """Light all LEDs with specific color for calibration"""
        # Emit to parent app to light all LEDs
        self.preview_color_signal.emit(r, g, b, 999999)  # Very long duration

    def _on_light_effect_changed(self, text):
        """Show/Hide Zone Editor based on effect"""
        is_custom = (text == "custom_zones")
        self.zone_editor.setVisible(is_custom)
        # Hide standard controls if custom (Optional, but let's keep them visible for global brightness)
    
    def _show_melody_smart_info(self):
        """Show Melody Smart effect info"""
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.information(self, "Melody Smart Effect", 
            "🎵 MELODY SMART MODE\n\n"
            "Multi-band reactive visualization that splits\n"
            "the LED strip into 4 zones responding to\n"
            "different frequency ranges.\n\n"
            "LED ZONES (66 LEDs):\n"
            "  • 0-16: 🔴 BASS (60-250 Hz)\n"
            "  • 17-33: 🟠 LOW-MID (250-800 Hz)\n"
            "  • 34-50: 🟢 MID-HIGH (800-3000 Hz)\n"
            "  • 51-66: 🟣 TREBLE (3000-8000 Hz)\n\n"
            "⚡ FLASH DETECTION:\n"
            "Each zone independently flashes on onset\n"
            "detection (energy spike).\n"
            "Decay: 0.70x per frame (punchy!)\n\n"
            "💡 TIP: Works best with songs that have\n"
            "clear instrument separation!")
    
    def _show_pc_health_info(self):
        """Show PC Health monitor mode info"""
        from PyQt6.QtWidgets import QMessageBox
        QMessageBox.information(self, "PC Health Monitor",
            "💻 PC HEALTH MONITOR MODE\n\n"
            "Visualizes your PC's performance metrics\n"
            "on the LED strip as colored gradients.\n\n"
            "📊 METRICS:\n"
            "  • CPU Usage (0-100%)\n"
            "  • GPU Usage (0-100%)\n"
            "  • RAM Usage (0-100%)\n"
            "  • CPU Temperature (°C)\n"
            "  • GPU Temperature (°C)\n\n"
            "🎨 COLOR SCALES:\n"
            "  Blue → Yellow → Red (low to high)\n"
            "  Custom: Define your own 3-color gradient\n\n"
            "🔧 REFRESH RATE:\n"
            "  How often metrics update (seconds)\n"
            "  Lower = more responsive, higher CPU\n\n"
            "💡 TIP: Use 'Custom' gradient to match\n"
            "your setup's RGB theme!")
    
    # === SCAN ZONE CONFIGURATION HANDLERS ===
    
    def _on_scan_mode_toggle(self, mode):
        """Toggle between simple and advanced scan mode"""
        if mode == "simple":
            self.btn_mode_simple.setChecked(True)
            self.btn_mode_advanced.setChecked(False)
            # Show simple containers, hide advanced containers
            self.simple_scan_container.setVisible(True)
            self.advanced_scan_container.setVisible(False)
            
            # Copy average of per-edge values to simple sliders
            if hasattr(self, 'sl_scan_depth_top'):
                avg_depth = int((
                    self.sl_scan_depth_top.value() +
                    self.sl_scan_depth_bottom.value() +
                    self.sl_scan_depth_left.value() +
                    self.sl_scan_depth_right.value()
                ) / 4)
                self.sl_scan_depth.setValue(avg_depth)
                
            if hasattr(self, 'sl_padding_top'):
                avg_pad = int((
                    self.sl_padding_top.value() +
                    self.sl_padding_bottom.value() +
                    self.sl_padding_left.value() +
                    self.sl_padding_right.value()
                ) / 4)
                self.sl_padding.setValue(avg_pad)
                
        else:  # advanced
            self.btn_mode_simple.setChecked(False)
            self.btn_mode_advanced.setChecked(True)
            # Hide simple containers, show advanced containers
            self.simple_scan_container.setVisible(False)
            self.advanced_scan_container.setVisible(True)
            
            # Copy simple values to all per-edge sliders
            if hasattr(self, 'sl_scan_depth'):
                simple_depth = self.sl_scan_depth.value()
                self.sl_scan_depth_top.setValue(simple_depth)
                self.sl_scan_depth_bottom.setValue(simple_depth)
                self.sl_scan_depth_left.setValue(simple_depth)
                self.sl_scan_depth_right.setValue(simple_depth)
                
            if hasattr(self, 'sl_padding'):
                simple_pad = self.sl_padding.value()
                self.sl_padding_top.setValue(simple_pad)
                self.sl_padding_bottom.setValue(simple_pad)
                self.sl_padding_left.setValue(simple_pad)
                self.sl_padding_right.setValue(simple_pad)
        
        # Update overlay if preview is active
        if hasattr(self, 'btn_preview_scan') and self.btn_preview_scan.isChecked():
            self._on_scan_slider_change()
    
    def _on_scan_slider_change(self):
        """Update labels and restart visualization timer"""
        if getattr(self, 'loading_config', False):
            return

        # Get scan depth values based on mode
        if self.btn_mode_simple.isChecked():
            # Simple mode - use single slider value for all edges
            d_pct = self.sl_scan_depth.value()
            self.lbl_scan_depth.setText(f"{d_pct}%")
            depth_top = depth_bottom = depth_left = depth_right = d_pct
        else:
            # Advanced mode - use per-edge sliders
            depth_top = self.sl_scan_depth_top.value()
            depth_bottom = self.sl_scan_depth_bottom.value()
            depth_left = self.sl_scan_depth_left.value()
            depth_right = self.sl_scan_depth_right.value()
            
            # Update labels
            self.lbl_scan_depth_top.setText(f"{depth_top}%")
            self.lbl_scan_depth_bottom.setText(f"{depth_bottom}%")
            self.lbl_scan_depth_left.setText(f"{depth_left}%")
            self.lbl_scan_depth_right.setText(f"{depth_right}%")
        
        # Get padding values based on mode
        if self.btn_mode_simple.isChecked():
            # Simple mode - use single slider value for all edges
            pad = self.sl_padding.value()
            self.lbl_padding.setText(f"{pad}%")
            pad_top = pad_bottom = pad_left = pad_right = pad
        else:
            # Advanced mode - use per-edge sliders
            pad_top = self.sl_padding_top.value()
            pad_bottom = self.sl_padding_bottom.value()
            pad_left = self.sl_padding_left.value()
            pad_right = self.sl_padding_right.value()
            
            # Update labels
            self.lbl_padding_top.setText(f"{pad_top}%")
            self.lbl_padding_bottom.setText(f"{pad_bottom}%")
            self.lbl_padding_left.setText(f"{pad_left}%")
            self.lbl_padding_right.setText(f"{pad_right}%")
        
        # Show/Update Overlay ONLY if preview button is checked
        if not hasattr(self, 'btn_preview_scan') or not self.btn_preview_scan.isChecked():
            return
        
        print(f"DEBUG: Updating scan overlays - Depth: T{depth_top}% B{depth_bottom}% L{depth_left}% R{depth_right}%, Padding: T{pad_top}% B{pad_bottom}% L{pad_left}% R{pad_right}%")
        
        # Update all monitor overlays with per-edge depth values
        if hasattr(self, 'scan_overlays'):
            screens = QApplication.screens()
            for i, overlay in enumerate(self.scan_overlays):
                if i < len(screens):
                    size = screens[i].size()
                    w, h = size.width(), size.height()
                    
                    if not overlay.isVisible():
                        overlay.show_regions(
                            w, h, 
                            depth_top, depth_bottom, depth_left, depth_right,
                            pad_top, pad_bottom, pad_left, pad_right
                        )
                    else:
                        overlay.update_params(
                            depth_top, depth_bottom, depth_left, depth_right,
                            pad_top, pad_bottom, pad_left, pad_right
                        )
        
        # Keep Settings dialog focused and on top
        self.raise_()
        self.activateWindow()
    
    def _toggle_scan_preview(self, checked):
        """Toggle scan area preview overlay on/off"""
        if checked:
            # Show overlay
            self.btn_preview_scan.setText("👁 Hide Preview")
            # Trigger slider change to show with current values
            self._on_scan_slider_change()
        else:
            # Hide overlay
            self.btn_preview_scan.setText("👁 Show Preview")
            self._hide_scan_overlay()
    
    def _hide_scan_overlay(self):
        """Hide all scan overlays"""
        if hasattr(self, 'scan_overlays'):
            for overlay in self.scan_overlays:
                overlay.hide()
    
    def _on_monitor_changed(self, index):
        """Update overlay when monitor selection changes"""
        # index matches the combo box index
        # Data item holds the actual monitor index for the backend
        mon_idx = self.cb_monitor.currentData()
        if mon_idx is None: mon_idx = 0
        
        print(f"DEBUG: Monitor changed to {mon_idx}")
        
        # 1. Update Config Immediately (Crucial for Wizards)
        self.config.screen_mode.monitor_index = mon_idx
        
        # 2. Update Calibration Overlay Target
        if hasattr(self, 'scan_overlay'):
             self.scan_overlay.monitor_idx = mon_idx

        # 3. Update Scanning Area Overlays
        # If preview is enabled, refreshing will update all overlays
        if hasattr(self, 'btn_preview_scan') and self.btn_preview_scan.isChecked():
            self._on_scan_slider_change()

