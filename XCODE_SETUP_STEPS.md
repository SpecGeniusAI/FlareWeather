# Xcode Setup Steps for FlareWeather

Follow these steps to configure your FlareWeather app in Xcode.

## ✅ Step 1: Open the Project

1. Open **Xcode**
2. Go to **File → Open...**
3. Navigate to: `FlareWeather/FlareWeather.xcodeproj`
4. Click **Open**
5. Wait for Xcode to finish indexing (progress bar at top)

## ✅ Step 2: Get OpenWeatherMap API Key

1. Go to: https://openweathermap.org/api
2. Click **Sign Up** (or log in if you have an account)
3. After signing up, go to **API keys** section
4. Copy your **API key** (looks like: `abc123def456...`)
5. Keep this key handy - you'll need it in Step 3

## ✅ Step 3: Configure API Key in Xcode

**Your API Key:** `283e823d16ee6e1ba0c625505e5df181`

### Option A: Environment Variable (Easiest)

1. In Xcode, look at the top toolbar - click on **FlareWeather** (next to the device selector)
2. Click **Edit Scheme...** (or press `⌘<`)
3. In the left sidebar, make sure **Run** is selected
4. Click the **Arguments** tab at the top
5. Under **Environment Variables**, click the **+** button
6. Add:
   - **Name**: `OPENWEATHER_API_KEY`
   - **Value**: `283e823d16ee6e1ba0c625505e5df181`
7. Make sure the checkbox is **checked** ✅
8. Click **Close**

### Option B: Info.plist (Alternative)

1. In Xcode, right-click on the **FlareWeather** folder (yellow folder icon)
2. Select **New File...**
3. Choose **iOS → Property List**
4. Name it: `Info.plist`
5. Make sure **FlareWeather** target is checked
6. Click **Create**
7. Open `Info.plist`
8. Click the **+** button to add a new row
9. Set:
   - **Key**: `OpenWeatherAPIKey`
   - **Type**: String
   - **Value**: Your API key
10. Save the file

## ✅ Step 4: Add Location Permission

1. In Xcode, click on **FlareWeather** project (blue icon)
2. Select the **FlareWeather** target
3. Go to the **Info** tab
4. Scroll down to **Custom iOS Target Properties**
5. Click the **+** button
6. Type: `Privacy - Location When In Use Usage Description`
7. Press Enter
8. Set the **Value** to:
   ```
   FlareWeather needs your location to provide accurate weather data and correlate it with your symptoms.
   ```

**Alternative:** If you used Info.plist (Option B), add this to Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FlareWeather needs your location to provide accurate weather data and correlate it with your symptoms.</string>
```

## ✅ Step 5: Verify Build Settings

1. Select the **FlareWeather** target
2. Go to **Build Settings** tab
3. Search for "iOS Deployment Target"
4. Make sure it's set to **iOS 15.0** or later
5. Search for "Swift Language Version"
6. Make sure it's set to **Swift 5**

## ✅ Step 6: Build and Run

1. Select a simulator from the device dropdown (top toolbar)
   - Recommended: **iPhone 15 Pro** or **iPhone 15**
2. Press **⌘R** (or click the Play button)
3. Wait for the build to complete
4. The app should launch in the simulator

## ✅ Step 7: Test the App

1. **Grant Location Permission**: When the app asks for location, click **Allow**
2. **Check Weather Data**: On the Home tab, you should see weather data
   - If you see mock data (temperature: 22°C), the API key might not be configured
   - Check the Xcode console for error messages
3. **Test Logging**: Go to the Log tab and try logging a symptom
4. **Check Trends**: Go to the Trends tab to see charts

## 🔍 Troubleshooting

### "No such module" errors
- **Product → Clean Build Folder** (⇧⌘K)
- Close and reopen Xcode
- Delete DerivedData: `~/Library/Developer/Xcode/DerivedData`

### Weather shows mock/fallback data
- Check that API key is set correctly in scheme
- Check Xcode console (bottom panel) for error messages
- Verify API key is valid at: https://openweathermap.org/api

### Location permission not working
- Make sure you added the location permission description
- In Simulator: Settings → Privacy → Location Services → FlareWeather → Enable

### Build errors
- Check that all Swift files are added to the target
- Verify Swift version matches (Swift 5)
- Try cleaning build folder (⇧⌘K)

## 📝 Next Steps

Once Xcode is set up and the app runs:
1. ✅ Test that weather data loads (should show real data, not mock)
2. ✅ Test location permissions
3. ✅ Test symptom logging
4. Then proceed with backend deployment on Railway

## 📞 Quick Reference

- **OpenWeatherMap API**: https://openweathermap.org/api
- **Xcode Scheme Editor**: Product → Scheme → Edit Scheme (⌘<)
- **Clean Build**: Product → Clean Build Folder (⇧⌘K)
- **Run**: ⌘R
- **Stop**: ⌘.

---

**Need Help?** Check the Xcode console (bottom panel) for error messages. Most issues are related to API key configuration or location permissions.

