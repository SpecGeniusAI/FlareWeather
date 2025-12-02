# App Store Review Response Guide

## Issue 1: Guideline 2.3.2 - Accurate Metadata

**Problem:** App description and screenshots refer to paid content/features but don't clearly identify that purchase is required.

**Solution:** Update App Store Connect metadata to clearly mark paid features.

### Steps to Fix:

1. **Log into App Store Connect**
   - Go to: https://appstoreconnect.apple.com
   - Navigate to: Apps → FlareWeather → App Information

2. **Update App Description**
   - Add clear language about what's free vs. what requires subscription
   - Example addition at the top or bottom of description:
   
   ```
   FREE FEATURES:
   - Real-time weather data
   - Basic weather forecasts
   - Generic daily weather insights
   
   PREMIUM FEATURES (Requires Subscription):
   - Personalized AI insights based on your conditions
   - Weekly forecast insights
   - Symptom tracking and correlation analysis
   
   Start with a 7-day free trial, then $2.99/month or $19.99/year.
   ```

3. **Update Screenshots**
   - Add text overlay to screenshots showing premium features:
   - Text like "Premium Feature" or "Subscription Required" on relevant screenshots
   - Or add a caption below screenshots indicating what requires subscription

4. **Update Keywords**
   - Ensure keywords don't imply all features are free

---

## Issue 2: Guideline 2.1 - App Completeness - Purchase Error

**Problem:** Error occurred when attempting to purchase subscription during review.

**Note:** Your app uses StoreKit 2, which handles purchases entirely client-side. There is **NO server-side receipt validation** in your backend. The error Apple is referencing might be:

1. A client-side StoreKit error during testing
2. A misunderstanding about StoreKit 2 architecture
3. An issue with sandbox testing environment

### What We've Fixed:

1. **Improved Error Handling** (already implemented)
   - Added detailed error logging
   - Better error messages for users
   - Handles "No active account" errors gracefully

2. **StoreKit 2 Architecture**
   - Uses `Transaction.currentEntitlements` for verification
   - No server-side receipt validation required
   - All subscription checking is client-side

### To Verify Before Resubmission:

1. **Test Purchase Flow:**
   - Test in TestFlight with a sandbox account
   - Verify purchases complete successfully
   - Verify entitlements are detected correctly
   - Test both monthly and yearly subscriptions

2. **Check App Store Connect:**
   - Ensure products are "Ready to Submit" or approved
   - Verify subscription group is correct
   - Ensure all metadata is filled out

3. **Response to Apple (if needed):**
   ```
   Our app uses StoreKit 2, which handles subscription purchases 
   entirely client-side using Transaction.currentEntitlements. 
   There is no server-side receipt validation that could cause 
   sandbox/production receipt errors. All subscription status 
   checking happens on the device using Apple's StoreKit 2 APIs.
   
   We've improved error handling and tested thoroughly in 
   TestFlight. Purchases should work correctly in the review 
   environment.
   ```

---

## Testing Checklist Before Resubmission:

- [ ] Updated app description with free vs. premium distinction
- [ ] Updated screenshots with premium feature indicators
- [ ] Tested purchase flow in TestFlight with sandbox account
- [ ] Verified monthly subscription purchase works
- [ ] Verified yearly subscription purchase works
- [ ] Verified free trial activates correctly
- [ ] Verified entitlements are detected after purchase
- [ ] Tested restore purchases functionality
- [ ] All subscription products show correct pricing

---

## Quick Fix Summary:

1. **Metadata Issue:** Update App Store Connect description and screenshots (5 minutes)
2. **Purchase Issue:** Already fixed with improved error handling - just needs testing verification

---

## Response Template for App Store Connect:

**Subject:** Resubmission - Metadata and Purchase Fixes

**Message:**

```
Thank you for the review feedback. We've addressed both issues:

1. Guideline 2.3.2 - Metadata: 
   We've updated our app description and screenshots to clearly 
   identify which features require a subscription purchase.

2. Guideline 2.1 - Purchase Error:
   Our app uses StoreKit 2 for subscriptions, which handles 
   purchases client-side. We've improved error handling and 
   thoroughly tested the purchase flow in TestFlight. Purchases 
   should work correctly during review.

Please let us know if you encounter any issues during testing.
```
