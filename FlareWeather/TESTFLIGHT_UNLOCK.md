# TestFlight Unlock Mode

## Overview
TestFlight testers automatically get **FlareWeather Plus unlocked** without needing to pay. This is implemented using build mode detection.

## How It Works

### 1. Build Mode Detection (`BuildMode.swift`)
- Detects if the app is running in **TestFlight** or **Debug** mode
- Uses the app store receipt URL to determine build type
- TestFlight builds use `sandboxReceipt`
- Production builds use `receipt`

### 2. Subscription Manager (`SubscriptionManager.swift`)
- Automatically unlocks premium features for TestFlight/Debug builds
- In production builds, checks real subscription status (TODO: implement RevenueCat/StoreKit)
- Provides `hasPlus` property to check premium access
- Provides `statusDescription` for UI display

### 3. Integration (`FlareWeatherApp.swift`)
- `SubscriptionManager` is added as an environment object
- Available throughout the app via `@EnvironmentObject`

## Usage in Views

```swift
struct MyView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        VStack {
            if subscriptionManager.hasPlus {
                // Premium features unlocked
                Text("FlareWeather Plus Active")
            } else {
                // Show upgrade prompt
                Text("Upgrade to FlareWeather Plus")
            }
            
            // Optional: Show beta status
            if subscriptionManager.isTestFlightBuild {
                Text("BETA • Plus features unlocked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

## TestFlight vs Production

### TestFlight Builds
- ✅ **Automatically unlocked** - All premium features available
- ✅ **No payment required** - Testers don't need to subscribe
- ✅ **Sandbox environment** - Uses TestFlight sandbox receipts

### Production Builds
- 🔒 **Subscription required** - Users must subscribe to access premium features
- 💰 **Real payments** - Uses App Store subscriptions
- 📱 **StoreKit integration** - TODO: Implement RevenueCat or StoreKit

## Next Steps

1. **Add Subscription UI** - Create paywall/settings screen
2. **Implement StoreKit** - Add real subscription handling (RevenueCat recommended)
3. **Backend Integration** - Connect subscription status to backend
4. **Premium Features** - Define which features require Plus subscription

## Files Created

- `BuildMode.swift` - Build mode detection
- `SubscriptionManager.swift` - Subscription status management
- `FlareWeatherApp.swift` - Updated to include SubscriptionManager

## Testing

### TestFlight Testing
1. Build app for TestFlight
2. Install via TestFlight
3. Verify `hasPlus` is `true`
4. Verify premium features are unlocked

### Production Testing
1. Build app for App Store
2. Test with sandbox account
3. Verify subscription flow works
4. Verify premium features are locked without subscription

