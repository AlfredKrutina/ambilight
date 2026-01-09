from PyQt6.QtWidgets import (
    QWidget, QPushButton, QColorDialog, QHBoxLayout, QLabel, 
    QFrame, QVBoxLayout, QToolButton, QScrollArea, QSizePolicy,
    QListWidget, QAbstractItemView, QSlider, QStyle, QStyleOptionSlider
)
from PyQt6.QtCore import Qt, pyqtSignal, QSize, QRect, QEvent, QObject
from PyQt6.QtGui import QColor, QPainter, QBrush, QStandardItemModel, QAction

class ColorPickerButton(QPushButton):
    colorChanged = pyqtSignal(QColor)

    def __init__(self, initial_color=QColor(255, 255, 255), parent=None):
        super().__init__(parent)
        self.setFixedSize(60, 30)
        self.color = initial_color
        self.clicked.connect(self.pick_color)
        self.update_style()

    def update_style(self):
        # Determine text color based on brightness
        text_col = "black" if self.color.lightness() > 128 else "white"
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: {self.color.name()};
                border: 2px solid #555;
                border-radius: 6px;
                color: {text_col};
                font-weight: bold;
            }}
            QPushButton:hover {{ border: 2px solid white; }}
        """)
        # self.setText(self.color.name().upper())

    def pick_color(self):
        c = QColorDialog.getColor(self.color, self, "Select Color")
        if c.isValid():
            self.color = c
            self.update_style()
            self.colorChanged.emit(c)
            
    def set_color(self, color):
        self.color = QColor(color)
        self.update_style()

class CollapsibleBox(QWidget):
    def __init__(self, title="", parent=None):
        super(CollapsibleBox, self).__init__(parent)

        self.toggle_button = QToolButton(text=title, checkable=True, checked=False)
        self.toggle_button.setStyleSheet("QToolButton { border: none; font-weight: bold; text-align: left; padding: 5px; background-color: rgba(255,255,255,10); border-radius: 4px; } QToolButton:hover { background-color: rgba(255,255,255,20); }")
        self.toggle_button.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.toggle_button.setArrowType(Qt.ArrowType.RightArrow)
        self.toggle_button.pressed.connect(self.on_pressed)

        self.content_area = QScrollArea()
        self.content_area.setMaximumHeight(0)
        self.content_area.setMinimumHeight(0)
        self.content_area.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.content_area.setFrameShape(QFrame.Shape.NoFrame)
        self.content_area.setStyleSheet("background: transparent;")

        lay = QVBoxLayout(self)
        lay.setSpacing(0)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.addWidget(self.toggle_button)
        lay.addWidget(self.content_area)

        # Animation logic would go here (optional), currently simple toggle

    def set_content_layout(self, layout):
        lay = self.content_area.layout()
        del lay
        self.content_area.setLayout(layout)
        collapsed_height = self.sizeHint().height() - self.content_area.maximumHeight()
        content_height = layout.sizeHint().height()
        
        # Self-adjust logic would be complex, simpler to just wrap a widget:
        w = QWidget()
        w.setLayout(layout)
        self.content_area.setWidget(w)
        self.content_area.setWidgetResizable(True)
        self._content_height = content_height

    def on_pressed(self):
        checked = self.toggle_button.isChecked()
        self.toggle_button.setArrowType(Qt.ArrowType.DownArrow if not checked else Qt.ArrowType.RightArrow)
        
        # Simple Toggle
        if not checked:
            self.content_area.setMaximumHeight(1000) # Expand
            self.content_area.setMinimumHeight(100) # Ensure visibility
        else:
            self.content_area.setMaximumHeight(0)
            self.content_area.setMinimumHeight(0)

class RangeSlider(QSlider):
    """ A slider with two handles for min/max selection """
    # Placeholder for complex implementation. 
    # For now ensuring existing logic works, this is a placeholder.
    # Implementing a full dual-handle slider in PyQt is verbose.
    # Using specific separate sliders is safer for now unless library used.
    pass

class DraggableList(QListWidget):
    """ List widget that supports drag-drop reordering """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.setAcceptDrops(True)
        
    def get_items(self):
        return [self.item(i).text() for i in range(self.count())]

class NoScrollFilter(QObject):
    """Event filter to block scroll wheel unless widget has focus"""
    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.Wheel:
            # Only allow scroll if widget has focus
            if not obj.hasFocus():
                event.ignore()
                return True # Event handled (blocked)
        return super().eventFilter(obj, event)
