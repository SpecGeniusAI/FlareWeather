# Fix Location Permission Issue

## The Problem
The app is getting error `kCLErrorDomain error 1` which means location permission isn't properly configured.

## Solution (Already Applied)
I've added the location permission description to the project settings. However, you may also need to:

## In Xcode (Alternative Method)

1. **Select the FlareWeather project** (blue icon) in Project Navigator
2. **Select the FlareWeather target** (under TARGETS)
3. Go to the **Info** tab
4. Under **Custom iOS Target Properties**, click the **+** button
5. Add: `Privacy - Location When In Use Usage Description`
6. Set value to: `FlareWeather needs your location to provide accurate weather data and correlate it with your symptoms.`

## In iOS Simulator

The simulator also needs location services enabled:

1. In the simulator, go to **Features → Location**
2. Select **Custom Location...** or **Apple** (to use Apple's location)
3. Or select **Allow Location Access** from the simulator menu

## After Fixing

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Rebuild**: Product → Run (⌘R)
3. When the app launches, you should see a location permission prompt
4. Click **Allow** when prompted

## Verify It's Working

After granting permission, check the console. You should see:
- `✅ LocationManager: Authorized, requesting location...`
- `✅ LocationManager: Got location: [coordinates]`
- `🌤️ WeatherService: fetchWeatherData called...`

