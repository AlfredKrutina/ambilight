
# src/ui/themes.py

FONT_MAIN = "font-family: 'Segoe UI', 'Roboto', 'San Francisco', sans-serif;"

# --- PALETTES ---

PALETTES = {
    "dark": {
        "bg_main": "rgba(18, 18, 18, 240)", # Semi-transparent
        "bg_card": "rgba(30, 30, 30, 240)",
        "bg_input": "#2C2C2E",
        "border": "#38383A",
        "accent": "#0A84FF",
        "accent_hover": "#409CFF",
        "text_main": "#FFFFFF",
        "text_sec": "#A1A1A6",
        "selection": "#0A84FF"
    },
    "light": {
        "bg_main": "#F5F5F7",
        "bg_card": "#FFFFFF",
        "bg_input": "#E5E5EA",
        "border": "#D1D1D6",
        "accent": "#007AFF",
        "accent_hover": "#0051A8",
        "text_main": "#000000",
        "text_sec": "#6E6E73",
        "selection": "#007AFF"
    },
    "brown": {
        "bg_main": "#F1EEE9",     # B&O Light Leather / Premium Beige
        "bg_card": "#FDFBF7",     # Creamy Card
        "bg_input": "#E8E4DC",    # Subtle Input
        "border": "#C7B299",      # Tan Leather Border
        "accent": "#8D6E63",      # Classic Leather Brown
        "accent_hover": "#A1887F",
        "text_main": "#4E342E",   # Deep Espresso Text
        "text_sec": "#8D6E63",    # Lighter Leather Text
        "selection": "#A1887F"
    },

    "blue": {
        "bg_main": "#0F172A",     # Slate 900
        "bg_card": "#1E293B",     # Slate 800
        "bg_input": "#334155",    # Slate 700
        "border": "#475569",      # Slate 600
        "accent": "#38BDF8",      # Sky Blue 400
        "accent_hover": "#0EA5E9",# Sky Blue 500
        "text_main": "#F1F5F9",   # Slate 100
        "text_sec": "#94A3B8",    # Slate 400
        "selection": "#0284C7"
    },
    "snowrunner": {
        "bg_main": "#1C2329",     # Dark Industrial Blue-Gray
        "bg_card": "#263238",     # Blue Gray Card
        "bg_input": "#101519",    # Darker Input
        "border": "#546E7A",      # Steel Blue Border
        "accent": "#FF9800",      # Blaze Orange (Truck/Logo)
        "accent_hover": "#FFB74D",# Light Orange
        "text_main": "#ECEFF1",   # Cool White
        "text_sec": "#90A4AE",    # Cool Gray
        "selection": "#FF9800"
    }
}

# --- TEMPLATE ---

STYLE_TEMPLATE = """
    QWidget {
        background-color: %bg_main%;
        color: %text_main%;
        selection-background-color: %selection%;
        selection-color: white;
        """ + FONT_MAIN + """
        font-size: 14px;
    }

    QDialog { background-color: %bg_main%; }

    /* --- CARDS / GROUPS --- */
    QGroupBox {
        background-color: %bg_card%;
        border: 1px solid %border%;
        border-radius: 8px;
        margin-top: 12px;
        padding: 15px;
        padding-top: 25px;
    }
    QGroupBox::title {
        subcontrol-origin: margin;
        subcontrol-position: top left;
        padding: 0 8px;
        margin-left: 10px;
        background-color: %bg_main%; /* Mask lines behind text */
        color: %accent%;
        font-weight: bold;
        font-size: 13px;
        border-radius: 4px;
    }

    /* --- BUTTONS --- */
    QPushButton {
        background-color: %bg_input%;
        color: %text_main%;
        border: 1px solid %border%;
        border-radius: 6px;
        padding: 8px 16px;
        font-weight: 600;
    }
    QPushButton:hover {
        border-color: %accent%;
    }
    QPushButton:checked {
        background-color: %accent%;
        border-color: %accent%;
        color: white; /* Always white on accent */
    }
    QPushButton#primaryButton {
        background-color: %accent%;
        border: none;
        color: white; /* Primary buttons usually strict accent */
    }
    QPushButton#primaryButton:hover {
        background-color: %accent_hover%;
    }
    
    /* Button Text Color Safety for Light Themes with Dark Accents */
    /* If theme is 'brown', text is dark. Accent is dark. So white text on accent is correct. */

    /* --- INPUTS --- */
    QComboBox, QSpinBox, QLineEdit {
        background-color: %bg_input%;
        border: 1px solid %border%;
        border-radius: 6px;
        padding: 6px 10px;
        color: %text_main%;
        min-height: 22px;
    }
    QComboBox:hover, QSpinBox:hover {
        border-color: %accent%;
    }
    QComboBox::drop-down { border: 0px; width: 25px; }
    
    QComboBox QAbstractItemView {
        background-color: %bg_card%;
        border: 1px solid %border%;
        color: %text_main%;
        selection-background-color: %accent%;
        outline: none;
    }

    /* --- TABS --- */
    QTabWidget::pane { border: 0; margin-top: 10px; }
    QTabBar::tab {
        background: %bg_main%;
        color: %text_sec%;
        padding: 8px 16px;
        margin-right: 4px;
        border-bottom: 2px solid transparent;
        font-weight: 600;
    }
    QTabBar::tab:selected {
        color: %accent%;
        border-bottom: 2px solid %accent%;
    }
    QTabBar::tab:hover:!selected {
        color: %text_main%;
    }

    /* --- SCROLLBARS --- */
    QScrollBar:vertical {
        border: none;
        background: transparent;
        width: 8px;
        margin: 0;
    }
    QScrollBar::handle:vertical {
        background: %border%;
        min-height: 20px;
        border-radius: 4px;
    }
    QScrollBar::handle:vertical:hover { background: %accent%; }
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0px; }

    /* --- SLIDERS --- */
    QSlider { background: transparent; min-height: 26px; }
    QSlider::groove:horizontal {
        border-radius: 3px;
        height: 6px;
        background: %bg_input%;
    }
    QSlider::handle:horizontal {
        background: #FFFFFF;
        width: 18px;
        height: 18px;
        margin: -6px 0;
        border-radius: 9px;
        border: 1px solid %border%;
    }
    QSlider::handle:horizontal:hover {
        border-color: %accent%;
        background: %accent_hover%; 
    }

    /* --- MISC --- */
    QCheckBox { spacing: 8px; color: %text_main%; background: transparent; }
    QRadioButton { background: transparent; color: %text_main%; }
    QCheckBox::indicator {
        width: 18px; height: 18px;
        border-radius: 4px;
        border: 1px solid %border%;
        background: %bg_input%;
    }
    QCheckBox::indicator:checked {
        background-color: %accent%;
        border-color: %accent%;
    }

    QLabel { color: %text_main%; background: transparent; }
    QLabel#secondary { color: %text_sec%; font-size: 12px; }
    
    QToolTip {
        color: %text_main%;
        background-color: %bg_card%;
        border: 1px solid %border%;
    }
"""

def get_theme(theme_name: str) -> str:
    """Returns the QSS stylesheet for the given theme name"""
    palette = PALETTES.get(theme_name, PALETTES["dark"]) # Default to dark
    
    style = STYLE_TEMPLATE
    for key, value in palette.items():
        style = style.replace(f"%{key}%", value)
        
    return style
