# How to Call Methods in Xcode

## Method 1: Already Running (App Launch)

The `checkOfferings()` method is **already being called automatically** when your app launches!

In `FlareWeatherApp.swift`, line 35:
```swift
.task {
    await subscriptionManager.checkOfferings()
}
```

**To see the output:**
1. Run your app (⌘R)
2. Open the **Console** (⌘⇧Y or View → Debug Area → Show Debug Area)
3. Look for the output that starts with `📦 RevenueCat Offerings:`

## Method 2: Add a Test Button (Temporary)

Add this to any view to test manually:

```swift
Button("Check Offerings") {
    Task {
        await SubscriptionManager.shared.checkOfferings()
    }
}
```

## Method 3: Use LLDB Debugger (While Running)

1. **Set a breakpoint** - Click in the gutter next to any line of code
2. **Run your app** (⌘R)
3. When it hits the breakpoint, in the **LLDB console** at the bottom, type:
   ```
   po Task { await SubscriptionManager.shared.checkOfferings() }
   ```

Or simpler - just type:
```
po SubscriptionManager.shared.checkOfferings()
```

## Method 4: Call from Any View's .task

Add to any SwiftUI view:

```swift
.task {
    await SubscriptionManager.shared.checkOfferings()
}
```

## Method 5: Add to Settings View (For Testing)

You can temporarily add a button to `SettingsView.swift`:

```swift
Button("Debug: Check Offerings") {
    Task {
        await subscriptionManager.checkOfferings()
    }
}
.padding()
```

## Quick Test: View Console Output

**Easiest way right now:**
1. Run your app (⌘R)
2. Press **⌘⇧Y** to show the console
3. Look for the output - it should appear automatically on launch

The output will look like:
```
📦 RevenueCat Offerings:
   Current offering: default
   Available packages:
     - monthly: fw_plus_monthly - $2.99
     - yearly: fw_plus_yearly - $19.99
```

Or if RevenueCat isn't added yet:
```
⚠️ RevenueCat not available - add package via SPM
```

## Pro Tip: Filter Console

In Xcode console, you can filter by typing "Offerings" in the search box to only see those logs.

