# Apple Sign In Setup Instructions

## Important Notes

⚠️ **Apple Sign In often doesn't work in iOS Simulator** - You need to test on a **real device** for it to work properly.

The errors you're seeing (`AKAuthenticationError Code=-7026` and `AuthorizationError Code=1000`) are common in simulator and typically mean:
1. Sign in with Apple capability isn't properly configured
2. Testing in simulator (which has limited Apple Sign In support)
3. Bundle identifier not configured in Apple Developer Portal

## Steps to Enable Apple Sign In

### 1. In Xcode (I've already created the entitlements file):

The entitlements file `FlareWeather.entitlements` has been created with Sign in with Apple capability.

**Manual steps in Xcode:**
1. Open the project in Xcode
2. Select your project in the navigator
3. Select the **FlareWeather** target
4. Go to the **Signing & Capabilities** tab
5. Click the **+ Capability** button
6. Search for and add **"Sign In with Apple"**
7. Make sure your **Team** is selected (5RX7SY5572)
8. Xcode should automatically configure the entitlements

### 2. In Apple Developer Portal:

1. Go to https://developer.apple.com/account
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click on **Identifiers**
4. Find or create an App ID with bundle identifier: `KHUR.FlareWeather`
5. Enable **"Sign In with Apple"** capability
6. Save the changes

### 3. Test on a Real Device:

1. Connect your iPhone/iPad to your Mac
2. In Xcode, select your device as the run destination
3. Build and run the app on the device
4. Try Apple Sign In - it should work on a real device

### 4. Backend Connection:

The error `Connection refused` means your backend isn't running. Start it with:
```bash
cd /path/to/backend
python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

Then update the iOS app's `AuthService.swift` and `AIInsightsService.swift` to use your Mac's IP address instead of `localhost` when testing on a real device:

```swift
// For testing on real device, use your Mac's IP:
private let baseURL = "http://192.168.1.XXX:8000"  // Replace with your Mac's IP
```

## Troubleshooting

- **Error -7026**: Usually means capability not enabled or testing in simulator
- **Error 1000**: Authorization failed - check Apple Developer Portal configuration
- **Connection refused**: Backend not running or wrong URL (use Mac's IP for real device testing)

## Quick Test Without Apple Sign In

For now, you can test the rest of the app using email/password signup until you configure Apple Sign In on a real device.

