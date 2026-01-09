import logging
import time

logger = logging.getLogger("SpotifyClient")

class SpotifyClient:
    """
    Client for Spotify Web API.
    Used to fetch Album Art colors.
    """
    def __init__(self, client_id=None, client_secret=None):
        self.enabled = False
        if client_id and client_secret:
            self.enabled = True
            
        self.last_color = (0, 255, 0) # Default Green
        self.last_check = 0
        self.check_interval = 5.0 # Seconds
    
    def get_current_track_color(self) -> tuple:
        """
        Returns (r, g, b) of current album art.
        """
        if not self.enabled:
            return (0, 255, 0)
            
        now = time.time()
        if now - self.last_check > self.check_interval:
            self.last_check = now
            # TODO: Implement real OAuth and API call
            # For now, simulate color change or return brand green
            pass
            
        return self.last_color
        
    def authenticate(self):
        # Placeholder for OAuth
        pass
