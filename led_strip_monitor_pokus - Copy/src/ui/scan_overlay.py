"""
Scanning Area Overlay Widget
Fullscreen transparent overlay that displays scanning regions on target monitor
"""
from PyQt6.QtWidgets import QWidget
from PyQt6.QtCore import Qt, QTimer, QRect
from PyQt6.QtGui import QPainter, QBrush, QPen, QColor
from PyQt6.QtWidgets import QApplication
from utils import is_mac

class ScanningAreaOverlay(QWidget):
    """Fullscreen overlay showing scanning area on monitor"""
    
    def __init__(self, parent=None):
        # CRITICAL: On Mac, window stacking is different
        # Strategy: Use Window type (not Tool/Popup) and rely on parent-child relationship
        # Child windows automatically stay behind parent on Mac
        if is_mac():
            # Mac: Use Window type, parent will ensure proper stacking
            window_flags = (
                Qt.WindowType.FramelessWindowHint | 
                Qt.WindowType.Window | 
                Qt.WindowType.WindowDoesNotAcceptFocus
            )
        else:
            # Windows/Linux: Use Tool with WindowStaysOnBottomHint
            window_flags = (
                Qt.WindowType.FramelessWindowHint | 
                Qt.WindowType.Tool | 
                Qt.WindowType.WindowDoesNotAcceptFocus |
                Qt.WindowType.WindowStaysOnBottomHint
            )
        
        super().__init__(parent, window_flags)
        
        # CRITICAL: Explicitly set parent if provided
        # This ensures proper window hierarchy on Mac
        if parent:
            self.setParent(parent)
        
        # Make transparent
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)  # Pass through clicks
        
        # Mac-specific: Set window level using AppKit
        if is_mac():
            self._setup_mac_window_level()
        
        # Regions to draw
        self.regions = []
        self.monitor_idx = 0
        self.visualize_mode = False
        self.monitor_width = 1920
        self.monitor_height = 1080
    
    def _setup_mac_window_level(self):
        """
        Setup Mac-specific window level using AppKit.
        This ensures overlay stays behind settings dialog but is still visible.
        """
        try:
            from AppKit import NSWindow, NSNormalWindowLevel
            from PyQt6.QtGui import QWindow
            
            # Get the QWindow from widget
            window = self.windowHandle()
            if window:
                # Get native window handle
                win_id = window.winId()
                if win_id:
                    # Convert to NSWindow (requires PyObjC or ctypes)
                    # For now, we'll use a simpler approach with window flags
                    # The Popup window type should handle this better
                    pass
        except ImportError:
            # AppKit not available - use Qt flags only
            pass
        except Exception as e:
            print(f"Warning: Could not setup Mac window level: {e}")
        
    def show_regions(self, mon_width, mon_height, depth_top, depth_bottom, depth_left, depth_right, pad_top, pad_bottom, pad_left, pad_right):
        """Show overlay with scanning regions (per-edge depth support)"""
        self.monitor_width = mon_width
        self.monitor_height = mon_height
        
        # Calculate regions FIRST
        self.calculate_regions(mon_width, mon_height, depth_top, depth_bottom, depth_left, depth_right, pad_top, pad_bottom, pad_left, pad_right)
        
        # Position on correct monitor - FULLSCREEN!
        # CRITICAL: Use MSS for monitor positioning to ensure consistency with capture thread
        # MSS and QApplication.screens() may have different ordering on Mac
        try:
            import mss
            with mss.mss() as sct:
                # Convert UI monitor index (0-based) to MSS index (1-based)
                # MSS[0] = All screens, MSS[1] = Primary, MSS[2] = Secondary, etc.
                mss_idx = self.monitor_idx + 1
                if mss_idx < len(sct.monitors):
                    monitor = sct.monitors[mss_idx]
                    # MSS monitor dict: {'left': x, 'top': y, 'width': w, 'height': h}
                    self.setGeometry(monitor['left'], monitor['top'], monitor['width'], monitor['height'])
                else:
                    # Fallback to primary monitor (MSS[1])
                    if len(sct.monitors) > 1:
                        monitor = sct.monitors[1]
                        self.setGeometry(monitor['left'], monitor['top'], monitor['width'], monitor['height'])
                    else:
                        # Last resort: use QApplication
                        screen = QApplication.primaryScreen()
                        geo = screen.geometry()
                        self.setGeometry(geo.x(), geo.y(), geo.width(), geo.height())
        except Exception as e:
            print(f"WARNING: Could not position overlay via MSS: {e}. Using QApplication.screens() as fallback.")
            # Fallback: Use QApplication.screens() if MSS fails
            screens = QApplication.screens()
            if self.monitor_idx < len(screens):
                screen = screens[self.monitor_idx]
                geo = screen.geometry()
                self.setGeometry(geo.x(), geo.y(), geo.width(), geo.height())
            else:
                # Fallback to primary screen
                screen = QApplication.primaryScreen()
                geo = screen.geometry()
                self.setGeometry(geo.x(), geo.y(), geo.width(), geo.height())
        
        self.visualize_mode = True
        
        # CRITICAL: On Mac, we need to ensure proper window ordering
        # Show the window first
        self.show()
        
        # CRITICAL: Window ordering on Mac
        if is_mac():
            # On Mac, child windows should automatically stay behind parent
            # But we need to ensure parent is raised after overlay is shown
            if self.parent():
                # Lower overlay first
                self.lower()
                # Then ensure parent is on top (with delay to ensure overlay is fully shown)
                QTimer.singleShot(50, self._ensure_behind_parent)
            else:
                # No parent - just lower it
                self.lower()
        else:
            # Windows/Linux: Just lower it
            self.lower()
        
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
        
    def _ensure_behind_parent(self):
        """
        Ensure overlay stays behind parent window (settings dialog).
        Called after show() to fix window ordering on Mac.
        """
        if not self.isVisible():
            return
        
        # Lower overlay
        self.lower()
        
        # If we have a parent, ensure parent is raised
        if self.parent():
            try:
                parent_widget = self.parent()
                if hasattr(parent_widget, 'raise_'):
                    parent_widget.raise_()
                if hasattr(parent_widget, 'activateWindow'):
                    parent_widget.activateWindow()
            except Exception as e:
                print(f"Warning: Could not raise parent window: {e}")
    
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
