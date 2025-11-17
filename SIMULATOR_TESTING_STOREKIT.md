# Testing StoreKit Subscriptions in Xcode Simulator

Yes! You **CAN** test StoreKit subscriptions in the Xcode Simulator using a StoreKit Configuration file.

---

## ✅ Quick Setup

### 1. Add StoreKit Configuration File to Xcode

I've created `Products.storekit` for you. Now you need to add it to your Xcode project:

1. **Open Xcode**
2. **Right-click** on your project in the navigator
3. Select **"Add Files to FlareWeather..."**
4. Navigate to `FlareWeather/Products.storekit`
5. ✅ Make sure **"Add to targets: FlareWeather"** is checked
6. Click **"Add"**

### 2. Configure Xcode Scheme to Use StoreKit Configuration

1. In Xcode, click on your scheme (next to the play/stop buttons)
2. Select **"Edit Scheme..."**
3. Select **"Run"** in the left sidebar
4. Go to the **"Options"** tab
5. Under **"StoreKit Configuration"**, select **"Products.storekit"**
6. Click **"Close"**

### 3. Run in Simulator

1. Select any iOS Simulator (iPhone 14, iPhone 15, etc.)
2. Build and run your app (⌘R)
3. Navigate to the paywall screen
4. **Products should now load!** ✅

---

## 🎯 What You Can Test

With StoreKit Configuration in the simulator:

- ✅ See both monthly and yearly products
- ✅ Purchase subscriptions (no real charges)
- ✅ Test 7-day free trial for monthly
- ✅ Test yearly purchase (no trial)
- ✅ Restore purchases
- ✅ See subscription status

---

## ⚠️ Important Notes

### StoreKit Configuration vs. Sandbox

- **StoreKit Configuration** (`.storekit` file): Works in **Xcode Simulator** only
  - Faster for development
  - No Apple ID needed
  - Products are local to your config file
  
- **Sandbox Testing**: Works on **real devices** and **TestFlight**
  - Requires sandbox test accounts
  - Uses products from App Store Connect
  - More realistic (closer to production)

### Both Are Valid!

You can use both:
- Use `.storekit` for quick simulator testing during development
- Use Sandbox for more realistic testing before release

---

## 🔧 Troubleshooting

### Products Still Don't Load?

1. **Check the scheme**: Make sure StoreKit Configuration is set in Run → Options
2. **Clean build folder**: Product → Clean Build Folder (⇧⌘K)
3. **Rebuild**: Product → Build (⌘B)
4. **Restart Xcode**: Sometimes Xcode needs a restart after adding `.storekit`

### "Selected plan not available" Error?

This should **not** happen with StoreKit Configuration, but if it does:
- Verify product IDs match exactly: `fw_plus_monthly` and `fw_plus_yearly`
- Check that `.storekit` file is added to the target
- Make sure scheme is configured to use the StoreKit file

---

## 📝 What's in the Configuration File

The `Products.storekit` file I created includes:

- **Monthly Subscription** (`fw_plus_monthly`)
  - Price: $2.99/month
  - 7-day free trial (configured as "free" introductory offer)
  
- **Yearly Subscription** (`fw_plus_yearly`)
  - Price: $19.99/year
  - No trial (no introductory offer)

Both products are in the **"FlareWeather Subscription"** group.

---

## 🚀 Next Steps

1. Add `Products.storekit` to your Xcode project
2. Configure the scheme to use it
3. Run in simulator and test purchases
4. Once it works in simulator, you can also test with Sandbox on real devices

Happy testing! 🎉

