# WeatherKit Key Setup - Step by Step

## The Problem
WeatherKit requires a **private key** to authenticate. Without it, you'll see:
```
WeatherKit authentication error. Please ensure WeatherKit is properly configured in Apple Developer Portal.
```

## Solution: Generate and Configure WeatherKit Key

### Step 1: Generate WeatherKit Key in Apple Developer Portal

1. **Go to Apple Developer Portal**
   - Visit: https://developer.apple.com/account/
   - Sign in with your Apple Developer account

2. **Navigate to Keys**
   - Click **Certificates, Identifiers & Profiles** in the left sidebar
   - Click **Keys** in the left sidebar (under "Certificates, Identifiers & Profiles")

3. **Create New Key**
   - Click the **+** button (top left, next to "Keys")
   - Enter a **Key Name**: `FlareWeather WeatherKit Key` (or any name you prefer)
   - **Check the box** next to **WeatherKit**
   - Click **Continue**
   - Review the key details
   - Click **Register**

4. **Download the Key File** ⚠️ **CRITICAL**
   - You'll see a page with your new key
   - **Click "Download"** to download the `.p8` file
   - ⚠️ **IMPORTANT:** You can only download this file **once**!
   - Save it somewhere safe (you won't need to upload it, but keep it as backup)
   - **Copy the Key ID** (it looks like: `ABC123DEF4`) - you'll need this

### Step 2: Configure Key in Xcode

1. **Open Your Project in Xcode**
   ```bash
   open FlareWeather/FlareWeather.xcodeproj
   ```

2. **Select Your Target**
   - Click on **FlareWeather** project in the navigator (top item)
   - Select **FlareWeather** target (under TARGETS)

3. **Go to Signing & Capabilities**
   - Click the **Signing & Capabilities** tab

4. **Configure WeatherKit**
   - Find **WeatherKit** in the capabilities list
   - Click on **WeatherKit** to expand it
   - You should see:
     - **Key ID**: This should auto-populate, but if not:
       - Click **Configure** button
       - Select your key from the dropdown (or enter the Key ID manually)
     - **Team ID**: Should auto-populate
     - **Service ID**: Should auto-populate

5. **If Key ID Doesn't Show:**
   - Click **Configure** next to WeatherKit
   - Select your key from the dropdown
   - If your key doesn't appear:
     - Make sure you created the key with WeatherKit enabled
     - Make sure you're signed in with the same Apple Developer account
     - Try restarting Xcode

### Step 3: Verify Configuration

1. **In Xcode, check:**
   - ✅ WeatherKit capability is enabled
   - ✅ Key ID is set (not empty)
   - ✅ Team ID is set
   - ✅ Service ID is set

2. **In Apple Developer Portal, verify:**
   - ✅ WeatherKit is enabled for your app identifier (`KHUR.FlareWeather`)
   - ✅ You have a key with WeatherKit enabled

### Step 4: Clean and Rebuild

1. **Clean Build Folder**
   - In Xcode: **Product → Clean Build Folder** (⌘⇧K)

2. **Restart Xcode** (optional but recommended)

3. **Rebuild**
   - **Product → Build** (⌘B)

4. **Run**
   - **Product → Run** (⌘R)

### Step 5: Test

1. **Run the app** in the simulator or on a device
2. **Check the console** - you should see:
   - ✅ `WeatherService: Initialized with WeatherKit (no API key needed)`
   - ✅ `WeatherService: Fetching weather from WeatherKit...`
   - ✅ `WeatherService: Successfully loaded weather data from WeatherKit`

3. **If you still see the error:**
   - Check that the Key ID is set in Xcode
   - Verify WeatherKit is enabled in Apple Developer Portal
   - Try deleting the app from simulator/device and reinstalling
   - Check Xcode console for more detailed error messages

## Troubleshooting

### "Key ID not showing in Xcode"

**Solution:**
1. Make sure you created the key with WeatherKit enabled
2. Make sure you're signed in with the same Apple Developer account in Xcode
3. Go to Xcode → Settings → Accounts → Select your account → Download Manual Profiles
4. Try removing and re-adding the WeatherKit capability

### "WeatherKit not enabled for app identifier"

**Solution:**
1. Go to Apple Developer Portal
2. Certificates, Identifiers & Profiles → Identifiers
3. Select `KHUR.FlareWeather`
4. Check **WeatherKit** checkbox
5. Click **Save**

### "Still getting authentication error"

**Possible causes:**
1. **Key not configured in Xcode** - Make sure Key ID is set
2. **Wrong Apple Developer account** - Make sure Xcode is signed in with the same account
3. **Simulator issue** - Try on a real device (WeatherKit works better on devices)
4. **Cached build** - Clean build folder and rebuild

### "Works on device but not simulator"

**Solution:**
- WeatherKit can be finicky on simulator
- Try on a **real device** for better reliability
- Make sure the device is signed in with your Apple ID

## Quick Checklist

- [ ] Created WeatherKit key in Apple Developer Portal
- [ ] Downloaded `.p8` key file (saved securely)
- [ ] Copied Key ID
- [ ] Enabled WeatherKit for app identifier in Apple Developer Portal
- [ ] Added WeatherKit capability in Xcode
- [ ] Configured Key ID in Xcode
- [ ] Verified Team ID and Service ID are set
- [ ] Cleaned build folder
- [ ] Rebuilt project
- [ ] Tested in app

## Important Notes

- **The `.p8` key file is only downloadable once** - save it securely!
- **WeatherKit requires iOS 16.0+** - your app targets iOS 18.5, so you're good ✅
- **WeatherKit is free** - up to 500,000 API calls/month included
- **No API keys needed in code** - once configured, WeatherKit works automatically
- **Works in TestFlight and production** - no additional configuration needed

## After Setup

Once the key is configured:
1. ✅ WeatherKit will automatically authenticate
2. ✅ No more JWT errors
3. ✅ Weather data will load correctly
4. ✅ Works in simulator and device
5. ✅ Works in TestFlight and production

## Need Help?

If you're still having issues:
1. Check the Xcode console for detailed error messages
2. Verify all steps in the checklist above
3. Try on a real device instead of simulator
4. Make sure you're using a paid Apple Developer account (WeatherKit requires it)

