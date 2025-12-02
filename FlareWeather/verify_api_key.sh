#!/bin/bash

# Verify OpenWeatherMap API Key Configuration
# This script checks if the API key is properly configured in project.pbxproj

PROJECT_FILE="FlareWeather/FlareWeather.xcodeproj/project.pbxproj"
REQUIRED_KEY="INFOPLIST_KEY_OpenWeatherAPIKey"

echo "🔍 Verifying OpenWeatherMap API Key configuration..."

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Project file not found: $PROJECT_FILE"
    exit 1
fi

# Check if API key is in Debug configuration
if grep -q "INFOPLIST_KEY_OpenWeatherAPIKey" "$PROJECT_FILE"; then
    echo "✅ API key found in project.pbxproj"
    
    # Check if it's in both Debug and Release configurations
    KEY_COUNT=$(grep -c "INFOPLIST_KEY_OpenWeatherAPIKey" "$PROJECT_FILE")
    if [ "$KEY_COUNT" -ge 2 ]; then
        echo "✅ API key found in both Debug and Release configurations"
        
        # Check if key has a value (not empty)
        if grep -q 'INFOPLIST_KEY_OpenWeatherAPIKey = "[^"]*";' "$PROJECT_FILE"; then
            echo "✅ API key has a value configured"
            
            # Extract and validate key length (should be at least 32 characters)
            KEY_VALUE=$(grep 'INFOPLIST_KEY_OpenWeatherAPIKey' "$PROJECT_FILE" | head -1 | sed -n 's/.*= "\([^"]*\)";/\1/p')
            if [ ${#KEY_VALUE} -ge 32 ]; then
                echo "✅ API key length is valid (${#KEY_VALUE} characters)"
                echo "✅ Configuration is correct!"
                exit 0
            else
                echo "⚠️  Warning: API key length is short (${#KEY_VALUE} characters). Should be at least 32 characters."
                exit 0
            fi
        else
            echo "❌ Error: API key found but has no value or is not properly quoted"
            exit 1
        fi
    else
        echo "⚠️  Warning: API key found but may not be in both Debug and Release configurations"
        echo "⚠️  Make sure it's in both configurations for TestFlight builds"
        exit 0
    fi
else
    echo "❌ Error: API key NOT found in project.pbxproj"
    echo "❌ Please add 'INFOPLIST_KEY_OpenWeatherAPIKey' to project.pbxproj"
    echo "❌ In Xcode: Project → Target → Info → Custom iOS Target Properties → Add 'OpenWeatherAPIKey'"
    exit 1
fi

