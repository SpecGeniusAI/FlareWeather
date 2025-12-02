# WeatherKit Key Quick Setup

## Your Key Information
- **Key ID**: `B88652888V`
- **Key File**: `AuthKey_B88652888V.p8` (in Downloads folder)

## Steps to Configure in Xcode

### 1. Open Your Project
```bash
open FlareWeather/FlareWeather.xcodeproj
```

### 2. Configure WeatherKit Key

1. **Select Your Target**
   - Click on **FlareWeather** project (top item in navigator)
   - Select **FlareWeather** target (under TARGETS)

2. **Go to Signing & Capabilities Tab**
   - Click the **Signing & Capabilities** tab

3. **Find WeatherKit Capability**
   - Scroll down to find **WeatherKit** in the capabilities list
   - Click on **WeatherKit** to expand it

4. **Configure the Key**
   - You should see a **Configure** button or a dropdown for Key ID
   - Click **Configure** (if visible)
   - **Select your key** from the dropdown:
     - Look for key with ID: `B88652888V`
     - Or key name: "FlareWeather WeatherKit Key" (or whatever you named it)
   - If the dropdown is empty or doesn't show your key:
     - Make sure you're signed in with the same Apple Developer account
     - Go to Xcode → Settings → Accounts
     - Select your account → Click "Download Manual Profiles"
     - Try again

5. **Verify Configuration**
   - After selecting the key, you should see:
     - ✅ **Key ID**: `B88652888V` (or similar)
     - ✅ **Team ID**: Should auto-populate
     - ✅ **Service ID**: Should auto-populate

### 3. Clean and Rebuild

1. **Clean Build Folder**
   - **Product → Clean Build Folder** (⌘⇧K)

2. **Rebuild**
   - **Product → Build** (⌘B)

3. **Run**
   - **Product → Run** (⌘R)

### 4. Test

Run the app and check the console. You should see:
- ✅ `WeatherService: Initialized with WeatherKit (no API key needed)`
- ✅ `WeatherService: Successfully loaded weather data from WeatherKit`

**No more authentication errors!**

## Troubleshooting

### Key Not Showing in Dropdown

**Solution:**
1. Make sure you're signed in with the correct Apple Developer account in Xcode
2. Go to **Xcode → Settings → Accounts**
3. Select your account
4. Click **Download Manual Profiles**
5. Wait for it to complete
6. Go back to Signing & Capabilities
7. Try selecting the key again

### Still Getting Authentication Error

**Check:**
1. ✅ Key ID is set in Xcode (should show `B88652888V`)
2. ✅ Team ID is set
3. ✅ Service ID is set
4. ✅ WeatherKit is enabled in Apple Developer Portal for `KHUR.FlareWeather`
5. ✅ You've cleaned and rebuilt

**If still not working:**
- Try deleting the app from simulator/device
- Clean build folder again
- Rebuild and reinstall
- Check Xcode console for detailed error messages

## Important Notes

- **The `.p8` file is safe in Downloads** - you don't need to move it to the project
- **Xcode automatically uses the key** once it's configured
- **The key file is only needed as backup** - Xcode handles everything automatically
- **Keep the `.p8` file safe** - you can't download it again!

## After Configuration

Once the key is configured:
- ✅ WeatherKit will authenticate automatically
- ✅ No more JWT errors
- ✅ Weather data loads correctly
- ✅ Works in simulator and device
- ✅ Works in TestFlight and production

