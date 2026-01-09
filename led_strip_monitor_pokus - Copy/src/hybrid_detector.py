# Hybrid AI + Real-time Approach
# AI stems for routing, FFT for immediate response

import numpy as np
from typing import Dict, List, Tuple

class HybridMelodyDetector:
    """
    Combines AI stem separation (slow, accurate) with 
    real-time FFT analysis (fast, responsive)
    
    AI: Which instruments are in which zones?
    FFT: When do they flash? (immediate onset)
    """
    
    def __init__(self, sample_rate=48000):
        self.sr = sample_rate
        
        # Real-time frequency bands for immediate onset detection
        self.freq_bands = [
            (60, 350, 'bass_range'),      # Bass instruments
            (350, 800, 'low_vocal_range'), # Male vocals, low instruments
            (800, 3000, 'mid_vocal_range'), # Female vocals, most instruments
            (3000, 8000, 'high_range')     # Percussion, highs
        ]
        
        # FFT state
        self.prev_spectrum = None
        self.band_energies = [0.0] * 4
        self.band_brightness = [0.3] * 4
        
        # AI routing hints (updated slowly by stem separator)
        self.ai_routing = {
            'vocals': None,  # Which band ID (0-3)
            'bass': None,
            'drums': None,
            'other': None
        }
        
        print("✓ HybridMelodyDetector (AI routing + FFT response)")
    
    def update_ai_routing(self, stem_analysis: Dict):
        """
        Update routing from AI stems (called ~every 300ms)
        Determines which frequency bands belong to which instruments
        """
        # Analyze which frequency ranges are active in each stem
        for stem_name, data in stem_analysis.items():
            if data['energy'] > 0.2:  # Stem is active
                # Map stem to likely frequency band
                if stem_name == 'vocals':
                    # Vocals usually mid-high
                    self.ai_routing['vocals'] = 2  # Mid vocal range
                elif stem_name == 'bass':
                    # Bass is low
                    self.ai_routing['bass'] = 0  # Bass range
                elif stem_name == 'drums':
                    # Drums have strong high transients
                    self.ai_routing['drums'] = 3  # High range
                elif stem_name == 'other':
                    # Other instruments mid
                    self.ai_routing['other'] = 1  # Low vocal range
    
    def process_frame_realtime(self, audio_frame: np.ndarray) -> List[Dict]:
        """
        Real-time FFT analysis for immediate response
        Returns per-zone data with instant onset detection
        """
        if len(audio_frame) < 2048:
            return self._empty_zones()
        
        # FFT
        spectrum = np.abs(np.fft.rfft(audio_frame * np.hanning(len(audio_frame))))
        spectrum = spectrum / (np.max(spectrum) + 1e-10)
        freqs = np.fft.rfftfreq(len(audio_frame), 1/self.sr)
        
        results = []
        
        for band_id, (low, high, name) in enumerate(self.freq_bands):
            # Extract frequency band
            mask = (freqs >= low) & (freqs < high)
            band_spectrum = spectrum[mask]
            
            # Spectral flux onset (IMMEDIATE)
            if self.prev_spectrum is not None:
                prev_band = self.prev_spectrum[mask]
                diff = band_spectrum - prev_band
                flux = np.sum(np.maximum(diff, 0))
                onset = flux > 0.02
            else:
                onset = False
            
            # Energy
            energy = np.sum(band_spectrum ** 2)
            self.band_energies[band_id] = energy
            
            # Brightness with FAST decay
            if onset:
                self.band_brightness[band_id] = 1.0
            else:
                self.band_brightness[band_id] *= 0.45  # VERY FAST decay
            
            # Determine which stem this band belongs to (from AI routing)
            stem_type = self._get_stem_for_band(band_id)
            
            results.append({
                'band_id': band_id,
                'stem_type': stem_type,  # From AI
                'onset': onset,           # From FFT (instant!)
                'energy': energy,
                'brightness': self.band_brightness[band_id]
            })
        
        self.prev_spectrum = spectrum
        return results
    
    def _get_stem_for_band(self, band_id: int) -> str:
        """Get which instrument type this band represents (from AI routing)"""
        # Reverse lookup: which stem uses this band?
        for stem_name, assigned_band in self.ai_routing.items():
            if assigned_band == band_id:
                return stem_name
        
        # Default mapping if AI hasn't decided yet
        defaults = ['bass', 'other', 'vocals', 'drums']
        return defaults[band_id]
    
    def _empty_zones(self) -> List[Dict]:
        return [
            {'band_id': i, 'stem_type': 'unknown', 'onset': False, 'energy': 0.0, 'brightness': 0.3}
            for i in range(4)
        ]


# Global instance
_hybrid_detector = None

def get_hybrid_detector():
    global _hybrid_detector
    if _hybrid_detector is None:
        _hybrid_detector = HybridMelodyDetector()
    return _hybrid_detector
