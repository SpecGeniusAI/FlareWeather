# How to View Console Logs from TestFlight App

## Method 1: Xcode Console (Easiest)

### Steps:
1. **Connect your iPhone to your Mac** via USB
2. **Open Xcode**
3. **Open Window → Devices and Simulators** (Shift + Cmd + 2)
4. **Select your iPhone** from the left sidebar
5. **Click "Open Console"** button at the bottom
6. **Run your TestFlight app** on your phone
7. **Watch the console** - you'll see all print statements in real-time

### Filter Logs:
- Type "WeatherService" in the search box to filter only weather-related logs
- Look for: `✅ WeatherService: API key found in Info.plist`
- Or: `❌ WeatherService: No API key found`

## Method 2: Console.app (More Detailed)

### Steps:
1. **Connect your iPhone to your Mac** via USB
2. **Open Console.app** (Applications → Utilities → Console)
3. **Select your iPhone** from the left sidebar (under "Devices")
4. **In the search box**, type your app name or "WeatherService"
5. **Run your TestFlight app** on your phone
6. **Watch the logs** appear in real-time

### Filter by App:
- Click the search icon
- Type: `process:FlareWeather` to see only your app's logs
- Or type: `WeatherService` to see only weather service logs

## Method 3: Xcode Debugger (During Development)

### Steps:
1. **Connect your iPhone**
2. **In Xcode**, select your device from the scheme menu
3. **Set breakpoints** in `WeatherService.swift` at the `apiKey` property
4. **Run the app** (not from TestFlight, but from Xcode)
5. **Check the debug console** at the bottom

## Method 4: View Logs from Device Settings (iOS 17+)

### Steps:
1. **On your iPhone**, go to **Settings → Privacy & Security → Analytics & Improvements → Analytics Data**
2. **Find entries** starting with your app name
3. **Tap to view** crash logs and some console output
4. **Note**: This only shows crashes and some system logs, not all console output

## What to Look For

### Success (API Key Found):
```
✅ WeatherService: API key validated successfully (length: 32 characters)
✅ WeatherService: API key found in Info.plist as 'OpenWeatherAPIKey' (length: 32)
```

### Failure (API Key Not Found):
```
❌ WeatherService: No API key found in Info.plist or environment variable
🔍 WeatherService: ALL Info.plist keys:
   - CFBundleDisplayName: String = FlareWeather...
   - BackendURL: String = https://flareweather-production...
   ... (list of all keys)
```

### If Key is Missing:
- Check the list of keys - `OpenWeatherAPIKey` should be in there
- If it's not listed, the key wasn't included in the Info.plist
- If it is listed but empty, there's a configuration issue

## Quick Test

1. **Connect iPhone to Mac**
2. **Open Xcode → Window → Devices and Simulators**
3. **Select your iPhone → Open Console**
4. **Filter by**: `WeatherService`
5. **Launch TestFlight app** on your phone
6. **Watch for**: The API key validation message

## Troubleshooting

### Can't See Logs?
- Make sure your iPhone is **unlocked**
- Make sure you **trust this computer** when prompted
- Try **disconnecting and reconnecting** the USB cable
- Make sure **Xcode is up to date**

### Logs Not Showing?
- Check that the app is actually **running** on your phone
- Make sure you're looking at the **correct device**
- Try **filtering** by your app name or "WeatherService"
- Check that **print statements** are actually executing

### Only See Old Logs?
- **Clear the console** (Cmd + K in Console.app)
- **Restart the app** on your phone
- **Check the timestamp** to ensure logs are current

## Pro Tip

Add this to your `WeatherService.swift` init to force a log message:

```swift
init() {
    // Validate API key at startup
    validateAPIKey()
    // ... rest of init
}
```

This will ensure you see a log message as soon as the app starts, making it easy to verify the API key is loaded correctly.

