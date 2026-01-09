
import numpy as np
import time

class BeatDetector:
    """Detekuj beaty ze spektra (Sudden energy spike)"""
    
    def __init__(self, history_size=43, threshold_multiplier=1.3):  
        # ~1 sec @ 44.1kHz buffer size
        self.history = []
        self.history_size = history_size
        self.threshold_multiplier = threshold_multiplier
    
    def detect(self, frequency_band_energy):
        """
        Detekuj beat v jednom pásmu
        Vrátí: (is_beat, intensity)
        """
        self.history.append(frequency_band_energy)
        if len(self.history) > self.history_size:
            self.history.pop(0)
        
        # Očekávaná energie = průměr historie
        if not self.history:
             expected = 0.0
        else:
             expected = np.mean(self.history)
        
        # Beat = když je aktuální > threshold * průměr
        # Add small epsilon to prevent div by zero or noise triggers
        if expected < 0.0001:
            expected = 0.0001
            
        is_beat = frequency_band_energy > (expected * self.threshold_multiplier)
        
        # Return intensity 0-1 (normalized by expect * 2)
        intensity = min(1.0, frequency_band_energy / (expected * 2))
        
        return is_beat, intensity

class AudioAnalyzer:
    """
    Realtime audio analysis pro LED sync using FFT
    Splits audio into Bass, Mid, High bands.
    """
    
    def __init__(self, sample_rate=48000):
        self.sr = sample_rate
        
        # Beat detection (7 bands)
        self.beat_detectors = {
            'sub_bass':   BeatDetector(threshold_multiplier=1.4), 
            'bass':       BeatDetector(threshold_multiplier=1.4),
            'low_mid':    BeatDetector(threshold_multiplier=1.5),
            'mid':        BeatDetector(threshold_multiplier=1.5),
            'high_mid':   BeatDetector(threshold_multiplier=1.5),
            'presence':   BeatDetector(threshold_multiplier=1.7), # Snaps
            'brilliance': BeatDetector(threshold_multiplier=1.9), # Sparkle
        }
        
        # Smoothing buffers
        self.smooth_vals = {
            'sub_bass': 0.0, 'bass': 0.0, 'low_mid': 0.0, 
            'mid': 0.0, 'high_mid': 0.0, 'presence': 0.0, 'brilliance': 0.0
        }
        
        self.alpha_attack = 0.6
        self.alpha_decay = 0.15 
        
        self.global_peak = 0.5
        self.peak_decay = 0.9992
    
    def process_audio_frame(self, audio_data: np.ndarray):
        if len(audio_data) == 0:
            return self._empty_analysis()

        # 1. LOUDNESS
        try:
            rms = np.sqrt(np.mean(audio_data ** 2))
        except:
            rms = 0.0
        loudness = min(1.0, rms / 0.5)

        # 2. FFT
        try:
            windowed_audio = audio_data * np.hanning(len(audio_data))
            fft_result = np.fft.rfft(windowed_audio)
            magnitude = np.abs(fft_result) / len(audio_data) * 2
            freqs = np.fft.rfftfreq(len(audio_data), 1/self.sr)
            
            # 3. EXTRACT 7 BANDS ("Super Resolution")
            # 1. Sub-Bass (20-60 Hz): Rumble
            # 2. Bass (60-150 Hz): Kick/Bass
            # 3. Low-Mid (150-400 Hz): Warmth
            # 4. Mid (400-1000 Hz): Instruments
            # 5. High-Mid (1000-2500 Hz): Vocals
            # 6. Presence (2500-6000 Hz): Definition
            # 7. Brilliance (6000-20000 Hz): Air
            
            masks = {
                'sub_bass':   (freqs >= 20) & (freqs < 60),
                'bass':       (freqs >= 60) & (freqs < 150),
                'low_mid':    (freqs >= 150) & (freqs < 400),
                'mid':        (freqs >= 400) & (freqs < 1000),
                'high_mid':   (freqs >= 1000) & (freqs < 2500),
                'presence':   (freqs >= 2500) & (freqs < 6000),
                'brilliance': (freqs >= 6000)
            }
            
            energies = {}
            max_e = 0.0
            for name, mask in masks.items():
                e = np.sum(magnitude[mask])
                energies[name] = e
                if e > max_e: max_e = e

            # --- SMART DYNAMICS ---
            if max_e > self.global_peak:
                 self.global_peak = max_e
            else:
                 self.global_peak *= self.peak_decay
            
            if self.global_peak < 0.1: self.global_peak = 0.1

            # Normalize & Gamma
            final_vals = {}
            for name, e in energies.items():
                norm = min(1.0, e / self.global_peak)
                # Variable Gamma: Lower freqs are naturally stronger, high freqs need boost
                gamma = 1.3
                if 'sub' in name or 'bass' in name: gamma = 1.2
                if 'presence' in name or 'brilliance' in name: gamma = 1.4
                
                final_vals[name] = norm ** gamma

        except Exception as e:
            print(f"FFT Error: {e}")
            return self._empty_analysis()
        
        # 4. BEAT & SMOOTH
        result = {'overall_loudness': loudness}
        
        for name in ['sub_bass', 'bass', 'low_mid', 'mid', 'high_mid', 'presence', 'brilliance']:
             val = final_vals.get(name, 0.0)
             is_beat, _ = self.beat_detectors[name].detect(val)
             
             # Smooth
             curr_s = self.smooth_vals[name]
             if val > curr_s:
                 new_s = self.alpha_attack * val + (1 - self.alpha_attack) * curr_s
             else:
                 new_s = self.alpha_decay * val + (1 - self.alpha_decay) * curr_s
             self.smooth_vals[name] = new_s
             
             result[name] = {
                 'is_beat': is_beat,
                 'intensity': val,
                 'smoothed': new_s,
                 'energy': energies.get(name, 0.0)
             }
             
        return result

    def _empty_analysis(self):
        empty = {'is_beat': False, 'intensity': 0.0, 'smoothed': 0.0, 'energy': 0.0}
        return {
            'sub_bass': empty.copy(), 'bass': empty.copy(),
            'low_mid': empty.copy(), 'mid': empty.copy(),
            'high_mid': empty.copy(), 'presence': empty.copy(), 'brilliance': empty.copy(),
            'overall_loudness': 0.0
        }
