"""
Ultra Saturation Implementation
Boosts color saturation to prevent washed-out whites in low-saturation scenes.
Add to capture.py after color extraction.
"""

import colorsys

def apply_ultra_saturation(rgb, ultra_saturation_amount=2.5):
    """
    Apply aggressive saturation boost to prevent washed-out colors.
    
    Args:
        rgb: Input RGB tuple (0-255)
        ultra_saturation_amount: Boost multiplier (1.0 = normal, 2.5 = very vibrant)
    
    Returns:
        Saturated RGB tuple (0-255)
    """
    r, g, b = rgb
    
    # Convert to HSV
    r_norm, g_norm, b_norm = r / 255.0, g / 255.0, b / 255.0
    h, s, v = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
    
    # Boost saturation aggressively
    s = min(s * ultra_saturation_amount, 1.0)
    
    # Convert back to RGB
    r_new, g_new, b_new = colorsys.hsv_to_rgb(h, s, v)
    
    return (int(r_new * 255), int(g_new * 255), int(b_new * 255))
