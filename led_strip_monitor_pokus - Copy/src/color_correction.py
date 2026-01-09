"""
Color Correction Module
Applies per-channel calibration to match LED colors to monitor colors.
"""

import numpy as np
from typing import Tuple, Dict, List


def apply_color_correction(rgb: Tuple[int, int, int], screen_mode_config) -> Tuple[int, int, int]:
    """
    Apply color calibration to RGB value for accurate LED output.
    Now uses active profile from calibration_profiles.
    
    Args:
        rgb: Input RGB tuple (0-255)
        screen_mode_config: ScreenModeSettings object with calibration_profiles
    
    Returns:
        Corrected RGB tuple (0-255)
    """
    # Get active profile calibration
    calibration = None
    
    if hasattr(screen_mode_config, 'calibration_profiles') and screen_mode_config.calibration_profiles:
        active_profile = getattr(screen_mode_config, 'active_calibration_profile', 'Default')
        calibration = screen_mode_config.calibration_profiles.get(active_profile)
    
    # Fallback to old single calibration for backward compat
    if not calibration and hasattr(screen_mode_config, 'color_calibration'):
        calibration = screen_mode_config.color_calibration
    
    if not calibration or not calibration.get('enabled', False):
        return rgb
    
    r, g, b = rgb
    corrected = []
    
    gain = calibration.get('gain', [1.0, 1.0, 1.0])
    gamma = calibration.get('gamma', [1.0, 1.0, 1.0])
    offset = calibration.get('offset', [0, 0, 0])
    
    for i, val in enumerate([r, g, b]):
        # Normalize to 0-1
        normalized = val / 255.0
        
        # Apply gamma correction (non-linear response)
        # gamma > 1.0 = darker LEDs need more brightness
        # gamma < 1.0 = brighter LEDs need less brightness
        gamma_corrected = normalized ** (1.0 / gamma[i]) if gamma[i] > 0 else normalized
        
        # Apply gain (linear scaling per channel)
        scaled = gamma_corrected * gain[i]
        
        # Apply offset (black level correction)
        final = scaled + (offset[i] / 255.0)
        
        # Clamp to valid range
        corrected.append(int(np.clip(final * 255, 0, 255)))
    
    return tuple(corrected)


def calculate_calibration(test_results: List[Dict]) -> Dict:
    """
    Calculate per-channel color corrections from user test results.
    
    Args:
        test_results: List of dicts with 'sent' and 'perceived' RGB tuples
            Example: [
                {"sent": (255, 0, 0), "perceived": (220, 15, 5)},  # Red
                {"sent": (0, 255, 0), "perceived": (10, 235, 8)},  # Green
                {"sent": (0, 0, 255), "perceived": (5, 8, 250)},   # Blue
                {"sent": (255, 255, 255), "perceived": (230, 240, 245)} # White
            ]
    
    Returns:
        Calibration dict with 'gain', 'gamma', 'offset' arrays
    """
    calibration = {
        'gain': [1.0, 1.0, 1.0],
        'gamma': [1.0, 1.0, 1.0],
        'offset': [0, 0, 0],
        'enabled': True
    }
    
    # Process each channel (R, G, B)
    for ch_idx in range(3):
        # Extract single-color test (where sent value in this channel is max)
        primary_test = None
        for test in test_results[:3]:  # Red, Green, Blue tests
            if test['sent'][ch_idx] >= 250:  # Primary channel active
                primary_test = test
                break
        
        if not primary_test:
            continue
        
        sent_val = primary_test['sent'][ch_idx]
        perceived_val = primary_test['perceived'][ch_idx]
        
        # 1. Calculate GAIN (linear scaling)
        # If perceived < sent → LEDs too dim → gain < 1.0
        # If perceived > sent → LEDs too bright → gain > 1.0
        if sent_val > 0:
            calibration['gain'][ch_idx] = sent_val / max(perceived_val, 1)
        
        # 2. Calculate GAMMA (non-linear response)
        # Estimate from brightness difference
        sent_brightness = sent_val / 255.0
        perceived_brightness = perceived_val / 255.0
        
        if perceived_brightness > 0.01:
            # gamma = log(output) / log(input)
            # If LEDs appear darker → need higher gamma
            # If LEDs appear brighter → need lower gamma
            estimated_gamma = np.log(perceived_brightness) / np.log(sent_brightness)
            
            # Clamp gamma to reasonable range
            calibration['gamma'][ch_idx] = float(np.clip(estimated_gamma, 0.5, 2.5))
        
        # 3. Calculate OFFSET (black level / color bleed)
        # Color bleed in other channels indicates offset needed
        other_channels = [i for i in range(3) if i != ch_idx]
        offset_sum = 0
        
        for other_ch in other_channels:
            # If we see color in channels that should be 0, that's bleed
            bleed = primary_test['perceived'][other_ch]
            if bleed > 5:  # Threshold for actual bleed vs noise
                offset_sum += bleed
        
        # Average bleed becomes negative offset for this channel
        calibration['offset'][ch_idx] = -int(offset_sum / 2)
    
    # 4. Validate with WHITE test (optional refinement)
    if len(test_results) >= 4:
        white_test = test_results[3]
        # Could use white to fine-tune overall balance, but simple approach is enough
    
    return calibration


def generate_test_colors() -> List[Tuple[str, Tuple[int, int, int]]]:
    """
    Generate list of test colors for calibration.
    
    Returns:
        List of (name, RGB) tuples
    """
    return [
        ("Red", (255, 0, 0)),
        ("Green", (0, 255, 0)),
        ("Blue", (0, 0, 255)),
        ("White", (255, 255, 255))
    ]


def validate_calibration(calibration: Dict) -> bool:
    """
    Validate calibration data is within reasonable bounds.
    
    Args:
        calibration: Calibration dict
    
    Returns:
        True if valid, False otherwise
    """
    if not calibration:
        return False
    
    # Check gain bounds
    for gain in calibration.get('gain', []):
        if gain < 0.1 or gain > 3.0:
            return False
    
    # Check gamma bounds
    for gamma in calibration.get('gamma', []):
        if gamma < 0.3 or gamma > 3.0:
            return False
    
    # Check offset bounds
    for offset in calibration.get('offset', []):
        if abs(offset) > 50:
            return False
    
    return True
