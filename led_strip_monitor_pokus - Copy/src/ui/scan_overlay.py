"""
Scanning Area Overlay Widget
Fullscreen transparent overlay that displays scanning regions on target monitor
"""
from PyQt6.QtWidgets import QWidget
from PyQt6.QtCore import Qt, QTimer, QRect
from PyQt6.QtGui import QPainter, QBrush, QPen, QColor
from PyQt6.QtWidgets import QApplication

class ScanningAreaOverlay(QWidget):
    """Fullscreen overlay showing scanning area on monitor"""
    
    def __init__(self, parent=None):
        # Overlay should be behind Settings and NEVER steal focus
        super().__init__(parent, Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool | Qt.WindowType.WindowDoesNotAcceptFocus)
        
        # Make transparent
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)  # Pass through clicks
        
        # Regions to draw
        self.regions = []
        self.monitor_idx = 0
        self.visualize_mode = False
        self.monitor_width = 1920
        self.monitor_height = 1080
        
    def show_regions(self, mon_width, mon_height, depth_top, depth_bottom, depth_left, depth_right, pad_top, pad_bottom, pad_left, pad_right):
        """Show overlay with scanning regions (per-edge depth support)"""
        self.monitor_width = mon_width
        self.monitor_height = mon_height
        
        # Calculate regions FIRST
        self.calculate_regions(mon_width, mon_height, depth_top, depth_bottom, depth_left, depth_right, pad_top, pad_bottom, pad_left, pad_right)
        
        # Position on correct monitor - FULLSCREEN!
        screens = QApplication.screens()
        if self.monitor_idx < len(screens):
            screen = screens[self.monitor_idx]
            geo = screen.geometry()
            # Set to EXACT screen geometry - fullscreen over entire monitor
            self.setGeometry(geo.x(), geo.y(), geo.width(), geo.height())
        else:
            # Fallback to primary screen
            screen = QApplication.primaryScreen()
            geo = screen.geometry()
            self.setGeometry(geo.x(), geo.y(), geo.width(), geo.height())
        
        self.visualize_mode = True
        self.show()
        self.raise_()
        
    def calculate_regions(self, w, h, depth_top_pct, depth_bottom_pct, depth_left_pct, depth_right_pct, pad_top, pad_bottom, pad_left, pad_right):
        """Calculate scanning rectangles with per-edge depth support"""
        # Calculate depth in pixels for each edge
        depth_top = int(h * depth_top_pct / 100.0)
        depth_bottom = int(h * depth_bottom_pct / 100.0)
        depth_left = int(w * depth_left_pct / 100.0)
        depth_right = int(w * depth_right_pct / 100.0)
        
        # Padding in pixels FROM EDGES
        p_top = int(h * pad_top / 100.0)
        p_bot = int(h * pad_bottom / 100.0)
        p_left = int(w * pad_left / 100.0)
        p_right = int(w * pad_right / 100.0)
        
        self.regions = []
        
        # TOP EDGE - horizontal bar at top with its own depth
        self.regions.append(QRect(p_left, p_top, w - p_left - p_right, depth_top))
        
        # BOTTOM EDGE - horizontal bar at bottom with its own depth
        self.regions.append(QRect(p_left, h - p_bot - depth_bottom, w - p_left - p_right, depth_bottom))
        
        # LEFT EDGE - vertical bar on left with its own depth
        # Height excludes top and bottom scan areas to avoid overlap
        left_y = p_top + depth_top
        left_height = h - p_top - p_bot - depth_top - depth_bottom
        self.regions.append(QRect(p_left, left_y, depth_left, left_height))
        
        # RIGHT EDGE - vertical bar on right with its own depth
        # Height excludes top and bottom scan areas to avoid overlap
        right_y = p_top + depth_top
        right_height = h - p_top - p_bot - depth_top - depth_bottom
        self.regions.append(QRect(w - p_right - depth_right, right_y, depth_right, right_height))
        
        self.update()
        
    def update_params(self, depth_top, depth_bottom, depth_left, depth_right, pad_top, pad_bottom, pad_left, pad_right):
        """Update parameters without recreating window (per-edge depth support)"""
        if self.isVisible():
            # Use stored monitor dimensions
            self.calculate_regions(self.monitor_width, self.monitor_height, depth_top, depth_bottom, depth_left, depth_right, pad_top, pad_bottom, pad_left, pad_right)
    
    def paintEvent(self, event):
        """Draw regions"""
        if not self.visualize_mode:
            return
            
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Semi-transparent dark overlay for NON-scanned area (middle)
        painter.fillRect(self.rect(), QColor(0, 0, 0, 120))
        
        # Highlight SCANNED regions (edges) - bright and visible
        brush = QBrush(QColor(10, 132, 255, 180))  # Bright blue semi-transparent
        pen = QPen(QColor(10, 255, 255, 255), 4, Qt.PenStyle.SolidLine)  # Cyan bright border
        
        painter.setBrush(brush)
        painter.setPen(pen)
        
        for region in self.regions:
            painter.drawRect(region)
            
        painter.end()
