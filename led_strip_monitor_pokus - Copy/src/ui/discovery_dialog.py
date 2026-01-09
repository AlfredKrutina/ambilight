from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, 
                             QTableWidgetItem, QPushButton, QLabel, QHeaderView, 
                             QProgressBar, QMessageBox, QComboBox)
from PyQt6.QtCore import Qt, pyqtSignal, QTimer
from PyQt6.QtGui import QIcon
from modules.discovery import DiscoveryService

class DiscoveryDialog(QDialog):
    """
    Dialog to scan for devices, identify them, and select one to add.
    """
    new_device_signal = pyqtSignal(dict) # Internal signal for thread safety
    device_selected = pyqtSignal(dict)   # Emits info dict when "Add" is clicked

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("AmbiLight - Scan Devices")
        self.setWindowIcon(QIcon("resources/icon_scan.png"))
        self.setWindowFlags(Qt.WindowType.Window | Qt.WindowType.WindowCloseButtonHint)
        self.resize(600, 400)
        
        self.found_devices = {} # ip -> info
        self.discovery = None
        
        # Connect internal signal
        self.new_device_signal.connect(self._add_row)

        self.selected_interface_ip = None
        self._init_ui()
        self._start_scan()

    def _init_ui(self):
        layout = QVBoxLayout(self)

        # Status
        self.lbl_status = QLabel("Scanning for ESP32 Ambilight devices...")
        layout.addWidget(self.lbl_status)

        # Interface Selection
        hbox_iface = QHBoxLayout()
        hbox_iface.addWidget(QLabel("Scanning Interface:"))
        self.combo_iface = QComboBox()
        self.combo_iface.addItem("All Interfaces", None)
        self.combo_iface.currentTextChanged.connect(self._on_interface_changed)
        hbox_iface.addWidget(self.combo_iface)
        layout.addLayout(hbox_iface)

        self.progress = QProgressBar()
        self.progress.setRange(0, 0) # Indeterminate
        layout.addWidget(self.progress)

        # Table
        self.table = QTableWidget()
        self.table.setColumnCount(5) # IP, Name, LEDs, Identify, Add
        self.table.setHorizontalHeaderLabels(["IP Address", "Name", "LEDs", "Identify", "Action"])
        
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed)
        
        self.table.verticalHeader().setVisible(False)
        self.table.setAlternatingRowColors(True)
        self.table.setStyleSheet("QTableWidget { background-color: #1e1e1e; border: 1px solid #333; }")
        
        layout.addWidget(self.table)

        # Footer
        btn_close = QPushButton("Close")
        btn_close.clicked.connect(self.reject)
        layout.addWidget(btn_close)

    def _on_interface_changed(self, text):
        self.selected_interface_ip = self.combo_iface.currentData()
        self.lbl_status.setText(f"Scanning on {text}...")
        # Clear table? Maybe appropriate if switching networks.
        self.table.setRowCount(0)
        self.found_devices.clear()
        
        # CLEAR SERVICE CACHE to ensure we get "new" notifications even if device was found before
        if self.discovery:
            self.discovery.clear_cache()
            # Trigger immediate scan
            self.discovery.scan(self.selected_interface_ip)

    def _start_scan(self):
        self.discovery = DiscoveryService()
        self.discovery.on_device_found = self._on_device_found
        
        # Populate Interfaces
        ifaces = self.discovery.get_local_interfaces()
        # sort by IP for neatness
        ifaces.sort(key=lambda x: x[0])
        
        # Block signals during populate to avoid triggering unnecessary rescans
        self.combo_iface.blockSignals(True)
        for ip, bcast in ifaces:
            self.combo_iface.addItem(f"{ip} (Broadcast: {bcast})", ip)
        self.combo_iface.blockSignals(False)
        
        self.discovery.start()
        self.discovery.scan(self.selected_interface_ip)
        
        # Rescan every 2s
        self.timer = QTimer(self)
        self.timer.timeout.connect(lambda: self.discovery.scan(self.selected_interface_ip) if self.discovery else None)
        self.timer.start(2000)

    def _on_device_found(self, info):
        # Run on UI Thread via Signal
        self.new_device_signal.emit(info)

    def _add_row(self, info):
        ip = info['ip']
        if ip in self.found_devices:
            return # Already listed
            
        self.found_devices[ip] = info
        
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        # IP
        self.table.setItem(row, 0, QTableWidgetItem(ip))
        # Name
        self.table.setItem(row, 1, QTableWidgetItem(info.get('name', 'Unknown')))
        # LEDs
        self.table.setItem(row, 2, QTableWidgetItem(str(info.get('led_count', '?'))))
        
        # Identify Button
        btn_id = QPushButton("👁")
        btn_id.setToolTip("Flash Device LEDs")
        btn_id.setStyleSheet("background-color: #0A84FF; color: white;")
        btn_id.clicked.connect(lambda _, i=ip: self._identify(i))
        self.table.setCellWidget(row, 3, btn_id)
        
        # Add Button
        btn_add = QPushButton("Add")
        btn_add.setStyleSheet("background-color: #30D158; color: white; font-weight: bold;")
        btn_add.clicked.connect(lambda _, inf=info: self._select_device(inf))
        self.table.setCellWidget(row, 4, btn_add)

    def _identify(self, ip):
        if self.discovery:
            self.discovery.identify_device(ip)

    def _select_device(self, info):
        self.device_selected.emit(info)
        # Find button in table? Or just flash status
        self.lbl_status.setText(f"Added {info['name']} ({info['ip']})")

    def done(self, r):
        """Override done to ensure cleanup happens on accept/reject"""
        if hasattr(self, 'timer'):
            self.timer.stop()
            
        if self.discovery:
            self.discovery.stop()
            self.discovery = None
            
        super().done(r)

    def closeEvent(self, event):
        # Forward to done just in case, or rely on done being called? 
        # Usually close calls reject which calls done.
        # But if X is clicked, closeEvent is called.
        if hasattr(self, 'timer'):
            self.timer.stop()
        if self.discovery:
            self.discovery.stop()
            self.discovery = None
        super().closeEvent(event)
