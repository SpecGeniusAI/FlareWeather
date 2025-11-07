# Step 6: Add Backend URL to iOS App

Your backend URL: **`https://flareweather-production.up.railway.app`**

## Option 1: Using Xcode Project Settings (Easiest)

Modern Xcode projects often don't have a separate `Info.plist` file. Instead, you can add custom keys directly in the project settings.

### Steps:

1. **Open your Xcode project** (`FlareWeather.xcodeproj`)

2. **Select your project** in the Project Navigator (the blue icon at the top)

3. **Select the "FlareWeather" target** (under "TARGETS")

4. **Go to the "Info" tab**

5. **Scroll down to find "Custom iOS Target Properties"** section

6. **Click the "+" button** to add a new key

7. **Add the key**:
   - **Key**: `BackendURL` (or type it exactly as shown)
   - **Type**: `String` (should be automatic)
   - **Value**: `https://flareweather-production.up.railway.app`

8. **Press Enter** to save

9. **Build and run** your app to verify it works

### Visual Guide:

```
Xcode Project Navigator
  └─ FlareWeather (project)
      └─ FlareWeather (target) ← Select this
          └─ Info tab ← Click here
              └─ Custom iOS Target Properties
                  └─ Click "+" button
                      └─ Add: BackendURL = https://flareweather-production.up.railway.app
```

## Option 2: Create Info.plist File (If Option 1 doesn't work)

If you can't find the Info tab or want a traditional approach:

1. **Create a new file** in Xcode:
   - Right-click on the `FlareWeather` folder in Project Navigator
   - Select "New File..."
   - Choose "Property List"
   - Name it: `Info.plist`
   - Make sure it's added to the FlareWeather target

2. **Open `Info.plist`** and add:
   ```xml
   <key>BackendURL</key>
   <string>https://flareweather-production.up.railway.app</string>
   ```

3. **Make sure the project uses this Info.plist**:
   - Select your target
   - Go to "Build Settings"
   - Search for "Info.plist File"
   - Set it to: `FlareWeather/Info.plist`

## Option 3: Environment Variable (For Development/Testing)

This is the easiest for quick testing, but not ideal for production:

1. **Open Xcode**

2. **Edit Scheme**:
   - Click on the scheme selector (next to the Run/Stop buttons at the top)
   - Select "Edit Scheme..."

3. **Go to "Run"** → **"Arguments" tab**

4. **Expand "Environment Variables"**

5. **Click the "+" button**

6. **Add**:
   - **Name**: `BACKEND_URL`
   - **Value**: `https://flareweather-production.up.railway.app`
   - **Check the checkbox** to enable it

7. **Click "Close"**

8. **Run your app** - it will use this environment variable

## Verify It's Working

After adding the backend URL, run your app and check the Xcode console for one of these messages:

```
✅ AIInsightsService: Backend URL found in Info.plist: https://flareweather-production.up.railway.app
```

OR

```
✅ AuthService: Backend URL found in Info.plist: https://flareweather-production.up.railway.app
```

If you see:
```
⚠️ AIInsightsService: Using default backend URL: http://localhost:8000
```

Then the configuration didn't work. Try a different option above.

## Troubleshooting

### Can't find "Info" tab
- Make sure you selected the **target** (FlareWeather), not the project
- Try Option 2 or Option 3 instead

### Key not recognized
- Make sure the key is exactly: `BackendURL` (case-sensitive)
- Make sure the value is exactly: `https://flareweather-production.up.railway.app` (no trailing slash)

### Still using localhost
- Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)
- Quit and restart Xcode
- Try Option 3 (Environment Variable) as a quick test

## Recommended Approach

- **For Development**: Use Option 3 (Environment Variable) - easy to change
- **For Production**: Use Option 1 (Project Settings) or Option 2 (Info.plist) - permanent configuration

## Quick Test

After configuring, run this in your app:
1. Go to Home screen
2. Check Xcode console logs
3. Look for the backend URL confirmation message
4. Try to fetch AI insights - it should connect to Railway!

