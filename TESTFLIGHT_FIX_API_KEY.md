# How to Fix OpenWeatherMap API Key for TestFlight

## 🚨 Critical Issue
The OpenWeatherMap API key is **NOT** configured in the Xcode project for Release builds. This means:
- ❌ Weather data will **NOT** work in TestFlight builds
- ❌ App will show error: "Weather API key not configured"
- ❌ Users won't be able to see weather data

## ✅ Solution: Add API Key to Info.plist

### Step 1: Open Xcode Project
1. Open `FlareWeather.xcodeproj` in Xcode
2. Select the **FlareWeather** project in the Project Navigator
3. Select the **FlareWeather** target
4. Click on the **Info** tab

### Step 2: Add API Key
1. Under "Custom iOS Target Properties", look for existing keys like `BackendURL`
2. Click the **+** button to add a new key
3. Add the following:
   - **Key**: `OpenWeatherAPIKey` (exact, case-sensitive)
   - **Type**: String
   - **Value**: Your OpenWeatherMap API key (get from https://openweathermap.org/api)

### Step 3: Configure for Release
1. Click on the `OpenWeatherAPIKey` row to expand it
2. Make sure it's set for **Release** configuration (used for TestFlight)
   - If you see configuration-specific settings, set the value for **Release**
   - If not, the value will apply to all configurations (which is fine)

### Step 4: Verify
1. Build the project (⌘+B)
2. Check that the key is in `project.pbxproj`:
   ```bash
   grep -i "OpenWeatherAPIKey" FlareWeather/FlareWeather.xcodeproj/project.pbxproj
   ```
3. You should see:
   ```
   INFOPLIST_KEY_OpenWeatherAPIKey = "your_api_key_here";
   ```

### Step 5: Test
1. Build and run on a physical device
2. Verify weather data loads correctly
3. Check console logs for:
   ```
   ✅ WeatherService: API key found in Info.plist
   ```

## 📝 Important Notes

### Environment Variables vs Info.plist
- **Xcode Scheme Environment Variables**: NOT included in TestFlight builds
- **Info.plist**: INCLUDED in TestFlight builds
- **Solution**: Use Info.plist for TestFlight/production builds

### API Key Security
- ⚠️ **DO NOT** commit API keys to git
- ⚠️ Make sure `.gitignore` excludes sensitive files
- ⚠️ Consider using environment variables for local development
- ⚠️ Use Info.plist for TestFlight/production (but don't commit to git)

### Verification
After adding the key, verify:
1. ✅ Key is in `project.pbxproj` (Release configuration)
2. ✅ Key is NOT in `.gitignore` (so it's not committed)
3. ✅ App loads weather data on physical device
4. ✅ Console shows: "✅ WeatherService: API key found in Info.plist"

## 🧪 Testing

### Before TestFlight
1. Build app for Release configuration
2. Install on physical device
3. Test weather data loading
4. Verify API key is working

### After TestFlight Upload
1. Install via TestFlight
2. Test weather data loading
3. Verify API key is working
4. Check for any errors

## 🎯 Summary

**Status**: ⚠️ **NEEDS FIX**

**Action Required**:
1. Add `OpenWeatherAPIKey` to Info.plist in Xcode
2. Set value for Release configuration
3. Verify it's working on physical device
4. Test on TestFlight

**Impact**: Without this fix, weather data will **NOT** work in TestFlight builds.

