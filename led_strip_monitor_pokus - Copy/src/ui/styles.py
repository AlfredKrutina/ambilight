
# src/ui/styles.py

DARK_THEME = """
/* --- GLOBAL RESET --- */
QWidget {
    background-color: #1c1c1e; /* Apple Dark Background */
    color: #ffffff;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 14px;
    selection-background-color: #0a84ff;
}

QDialog, QMainWindow {
    background-color: #000000; /* Deep black for main window */
}

/* --- LABELS --- */
QLabel {
    color: #f2f2f7; /* Apple Label Color */
}
QLabel#title {
    font-size: 24px;
    font-weight: 600;
    color: #ffffff;
    margin-bottom: 15px;
}
QLabel#status {
    font-size: 15px; 
    color: #8e8e93; /* Secondary Label */
}
QLabel#serial_ok {
    color: #30d158; /* Apple Green */
    font-weight: 500;
}
QLabel#serial_err {
    color: #ff453a; /* Apple Red */
    font-weight: 500;
}

/* --- BUTTONS --- */
QPushButton {
    background-color: #2c2c2e; /* Secondary System Fill */
    border: none;
    border-radius: 10px;
    padding: 10px 20px;
    color: #0a84ff; /* System Blue Text */
    font-weight: 500;
}
QPushButton:hover {
    background-color: #3a3a3c;
}
QPushButton:pressed {
    background-color: #1c1c1e;
    color: #007aff;
}
QPushButton#primary {
    background-color: #007aff; /* Apple System Blue */
    color: #ffffff;
}
QPushButton#primary:hover {
    background-color: #0062cc;
}
QPushButton#primary:pressed {
    background-color: #0051a8;
}

/* --- INPUTS --- */
QComboBox, QSpinBox {
    background-color: #2c2c2e;
    border: 1px solid transparent;
    border-radius: 8px;
    padding: 6px 12px;
    color: #ffffff;
    min-height: 20px;
}
QComboBox:hover, QSpinBox:hover {
    background-color: #3a3a3c;
}
QComboBox::drop-down {
    border: none;
    padding-right: 10px;
}
QComboBox QAbstractItemView {
    background-color: #2c2c2e;
    border-radius: 8px;
    outline: none;
    padding: 5px;
}
QComboBox::item {
    border-radius: 4px;
    padding: 5px;
}
QComboBox::item:selected {
    background-color: #0a84ff;
}

/* --- SLIDERS --- */
QSlider::groove:horizontal {
    border: none;
    height: 4px;
    background: #48484a; /* System Gray 4 */
    margin: 2px 0;
    border-radius: 2px;
}
QSlider::sub-page:horizontal {
    background: #0a84ff;
    border-radius: 2px;
}
QSlider::handle:horizontal {
    background: #ffffff;
    border: 0.5px solid #000000; /* Subtle border for shadow effect */
    width: 20px;
    height: 20px;
    margin: -8px 0;
    border-radius: 10px; /* Perfect circle */
}
QSlider::handle:horizontal:hover {
    background: #f2f2f7;
}

/* --- CHECKBOX --- */
QCheckBox {
    spacing: 8px;
    color: #ffffff;
}
QCheckBox::indicator {
    width: 18px;
    height: 18px;
    background-color: #2c2c2e;
    border-radius: 4px;
}
QCheckBox::indicator:checked {
    background-color: #30d158;
    image: none; /* Can add tick icon here if asset available */
}

/* --- MENU --- */
QMenu {
    background-color: #2c2c2e; /* Apple Elevated */
    border: 1px solid #3a3a3c;
    border-radius: 10px;
    padding: 5px 0;
}
QMenu::item {
    padding: 8px 25px;
    color: #ffffff;
}
QMenu::item:selected {
    background-color: #0a84ff;
    border-radius: 4px;
}

/* --- GROUP BOX --- */
QGroupBox {
    background-color: #1c1c1e;
    border: none;
    border-radius: 12px;
    margin-top: 25px; /* Leave space for title */
    font-weight: 600;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    padding: 0 10px;
    color: #8e8e93; /* Uppercase section header style */
    text-transform: uppercase;
    font-size: 11px;
    letter-spacing: 1px;
}
"""
