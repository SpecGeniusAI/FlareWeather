# Step-by-Step: Add WeatherKit Capability in Xcode

## ✅ What I've Already Done

1. ✅ **Added WeatherKit entitlement** to `FlareWeather/FlareWeather.entitlements`
   - Added `com.apple.developer.weatherkit` with value `true`
   - This is the main configuration needed for WeatherKit

2. ✅ **Verified deployment target** is iOS 18.5 (WeatherKit requires iOS 16.0+)
   - Your app already meets this requirement

3. ✅ **Verified entitlements file is linked** in the project
   - `CODE_SIGN_ENTITLEMENTS = FlareWeather/FlareWeather.entitlements`

## 📋 Steps to Complete in Xcode

### Option 1: Verify in Xcode (Recommended - Easy Way)

1. **Open your project in Xcode**
   ```bash
   open FlareWeather/FlareWeather.xcodeproj
   ```

2. **Select your project** in the navigator (top-level "FlareWeather" item)

3. **Select the "FlareWeather" target** (under TARGETS)

4. **Go to the "Signing & Capabilities" tab**

5. **Check if WeatherKit appears** in the capabilities list
   - If you see "WeatherKit" with a checkmark ✅, you're done!
   - If you see "WeatherKit" but it's not enabled, click the "+" button and add it
   - If you don't see it, continue to Option 2

6. **Verify the entitlement is present**
   - Scroll down to see the entitlements section
   - You should see `com.apple.developer.weatherkit` = `true`

### Option 2: Manually Add in Xcode (If Needed)

If WeatherKit doesn't appear automatically:

1. **In the "Signing & Capabilities" tab**, click the **"+ Capability"** button (top-left)

2. **Search for "WeatherKit"** in the capability browser

3. **Double-click "WeatherKit"** to add it

4. **Verify it appears** in the capabilities list with a checkmark ✅

5. **Verify the entitlement** appears in the entitlements section below

### Option 3: Verify Entitlements File (Already Done)

The entitlements file has already been updated with:
```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

You can verify this by:
1. Opening `FlareWeather/FlareWeather.entitlements` in Xcode
2. Confirming you see the WeatherKit entitlement

## ✅ Verification Checklist

After completing the steps above, verify:

- [ ] WeatherKit capability appears in "Signing & Capabilities" tab
- [ ] WeatherKit entitlement is in the entitlements file
- [ ] Deployment target is iOS 16.0 or later (you have iOS 18.5 ✅)
- [ ] Project builds without errors
- [ ] WeatherKit is enabled in Apple Developer Portal (Step 1 - if not done yet)

## 🚨 Important: Enable in Apple Developer Portal First

**Before WeatherKit will work, you MUST enable it in the Apple Developer Portal:**

1. Go to https://developer.apple.com/account/
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → Select `KHUR.FlareWeather`
4. Check **WeatherKit** capability
5. Click **Save**

**If you haven't done this yet, WeatherKit will not work even if it's configured in Xcode.**

## 🔍 Troubleshooting

### WeatherKit doesn't appear in Xcode

**Solution:** The entitlement file is already configured. Try:
1. Clean build folder (Product → Clean Build Folder)
2. Restart Xcode
3. Close and reopen the project

### Build errors about WeatherKit

**Solution:** 
1. Make sure you've enabled WeatherKit in Apple Developer Portal (Step 1)
2. Make sure your development team is set correctly in Xcode
3. Make sure you have a valid provisioning profile

### WeatherKit not working in TestFlight

**Solution:**
1. Verify WeatherKit is enabled in Apple Developer Portal
2. Verify WeatherKit capability is added in Xcode
3. Create a new archive and upload to TestFlight
4. Wait for Apple to process the build

## 🎯 Next Steps

After completing Step 2:

1. **Build and test** your app locally
2. **Verify weather data loads** from WeatherKit
3. **Test on a device** (WeatherKit works on device and simulator)
4. **Archive and upload** to TestFlight when ready

## 📝 Notes

- **WeatherKit works on simulator and device** - no special requirements
- **No API keys needed** - WeatherKit is built into iOS
- **Free for developers** - up to 500,000 API calls/month included
- **Requires iOS 16.0+** - your app targets iOS 18.5, so you're good ✅

