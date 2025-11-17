# TestFlight StoreKit Troubleshooting Guide

## "Selected Plan Not Available" Error

If you're seeing "Selected plan not available" in TestFlight, follow these troubleshooting steps:

---

## Step 1: Check Xcode Console Logs

When the paywall loads and you tap Subscribe, check the Xcode console for debug messages:

**Expected logs when products load successfully:**
```
✅ Fetched 2 products
   - fw_plus_monthly: $2.99
   - fw_plus_yearly: $19.99
```

**If products don't load, you'll see:**
```
⚠️ No products found! Check:
   1. Products created in App Store Connect with IDs: fw_plus_monthly, fw_plus_yearly
   2. Products are in 'Ready to Submit' or approved status
   3. Products are in the 'FlareWeather Subscription' subscription group
   4. Testing with sandbox account in TestFlight
```

---

## Step 2: Verify Products in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app → **Features** → **Subscriptions**
3. Check subscription group **"FlareWeather Subscription"**

**Verify each product:**

### Monthly Product (`fw_plus_monthly`):
- ✅ Product ID: **exactly** `fw_plus_monthly` (case-sensitive, no spaces)
- ✅ Status: **Ready to Submit** or **Approved**
- ✅ Subscription Group: **FlareWeather Subscription**
- ✅ Pricing: Set for your regions
- ✅ Intro Offer: **7-Day Free Trial** configured

### Yearly Product (`fw_plus_yearly`):
- ✅ Product ID: **exactly** `fw_plus_yearly` (case-sensitive, no spaces)
- ✅ Status: **Ready to Submit** or **Approved**
- ✅ Subscription Group: **FlareWeather Subscription**
- ✅ Pricing: Set for your regions
- ✅ Intro Offer: **None** (or configured as needed)

---

## Step 3: Verify TestFlight Setup

### Sandbox Account Required:
1. **Create Sandbox Test Accounts** in App Store Connect:
   - Go to **Users and Access** → **Sandbox Testers**
   - Click **"+"** to create test accounts
   - Use fake email addresses (e.g., `test@example.com`)
   - **Do NOT** use real Apple IDs

2. **Sign Out of Real Apple ID in TestFlight**:
   - Open **Settings** app on your device
   - Tap **App Store** (or **iTunes & App Store** on older iOS)
   - **Sign Out** of your real Apple ID
   - Do **NOT** sign back in

3. **Launch App and Sign In with Sandbox Account**:
   - Open FlareWeather app from TestFlight
   - When prompted for Apple ID (during purchase), use a **sandbox test account**
   - Sandbox purchases don't charge real money

---

## Step 4: Check Common Issues

### Issue 1: Products Not Approved Yet
**Symptom:** Products load but show as unavailable
**Solution:**
- Products must be in **"Ready to Submit"** status at minimum
- Even if not approved, they should work in **Sandbox/TestFlight**
- If not working, try **submitting products for review** (they'll work in sandbox even during review)

### Issue 2: Product IDs Don't Match
**Symptom:** "Selected plan not available" error
**Solution:**
- Product IDs are **case-sensitive**
- Must match exactly: `fw_plus_monthly` and `fw_plus_yearly`
- Check for typos, extra spaces, or different casing

### Issue 3: Products Not in Same Subscription Group
**Symptom:** Only one product shows or neither shows
**Solution:**
- Both products **MUST** be in the same subscription group: **"FlareWeather Subscription"**
- If they're in different groups, they won't work together

### Issue 4: Using Real Apple ID
**Symptom:** Products don't load or show unavailable
**Solution:**
- **MUST** use sandbox test account for TestFlight testing
- Real Apple IDs won't see sandbox products

### Issue 5: Network/StoreKit Issues
**Symptom:** Products fail to load
**Solution:**
- Check internet connection
- Wait a few minutes after creating products (Apple needs to process)
- Try restarting the app
- Try on a different device/network

---

## Step 5: Debug in Xcode

1. **Connect device via USB**
2. **Open Xcode** → **Window** → **Devices and Simulators**
3. **Select your device** → Click **"Open Console"**
4. **Filter logs** for: `StoreKit`, `Subscription`, `fw_plus`
5. **Reproduce the issue** (open paywall, tap Subscribe)
6. **Check console** for error messages

**Look for:**
- ✅ `Fetched 2 products` (success)
- ❌ `No products found` (products not loaded)
- ❌ `Product not available` (product IDs don't match)
- ❌ Network errors (connection issues)

---

## Step 6: Verify Bundle ID Match

Your app's Bundle ID in Xcode **MUST** match the app in App Store Connect:

1. **In Xcode:**
   - Select your project
   - Go to **Signing & Capabilities**
   - Note the **Bundle Identifier**

2. **In App Store Connect:**
   - Go to your app
   - Check the **Bundle ID** matches exactly

**Mismatch = Products won't load**

---

## Quick Checklist

Before reporting an issue, verify:

- [ ] Products created in App Store Connect with exact IDs: `fw_plus_monthly`, `fw_plus_yearly`
- [ ] Both products in subscription group: **"FlareWeather Subscription"**
- [ ] Products in **"Ready to Submit"** or **"Approved"** status
- [ ] Bundle ID matches between Xcode and App Store Connect
- [ ] Using **sandbox test account** in TestFlight (not real Apple ID)
- [ ] Signed out of real Apple ID in Settings → App Store
- [ ] Internet connection working
- [ ] Waiting at least 5 minutes after creating products
- [ ] Checked Xcode console for error logs

---

## Still Not Working?

If products still don't load after checking everything:

1. **Share Xcode console logs** when you:
   - Open the paywall screen
   - Tap the Subscribe button

2. **Verify in App Store Connect:**
   - Screenshot of subscription group showing both products
   - Screenshot of each product's details (especially Product ID)

3. **Common fixes:**
   - **Delete and recreate** subscription group (sometimes helps)
   - **Remove and re-add** products to subscription group
   - **Wait 15-30 minutes** after making changes (Apple propagation time)
   - **Test on a different device** to rule out device-specific issues

---

## Testing with StoreKit Configuration (Simulator)

While debugging TestFlight issues, you can test in the **Xcode Simulator**:

1. Use the `Products.storekit` file
2. Configure Xcode scheme to use it (Run → Options → StoreKit Configuration)
3. Products will load immediately (no App Store Connect needed)
4. Perfect for UI testing while fixing App Store Connect setup

See `SIMULATOR_TESTING_STOREKIT.md` for details.

