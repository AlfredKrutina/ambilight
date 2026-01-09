# src/ui/main_window.py

from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QSystemTrayIcon, QMenu
)
from PyQt6.QtGui import QIcon, QPixmap
from PyQt6.QtCore import Qt, pyqtSignal, QTimer
from pathlib import Path


from utils import get_resource_path
class TrayIcon(QSystemTrayIcon):
    """System tray icon s kontextovým menu"""
    
    toggle_signal = pyqtSignal(bool)
    settings_signal = pyqtSignal()
    quit_signal = pyqtSignal()
    mode_signal = pyqtSignal(str)
    preset_signal = pyqtSignal(str, str) # type (screen/music), preset_name
    lock_signal = pyqtSignal(bool)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.enabled = True
        
        # Menu
        self.menu = QMenu()
        
        # 1. Toggle
        self.toggle_action = self.menu.addAction("Turn OFF")
        self.toggle_action.triggered.connect(self._on_toggle)
        
        self.menu.addSeparator()
        
        # 2. Mode Submenu
        mode_menu = self.menu.addMenu("Switch Mode")
        for m in ["light", "screen", "music", "pchealth"]:
            display_name = {
                "light": "Light",
                "screen": "Screen",
                "music": "Music",
                "pchealth": "PC Health"
            }.get(m, m.capitalize())
            a = mode_menu.addAction(display_name)
            a.triggered.connect(lambda checked, x=m: self.mode_signal.emit(x))
            
        # Lock Colors
        self.lock_action = self.menu.addAction("Lock Colors")
        self.lock_action.setCheckable(True)
        self.lock_action.triggered.connect(self._on_lock)
        
        self.menu.addSeparator()

        # 3. Presets Submenu
        preset_menu = self.menu.addMenu("Quick Presets")
        
        # Screen Presets
        cat_screen = preset_menu.addSection("Screen")
        for pres in ["Movie", "Gaming", "Desktop"]:
             a = preset_menu.addAction(pres)
             a.triggered.connect(lambda checked, x=pres: self.preset_signal.emit("screen", x))
             
        # Music Presets
        cat_music = preset_menu.addSection("Music")
        for pres in ["Party", "Chill", "Bass Focus"]:
             a = preset_menu.addAction(pres)
             a.triggered.connect(lambda checked, x=pres: self.preset_signal.emit("music", x))

        self.menu.addSeparator()
        
        # 4. Settings & Exit
        settings_action = self.menu.addAction("Settings")
        settings_action.triggered.connect(self._on_settings)
        
        quit_action = self.menu.addAction("Exit")
        quit_action.triggered.connect(self._on_quit)
        
        self.setContextMenu(self.menu)
        
        # Double-click
        self.activated.connect(self._on_activated)
        
        # Set initial icon
        self.current_mode = "screen"  # Default mode
        self.set_enabled(self.enabled)
    
    def set_mode(self, mode: str):
        """Update tray icon based on current mode"""
        self.current_mode = mode
        self._update_icon()
    
    def set_enabled(self, enabled: bool):
        """Aktualizuj tray icon a label"""
        self.enabled = enabled
        self.toggle_action.setText("Turn OFF" if enabled else "Turn ON")
        self._update_icon()
    
    def _update_icon(self):
        """Update icon based on enabled state and mode"""
        if not self.enabled:
            # Disabled state - always use disabled icon
            icon_path = get_resource_path("resources/icon_disabled.png")
        else:
            # Enabled - use mode-specific icon
            mode_icons = {
                "music": "resources/icon_music.png",
                "screen": "resources/icon_screen.png",
                "light": "resources/icon_light.png",
                "pchealth": "resources/icon_app.png"  # Use main icon for PC Health
            }
            icon_file = mode_icons.get(self.current_mode, "resources/icon_tray.png")
            icon_path = get_resource_path(icon_file)
        
        if icon_path.exists():
            self.setIcon(QIcon(str(icon_path)))
    
    def _on_toggle(self):
        self.toggle_signal.emit(not self.enabled)
        
    def _on_lock(self, checked):
        self.lock_signal.emit(checked)
    
    def _on_settings(self):
        self.settings_signal.emit()
    
    def _on_quit(self):
        self.quit_signal.emit()
    
    def _on_activated(self, reason):
        # Open Settings on Single Click (Trigger) or Double Click
        if reason in (QSystemTrayIcon.ActivationReason.Trigger, QSystemTrayIcon.ActivationReason.DoubleClick):
            self.settings_signal.emit()
            
            # FOCUS HELPER: Try to find the actual window and raise it
            # The signal just tells App to show it, but we can try to find active modal dialogs
            # or rely on the visible MainWindow if used.
            # However, SettingsDialog is usually a separate dialog instance in App logic.
            # Since we can't access it easily here, we will trust the App handler to do raise_().
            # BUT, if MainWindow is the parent, let's activate it.
            
            if self.parent():
                self.parent().showNormal()
                self.parent().activateWindow()
                self.parent().raise_()


class MainWindow(QMainWindow):
    """Hlavní okno aplikace"""
    
    toggle_signal = pyqtSignal(bool)
    settings_signal = pyqtSignal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("AmbiLight - Controller")
        self.setWindowIcon(QIcon("resources/icon_app.png"))
        self.setGeometry(100, 100, 400, 300)
        self.enabled = True  # Track UI state
        
        # self.setStyleSheet(DARK_THEME) # Uses global theme now
        self._init_ui()
        
        # Hide by default - only show via tray menu
        self.hide()
        
        # Close → minimize to tray
        self.closeEvent = self._on_close_event
        
        # Track current mode for icon
        self.current_mode = "screen"
    
    def set_mode(self, mode: str):
        """Update window icon based on current mode"""
        self.current_mode = mode
        mode_icons = {
            "music": "resources/icon_music.png",
            "screen": "resources/icon_screen.png",
            "light": "resources/icon_light.png",
            "pchealth": "resources/icon_app.png"
        }
        icon_file = mode_icons.get(mode, "resources/icon_app.png")
        self.setWindowIcon(QIcon(icon_file))
    
    def _init_ui(self):
        """Vytvoř minimální UI"""
        central_widget = QWidget()
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("AmbiLight Status")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Status Card (Label)
        self.status_label = QLabel("Status: Initializing...")
        self.status_label.setObjectName("status")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.status_label)
        
        # Serial status
        self.serial_label = QLabel("Serial: Connecting...")
        self.serial_label.setObjectName("serial_err")
        self.serial_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.serial_label)
        
        layout.addStretch()
        
        # Buttons
        buttons_layout = QHBoxLayout()
        
        self.toggle_btn = QPushButton("Turn OFF")
        self.toggle_btn.setMinimumHeight(45)
        self.toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.toggle_btn.setObjectName("primary")
        self.toggle_btn.clicked.connect(self._on_toggle_btn_click)
        buttons_layout.addWidget(self.toggle_btn)
        
        settings_btn = QPushButton("Settings")
        settings_btn.setMinimumHeight(45)
        settings_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        settings_btn.clicked.connect(lambda: self.settings_signal.emit())
        buttons_layout.addWidget(settings_btn)
        
        layout.addLayout(buttons_layout)
        
        central_widget.setLayout(layout)
        self.setCentralWidget(central_widget)
        
    def _on_toggle_btn_click(self):
        """Handle toggle button click"""
        self.toggle_signal.emit(not self.enabled)
    
    def set_enabled(self, enabled: bool):
        """Nastav stav ON/OFF"""
        self.enabled = enabled
        self.toggle_btn.setText("Turn OFF" if enabled else "Turn ON")
        
        if enabled:
            self.toggle_btn.setObjectName("primary")
        else:
            self.toggle_btn.setObjectName("") # Standard gray
        
        # Force style reload
        self.toggle_btn.style().unpolish(self.toggle_btn)
        self.toggle_btn.style().polish(self.toggle_btn)
    
    def set_status(self, status: str):
        """Aktualizuj status label"""
        self.status_label.setText(status)
    
    def set_serial_status(self, status_data):
        """
        Update serial status label.
        status_data: Can be bool (old way) or str (detailed HTML).
        """
        if isinstance(status_data, bool):
            # Legacy fallback
            if status_data:
                self.serial_label.setText("Serial: Connected ✓")
                self.serial_label.setStyleSheet("color: #34C759; font-weight: bold;")
            else:
                self.serial_label.setText("Serial: Disconnected ✗")
                self.serial_label.setStyleSheet("color: #FF3B30; font-weight: bold;")
        else:
            # Rich text / Detailed
            self.serial_label.setText(status_data)
            self.serial_label.setStyleSheet("font-size: 11px;")
            self.serial_label.setWordWrap(True)
            
    def _on_close_event(self, event):
        """Kliknutí na X → minimize to tray"""
        self.hide()
        event.ignore()