from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QListWidget, QListWidgetItem, 
    QPushButton, QGroupBox, QComboBox, QCheckBox, QLabel, QSpinBox,
    QColorDialog, QFormLayout, QFrame, QSplitter
)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QColor, QIcon
import copy

class MetricEditorWidget(QWidget):
    """
    Master-Detail Widget for editing PC Health Metrics.
    Left: List of Rules
    Right: Editor for selected Rule
    """
    metrics_changed = pyqtSignal(list) # Emits updated list of dicts
    preview_gradient = pyqtSignal(object, object, object) # Low, Mid, High colors (tuples)

    def __init__(self, initial_metrics: list):
        super().__init__()
        # Deep copy to avoid modifying config directly until saved
        self.metrics = copy.deepcopy(initial_metrics)
        sorted(self.metrics, key=lambda x: x.get('metric', ''))
        
        self.current_index = -1
        self.init_ui()

    def init_ui(self):
        main_layout = QHBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # --- LEFT PANEL (LIST) ---
        left_panel = QWidget()
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(0, 0, 0, 0)
        
        self.list_widget = QListWidget()
        self.list_widget.currentRowChanged.connect(self._on_row_changed)
        left_layout.addWidget(self.list_widget)
        
        # Buttons
        h_btn = QHBoxLayout()
        btn_add = QPushButton("➕ Add Rule")
        btn_add.clicked.connect(self._add_rule)
        btn_del = QPushButton("➖ Remove")
        btn_del.clicked.connect(self._remove_rule)
        
        h_btn.addWidget(btn_add)
        h_btn.addWidget(btn_del)
        left_layout.addLayout(h_btn)
        
        # --- RIGHT PANEL (EDITOR) ---
        self.right_panel = QGroupBox("Rule Configuration")
        self.right_panel.setEnabled(False) # Disabled until selection
        right_layout = QVBoxLayout(self.right_panel)
        
        # 1. Metric Type
        form = QFormLayout()
        self.cb_metric = QComboBox()
        self.cb_metric.addItems(["cpu_usage", "cpu_temp", "gpu_usage", "gpu_temp", "ram_usage", "net_usage"])
        self.cb_metric.currentTextChanged.connect(self._update_current_data)
        form.addRow("Metric Source:", self.cb_metric)
        right_layout.addLayout(form)
        
        # 2. Zones
        grp_zones = QGroupBox("Target Zones")
        lz = QHBoxLayout()
        self.chk_zones = {}
        for z in ["left", "top", "right", "bottom"]:
            c = QCheckBox(z.capitalize())
            c.toggled.connect(self._update_current_data)
            self.chk_zones[z] = c
            lz.addWidget(c)
        grp_zones.setLayout(lz)
        right_layout.addWidget(grp_zones)
        
        # 3. Colors
        grp_color = QGroupBox("Color Gradient")
        lc = QVBoxLayout()
        
        h_sc = QHBoxLayout()
        h_sc.addWidget(QLabel("Preset:"))
        self.cb_scale = QComboBox()
        self.cb_scale.addItems(["blue_green_red", "cool_warm", "cyan_yellow", "rainbow", "custom"])
        self.cb_scale.currentTextChanged.connect(self._on_scale_changed)
        h_sc.addWidget(self.cb_scale, 1)
        lc.addLayout(h_sc)
        
        # Custom Pickers
        self.pickers_container = QWidget()
        lp = QHBoxLayout(self.pickers_container)
        lp.setContentsMargins(0,5,0,0)
        
        self.btn_low = self._create_color_btn("Low")
        self.btn_mid = self._create_color_btn("Mid")
        self.btn_high = self._create_color_btn("High")
        
        lp.addWidget(QLabel("Low:"))
        lp.addWidget(self.btn_low)
        lp.addWidget(QLabel("Mid:"))
        lp.addWidget(self.btn_mid)
        lp.addWidget(QLabel("High:"))
        lp.addWidget(self.btn_high)
        lp.addStretch()
        
        lc.addWidget(self.pickers_container)
        grp_color.setLayout(lc)
        right_layout.addWidget(grp_color)
        
        # 4. Brightness
        grp_bright = QGroupBox("Brightness Control")
        lb = QVBoxLayout()
        
        h_mode = QHBoxLayout()
        h_mode.addWidget(QLabel("Mode:"))
        self.cb_bright_mode = QComboBox()
        self.cb_bright_mode.addItems(["static", "dynamic"])
        self.cb_bright_mode.setToolTip("'Dynamic' scales brightness with metric value (Hot = Bright)")
        self.cb_bright_mode.currentTextChanged.connect(self._on_bright_mode_changed)
        h_mode.addWidget(self.cb_bright_mode)
        lb.addLayout(h_mode)
        
        # Static Slider
        self.w_static = QWidget()
        ls = QHBoxLayout(self.w_static)
        ls.setContentsMargins(0,0,0,0)
        ls.addWidget(QLabel("Value:"))
        self.sb_static = QSpinBox()
        self.sb_static.setRange(0, 255)
        self.sb_static.valueChanged.connect(self._update_current_data)
        ls.addWidget(self.sb_static)
        lb.addWidget(self.w_static)
        
        # Dynamic Range
        self.w_dynamic = QWidget()
        ld = QHBoxLayout(self.w_dynamic)
        ld.setContentsMargins(0,0,0,0)
        ld.addWidget(QLabel("Min:"))
        self.sb_min_br = QSpinBox()
        self.sb_min_br.setRange(0, 255)
        self.sb_min_br.valueChanged.connect(self._update_current_data)
        ld.addWidget(self.sb_min_br)
        
        ld.addWidget(QLabel("Max:"))
        self.sb_max_br = QSpinBox()
        self.sb_max_br.setRange(0, 255)
        self.sb_max_br.valueChanged.connect(self._update_current_data)
        ld.addWidget(self.sb_max_br)
        lb.addWidget(self.w_dynamic)
        
        grp_bright.setLayout(lb)
        right_layout.addWidget(grp_bright)
        
        # 5. Range (Min/Max Value)
        grp_range = QGroupBox("Input Range setup")
        lr = QHBoxLayout()
        lr.addWidget(QLabel("Min Val:"))
        self.sb_vmin = QSpinBox()
        self.sb_vmin.setRange(0, 200)
        self.sb_vmin.valueChanged.connect(self._update_current_data)
        lr.addWidget(self.sb_vmin)
        
        lr.addWidget(QLabel("Max Val:"))
        self.sb_vmax = QSpinBox()
        self.sb_vmax.setRange(0, 200)
        self.sb_vmax.valueChanged.connect(self._update_current_data)
        lr.addWidget(self.sb_vmax)
        grp_range.setLayout(lr)
        right_layout.addWidget(grp_range)
        
        right_layout.addStretch()
        
        # Splitter
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.addWidget(left_panel)
        splitter.addWidget(self.right_panel)
        splitter.setStretchFactor(0, 1)
        splitter.setStretchFactor(1, 2)
        
        main_layout.addWidget(splitter)
        self.setLayout(main_layout)
        
        self.refresh_list()

    def _create_color_btn(self, tag):
        btn = QPushButton()
        btn.setFixedSize(50, 24)
        btn.clicked.connect(lambda: self._pick_color(btn))
        return btn

    def _pick_color(self, btn):
        if self.current_index < 0: return
        
        curr_color = btn.property("rgb_val") or (128,128,128)
        c = QColorDialog.getColor(QColor(*curr_color), self, "Pick Color")
        if c.isValid():
            rgb = (c.red(), c.green(), c.blue())
            btn.setStyleSheet(f"background-color: rgb{rgb}")
            btn.setProperty("rgb_val", rgb)
            self._update_current_data()

    def refresh_list(self):
        self.list_widget.clear()
        for m in self.metrics:
            zones = ",".join([z[0].upper() for z in m.get('zones', [])])
            txt = f"{m.get('metric')} [{zones}]"
            item = QListWidgetItem(txt)
            self.list_widget.addItem(item)
            
        if self.current_index >= 0 and self.current_index < len(self.metrics):
            self.list_widget.setCurrentRow(self.current_index)

    def _add_rule(self):
        new_rule = {
            "metric": "cpu_usage",
            "zones": ["right"],
            "color_scale": "blue_green_red",
            "min_value": 0, "max_value": 100,
            "brightness_mode": "static",
            "brightness": 200,
            "brightness_min": 50,
            "brightness_max": 255,
            "color_low": (0,0,255), "color_mid": (0,255,0), "color_high": (255,0,0),
            "enabled": True
        }
        self.metrics.append(new_rule)
        self.refresh_list()
        self.list_widget.setCurrentRow(len(self.metrics)-1)
        self.metrics_changed.emit(self.metrics)

    def _remove_rule(self):
        row = self.list_widget.currentRow()
        if row >= 0:
            del self.metrics[row]
            self.current_index = -1
            self.refresh_list()
            self.metrics_changed.emit(self.metrics)

    def _on_row_changed(self, row):
        if row < 0:
            self.right_panel.setEnabled(False)
            self.current_index = -1
            return
            
        self.current_index = row
        self.right_panel.setEnabled(True)
        data = self.metrics[row]
        
        # Populate UI (Block signals)
        self.blockSignals(True)
        
        idx = self.cb_metric.findText(data.get('metric'))
        if idx >= 0: self.cb_metric.setCurrentIndex(idx)
        
        zones = data.get('zones', [])
        for z, chk in self.chk_zones.items():
            chk.setChecked(z in zones)
            
        idx_s = self.cb_scale.findText(data.get('color_scale'))
        if idx_s >= 0: self.cb_scale.setCurrentIndex(idx_s)
        
        # Colors
        def set_btn(btn, key, default):
            c = data.get(key, default)
            btn.setProperty("rgb_val", c)
            btn.setStyleSheet(f"background-color: rgb{c}")
            
        set_btn(self.btn_low, 'color_low', (0,0,255))
        set_btn(self.btn_mid, 'color_mid', (0,255,0))
        set_btn(self.btn_high, 'color_high', (255,0,0))
        
        self.pickers_container.setVisible(data.get('color_scale') == 'custom')
        
        # Brightness
        b_mode = data.get('brightness_mode', 'static')
        self.cb_bright_mode.setCurrentText(b_mode)
        self._on_bright_mode_changed(b_mode) # Update visibility
        
        self.sb_static.setValue(int(data.get('brightness', 200)))
        self.sb_min_br.setValue(int(data.get('brightness_min', 50)))
        self.sb_max_br.setValue(int(data.get('brightness_max', 255)))
        
        self.sb_vmin.setValue(int(data.get('min_value', 0)))
        self.sb_vmax.setValue(int(data.get('max_value', 100)))
        
        self.blockSignals(False)

    def _on_bright_mode_changed(self, mode):
        self.w_static.setVisible(mode == 'static')
        self.w_dynamic.setVisible(mode == 'dynamic')
        self._update_current_data()

    def _on_scale_changed(self, scale):
        self.pickers_container.setVisible(scale == 'custom')
        self._update_current_data()

    def _update_current_data(self):
        if self.current_index < 0: return
        
        # Gather data from UI
        d = self.metrics[self.current_index]
        
        d['metric'] = self.cb_metric.currentText()
        d['zones'] = [z for z, chk in self.chk_zones.items() if chk.isChecked()]
        d['color_scale'] = self.cb_scale.currentText()
        
        d['color_low'] = self.btn_low.property("rgb_val")
        d['color_mid'] = self.btn_mid.property("rgb_val")
        d['color_high'] = self.btn_high.property("rgb_val")
        
        d['brightness_mode'] = self.cb_bright_mode.currentText()
        d['brightness'] = self.sb_static.value()
        d['brightness_min'] = self.sb_min_br.value()
        d['brightness_max'] = self.sb_max_br.value()
        
        d['min_value'] = self.sb_vmin.value()
        d['max_value'] = self.sb_vmax.value()
        
        # Update list item text
        item = self.list_widget.item(self.current_index)
        zones = ",".join([z[0].upper() for z in d['zones']])
        item.setText(f"{d['metric']} [{zones}]")
        
        self.metrics_changed.emit(self.metrics)
