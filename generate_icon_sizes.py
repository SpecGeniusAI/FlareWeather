#!/usr/bin/env python3
"""
Generate all required iOS app icon sizes from 1024x1024 source images.
"""
import os
from PIL import Image

# Icon sizes required for iOS (size @ scale = actual pixels)
ICON_SIZES = [
    # iPhone icons
    {"size": "20x20", "scale": "2x", "pixels": 40, "idiom": "iphone"},   # 40x40
    {"size": "20x20", "scale": "3x", "pixels": 60, "idiom": "iphone"},   # 60x60
    {"size": "29x29", "scale": "2x", "pixels": 58, "idiom": "iphone"},   # 58x58
    {"size": "29x29", "scale": "3x", "pixels": 87, "idiom": "iphone"},   # 87x87
    {"size": "40x40", "scale": "2x", "pixels": 80, "idiom": "iphone"},    # 80x80
    {"size": "40x40", "scale": "3x", "pixels": 120, "idiom": "iphone"},  # 120x120
    {"size": "60x60", "scale": "2x", "pixels": 120, "idiom": "iphone"},  # 120x120 (required!)
    {"size": "60x60", "scale": "3x", "pixels": 180, "idiom": "iphone"},  # 180x180
]

ICONSET_DIR = "FlareWeather/FlareWeather/Assets.xcassets/AppIcon 1.appiconset"
SOURCE_LIGHT = f"{ICONSET_DIR}/1024.png"
SOURCE_DARK = f"{ICONSET_DIR}/1024-B.png"

def generate_icon_sizes():
    """Generate all required icon sizes from source images."""
    
    if not os.path.exists(SOURCE_LIGHT):
        print(f"❌ Source file not found: {SOURCE_LIGHT}")
        return False
    
    if not os.path.exists(SOURCE_DARK):
        print(f"❌ Source file not found: {SOURCE_DARK}")
        return False
    
    # Load source images
    light_img = Image.open(SOURCE_LIGHT)
    dark_img = Image.open(SOURCE_DARK)
    
    print(f"✅ Loaded source images: {light_img.size}")
    
    generated_files = []
    
    # Generate light mode icons
    for icon_spec in ICON_SIZES:
        pixels = icon_spec["pixels"]
        size = icon_spec["size"]
        scale = icon_spec["scale"]
        idiom = icon_spec["idiom"]
        
        # Resize image
        resized = light_img.resize((pixels, pixels), Image.Resampling.LANCZOS)
        
        # Generate filename
        filename = f"{size.replace('x', '_')}@{scale}_{idiom}_light.png"
        filepath = f"{ICONSET_DIR}/{filename}"
        
        # Save
        resized.save(filepath, "PNG")
        generated_files.append((filename, "light", icon_spec))
        print(f"✅ Generated: {filename} ({pixels}x{pixels})")
    
    # Generate dark mode icons
    for icon_spec in ICON_SIZES:
        pixels = icon_spec["pixels"]
        size = icon_spec["size"]
        scale = icon_spec["scale"]
        idiom = icon_spec["idiom"]
        
        # Resize image
        resized = dark_img.resize((pixels, pixels), Image.Resampling.LANCZOS)
        
        # Generate filename
        filename = f"{size.replace('x', '_')}@{scale}_{idiom}_dark.png"
        filepath = f"{ICONSET_DIR}/{filename}"
        
        # Save
        resized.save(filepath, "PNG")
        generated_files.append((filename, "dark", icon_spec))
        print(f"✅ Generated: {filename} ({pixels}x{pixels})")
    
    print(f"\n✅ Generated {len(generated_files)} icon files")
    print("\n📝 Update Contents.json to reference these files")
    
    return True

if __name__ == "__main__":
    generate_icon_sizes()
