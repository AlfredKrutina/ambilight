import cv2
import numpy as np

# Load the composite image
img = cv2.imread(r'C:/Users/alfid/.gemini/antigravity/brain/89bfe2eb-7dbb-4109-a86b-94a14179750a/uploaded_image_1766092686280.png', cv2.IMREAD_UNCHANGED)

print(f"Image size: {img.shape}")

# Define icon positions and names (based on the layout)
# Top row: 4 icons
# Bottom row: 3 icons
icons = [
    # Top row (y=45 to 265, each icon ~256x256)
    {"name": "icon_settings.png", "x": 40, "y": 45, "w": 215, "h": 215},
    {"name": "icon_scan.png", "x": 283, "y": 45, "w": 215, "h": 215},
    {"name": "icon_calibration.png", "x": 526, "y": 45, "w": 215, "h": 215},
    {"name": "icon_led_wizard.png", "x": 769, "y": 45, "w": 215, "h": 215},
    # Bottom row
    {"name": "icon_music.png", "x": 146, "y": 305, "w": 215, "h": 215},
    {"name": "icon_screen.png", "x": 403, "y": 305, "w": 215, "h": 215},
    {"name": "icon_light.png", "x": 660, "y": 305, "w": 215, "h": 215},
]

# Extract and save each icon
output_dir = "resources"
for icon in icons:
    # Extract region
    x, y, w, h = icon["x"], icon["y"], icon["w"], icon["h"]
    icon_img = img[y:y+h, x:x+w]
    
    # Save
    output_path = f"{output_dir}/{icon['name']}"
    cv2.imwrite(output_path, icon_img)
    print(f"✓ Saved: {output_path}")

print("\n✅ All icons extracted successfully!")
