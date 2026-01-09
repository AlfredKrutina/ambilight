# Enhanced Melody Detector - v2
# Better onset, multi-pitch, note-class mapping

import numpy as np
from typing import Dict, List, Tuple
import time

class MelodyDetector:
    """
    Enhanced melody detection v2
    - Spectral flux onset detection  
    - Multi-pitch tracking (chords)
    - Note class mapping (ignore octaves)
    - Harmonic analysis
    """
    
    def __init__(self, sample_rate=48000, hop_size=2048):
        self.sr = sample_rate
        self.hop_size = hop_size
        
        # Spectral flux for onset
        self.prev_spectrum = None
        self.onset_threshold = 0.02
        
        # Multi-pitch state
        self.active_pitches = []  # List of (freq, strength)
        
        # Beat tracking
        self.beat_history = []
        self.last_beat_time = 0.0
        
        # Energy history for dynamics
        self.energy_history = []
        self.max_energy = 0.1
        
        print("✓ MelodyDetector v2 (spectral flux, multi-pitch)")
    
    def process_frame(self, audio_frame: np.ndarray) -> Dict:
        """
        Enhanced melody detection
        Returns multi-pitch data, stronger onset, better dynamics
        """
        if len(audio_frame) < self.hop_size:
            return self._empty_result()
        
        frame = audio_frame[-self.hop_size:]
        
        # === FFT SPECTRUM ===
        spectrum = np.abs(np.fft.rfft(frame * np.hanning(len(frame))))
        spectrum = spectrum / (np.max(spectrum) + 1e-10)
        
        # === SPECTRAL FLUX ONSET ===
        onset = self._detect_onset_spectral_flux(spectrum)
        
        # === MULTI-PITCH DETECTION ===
        pitches = self._detect_multiple_pitches(spectrum)
        self.active_pitches = pitches
        
        # === ENERGY & DYNAMICS ===
        energy = np.sum(frame ** 2) / len(frame)
        self.energy_history.append(energy)
        if len(self.energy_history) > 30:
            self.energy_history.pop(0)
        self.max_energy = max(self.max_energy * 0.99, energy)
        
        # Dynamic range (0-1)
        dynamics = min(energy / (self.max_energy + 1e-10), 1.0)
        
        # === BEAT DETECTION ===
        beat = self._detect_beat(energy)
        
        # === NOTE CLASSES (ignore octaves) ===
        note_classes = []
        for freq, strength in pitches:
            note_class = self._freq_to_note_class(freq)
            if note_class:
                note_classes.append((note_class, strength))
        
        # Primary pitch (strongest)
        primary_pitch = pitches[0][0] if pitches else 0.0
        primary_note = note_classes[0][0] if note_classes else None
        
        # Confidence = how clear the pitch is
        confidence = pitches[0][1] if pitches else 0.0
        
        return {
            'onset': onset,
            'beat': beat,
            'pitch': primary_pitch,
            'pitches': pitches,  # [(freq, strength), ...]
            'note_class': primary_note,  # 'C', 'D#', etc (no octave)
            'note_classes': note_classes,  # [(note_class, strength), ...]
            'pitch_confidence': confidence,
            'dynamics': dynamics,  # 0-1 how loud/intense
            'has_melody': confidence > 0.4 and len(pitches) > 0
        }
    
    def _detect_onset_spectral_flux(self, spectrum: np.ndarray) -> bool:
        """
        Spectral flux: change in spectrum over time
        More accurate than simple energy
        """
        if self.prev_spectrum is None:
            self.prev_spectrum = spectrum
            return False
        
        # Spectral flux = sum of positive differences
        diff = spectrum - self.prev_spectrum
        flux = np.sum(np.maximum(diff, 0))
        
        self.prev_spectrum = spectrum * 0.9 + self.prev_spectrum * 0.1  # Smooth
        
        return flux > self.onset_threshold
    
    def _detect_multiple_pitches(self, spectrum: np.ndarray) -> List[Tuple[float, float]]:
        """
        Detect up to 3 simultaneous pitches (chords)
        Returns [(freq, strength), ...] sorted by strength
        """
        pitches = []
        
        # Find peaks in spectrum
        freq_bins = np.fft.rfftfreq(self.hop_size, 1/self.sr)
        
        # Focus on musical range (60-2000 Hz)
        min_bin = np.searchsorted(freq_bins, 60)
        max_bin = np.searchsorted(freq_bins, 2000)
        
        search_spectrum = spectrum[min_bin:max_bin].copy()
        search_freqs = freq_bins[min_bin:max_bin]
        
        # Find up to 3 peaks
        for _ in range(3):
            if len(search_spectrum) == 0:
                break
            
            peak_idx = np.argmax(search_spectrum)
            peak_strength = search_spectrum[peak_idx]
            
            if peak_strength < 0.1:  # Too weak
                break
            
            peak_freq = search_freqs[peak_idx]
            pitches.append((peak_freq, peak_strength))
            
            # Zero out around this peak to find next
            zero_range = 20  # bins
            start = max(0, peak_idx - zero_range)
            end = min(len(search_spectrum), peak_idx + zero_range)
            search_spectrum[start:end] = 0
        
        # Sort by strength
        pitches.sort(key=lambda x: x[1], reverse=True)
        
        return pitches if pitches else [(0.0, 0.0)]
    
    def _freq_to_note_class(self, freq: float) -> str:
        """
        Convert frequency to note class (C, C#, D, etc) - ignore octave!
        This makes A1, A2, A3 all map to 'A'
        """
        if freq < 20 or freq > 4000:
            return None
        
        A4 = 440.0
        notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        
        half_steps = 12 * np.log2(freq / A4)
        note_index = (int(round(half_steps)) + 9) % 12
        
        return notes[note_index]
    
    def _detect_beat(self, energy: float) -> bool:
        """Beat detection with better timing"""
        current_time = time.time()
        
        self.beat_history.append(energy)
        if len(self.beat_history) > 20:
            self.beat_history.pop(0)
        
        if len(self.beat_history) < 5:
            return False
        
        avg = np.mean(self.beat_history)
        is_peak = energy > avg * 1.8  # Stronger threshold
        time_ok = (current_time - self.last_beat_time) > 0.15  # Min 150ms
        
        if is_peak and time_ok:
            self.last_beat_time = current_time
            return True
        
        return False
    
    def _empty_result(self) -> Dict:
        return {
            'onset': False,
            'beat': False,
            'pitch': 0.0,
            'pitches': [],
            'note_class': None,
            'note_classes': [],
            'pitch_confidence': 0.0,
            'dynamics': 0.0,
            'has_melody': False
        }
