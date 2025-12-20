#!/bin/bash
# Generate all required iOS app icon sizes from 1024x1024 source images using macOS sips

ICONSET_DIR="FlareWeather/FlareWeather/Assets.xcassets/AppIcon 1.appiconset"
SOURCE_LIGHT="${ICONSET_DIR}/1024.png"
SOURCE_DARK="${ICONSET_DIR}/1024-B.png"

if [ ! -f "$SOURCE_LIGHT" ]; then
    echo "❌ Source file not found: $SOURCE_LIGHT"
    exit 1
fi

if [ ! -f "$SOURCE_DARK" ]; then
    echo "❌ Source file not found: $SOURCE_DARK"
    exit 1
fi

echo "✅ Generating icon sizes from source images..."

# Generate iPhone icons from light source
sips -z 40 40 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/20x20@2x_iphone_light.png" > /dev/null 2>&1
sips -z 60 60 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/20x20@3x_iphone_light.png" > /dev/null 2>&1
sips -z 58 58 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/29x29@2x_iphone_light.png" > /dev/null 2>&1
sips -z 87 87 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/29x29@3x_iphone_light.png" > /dev/null 2>&1
sips -z 80 80 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/40x40@2x_iphone_light.png" > /dev/null 2>&1
sips -z 120 120 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/40x40@3x_iphone_light.png" > /dev/null 2>&1
sips -z 120 120 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/60x60@2x_iphone_light.png" > /dev/null 2>&1
sips -z 180 180 "$SOURCE_LIGHT" --out "${ICONSET_DIR}/60x60@3x_iphone_light.png" > /dev/null 2>&1

# Generate iPhone icons from dark source
sips -z 40 40 "$SOURCE_DARK" --out "${ICONSET_DIR}/20x20@2x_iphone_dark.png" > /dev/null 2>&1
sips -z 60 60 "$SOURCE_DARK" --out "${ICONSET_DIR}/20x20@3x_iphone_dark.png" > /dev/null 2>&1
sips -z 58 58 "$SOURCE_DARK" --out "${ICONSET_DIR}/29x29@2x_iphone_dark.png" > /dev/null 2>&1
sips -z 87 87 "$SOURCE_DARK" --out "${ICONSET_DIR}/29x29@3x_iphone_dark.png" > /dev/null 2>&1
sips -z 80 80 "$SOURCE_DARK" --out "${ICONSET_DIR}/40x40@2x_iphone_dark.png" > /dev/null 2>&1
sips -z 120 120 "$SOURCE_DARK" --out "${ICONSET_DIR}/40x40@3x_iphone_dark.png" > /dev/null 2>&1
sips -z 120 120 "$SOURCE_DARK" --out "${ICONSET_DIR}/60x60@2x_iphone_dark.png" > /dev/null 2>&1
sips -z 180 180 "$SOURCE_DARK" --out "${ICONSET_DIR}/60x60@3x_iphone_dark.png" > /dev/null 2>&1

echo "✅ Generated all icon sizes"
echo "📝 Now updating Contents.json..."
