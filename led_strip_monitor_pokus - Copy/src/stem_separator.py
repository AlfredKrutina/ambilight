# AI Source Separator - Using Demucs (Facebook Research)
# More modern than Spleeter, better maintained

import numpy as np
import threading
import queue
import time
from typing import Dict, Optional
import torch

class AIStemSeparator:
    """
    AI source separation using Demucs
    Lazy-loads model, runs in background thread
    """
    
    def __init__(self):
        self.enabled = False
        self.model = None
        self.processing_thread = None
        self.input_queue = queue.Queue(maxsize=2)
        self.output_queue = queue.Queue(maxsize=2)
        self.running = False
        
        # Latest stem analysis  
        self.latest_stems = {
            'vocals': {'energy': 0.0, 'onset': False, 'brightness': 0.3},
            'bass': {'energy': 0.0, 'onset': False, 'brightness': 0.3},
            'drums': {'energy': 0.0, 'onset': False, 'brightness': 0.3},
            'other': {'energy': 0.0, 'onset': False, 'brightness': 0.3}
        }
        
        self.prev_energies = {'vocals': 0.0, 'bass': 0.0, 'drums': 0.0, 'other': 0.0}
        
        print("✓ AIStemSeparator initialized (Demucs, lazy-load)")
    
    def enable(self):
        """Enable AI separation - lazy loads Demucs"""
        if self.enabled:
            return
        
        print("🤖 Loading Demucs model...")
        try:
            from demucs.pretrained import get_model
            from demucs.apply import apply_model
            
            # Use htdemucs (hybrid transformer, fast)
            self.model = get_model('htdemucs')
            self.apply_model = apply_model
            self.enabled = True
            
            # Start background thread
            self.running = True
            self.processing_thread = threading.Thread(target=self._process_loop, daemon=True)
            self.processing_thread.start()
            
            print("✓ Demucs loaded (htdemucs model)")
            
        except Exception as e:
            print(f"⚠ Demucs unavailable: {e}")
            print("  → Melody mode will use frequency-based detection")
            self.enabled = False
    
    def disable(self):
        """Disable and free memory"""
        if not self.enabled:
            return
        
        print("🛑 Stopping AI separation...")
        self.running = False
        if self.processing_thread:
            self.processing_thread.join(timeout=2.0)
        
        self.model = None
        self.enabled = False
        print("✓ AI separation stopped")
    
    def process_audio_chunk(self, audio_chunk: np.ndarray, sample_rate: int):
        """Queue audio (non-blocking)"""
        if not self.enabled or self.model is None:
            return
        
        try:
            self.input_queue.put_nowait((audio_chunk, sample_rate))
        except queue.Full:
            pass
    
    def get_latest_stems(self) -> Dict:
        """Get latest stem analysis"""
        try:
            while not self.output_queue.empty():
                self.latest_stems = self.output_queue.get_nowait()
        except queue.Empty:
            pass
        
        return self.latest_stems
    
    def _process_loop(self):
        """Background processing"""
        print("🔄 Demucs thread started")
        
        while self.running:
            try:
                audio_chunk, sr = self.input_queue.get(timeout=0.5)
                
                # Separate stems
                stems = self._separate_stems(audio_chunk, sr)
                
                # Analyze
                result = {}
                for stem_name, stem_audio in stems.items():
                    result[stem_name] = self._analyze_stem(stem_name, stem_audio)
                
                # Queue result
                try:
                    self.output_queue.put_nowait(result)
                except queue.Full:
                    try:
                        self.output_queue.get_nowait()
                        self.output_queue.put_nowait(result)
                    except:
                        pass
                
            except queue.Empty:
                continue
            except Exception as e:
                print(f"⚠ Demucs error: {e}")
        
        print("🛑 Demucs thread stopped")
    
    def _separate_stems(self, audio: np.ndarray, sr: int) -> Dict[str, np.ndarray]:
        """Separate with Demucs"""
        # Demucs expects tensor shape (1, channels, samples)
        if len(audio.shape) == 1:
            # Mono to stereo
            audio = np.stack([audio, audio])
        
        # To tensor
        wav = torch.from_numpy(audio).float().unsqueeze(0)
        
        # Run model (CPU for now, GPU would be faster)
        with torch.no_grad():
            sources = self.apply_model(self.model, wav, device='cpu')
        
        # Extract stems
        # Demucs returns (batch, stems, channels, samples)
        # Stems order: drums, bass, other, vocals
        stems_order = ['drums', 'bass', 'other', 'vocals']
        
        results = {}
        for i, name in enumerate(stems_order):
            # Get stem, convert to mono
            stem_audio = sources[0, i].mean(dim=0).numpy()
            results[name] = stem_audio
        
        return results
    
    def _analyze_stem(self, stem_name: str, audio: np.ndarray) -> Dict:
        """Analyze stem"""
        # Energy
        energy = np.sum(audio ** 2) / len(audio)
        energy = min(energy * 100, 1.0)
        
        # Onset
        prev = self.prev_energies[stem_name]
        delta = energy - prev
        onset = delta > 0.05 and energy > 0.1
        self.prev_energies[stem_name] = energy * 0.9
        
        # Brightness (FAST decay 0.50)
        current = self.latest_stems[stem_name]['brightness']
        if onset:
            brightness = 1.0
        else:
            brightness = current * 0.50
        
        return {
            'energy': energy,
            'onset': onset,
            'brightness': brightness
        }


# Global instance
_stem_separator = None

def get_stem_separator() -> AIStemSeparator:
    global _stem_separator
    if _stem_separator is None:
        _stem_separator = AIStemSeparator()
    return _stem_separator
