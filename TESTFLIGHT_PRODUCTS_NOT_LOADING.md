# TestFlight: "Unable to load subscription data" - Troubleshooting Guide

If you're seeing **"Unable to load subscription data. Please check connection and try again."** in TestFlight, follow these steps:

---

## Step 1: Check Xcode Console Logs

**When you open the paywall in TestFlight, check the Xcode console for debug messages:**

1. **Connect your iPhone to your Mac via USB**
2. **Open Xcode** → **Window** → **Devices and Simulators**
3. **Select your iPhone** → Click **"Open Console"**
4. **Filter logs** for: `SubscriptionManager`, `fetchProducts`, `fw_plus`
5. **Open FlareWeather** from TestFlight → Navigate to paywall
6. **Look for these messages:**

### ✅ Success Message:
```
✅ Fetched 2 products
   - fw_plus_monthly: $2.99
   - fw_plus_yearly: $19.99
✅ Both products found and available
```

### ❌ Failure Message (Products Empty):
```
❌ No products found! This means:
   1. Products may not exist in App Store Connect...
```

### ❌ Failure Message (Error):
```
❌ Failed to fetch products: [error description]
   Error domain: [domain]
   Error code: [code]
```

**Share these console logs** - they'll tell us exactly what's wrong.

---

## Step 2: Verify Products in App Store Connect

### 2.1: Check Products Exist

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app → **Features** → **Subscriptions**
3. Click on **"FlareWeather Subscription"** subscription group

**Verify you see both products:**
- `fw_plus_monthly`
- `fw_plus_yearly`

**If products are missing:**
- Create them following `FIX_MISSING_METADATA.md`

### 2.2: Check Product Status

For **each product** (`fw_plus_monthly` and `fw_plus_yearly`):

1. Click on the product name
2. Check the **status** at the top:
   - ✅ **"Ready to Submit"** = Good (should work)
   - ✅ **"Approved"** = Good (will work)
   - ❌ **"Missing Metadata"** = Bad (won't work)
   - ❌ **"Waiting for Review"** = Should work, but may have issues

**If status is "Missing Metadata":**
- Complete all required fields (see `FIX_MISSING_METADATA.md`)
- Save the product
- Wait 15-30 minutes for Apple to process

### 2.3: Verify Product IDs Match Exactly

**CRITICAL**: Product IDs must match **exactly** (case-sensitive, no spaces):

- ✅ `fw_plus_monthly` (correct)
- ❌ `fw_plus_Monthly` (wrong - capital M)
- ❌ `fw_plus_monthly ` (wrong - trailing space)
- ❌ `fw-plus-monthly` (wrong - dashes instead of underscores)

**Check in App Store Connect:**
1. Click on each product
2. Look at the **"Product ID"** field
3. Must be exactly: `fw_plus_monthly` and `fw_plus_yearly`

---

## Step 3: Verify Products Are Attached to App Version

**This is the #1 cause of "products not available" in TestFlight.**

### 3.1: Check App Version Has Subscriptions

1. Go to your app in App Store Connect
2. Click **"App Store"** tab
3. Click on your current version (e.g., **1.3**)
4. Scroll down to **"In-App Purchases and Subscriptions"** section
5. **Verify both products are listed:**
   - `fw_plus_monthly`
   - `fw_plus_yearly`

### 3.2: If Products Are NOT Attached

**You must attach products to an app version:**

1. In the app version page, scroll to **"In-App Purchases and Subscriptions"**
2. Click **"+"** or **"Manage In-App Purchases"**
3. Select your subscription group: **"FlareWeather Subscription"**
4. Check both products: `fw_plus_monthly`, `fw_plus_yearly`
5. Click **"Add"** or **"Save"**
6. **Save the app version**

**Important:**
- If this is your **first time** adding subscriptions, you **must submit the app version for review**
- Even if you don't intend to release yet, you need to submit to make subscriptions work in TestFlight
- See `SUBMIT_FIRST_SUBSCRIPTION.md` for details

---

## Step 4: Verify Bundle ID Matches

**If Bundle ID doesn't match, products won't load.**

### 4.1: Check Bundle ID in Xcode

1. Open your Xcode project
2. Select the **FlareWeather** target
3. Go to **"Signing & Capabilities"** tab
4. Note the **Bundle Identifier** (e.g., `com.yourcompany.FlareWeather`)

### 4.2: Check Bundle ID in App Store Connect

1. Go to your app in App Store Connect
2. Click **"App Information"** tab
3. Look at **"Bundle ID"** field
4. **Must match exactly** (including casing)

**If they don't match:**
- Update the Bundle ID in Xcode to match App Store Connect
- Or create a new app in App Store Connect with the correct Bundle ID

---

## Step 5: Wait for Propagation

**After making any changes in App Store Connect, wait 15-30 minutes:**

- ✅ Product status changes: **15-30 minutes**
- ✅ Attaching products to version: **15-30 minutes**
- ✅ Creating new products: **15-30 minutes**
- ✅ Submitting for review: **30-60 minutes**

**TestFlight doesn't update immediately** - Apple needs time to process changes.

---

## Step 6: Verify TestFlight Setup

### 6.1: Check You're Using TestFlight Build

**Products only work in TestFlight builds, NOT simulator:**

- ✅ Testing in **TestFlight** on real device = Good
- ❌ Testing in **Xcode Simulator** = Uses `Products.storekit` (not App Store Connect)
- ❌ Testing in **Production App Store** = Won't work (products not released)

### 6.2: Check Sandbox Account

1. **Sign out** of real Apple ID: Settings → App Store → Sign Out
2. When making purchase, use **sandbox test account** (not real Apple ID)
3. See `SANDBOX_SETUP_WALKTHROUGH.md` for details

---

## Step 7: Common Issues & Solutions

### Issue 1: Products Show "Missing Metadata"

**Solution:**
- Complete all required fields in App Store Connect
- Pricing for at least one region
- Subscription group assigned
- Localized description
- See `FIX_MISSING_METADATA.md`

### Issue 2: "First subscription must be submitted with app version"

**Solution:**
- Attach subscriptions to app version
- Submit app version for review (even if beta)
- See `SUBMIT_FIRST_SUBSCRIPTION.md`

### Issue 3: Products Load but Purchase Fails

**Different issue** - products are loading correctly
- Check sandbox account is signed in
- Check products are in "Ready to Submit" status
- See `TESTFLIGHT_STOREKIT_TROUBLESHOOTING.md`

### Issue 4: Network/Connection Errors

**Solution:**
- Check internet connection
- Try on different network (WiFi vs Cellular)
- Restart device
- Wait a few minutes and try again

---

## Step 8: Debug Checklist

Before reporting an issue, verify:

- [ ] Both products exist in App Store Connect: `fw_plus_monthly`, `fw_plus_yearly`
- [ ] Both products in subscription group: **"FlareWeather Subscription"**
- [ ] Both products status: **"Ready to Submit"** or **"Approved"**
- [ ] Both products **attached to app version** in App Store Connect
- [ ] Bundle ID matches between Xcode and App Store Connect
- [ ] Waited 15-30 minutes after making changes
- [ ] Testing in **TestFlight** (not simulator or production)
- [ ] Signed out of real Apple ID on test device
- [ ] Checked Xcode console logs when opening paywall
- [ ] Console shows: `✅ Fetched 2 products` or error details

---

## Step 9: Share Debug Information

If products still don't load, share:

1. **Xcode Console Logs** when opening paywall (filter: `SubscriptionManager`, `fetchProducts`)
2. **App Store Connect Screenshots:**
   - Subscription group showing both products
   - Each product's details page (showing Product ID and status)
   - App version page showing "In-App Purchases and Subscriptions" section
3. **Product Status:**
   - Status of `fw_plus_monthly` (Ready to Submit? Missing Metadata?)
   - Status of `fw_plus_yearly` (Ready to Submit? Missing Metadata?)
4. **Are products attached to app version?** (Yes/No)

This information will help diagnose the exact issue.

---

## Quick Fixes to Try

1. **Wait 30 minutes** after making any App Store Connect changes
2. **Force close FlareWeather** app on your device and reopen
3. **Restart your iPhone**
4. **Pull to refresh** on the paywall screen (swipe down)
5. **Tap "Retry Loading Plans"** button if shown
6. **Sign out and back in** with sandbox test account
7. **Delete TestFlight build** and reinstall
8. **Try on a different device** (if available)

---

## Still Not Working?

If you've checked everything above and products still don't load:

1. **Verify products are attached to app version** (most common issue)
2. **Submit app version for review** (required for first subscription)
3. **Wait 30 minutes** after submitting
4. **Check Xcode console logs** for specific error messages
5. **Share debug information** (Step 9 above)

The improved error handling and retry logic should provide better error messages in the app. Check the Xcode console for detailed logs when the paywall loads.

