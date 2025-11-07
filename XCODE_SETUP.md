# Xcode Setup Guide for FlareWeather

This guide will help you configure the FlareWeather iOS app in Xcode.

## Step 1: Open the Project in Xcode

1. Open Xcode
2. Navigate to: `File → Open...`
3. Select the `FlareWeather.xcodeproj` file in the `FlareWeather` folder
4. Wait for Xcode to index the project

## Step 2: Configure OpenWeatherMap API Key

You have two options for adding the API key:

### Option A: Environment Variable (Recommended for Development)

1. Get your free API key from: https://openweathermap.org/api
   - Sign up for a free account
   - Go to API keys section
   - Copy your API key

2. In Xcode:
   - Click on the **FlareWeather** project in the Project Navigator (left sidebar)
   - Select the **FlareWeather** target
   - Go to the **Edit Scheme...** menu (Product → Scheme → Edit Scheme...)
   - Select **Run** in the left sidebar
   - Click the **Arguments** tab
   - Under **Environment Variables**, click the **+** button
   - Add:
     - **Name**: `OPENWEATHER_API_KEY`
     - **Value**: `your_api_key_here` (paste your actual API key)
   - Click **Close**

### Option B: Info.plist (More Secure for Production)

1. Create an `Info.plist` file if it doesn't exist:
   - Right-click on the `FlareWeather` folder in Project Navigator
   - Select **New File...**
   - Choose **Property List**
   - Name it `Info.plist`
   - Make sure it's added to the FlareWeather target

2. Add the API key to Info.plist:
   - Open `Info.plist`
   - Add a new row:
     - **Key**: `OpenWeatherAPIKey` (or `OPENWEATHER_API_KEY`)
     - **Type**: String
     - **Value**: Your API key

3. Update `WeatherService.swift` to read from Info.plist:
   - The code already tries to read from environment variables first
   - We can update it to also check Info.plist (see below)

## Step 3: Configure Backend URL (Optional)

If your backend is deployed to a different URL:

1. Open `FlareWeather/AIInsightsService.swift`
2. Find line 41: `private let baseURL = "https://flareweather-production.up.railway.app"`
3. Update it to your backend URL if different

## Step 4: Add Location Permission (Required)

1. In Xcode, click on the **FlareWeather** project
2. Select the **FlareWeather** target
3. Go to the **Info** tab
4. Under **Custom iOS Target Properties**, add:
   - **Privacy - Location When In Use Usage Description**
   - **Value**: `FlareWeather needs your location to provide accurate weather data and correlate it with your symptoms.`

Or add to Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>FlareWeather needs your location to provide accurate weather data and correlate it with your symptoms.</string>
```

## Step 5: Verify Build Settings

1. Select the **FlareWeather** target
2. Go to **Build Settings** tab
3. Verify:
   - **iOS Deployment Target**: Should be iOS 15.0 or later
   - **Swift Language Version**: Swift 5

## Step 6: Build and Run

1. Select a simulator or your device
2. Press **⌘R** (or Product → Run)
3. The app should build and launch

## Troubleshooting

### If you get "No such module" errors:
- Close Xcode
- Delete `DerivedData` folder: `~/Library/Developer/Xcode/DerivedData`
- Reopen the project
- Product → Clean Build Folder (⇧⌘K)
- Build again

### If weather data shows mock/fallback data:
- Check that the API key is set correctly
- Check Xcode console for error messages
- Verify the API key is valid at: https://openweathermap.org/api

### If location permission is denied:
- Go to iOS Settings → Privacy → Location Services → FlareWeather
- Enable location access

## Next Steps After Xcode Setup

Once Xcode is configured:
1. Test the app runs successfully
2. Verify location permissions work
3. Test weather data fetching
4. Then proceed with backend deployment (Railway)

## Files Modified for API Key Support

- `FlareWeather/WeatherService.swift` - Already configured to read from environment variables
- Falls back to mock data if API key not found (for development)

