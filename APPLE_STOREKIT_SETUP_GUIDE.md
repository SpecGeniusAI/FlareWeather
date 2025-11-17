# Apple StoreKit Subscription Setup Guide

## Overview
To fix the "selected plan not available" error, you need to configure subscription products in App Store Connect. This guide walks you through the complete setup process.

---

## Step 1: Access App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Select your app (FlareWeather)

---

## Step 2: Create Subscription Groups

1. Navigate to your app
2. Click **"Features"** in the left sidebar
3. Click **"Subscriptions"**
4. Click the **"+"** button to create a subscription group
5. Name it: **"FlareWeather Plus"** (or similar)
6. Click **"Create"**

---

## Step 3: Create Monthly Subscription

1. Within your subscription group, click **"Create Subscription"**
2. **Reference Name**: `FlareWeather Plus Monthly`
3. **Product ID**: `fw_plus_monthly` ⚠️ **MUST MATCH EXACTLY**
4. Click **"Create"**

### Configure Monthly Subscription:

#### Subscription Information:
- **Subscription Duration**: 1 Month
- **Subscription Display Name**: "FlareWeather Plus Monthly" (or "Monthly")
- **Description**: "Monthly subscription to FlareWeather Plus"

#### Pricing:
- Select your pricing tier (e.g., $2.99/month)
- Set pricing for all countries/regions where you want to sell

#### Introductory Offer (7-Day Free Trial):
1. Click **"Add Introductory Offer"**
2. **Offer Type**: Free Trial
3. **Duration**: 7 Days
4. **Display Name**: "7-Day Free Trial"
5. Click **"Save"**

#### Review Information:
- Fill in screenshots, description, and other required fields
- Click **"Save"**

---

## Step 4: Create Yearly Subscription

1. Within the same subscription group, click **"Create Subscription"** again
2. **Reference Name**: `FlareWeather Plus Yearly`
3. **Product ID**: `fw_plus_yearly` ⚠️ **MUST MATCH EXACTLY**
4. Click **"Create"**

### Configure Yearly Subscription:

#### Subscription Information:
- **Subscription Duration**: 1 Year
- **Subscription Display Name**: "FlareWeather Plus Yearly" (or "Yearly")
- **Description**: "Yearly subscription to FlareWeather Plus"

#### Pricing:
- Select your pricing tier (e.g., $19.99/year)
- Set pricing for all countries/regions where you want to sell

#### Introductory Offer:
- **No introductory offer** (as per your spec)
- Leave this section empty

#### Review Information:
- Fill in screenshots, description, and other required fields
- Click **"Save"**

---

## Step 5: Submit for Review

1. Both subscriptions must be in **"Ready to Submit"** status
2. Submit your app version that includes the subscription code
3. Apple will review both the app and subscription configuration

---

## Step 6: Testing in Sandbox

### Before Products Are Approved:

You can test in **Sandbox** mode even before products are approved:

1. **Create Sandbox Test Accounts**:
   - In App Store Connect, go to **Users and Access** → **Sandbox Testers**
   - Create test accounts (use fake emails like `test@example.com`)

2. **Use TestFlight**:
   - Build your app with StoreKit code
   - Install via TestFlight
   - Sign out of your real Apple ID in Settings → App Store
   - Launch the app and sign in with a sandbox test account when prompted

3. **Test Purchases**:
   - Products will be available for testing even if not yet approved
   - Sandbox purchases don't charge real money
   - Transactions appear in App Store Connect → Sales and Trends → Sandbox

---

## Step 7: Verify Product IDs in Code

Ensure these match exactly in your `SubscriptionManager.swift`:

```swift
private let monthlyProductID = "fw_plus_monthly"  // ✅ Must match App Store Connect
private let yearlyProductID = "fw_plus_yearly"    // ✅ Must match App Store Connect
```

---

## Common Issues & Solutions

### "Selected plan not available" Error:

**Causes:**
1. ❌ Product IDs don't match exactly
2. ❌ Products not created in App Store Connect yet
3. ❌ Products created but not in "Ready to Submit" status
4. ❌ Testing with wrong Apple ID (need sandbox account)
5. ❌ App bundle ID doesn't match App Store Connect app

**Solutions:**
- ✅ Double-check product IDs match exactly (case-sensitive)
- ✅ Verify products exist in App Store Connect
- ✅ Use sandbox test account for testing
- ✅ Ensure app bundle ID matches

### Products Not Loading:

**Causes:**
1. ❌ Network issues
2. ❌ Not signed in with sandbox account
3. ❌ Products still being processed by Apple

**Solutions:**
- ✅ Check internet connection
- ✅ Sign in with sandbox test account in Settings → App Store
- ✅ Wait a few minutes after creating products (Apple needs to process)

---

## Testing Checklist

- [ ] Created subscription group in App Store Connect
- [ ] Created `fw_plus_monthly` product with 7-day free trial
- [ ] Created `fw_plus_yearly` product (no trial)
- [ ] Product IDs match exactly in code
- [ ] Set pricing for all regions
- [ ] Created sandbox test accounts
- [ ] Tested purchase flow with sandbox account
- [ ] Verified free trial works for monthly
- [ ] Verified yearly purchase works
- [ ] Tested restore purchases
- [ ] Verified subscription status updates correctly

---

## Important Notes

1. **Product IDs are case-sensitive**: `fw_plus_monthly` ≠ `FW_Plus_Monthly`
2. **Sandbox is required for testing**: Real Apple IDs won't work until products are live
3. **Processing time**: Products may take a few minutes to appear after creation
4. **Review process**: Products must be reviewed before going live (can still test in sandbox)

---

## Next Steps

1. Complete the setup in App Store Connect
2. Test thoroughly in sandbox
3. Submit app for review
4. Once approved, subscriptions will work for all users

---

## Support Resources

- [Apple StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Testing In-App Purchases](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)

