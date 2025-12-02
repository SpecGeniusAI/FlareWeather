# WeatherKit Key Setup Guide

## Issue

You're seeing this error:
```
Failed to generate jwt token for: com.apple.weatherkit.authservice with error: Error Domain=WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors Code=2 "(null)"
```

This means WeatherKit needs a **private key** to be generated and configured.

## Solution: Generate WeatherKit Key

### Step 1: Generate WeatherKit Key in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Keys** in the left sidebar
4. Click the **+** button to create a new key
5. Enter a **Key Name** (e.g., "FlareWeather WeatherKit Key")
6. Check **WeatherKit** checkbox
7. Click **Continue**
8. Click **Register**
9. **IMPORTANT:** Click **Download** to download the `.p8` key file
   - ⚠️ **You can only download this once!** Save it securely.
   - If you lose it, you'll need to create a new key.

### Step 2: Configure Key in Xcode

1. Open your project in Xcode
2. Select your **FlareWeather** target
3. Go to **Signing & Capabilities** tab
4. Find **WeatherKit** capability (should already be there)
5. Click on **WeatherKit** capability
6. In the **WeatherKit** section, you should see:
   - **Key ID**: This should be automatically populated
   - **Team ID**: This should be automatically populated
   - **Service ID**: This should be automatically populated

If the Key ID is not showing:
1. Go back to Apple Developer Portal
2. Find the key you just created
3. Copy the **Key ID** (it looks like: `ABC123DEF4`)
4. In Xcode, click **Configure** next to WeatherKit
5. Select the key from the dropdown (or enter the Key ID manually)

### Step 3: Verify Configuration

1. In Xcode, go to **Signing & Capabilities**
2. Verify **WeatherKit** shows:
   - ✅ Key ID is set
   - ✅ Team ID is set
   - ✅ Service ID is set

### Step 4: Clean and Rebuild

1. **Clean Build Folder**: Product → Clean Build Folder (⌘⇧K)
2. **Restart Xcode** (optional but recommended)
3. **Build the project**: Product → Build (⌘B)
4. **Run the app**: Product → Run (⌘R)

## Troubleshooting

### Key ID Not Showing in Xcode

**Solution:**
1. Make sure you've enabled WeatherKit capability in Apple Developer Portal for your app identifier
2. Make sure you've created a key with WeatherKit enabled
3. Try restarting Xcode
4. Try removing and re-adding the WeatherKit capability in Xcode

### Still Getting JWT Errors

**Possible causes:**
1. **Key not properly configured**: Make sure the Key ID is set in Xcode
2. **Key doesn't have WeatherKit enabled**: Create a new key with WeatherKit checked
3. **App identifier doesn't have WeatherKit**: Enable WeatherKit in Apple Developer Portal
4. **Simulator issue**: Try on a real device (WeatherKit works better on devices)

### WeatherKit Not Working on Simulator

**Solution:**
- WeatherKit works on simulator, but sometimes has issues
- Try on a **real device** for better reliability
- Make sure you're signed in with your Apple ID on the simulator/device

## Important Notes

- **The `.p8` key file is only downloadable once** - save it securely!
- **WeatherKit requires iOS 16.0+** - your app targets iOS 18.5, so you're good ✅
- **WeatherKit is free** - up to 500,000 API calls/month included
- **No API keys needed** - once configured, WeatherKit works automatically

## After Setup

Once the key is configured:
1. WeatherKit will automatically authenticate
2. No more JWT errors
3. Weather data will load correctly
4. Works in TestFlight and production automatically

## Quick Checklist

- [ ] Created WeatherKit key in Apple Developer Portal
- [ ] Downloaded `.p8` key file (saved securely)
- [ ] Enabled WeatherKit capability in Apple Developer Portal for app identifier
- [ ] Added WeatherKit capability in Xcode
- [ ] Configured Key ID in Xcode
- [ ] Cleaned build folder
- [ ] Rebuilt and tested

## Need Help?

If you're still having issues:
1. Check Apple's WeatherKit documentation: https://developer.apple.com/weatherkit/
2. Verify your Apple Developer account has access to WeatherKit
3. Make sure your app identifier has WeatherKit enabled
4. Try creating a new key if the current one isn't working

