# Add API Key Verification Build Phase (Optional)

## Overview

You can add a build phase script to Xcode that automatically verifies the API key configuration during builds. This will catch configuration issues early.

## How to Add Build Phase Script

### Step 1: Open Xcode

1. Open `FlareWeather.xcodeproj` in Xcode
2. Select the **FlareWeather** project in the Project Navigator
3. Select the **FlareWeather** target
4. Click on the **Build Phases** tab

### Step 2: Add Run Script Phase

1. Click the **+** button at the top left of the Build Phases section
2. Select **New Run Script Phase**
3. Name it: **Verify API Key Configuration**

### Step 3: Add Script

1. Expand the **Run Script Phase** you just created
2. In the script editor, add:
```bash
# Verify OpenWeatherMap API Key Configuration
PROJECT_FILE="${PROJECT_DIR}/FlareWeather.xcodeproj/project.pbxproj"
REQUIRED_KEY="INFOPLIST_KEY_OpenWeatherAPIKey"

if [ -f "$PROJECT_FILE" ]; then
    if grep -q "$REQUIRED_KEY" "$PROJECT_FILE"; then
        KEY_COUNT=$(grep -c "$REQUIRED_KEY" "$PROJECT_FILE")
        if [ "$KEY_COUNT" -ge 2 ]; then
            echo "✅ API key found in both Debug and Release configurations"
        else
            echo "⚠️  Warning: API key may not be in both configurations"
        fi
    else
        echo "❌ Error: API key NOT found in project.pbxproj"
        echo "❌ Please add 'INFOPLIST_KEY_OpenWeatherAPIKey' to project.pbxproj"
        exit 1
    fi
else
    echo "⚠️  Warning: Project file not found, skipping API key verification"
fi
```

### Step 4: Configure Script

1. Set **Shell**: `/bin/bash`
2. Set **Show environment variables in build log**: Unchecked (to hide API key)
3. Move the script phase **BEFORE** "Compile Sources" (optional, but recommended)

### Step 5: Test

1. Build the project (⌘+B)
2. Check build log for verification message
3. Should see: `✅ API key found in both Debug and Release configurations`

## Alternative: Use External Script

If you prefer to use the external verification script:

1. Add **New Run Script Phase**
2. Add script:
```bash
"${PROJECT_DIR}/verify_api_key.sh"
```

3. Set **Shell**: `/bin/bash`

## Benefits

- ✅ **Automatic verification** during builds
- ✅ **Early detection** of configuration issues
- ✅ **Prevents broken builds** from going to TestFlight
- ✅ **No manual verification needed**

## Notes

- The script runs during **every build**
- It only verifies configuration (doesn't expose API key value)
- Build will fail if API key is not found (prevents broken builds)
- You can disable the script if needed (uncheck "Run script only when installing")

## Troubleshooting

### Script Not Running

1. Check script is in Build Phases
2. Check script is enabled (checkbox is checked)
3. Check script has correct path
4. Check build log for script output

### Build Fails

1. Check API key is in project.pbxproj
2. Run `./FlareWeather/verify_api_key.sh` manually
3. Fix configuration issues
4. Rebuild

### Script Output Not Visible

1. Check "Show environment variables in build log" is checked (if you want to see output)
2. Check build log for script output
3. Script output may be hidden by default in Xcode

