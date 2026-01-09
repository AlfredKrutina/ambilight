from typing import List, Tuple

def compute_segments(w: int, h: int, depth_pct: float, pad_top: float, pad_bottom: float, pad_left: float, pad_right: float) -> List[Tuple[int, int, int, int]]:
    """
    Compute default capture regions for 20-zone setup with granular padding.
    Returns list of (x1, y1, x2, y2) tuples.
    """
    regions = []
    
    # Calculate effective area after padding
    start_x = int(w * pad_left)
    end_x = int(w * (1.0 - pad_right))
    start_y = int(h * pad_top)
    end_y = int(h * (1.0 - pad_bottom))
    
    eff_w = end_x - start_x
    eff_h = end_y - start_y
    
    if eff_w <= 0 or eff_h <= 0:
        return [] # Invalid padding
    
    def clamp_x(val): return min(max(val, 0), w-1)
    def clamp_y(val): return min(max(val, 0), h-1)

    # Top (0-4)
    for i in range(5):
        seg_w = eff_w // 5
        x1 = start_x + (i * seg_w)
        x2 = x1 + seg_w
        y1 = start_y
        y2 = start_y + int(eff_h * depth_pct)
        regions.append((clamp_x(x1), clamp_y(y1), clamp_x(x2), clamp_y(y2)))
    
    # Right (5-9)
    for i in range(5):
        seg_h = eff_h // 5
        y1 = start_y + (i * seg_h)
        y2 = y1 + seg_h
        x1 = end_x - int(eff_w * depth_pct)
        x2 = end_x
        regions.append((clamp_x(x1), clamp_y(y1), clamp_x(x2), clamp_y(y2)))
    
    # Bottom (10-14) (Right->Left)
    for i in range(5):
        seg_w = eff_w // 5
        x1 = start_x + ((5 - i - 1) * seg_w)
        x2 = x1 + seg_w
        y1 = end_y - int(eff_h * depth_pct)
        y2 = end_y
        regions.append((clamp_x(x1), clamp_y(y1), clamp_x(x2), clamp_y(y2)))
    
    # Left (15-19) (Bottom->Top)
    for i in range(5):
        seg_h = eff_h // 5
        y1 = start_y + ((5 - i - 1) * seg_h)
        y2 = y1 + seg_h
        x1 = start_x
        x2 = start_x + int(eff_w * depth_pct)
        regions.append((clamp_x(x1), clamp_y(y1), clamp_x(x2), clamp_y(y2)))
    
    return regions

def compute_calibrated_segments(points, depth_pct, w, h):
    """
    Interpolate 5 segments per edge based on 4 corner points.
    points: [(x,y), (x,y), (x,y), (x,y)] -> TL, TR, BR, BL
    """
    tl, tr, br, bl = points[0], points[1], points[2], points[3]
    
    # Center (Simple Avg)
    cx = (tl[0] + tr[0] + br[0] + bl[0]) / 4
    cy = (tl[1] + tr[1] + br[1] + bl[1]) / 4
    center = (cx, cy)
    
    regions = []
    # Top (TL->TR)
    regions += _interpolate_edge(tl, tr, center, 5, depth_pct, w, h)
    # Right (TR->BR)
    regions += _interpolate_edge(tr, br, center, 5, depth_pct, w, h)
    # Bottom (BR->BL) Reversed (Right to Left)
    regions += _interpolate_edge(br, bl, center, 5, depth_pct, w, h)
    # Left (BL->TL) Reversed (Bottom to Top)
    regions += _interpolate_edge(bl, tl, center, 5, depth_pct, w, h)
    return regions

def _interpolate_edge(p1, p2, center, count, depth, w, h):
    regs = []
    def clamp_x(val): return int(min(max(val, 0), w-1))
    def clamp_y(val): return int(min(max(val, 0), h-1))

    for i in range(count):
        t1 = i / count
        t2 = (i+1) / count
        
        # Edge Points
        e1_x = p1[0] + (p2[0] - p1[0]) * t1
        e1_y = p1[1] + (p2[1] - p1[1]) * t1
        e2_x = p1[0] + (p2[0] - p1[0]) * t2
        e2_y = p1[1] + (p2[1] - p1[1]) * t2
        
        # Inner Points (Lerp towards center)
        i1_x = e1_x + (center[0] - e1_x) * depth
        i1_y = e1_y + (center[1] - e1_y) * depth
        i2_x = e2_x + (center[0] - e2_x) * depth
        i2_y = e2_y + (center[1] - e2_y) * depth
        
        # Rect
        min_x = clamp_x(min(e1_x, e2_x, i1_x, i2_x))
        max_x = clamp_x(max(e1_x, e2_x, i1_x, i2_x))
        min_y = clamp_y(min(e1_y, e2_y, i1_y, i2_y))
        max_y = clamp_y(max(e1_y, e2_y, i1_y, i2_y))
        
        # Ensure valid area
        if max_x <= min_x: max_x = min_x + 1
        if max_y <= min_y: max_y = min_y + 1
        
        regs.append((min_x, min_y, max_x, max_y))
    return regs
