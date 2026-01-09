from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem,
    QPushButton, QLabel, QLineEdit, QSpinBox, QComboBox, QColorDialog,
    QHeaderView, QGroupBox, QAbstractItemView
)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QColor

class ZoneEditorWidget(QWidget):
    zones_changed = pyqtSignal(list) # Emits updated list of dicts

    def __init__(self, parent=None):
        super().__init__(parent)
        self.zones = [] # List of dicts
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        
        # --- TOP: Tool Bar ---
        h_tools = QHBoxLayout()
        btn_add = QPushButton("Add Zone")
        btn_add.clicked.connect(self._add_zone)
        btn_del = QPushButton("Remove")
        btn_del.clicked.connect(self._remove_zone)
        
        h_tools.addWidget(btn_add)
        h_tools.addWidget(btn_del)
        h_tools.addStretch()
        layout.addLayout(h_tools)

        # --- MIDDLE: Table ---
        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["Name", "Start", "End", "Effect"])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.table.itemSelectionChanged.connect(self._on_selection_change)
        layout.addWidget(self.table)
        
        # --- BOTTOM: Detail Editor ---
        self.grp_detail = QGroupBox("Zone Properties")
        self.grp_detail.setVisible(False)
        l_det = QVBoxLayout()
        
        # Name
        h1 = QHBoxLayout()
        h1.addWidget(QLabel("Name:"))
        self.txt_name = QLineEdit()
        self.txt_name.textChanged.connect(self._update_current_zone)
        h1.addWidget(self.txt_name)
        l_det.addLayout(h1)
        
        # Range
        h2 = QHBoxLayout()
        h2.addWidget(QLabel("Start (%):"))
        self.sb_start = QSpinBox(); self.sb_start.setRange(0, 100)
        self.sb_start.valueChanged.connect(self._update_current_zone)
        h2.addWidget(self.sb_start)
        
        h2.addWidget(QLabel("End (%):"))
        self.sb_end = QSpinBox(); self.sb_end.setRange(0, 100)
        self.sb_end.valueChanged.connect(self._update_current_zone)
        h2.addWidget(self.sb_end)
        l_det.addLayout(h2)
        
        # Color & Effect
        h3 = QHBoxLayout()
        self.btn_color = QPushButton()
        self.btn_color.setFixedSize(50, 24)
        self.btn_color.clicked.connect(self._pick_color)
        h3.addWidget(QLabel("Color:"))
        h3.addWidget(self.btn_color)
        
        h3.addWidget(QLabel("Effect:"))
        self.cb_effect = QComboBox()
        self.cb_effect.addItems(["static", "pulse", "blink", "breathe"])
        self.cb_effect.currentTextChanged.connect(self._update_current_zone)
        h3.addWidget(self.cb_effect)
        l_det.addLayout(h3)
        
        # Speed & Brightness
        h4 = QHBoxLayout()
        h4.addWidget(QLabel("Speed:"))
        self.sb_speed = QSpinBox(); self.sb_speed.setRange(0, 100)
        self.sb_speed.valueChanged.connect(self._update_current_zone)
        h4.addWidget(self.sb_speed)
        
        h4.addWidget(QLabel("Bright:"))
        self.sb_bright = QSpinBox(); self.sb_bright.setRange(0, 255)
        self.sb_bright.valueChanged.connect(self._update_current_zone)
        h4.addWidget(self.sb_bright)
        l_det.addLayout(h4)
        
        self.grp_detail.setLayout(l_det)
        layout.addWidget(self.grp_detail)
        
        self.setLayout(layout)

    def set_zones(self, zones: list):
        self.zones = zones if zones else []
        self._refresh_table()

    def get_zones(self) -> list:
        return self.zones

    def _add_zone(self):
        new_zone = {
            "name": f"Zone {len(self.zones)+1}",
            "start": 0, "end": 20,
            "color": (255, 0, 0),
            "effect": "static",
            "speed": 50,
            "brightness": 255
        }
        self.zones.append(new_zone)
        self._refresh_table()
        self.table.selectRow(len(self.zones)-1)
        self.zones_changed.emit(self.zones)

    def _remove_zone(self):
        row = self.table.currentRow()
        if row >= 0:
            self.zones.pop(row)
            self._refresh_table()
            self.zones_changed.emit(self.zones)

    def _refresh_table(self):
        self.table.blockSignals(True)
        self.table.setRowCount(len(self.zones))
        for i, z in enumerate(self.zones):
            self.table.setItem(i, 0, QTableWidgetItem(z.get("name", "?")))
            self.table.setItem(i, 1, QTableWidgetItem(str(z.get("start", 0))))
            self.table.setItem(i, 2, QTableWidgetItem(str(z.get("end", 0))))
            self.table.setItem(i, 3, QTableWidgetItem(z.get("effect", "static")))
        self.table.blockSignals(False)

    def _on_selection_change(self):
        row = self.table.currentRow()
        if row >= 0:
            z = self.zones[row]
            self.grp_detail.setVisible(True)
            
            # Populate Detail
            self.txt_name.blockSignals(True)
            self.sb_start.blockSignals(True)
            self.sb_end.blockSignals(True)
            self.cb_effect.blockSignals(True)
            self.sb_speed.blockSignals(True)
            self.sb_bright.blockSignals(True)
            
            self.txt_name.setText(z.get("name", ""))
            self.sb_start.setValue(z.get("start", 0))
            self.sb_end.setValue(z.get("end", 0))
            self.cb_effect.setCurrentText(z.get("effect", "static"))
            self.sb_speed.setValue(z.get("speed", 50))
            self.sb_bright.setValue(z.get("brightness", 255))
            self._update_color_btn(z.get("color", (255,255,255)))
            
            self.txt_name.blockSignals(False)
            self.sb_start.blockSignals(False)
            self.sb_end.blockSignals(False)
            self.cb_effect.blockSignals(False)
            self.sb_speed.blockSignals(False)
            self.sb_bright.blockSignals(False)
        else:
            self.grp_detail.setVisible(False)

    def _update_current_zone(self):
        row = self.table.currentRow()
        if row < 0: return
        
        z = self.zones[row]
        z["name"] = self.txt_name.text()
        z["start"] = self.sb_start.value()
        z["end"] = self.sb_end.value()
        z["effect"] = self.cb_effect.currentText()
        z["speed"] = self.sb_speed.value()
        z["brightness"] = self.sb_bright.value()
        
        self._refresh_table() # Update table values
        self.zones_changed.emit(self.zones)

    def _pick_color(self):
        row = self.table.currentRow()
        if row < 0: return
        
        c_curr = self.zones[row].get("color", (255,255,255))
        c = QColorDialog.getColor(QColor(*c_curr), self, "Pick Zone Color")
        if c.isValid():
            self.zones[row]["color"] = (c.red(), c.green(), c.blue())
            self._update_color_btn(self.zones[row]["color"])
            self.zones_changed.emit(self.zones)

    def _update_color_btn(self, rgb):
        self.btn_color.setStyleSheet(f"background-color: rgb({rgb[0]},{rgb[1]},{rgb[2]}); border: 1px solid #777;")
