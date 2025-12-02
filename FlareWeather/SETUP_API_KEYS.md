# API Keys Setup for TestFlight/Production

## Issue
The app works on the emulator but not on TestFlight because:
- **Emulator**: Uses environment variables from Xcode scheme
- **TestFlight**: Uses Info.plist values (environment variables are NOT included in TestFlight builds)

## Solution: Add API Keys to Info.plist

### Step 1: Get Your OpenWeatherMap API Key
1. Go to https://openweathermap.org/api
2. Sign up for a free account (if you don't have one)
3. Get your API key from the API keys section
4. The free tier includes 1,000 API calls/day

### Step 2: Add API Key to Info.plist in Xcode (REQUIRED FOR TESTFLIGHT)

**Easy Method: Using Xcode Info Tab (Recommended)**
1. Open Xcode
2. Select the **FlareWeather** project (blue icon at the top of the navigator)
3. Select the **FlareWeather** target (under TARGETS)
4. Click the **Info** tab at the top
5. Find the section with custom keys (or click the **+** button)
6. Add a new row:
   - **Key**: `OpenWeatherAPIKey` (must match exactly)
   - **Type**: `String`
   - **Value**: `your_actual_api_key_here`
7. Make sure it's visible in both Debug and Release configurations
8. Save the project

**Method 2: Using Build Settings**
1. Open Xcode
2. Select the **FlareWeather** project
3. Select the **FlareWeather** target
4. Go to **Build Settings** tab
5. Search for "Info.plist"
6. Find "Info.plist Preprocessor Definitions" or "INFOPLIST_KEY_*"
7. Add: `INFOPLIST_KEY_OpenWeatherAPIKey = $(OPENWEATHER_API_KEY)`
8. Then set `OPENWEATHER_API_KEY` in your build settings or Xcode scheme

**Method 3: Edit project.pbxproj (Advanced)**
Add this line to both Debug and Release configurations:
```
INFOPLIST_KEY_OpenWeatherAPIKey = "your_api_key_here";
```

⚠️ **Warning**: Don't commit the actual API key to git if using Method 3.

### Step 3: Verify Configuration
1. Build the app
2. Check console logs for:
   - `✅ WeatherService: API key found in Info.plist`
3. If you see `⚠️ WeatherService: No API key found`, the key is not configured correctly

### Step 4: Archive and Upload to TestFlight
1. Clean build folder (Product → Clean Build Folder)
2. Archive (Product → Archive)
3. Upload to TestFlight

## Backend URL
The backend URL is already configured in Info.plist:
- Key: `BackendURL`
- Value: `https://flareweather-production.up.railway.app`

## Troubleshooting

### Still Seeing "Weather API key not configured"
1. Verify the key is in Info.plist:
   - Check the Info tab in Xcode
   - Verify the key name is exactly `OpenWeatherAPIKey`
   - Verify the value is not empty
2. Clean and rebuild:
   - Product → Clean Build Folder
   - Product → Build
3. Check build configuration:
   - Make sure the key is set for the Release configuration (used for TestFlight)

### API Key Works in Emulator but Not TestFlight
- Environment variables in Xcode scheme are NOT included in TestFlight builds
- You MUST add the API key to Info.plist for TestFlight to work
- Use the Info tab in Xcode to add it

## Security Notes
- **Never commit API keys to git**
- Use environment variables for local development
- Use Info.plist for TestFlight/production (but be careful not to commit sensitive keys)
- Consider using a secrets management service for production apps

