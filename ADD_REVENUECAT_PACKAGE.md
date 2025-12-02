# Adding RevenueCat Package to Xcode Project

## Steps to Add RevenueCat via Swift Package Manager

1. **Open your Xcode project**
   - Open `FlareWeather.xcodeproj` in Xcode

2. **Add Package Dependency**
   - In Xcode, go to: **File** → **Add Package Dependencies...**
   - Or: Select your project in the navigator → Select the **FlareWeather** target → Go to **Package Dependencies** tab → Click the **+** button

3. **Enter Package URL**
   - Paste this URL: `https://github.com/RevenueCat/purchases-ios`
   - Click **Add Package**

4. **Select Products**
   - You need to add **TWO** products:
     - ✅ **RevenueCat** (the core SDK)
     - ✅ **RevenueCatUI** (for PaywallView and CustomerCenterView)
   - Click **Add Package**

5. **Verify Installation**
   - The packages should appear in your project navigator under "Package Dependencies"
   - You should see:
     - `RevenueCat`
     - `RevenueCatUI`

6. **Build the Project**
   - Press `Cmd + B` to build
   - If you see import errors, make sure both `RevenueCat` and `RevenueCatUI` are added to your target's "Frameworks, Libraries, and Embedded Content"

## Alternative: Faster SPM Mirror (Optional)

For faster downloads, you can use the SPM mirror repository:
- URL: `https://github.com/RevenueCat/purchases-ios-spm`

## What's Already Done

✅ All code integration is complete:
- `SubscriptionManager.swift` - Updated to use RevenueCat
- `FlareWeatherApp.swift` - RevenueCat initialization added
- `PaywallLauncherView.swift` - New RevenueCat paywall view
- `SettingsView.swift` - Updated to use CustomerCenterView
- `WeeklyInsightGateView.swift` - Entitlement-based content gating
- `OnboardingFlowView.swift` - Updated to use new paywall

## Next Steps After Adding Package

1. Replace the test API key in `FlareWeatherApp.swift` with your production key
2. Set up products and entitlements in RevenueCat Dashboard
3. Test the integration!

