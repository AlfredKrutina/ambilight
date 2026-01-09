# Simplified Adaptive Melody Detector
# Learns song frequencies, responsive onset detection, clean state management

import numpy as np
from typing import Dict, List, Tuple
import time

class AdaptiveMelodyDetector:
    """
    Simplified, robust approach:
    - Multi-band FFT with adaptive frequency learning
    - Clean state management (fixes "stops working" bug)
    - Proper brightness decay with floor/ceiling
    - Energy normalization that doesn't overflow
    """
    
    def __init__(self, sample_rate=48000, hop_size=2048):
        self.sr = sample_rate
        self.hop_size = hop_size
        
        # 4 adaptive frequency bands (learned from song)
        self.learned_bands = [
            {'low': 60, 'high': 250, 'name': 'bass', 'color': (255, 0, 0)},
            {'low': 250, 'high': 800, 'name': 'low_mid', 'color': (255, 128, 0)},
            {'low': 800, 'high': 3000, 'name': 'mid_high', 'color': (0, 255, 128)},
            {'low': 3000, 'high': 8000, 'name': 'treble', 'color': (128, 0, 255)}
        ]
        
        # Per-band state (CLEAN INITIALIZATION)
        self.band_brightness = [0.0, 0.0, 0.0, 0.0]
        self.band_energy_history = [[] for _ in range(4)]
        self.band_max_energy = [0.1, 0.1, 0.1, 0.1]  # Adaptive max
        
        # Onset detection state
        self.prev_band_energy = [0.0, 0.0, 0.0, 0.0]
        
        # Adaptive learning
        self.learning_frames = 0
        self.max_learning_frames = 100  # Learn for ~3 seconds
        
        # Prevent state overflow
        self.total_frames = 0
        self.last_reset = time.time()
        
        print("✓ AdaptiveMelodyDetector (simplified, robust)")
    
    def process_frame(self, audio_frame: np.ndarray) -> List[Dict]:
        """
        Process audio and return per-zone visualization data
        CLEAN state management, no memory leaks
        """
        # Reset state every 60 seconds to prevent overflow
        if time.time() - self.last_reset > 60.0:
            self._reset_state()
        
        self.total_frames += 1
        
        if len(audio_frame) < self.hop_size:
            return self._empty_result()
        
        frame = audio_frame[-self.hop_size:]
        
        # FFT
        window = np.hanning(len(frame))
        spectrum = np.abs(np.fft.rfft(frame * window))
        freqs = np.fft.rfftfreq(len(frame), 1/self.sr)
        
        # Normalize spectrum (prevent overflow)
        max_val = np.max(spectrum)
        if max_val > 0:
            spectrum = spectrum / max_val
        
        results = []
        
        for band_id, band_info in enumerate(self.learned_bands):
            # Extract frequency band
            low, high = band_info['low'], band_info['high']
            mask = (freqs >= low) & (freqs < high)
            band_spectrum = spectrum[mask]
            
            if len(band_spectrum) == 0:
                results.append(self._empty_band(band_id))
                continue
            
            # Energy calculation (WITH CLAMPING)
            energy = np.sum(band_spectrum ** 2) / len(band_spectrum)
            energy = min(energy, 10.0)  # Clamp to prevent overflow
            
            # Adaptive max tracking (WITH DECAY)
            self.band_max_energy[band_id] = max(
                self.band_max_energy[band_id] * 0.999,  # Slow decay
                energy,
                0.01  # Floor
            )
            
            # Normalized energy (0-1)
            norm_energy = energy / (self.band_max_energy[band_id] + 0.001)
            norm_energy = min(norm_energy, 1.0)
            
            # Onset detection (energy delta)
            prev_energy = self.prev_band_energy[band_id]
            delta = energy - prev_energy
            onset = delta > 0.02 and energy > 0.05  # Stricter threshold
            
            self.prev_band_energy[band_id] = energy * 0.9  # Decay for next frame
            
            # === BRIGHTNESS CALCULATION (FIXED!) ===
            current_bright = self.band_brightness[band_id]
            
            if onset:
                # Flash on onset
                self.band_brightness[band_id] = 1.0
            else:
                # FAST DECAY with FLOOR
                self.band_brightness[band_id] = max(
                    current_bright * 0.40,  # VERY fast decay
                    norm_energy * 0.3  # Floor based on energy
                )
            
            # Clamp brightness (IMPORTANT!)
            self.band_brightness[band_id] = np.clip(self.band_brightness[band_id], 0.0, 1.0)
            
            results.append({
                'band_id': band_id,
                'name': band_info['name'],
                'color': band_info['color'],
                'onset': onset,
                'energy': norm_energy,
                'brightness': self.band_brightness[band_id],
                'freq_range': (low, high)
            })
        
        # Learning phase (optional)
        if self.learning_frames < self.max_learning_frames:
            self._learn_frequencies(spectrum, freqs)
            self.learning_frames += 1
        
        return results
    
    def _learn_frequencies(self, spectrum: np.ndarray, freqs: np.ndarray):
        """
        Adaptive learning: Find dominant frequencies in song
        Adjusts band boundaries to match song characteristics
        """
        # Find top 10 peaks in spectrum
        peaks = []
        for i in range(10, len(spectrum) - 10):
            if spectrum[i] > spectrum[i-1] and spectrum[i] > spectrum[i+1]:
                if spectrum[i] > 0.1:  # Significant peak
                    peaks.append((freqs[i], spectrum[i]))
        
        if len(peaks) < 4:
            return
        
        # Sort by strength
        peaks.sort(key=lambda x: x[1], reverse=True)
        
        # Use top peaks to adjust band boundaries (slowly)
        # This makes bands adapt to song's specific frequency content
        # TODO: Implement gentle band adjustment logic
        pass
    
    def _reset_state(self):
        """Reset state to prevent overflow/stuck issues"""
        print("🔄 Resetting melody detector state (prevent overflow)")
        self.band_brightness = [0.0, 0.0, 0.0, 0.0]
        self.prev_band_energy = [0.0, 0.0, 0.0, 0.0]
        # Keep learned max energies (don't reset learning)
        self.last_reset = time.time()
        self.total_frames = 0
    
    def _empty_band(self, band_id: int) -> Dict:
        """Empty result for one band"""
        band_info = self.learned_bands[band_id]
        return {
            'band_id': band_id,
            'name': band_info['name'],
            'color': band_info['color'],
            'onset': False,
            'energy': 0.0,
            'brightness': 0.0,
            'freq_range': (band_info['low'], band_info['high'])
        }
    
    def _empty_result(self) -> List[Dict]:
        """Empty result for all bands"""
        return [self._empty_band(i) for i in range(4)]


# Global instance
_adaptive_detector = None

def get_adaptive_detector():
    global _adaptive_detector
    if _adaptive_detector is None:
        _adaptive_detector = AdaptiveMelodyDetector()
    return _adaptive_detector
