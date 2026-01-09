    def _get_gradient_color(self, value, min_val, max_val, scale_type):
        """Get RGB color based on value in gradient scale"""
        # Normalize to 0-1
        t = max(0.0, min(1.0, (value - min_val) / (max_val - min_val) if max_val != min_val else 0.5))
        
        if scale_type == "blue_green_red":
            # Blue (cold) → Green (medium) → Red (hot)
            if t < 0.5:
                # Blue to Green
                return self._interpolate_rgb((0, 0, 255), (0, 255, 0), t * 2)
            else:
                # Green to Red
                return self._interpolate_rgb((0, 255, 0), (255, 0, 0), (t - 0.5) * 2)
        
        elif scale_type == "cool_warm":
            # Cyan (cold) → White (medium) → Orange (hot)
            if t < 0.5:
                return self._interpolate_rgb((0, 255, 255), (255, 255, 255), t * 2)
            else:
                return self._interpolate_rgb((255, 255, 255), (255, 128, 0), (t - 0.5) * 2)
        
        elif scale_type == "cyan_yellow":
            # Cyan → Yellow
            return self._interpolate_rgb((0, 255, 255), (255, 255, 0), t)
        
        elif scale_type == "rainbow":
            # Full rainbow spectrum
            import colorsys
            r, g, b = colorsys.hsv_to_rgb(t, 1.0, 1.0)
            return (int(r * 255), int(g * 255), int(b * 255))
        
        else:
            # Default: white
            return (255, 255, 255)
    
    def _interpolate_rgb(self, color1, color2, t):
        """Linear interpolation between two RGB colors"""
        r = int(color1[0] + (color2[0] - color1[0]) * t)
        g = int(color1[1] + (color2[1] - color1[1]) * t)
        b = int(color1[2] + (color2[2] - color1[2]) * t)
        return (r, g, b)
        
    def _process_pchealth_mode(self):
        """PC Health Monitoring - Customizable Metrics Visualization"""
        settings = self.config.pc_health
        led_count = self.config.global_settings.led_count
        
        # Initialize LED array
        leds = [(0, 0, 0)] * led_count
        
        # Define zone ranges (based on 66 LED setup)
        zone_map = {
            'bottom': list(range(0, 21)),      # 0-20
            'right': list(range(21, 33)),       # 21-32
            'top': list(range(33, 54)),         # 33-53
            'left': list(range(54, 66))         # 54-65
        }
        
        # Get system stats
        stats = self.system_monitor.get_stats()
        
        # Initialize metrics if empty
        metrics = settings.metrics
        if not metrics:
            metrics = settings.get_default_metrics()
        
        # Process each enabled metric
        for metric_config in metrics:
            if not metric_config.get('enabled', True):
                continue
            
            metric_type = metric_config.get('metric', 'cpu_usage')
            zones = metric_config.get('zones', ['right'])
            color_scale = metric_config.get('color_scale', 'blue_green_red')
            min_value = metric_config.get('min_value', 0.0)
            max_value = metric_config.get('max_value', 100.0)
            brightness_factor = metric_config.get('brightness', 200) / 255.0
            
            # Get metric value
            value = 0.0
            if metric_type == 'cpu_usage':
                value = stats.get('cpu', 0.0)
            elif metric_type == 'cpu_temp':
                value = stats.get('cpu_temp', 50.0)  # Default if not available
            elif metric_type == 'gpu_usage':
                value = stats.get('gpu', 0.0)
            elif metric_type == 'gpu_temp':
                value = stats.get('gpu_temp', 50.0)
            elif metric_type == 'ram_usage':
                value = stats.get('ram', 0.0)
            
            # Get gradient color for this value
            r, g, b = self._get_gradient_color(value, min_value, max_value, color_scale)
            
            # Apply brightness
            r = int(r * brightness_factor)
            g = int(g * brightness_factor)
            b = int(b * brightness_factor)
            
            # Apply to all selected zones
            for zone_name in zones:
                if zone_name in zone_map:
                    for led_idx in zone_map[zone_name]:
                        if led_idx < led_count:
                            # Simple override (can be enhanced with blending)
                            leds[led_idx] = (r, g, b)
        
        # Return LEDs with fixed brightness (already applied per-metric)
        return leds, 255
