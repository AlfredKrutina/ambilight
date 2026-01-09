from PyQt6.QtWidgets import QWidget, QApplication, QLabel, QVBoxLayout
from PyQt6.QtCore import Qt, pyqtSignal, QPoint, QRect, QTimer, QPropertyAnimation, QRectF
from PyQt6.QtGui import QPainter, QColor, QPen, QBrush, QFont, QPainterPath
from geometry import compute_segments, compute_calibrated_segments

class CalibrationOverlay(QWidget):
    """
    Transparent Fullscreen Overlay for LED Calibration.
    User clicks 4 corners to define the capture area.
    """
    finished = pyqtSignal(list) # Emits list of (x, y) tuples
    cancelled = pyqtSignal()    # Emits if user cancels (ESC)
    light_led_request = pyqtSignal(str) # "top-left", "top-right", etc.

    def __init__(self, monitor_idx=0):
        super().__init__()
        self.monitor_idx = monitor_idx
        # Standard Window (User requested maximize ability)
        self.setWindowFlags(Qt.WindowType.Window)
        self.setWindowTitle("Calibration Wizard - Please Maximize This Window")
        self.setCursor(Qt.CursorShape.CrossCursor)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground) # Required for transparency
        self.setStyleSheet("background-color: rgba(0, 0, 0, 200);") # Dark background
        
        # Calibration State
        self.points = []
        self.steps = [
            {"name": "top_left", "label": "Look at the LED strip.\nClick on the screen where the GREEN LED is lit.\n(Corner 1/4)"},
            {"name": "top_right", "label": "Look at the LED strip.\nClick on the screen where the GREEN LED is lit.\n(Corner 2/4)"},
            {"name": "bottom_right", "label": "Look at the LED strip.\nClick on the screen where the GREEN LED is lit.\n(Corner 3/4)"},
            {"name": "bottom_left", "label": "Look at the LED strip.\nClick on the screen where the GREEN LED is lit.\n(Corner 4/4)"}
        ]
        self.current_step = 0
        
        # UI
        self.info_label = QLabel(self)
        self.info_label.setStyleSheet("color: white; font-size: 24px; font-weight: bold; background-color: rgba(0,0,0,200); padding: 30px; border-radius: 15px; border: 2px solid #0A84FF;")
        self.info_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._update_label()
        
        self.info_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._update_label()
        
        # Position label in center
        layout = QVBoxLayout()
        layout.addWidget(self.info_label, 0, Qt.AlignmentFlag.AlignCenter)
        self.setLayout(layout)

        # Region Visualization
        self.visualize_mode = False
        self.region_params = {} # {w, h, depth, pad, calib}
        self.visualized_regions = []

    def show_regions(self, w, h, depth_pct, pad_top, pad_bottom, pad_left, pad_right, calibration_points=None):
        """Enable realtime visualization of capture zones"""
        self.visualize_mode = True
        self.info_label.setVisible(False) 
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating) # Don't steal focus
        self.setStyleSheet("background-color: transparent;")
        
        # Smooth Animation
        if hasattr(self, 'opacity_anim'):
             self.opacity_anim.stop()
        else:
             self.opacity_anim = QPropertyAnimation(self, b"windowOpacity")
             self.opacity_anim.setDuration(250) 

        self.setWindowOpacity(0.0)

        self.region_params = {
            "w": w, "h": h, 
            "depth": depth_pct, 
            "pad_top": pad_top,
            "pad_bottom": pad_bottom,
            "pad_left": pad_left,
            "pad_right": pad_right,
            "calib": calibration_points
        }
        self._recalc_regions()
        
        # Show on correct screen
        screens = QApplication.screens()
        if 0 <= self.monitor_idx < len(screens):
            screen = screens[self.monitor_idx]
            geo = screen.geometry()
            print(f"DEBUG: Visualizer Geometry: {geo} for MonIdx: {self.monitor_idx}")
            self.setGeometry(geo)
            self.setFixedSize(geo.width(), geo.height())
        else:
            print(f"DEBUG: Invalid monitor index {self.monitor_idx} for screens len {len(screens)}")
            
        self.show()
        # Fade In
        self.opacity_anim.setStartValue(0.0)
        self.opacity_anim.setEndValue(1.0)
        self.opacity_anim.start()
        self.update()

    def update_params(self, depth_pct=None, pad_top=None, pad_bottom=None, pad_left=None, pad_right=None):
        if not self.visualize_mode: return
        if depth_pct is not None: self.region_params['depth'] = depth_pct
        if pad_top is not None: self.region_params['pad_top'] = pad_top
        if pad_bottom is not None: self.region_params['pad_bottom'] = pad_bottom
        if pad_left is not None: self.region_params['pad_left'] = pad_left
        if pad_right is not None: self.region_params['pad_right'] = pad_right
        self._recalc_regions()
        self.update()

    def _recalc_regions(self):
        p = self.region_params
        if not p: return
        
        # Use geometry logic
        if p.get('calib') and len(p['calib']) == 4:
            self.visualized_regions = compute_calibrated_segments(p['calib'], p['depth'], p['w'], p['h'])
        else:
            self.visualized_regions = compute_segments(
                p['w'], p['h'], p['depth'], 
                p.get('pad_top', 0), p.get('pad_bottom', 0), 
                p.get('pad_left', 0), p.get('pad_right', 0)
            )

    def hide_regions(self):
        self.visualize_mode = False
        self.hide()


    def start(self):
        """Show and start sequence"""
        # RESET STATE (In case Visualizer was used previously)
        self.visualize_mode = False
        self.info_label.setVisible(True)
        self.setStyleSheet("background-color: rgba(0, 0, 0, 200);")
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, False) # Can take focus
        self.setWindowOpacity(1.0) # Ensure fully opaque

        self.show() # Show first to get handle, but don't maximize yet
        
        # Move to correct screen
        screens = QApplication.screens()
        if 0 <= self.monitor_idx < len(screens):
            screen = screens[self.monitor_idx]
            geo = screen.geometry()
            self.setGeometry(geo)
            self.setFixedSize(geo.width(), geo.height()) # Enforce size
        else:
            self.showFullScreen()
            
        self.raise_()
        self.activateWindow()
        self.setFocus()
        
        self.points = []
        self.current_step = 0
        self._update_label()
        self._emit_led_request()

    def _update_label(self):
        if self.current_step < len(self.steps):
            txt = self.steps[self.current_step]["label"]
            self.info_label.setText(f"{txt}\n(Press ESC to cancel)")
        else:
            self.info_label.setText("Calibration Complete!")

    def _emit_led_request(self):
        """Ask main app to light up the corresponding corner for guidance"""
        if self.current_step < len(self.steps):
            self.light_led_request.emit(self.steps[self.current_step]["name"])

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            # Capture Global Coordinate (Screen Absolute)
            # This ensures accuracy regardless of window position/borders
            global_pos = event.globalPosition().toPoint()
            
            self.points.append((global_pos.x(), global_pos.y()))
            self.current_step += 1
            
            if self.current_step >= len(self.steps):
                self.finished.emit(self.points)
                self.close()
            else:
                self._update_label()
                self._emit_led_request()
                self.update() # Redraw markers

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:
            self.cancelled.emit()
            self.close()

    def paintEvent(self, event):
        if self.visualize_mode:
            painter = QPainter(self)
            painter.setRenderHint(QPainter.RenderHint.Antialiasing)
            
            # --- APPLE-LIKE VISUALIZATION ---
            # 1. Dim the whole screen (The "Ignored" Area)
            painter.setBrush(QColor(0, 0, 0, 90)) # Lighter dimming for transparency
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawRect(self.rect())
            
            # 2. Calculate the Cutout Path (The "Active" Capture Area)
            from PyQt6.QtGui import QPainterPath
            from PyQt6.QtCore import QRectF
            path = QPainterPath()
            for r in self.visualized_regions:
                # r is (x1, y1, x2, y2)
                # QRect takes (x, y, w, h)
                rect = QRectF(float(r[0]), float(r[1]), float(r[2]-r[0]), float(r[3]-r[1]))
                path.addRect(rect)
            simplified_path = path.simplified()
            
            # 3. Cut out the active area (Make it transparent/clear)
            painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_Clear)
            painter.setBrush(QColor(0, 0, 0, 0))
            painter.drawPath(simplified_path)
            
            # 4. Draw Elegant Border around the Cutout
            painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            
            # Inner White Glow
            pen = QPen(QColor(255, 255, 255, 200))
            pen.setWidth(2)
            painter.setPen(pen)
            painter.drawPath(simplified_path)
            
            return

        # Original Calibration logic
        painter = QPainter(self)

        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Draw all captured points
        painter.setPen(QPen(QColor(0, 255, 0), 3))
        painter.setBrush(QBrush(QColor(0, 255, 0)))
        
        for i, pt in enumerate(self.points):
            # Convert Global -> Local for drawing
            local_pt = self.mapFromGlobal(QPoint(pt[0], pt[1]))
            
            painter.drawEllipse(local_pt, 8, 8)
            # Draw lines
            if i > 0:
                prev_global = self.points[i-1]
                prev_local = self.mapFromGlobal(QPoint(prev_global[0], prev_global[1]))
                painter.drawLine(prev_local, local_pt)

        # Draw line to cursor? (Optional polish)
