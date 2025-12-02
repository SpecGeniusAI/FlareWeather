# Fix Weather API Key in TestFlight

## The Problem

The weather API key works in the emulator but not in TestFlight because:
- **Emulator (Debug)**: Uses environment variable from Xcode scheme ✅
- **TestFlight (Release)**: Environment variables are NOT included ❌
- **TestFlight (Release)**: Must use Info.plist values ✅

## Root Cause Analysis

### What Happens in Emulator:
1. App builds with **Debug** configuration
2. Xcode scheme has `OPENWEATHER_API_KEY` environment variable
3. Environment variables ARE available in Debug builds
4. Code finds key in environment variable → ✅ Works

### What Happens in TestFlight:
1. App builds with **Release** configuration  
2. Xcode scheme environment variables are **NOT included** in Release builds
3. Code must find key in Info.plist
4. Info.plist is generated from `INFOPLIST_KEY_*` values in `project.pbxproj`
5. If key isn't in Info.plist → ❌ Fails

## The Fix

### Step 1: Verify Configuration

The key is already in `project.pbxproj` for both Debug and Release:
- Debug: Line 510: `INFOPLIST_KEY_OpenWeatherAPIKey = "283e823d16ee6e1ba0c625505e5df181";`
- Release: Line 548: `INFOPLIST_KEY_OpenWeatherAPIKey = "283e823d16ee6e1ba0c625505e5df181";`

✅ Configuration is correct!

### Step 2: Clean Build

The app was likely archived **before** the key was added to `project.pbxproj`. You need to:

1. **Clean Build Folder**:
   - In Xcode: `Product` → `Clean Build Folder` (Shift + Cmd + K)
   - This removes old build artifacts

2. **Delete Derived Data** (optional but recommended):
   - In Xcode: `File` → `Project Settings...` → `Derived Data` → Click arrow to open folder
   - Delete the folder for your project
   - This ensures a completely fresh build

### Step 3: Rebuild for Release

1. **Select Release Scheme**:
   - In Xcode: `Product` → `Scheme` → `Edit Scheme...`
   - Select `Run` → `Build Configuration` → Choose `Release`
   - (Or just build for Archive, which uses Release automatically)

2. **Build for Archive**:
   - `Product` → `Archive`
   - This builds with Release configuration
   - The Info.plist will be generated with the API key

### Step 4: Verify Before Uploading

Before uploading to TestFlight, verify the key is in the archive:

1. **Inspect the Archive**:
   - After archiving, right-click the archive in Organizer
   - Select `Show in Finder`
   - Right-click the `.xcarchive` file → `Show Package Contents`
   - Navigate to `Products/Applications/FlareWeather.app`
   - Right-click `FlareWeather.app` → `Show Package Contents`
   - Open `Info.plist` in a text editor
   - Search for `OpenWeatherAPIKey`
   - ✅ Should see: `<key>OpenWeatherAPIKey</key><string>283e823d16ee6e1ba0c625505e5df181</string>`

2. **If key is NOT in Info.plist**:
   - The build didn't include it
   - Check `project.pbxproj` again
   - Clean and rebuild

### Step 5: Upload to TestFlight

1. **Distribute App**:
   - In Organizer, select your archive
   - Click `Distribute App`
   - Choose `App Store Connect`
   - Follow the prompts

2. **Test in TestFlight**:
   - Install the app on a TestFlight device
   - Check console logs (if connected to Xcode)
   - Should see: `✅ WeatherService: API key found in Info.plist as 'OpenWeatherAPIKey'`

## Debugging in TestFlight

If it still doesn't work, check the console logs:

### What to Look For:

1. **If key is found**:
   ```
   ✅ WeatherService: API key found in Info.plist as 'OpenWeatherAPIKey' (length: 32)
   ```

2. **If key is NOT found**:
   ```
   ❌ WeatherService: No API key found in Info.plist or environment variable
   🔍 WeatherService: ALL Info.plist keys:
      - CFBundleDisplayName: String = FlareWeather...
      - BackendURL: String = https://flareweather-production...
      ... (all keys listed)
   ```

3. **Check the list of keys**:
   - Look for `OpenWeatherAPIKey` in the list
   - If it's there but with a different name, the code will try to find it
   - If it's NOT there, the build didn't include it

## Why This Happens

### Build Process:

1. **Xcode reads `project.pbxproj`**
   - Finds `INFOPLIST_KEY_OpenWeatherAPIKey = "283e823d16ee6e1ba0c625505e5df181";`
   - This is in the Release configuration

2. **Xcode generates Info.plist**
   - Strips `INFOPLIST_KEY_` prefix
   - Creates: `<key>OpenWeatherAPIKey</key><string>283e823d16ee6e1ba0c625505e5df181</string>`

3. **App reads Info.plist at runtime**
   - `Bundle.main.infoDictionary["OpenWeatherAPIKey"]`
   - Should return the API key string

### Why Emulator Works But TestFlight Doesn't:

- **Emulator**: Uses Debug config → Environment variable available → Works
- **TestFlight**: Uses Release config → No environment variables → Must use Info.plist
- **If archived before key was added**: Old archive doesn't have key → Fails

## Verification Checklist

Before uploading to TestFlight:

- [ ] Key is in `project.pbxproj` for Release configuration (line 548)
- [ ] Cleaned build folder (Shift + Cmd + K)
- [ ] Built for Archive (uses Release config)
- [ ] Verified key is in archive's Info.plist
- [ ] Uploaded new archive to TestFlight
- [ ] Tested on TestFlight device
- [ ] Checked console logs for key validation message

## Quick Fix Command

Run this to verify the key is in the project file:

```bash
grep -i "OpenWeatherAPIKey" FlareWeather/FlareWeather.xcodeproj/project.pbxproj
```

Should show 2 lines (Debug and Release configurations).

## If Still Not Working

1. **Check console logs** in TestFlight (connect device to Xcode)
2. **Look for the debug output** showing all Info.plist keys
3. **Verify the key name** matches what's in the logs
4. **Check if key is in a different format** (the code now tries multiple variations)
5. **Ensure you rebuilt** after adding the key to project.pbxproj

## Summary

The fix is simple:
1. ✅ Key is already in `project.pbxproj` (both Debug and Release)
2. ✅ Code is looking for it correctly
3. ⚠️ **You need to rebuild and re-archive** for the key to be included
4. ⚠️ **Old archives don't have the key** - they were created before it was added

**Solution**: Clean, rebuild, re-archive, upload to TestFlight.

