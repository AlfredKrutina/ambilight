import threading
import time
import numpy as np
try:
    import pyaudiowpatch as pyaudio
except ImportError:
    import pyaudio

from typing import List, Dict, Optional


from audio_analyzer import AudioAnalyzer

class AudioProcessor(threading.Thread):
    """Snímání audia a výpočet FFT (Bass/Mid/High) s podporou Loopback"""
    
    def __init__(self, device_index: Optional[int] = None):
        super().__init__(daemon=True)
        self.p = pyaudio.PyAudio()
        self.device_index = device_index
        self.error_count = 0
        self.running = True
        self.stream = None
        
        # Analyzer
        self.analyzer = AudioAnalyzer(sample_rate=48000)
        self.latest_analysis = self.analyzer._empty_analysis()
        self.lock = threading.Lock()
        
        print(f"✓ AudioProcessor initialized (device_index={device_index}, FFT ready)")
        self.paused = False

        # Melody detection (lazy-init)
        self.melody_detector = None
        self.melody_enabled = False
        self.latest_melody = {'onset': False, 'pitch': 0, 'beat': False}
        
        # Melody detection (lazy-init)
        self.melody_detector = None
        self.melody_enabled = False
        self.latest_melody = {'onset': False, 'pitch': 0, 'beat': False, 'has_melody': False}

    def set_paused(self, paused: bool):
        self.paused = paused

    def get_devices(self) -> List[Dict]:
        """Vrátí seznam vstupních zařízení včetně WASAPI Loopback"""
        devices = []
        
        # 1. Try WASAPI loopback devices first
        try:
            wasapi_info = self.p.get_host_api_info_by_type(pyaudio.paWASAPI)
            wasapi_index = wasapi_info.get('index')
            
            for i in range(wasapi_info.get('deviceCount')):
                try:
                    dev = self.p.get_device_info_by_host_api_device_index(wasapi_index, i)
                    # Loopback devices are inputs, but technically "output loopback"
                    # pyaudiowpatch marks them as isLoopbackDevice
                    is_loopback = dev.get("isLoopbackDevice", False)
                    
                    if dev.get('maxInputChannels') > 0 or is_loopback:
                        name = dev.get('name')
                        if is_loopback:
                            name = f"[Loopback] {name}"
                        else:
                            name = f"[Mic/Input] {name}"
                            
                        devices.append({
                            "index": dev.get('index'),
                            "name": name,
                            "is_loopback": is_loopback
                        })
                except Exception:
                    continue
        except Exception:
            pass
            
        # 2. Add standard MME/DirectSound devices if mismatched
        current_indices = [d['index'] for d in devices]
        for i in range(self.p.get_device_count()):
            if i in current_indices: continue
            try:
                dev = self.p.get_device_info_by_index(i)
                # Only real inputs
                if dev.get('maxInputChannels') > 0:
                    devices.append({
                        "index": dev['index'],
                        "name": dev['name'],
                        "is_loopback": False
                    })
            except: pass
                
        return devices

    def set_device(self, index: Optional[int]):
        """Změna zařízení za běhu"""
        print(f"⟳ Requesting Audio Device change to index {index}")
        with self.lock:
            # Only change index and close stream. Run loop will re-open.
            self.device_index = index
            if self.stream:
                try:
                    self.stream.stop_stream()
                    self.stream.close()
                except: pass
                self.stream = None

    def get_volume(self) -> float:
        """Vrátí aktuální celkovou hlasitost 0.0 - 1.0 (backward compatibility)"""
        return self.latest_analysis.get('overall_loudness', 0.0)
    
    def get_analysis(self) -> dict:
        """Vrátí kompletní analýzu (Bass/Mid/High)"""
        with self.lock:
            return self.latest_analysis

    def enable_melody_detection(self, enabled: bool):
        self.melody_enabled = enabled
        if enabled and self.melody_detector is None:
            try:
                from melody_detector import MelodyDetector
                self.melody_detector = MelodyDetector(self.analyzer.sr)
                print('✓ Melody detection enabled')
            except Exception as e:
                print(f'⚠ Melody unavailable: {e}')
                self.melody_enabled = False

    def get_melody_analysis(self):
        with self.lock:
            return self.latest_melody

    def _find_default_loopback(self):
        """Find best loopback device if none selected"""
        try:
            wasapi_info = self.p.get_host_api_info_by_type(pyaudio.paWASAPI)
            default_speakers = self.p.get_device_info_by_index(wasapi_info["defaultOutputDevice"])
            
            if not default_speakers["isLoopbackDevice"]:
                for loopback in self.p.get_loopback_device_info_generator():
                    if default_speakers["name"] in loopback["name"]:
                        print(f"🔍 Auto-found Loopback: {loopback['name']}")
                        return loopback
            else:
                 return default_speakers
        except Exception:
            pass
        return None

    def run(self):
        """Hlavní smyčka snímání"""
        print(f"✓ Audio Stream started")
        
        while self.running:
            # MODE-AWARE: Only process audio in music mode
            current_mode = getattr(self, 'current_mode', 'music')
            if current_mode != "music":
                # Not music mode - pause to save CPU
                if self.stream:
                    with self.lock:
                        try:
                            self.stream.close()
                        except: pass
                        self.stream = None
                time.sleep(0.5)
                continue
            
            if self.paused:
                time.sleep(0.5)
                continue

            target_device = None
            
            # --- OPEN STREAM SECTION ---
            with self.lock:
                if self.stream is None:
                    try:
                        # 1. Resolve Target
                        if self.device_index is not None:
                            try:
                                target_device = self.p.get_device_info_by_index(self.device_index)
                            except: target_device = None
                        
                        # 2. Auto-Loopback
                        if target_device is None:
                            loopback = self._find_default_loopback()
                            if loopback: target_device = loopback
                            else:
                                try: target_device = self.p.get_default_input_device_info()
                                except: pass
                        
                        if target_device:
                            print(f"🎤 Opening Stream on: {target_device['name']} (Rate: {int(target_device['defaultSampleRate'])})")
                            
                            # Update Analyzer Sample Rate
                            self.analyzer.sr = int(target_device["defaultSampleRate"])
                            
                            try:
                                # Primary attempt
                                self.stream = self.p.open(
                                    format=pyaudio.paInt16,
                                    channels=target_device["maxInputChannels"],
                                    rate=int(target_device["defaultSampleRate"]),
                                    input=True,
                                    frames_per_buffer=4096,
                                    input_device_index=target_device["index"]
                                )
                            except Exception as e1:
                                print(f"⚠ Standard Stream Open Failed ({e1}), trying fallback (Stereo)...")
                                # Fallback: Force Stereo (Common for Loopback)
                                try:
                                    self.stream = self.p.open(
                                        format=pyaudio.paInt16,
                                        channels=2,
                                        rate=int(target_device["defaultSampleRate"]),
                                        input=True,
                                        frames_per_buffer=4096,
                                        input_device_index=target_device["index"]
                                    )
                                    print("✓ Fallback to Stereo successful")
                                except Exception as e2:
                                    raise e1 # Raise original error if fallback fails
                    except Exception as e:
                        print(f"✗ Stream Open Error: {e}")
                        self.error_count += 1
                        time.sleep(2) # Increased backoff
                        if self.error_count > 2:
                            # Re-init attempt
                            try:
                                self.p.terminate()
                                self.p = pyaudio.PyAudio()
                                self.error_count = 0
                            except: pass
                        continue

            # --- READ DATA SECTION ---
            if self.stream:
                try:
                    data = self.stream.read(4096, exception_on_overflow=False)
                    audio_data = np.frombuffer(data, dtype=np.int16).astype(np.float32)
                    
                    # ANALYZE (FFT + Beat Detect)
                    analysis_result = self.analyzer.process_audio_frame(audio_data)
                    
                    # Store Result
                    with self.lock:
                        self.latest_analysis = analysis_result
                        self.latest_buffer = audio_data  # For AI stem separation

                        # Melody
                        if self.melody_enabled and self.melody_detector:
                            self.latest_melody = self.melody_detector.process_frame(audio_data)
                        
                        # Melody analysis (if enabled)
                        if self.melody_enabled and self.melody_detector:
                            melody_result = self.melody_detector.process_frame(audio_data)
                            self.latest_melody = melody_result
                        
                except Exception as e:
                    # Stream broken (e.g. device disconnected or changed)
                    # print(f"⚠ Read Error: {e}")
                    with self.lock:
                        if self.stream:
                            try: self.stream.close()
                            except: pass
                            self.stream = None
                    time.sleep(0.5)
            else:
                # No stream (waiting for device?)
                time.sleep(0.2)

    def stop(self):
        self.running = False
        with self.lock:
            if self.stream:
                try:
                    self.stream.stop_stream()
                    self.stream.close()
                except: pass
        self.p.terminate()
