# Why "Selected Plan Not Available" After Creating Sandbox Tester?

**Short answer:** Products should work in sandbox BEFORE review, but you need to complete these steps first:

---

## The Issue

You're seeing "Selected plan not available" because products aren't ready for sandbox testing yet. **You don't need Apple to review a build** - products should work in sandbox once properly configured.

---

## What You Need (In Order)

### ✅ Step 1: Fix "Missing Metadata" Status (MUST DO FIRST)

**Go to App Store Connect:**
1. Features → Subscriptions → [Your Group]
2. Click on each subscription (`fw_plus_monthly`, `fw_plus_yearly`)
3. Complete ALL required fields:
   - **Subscription Information** tab (Display Name, Description)
   - **Pricing** tab (at least US region)
   - **Review Information** tab (Description, Screenshot - at least 1)
   - **Introductory Offer** tab (Monthly: 7-day trial, Yearly: leave empty)
4. **Save** each tab
5. **Status should change** from "Missing Metadata" → **"Ready to Submit"** ✅

**⚠️ Products MUST be "Ready to Submit" before they'll work in sandbox.**

---

### ✅ Step 2: Upload a Binary (REQUIRED)

Even though you don't need to submit for review, you DO need a binary uploaded:

1. **In Xcode:**
   - Increment **Build** number (e.g., `1` → `2`)
   - Product → **Archive**
   - Click **"Distribute App"**
   - Choose **"App Store Connect"**
   - Upload the build

2. **Wait for processing** (10-30 minutes)
   - Check in App Store Connect → TestFlight
   - Build should show as "Processing" → "Ready to Test"

**⚠️ Products won't work until a binary is uploaded to App Store Connect.**

---

### ✅ Step 3: Attach Subscriptions to App Version (REQUIRED)

After binary is uploaded:

1. **Go to App Store Connect:**
   - App Store tab → Your app version
   - Scroll to **"In-App Purchases and Subscriptions"** section
   - Click **"+"** or **"Manage"**
   - Select your subscription group (both products should be listed)
   - Click **"Done"** or **"Save"**

**⚠️ Products must be attached to the app version with the uploaded binary.**

---

### ✅ Step 4: Wait for Propagation (15-30 minutes)

After completing all steps:
- Wait **15-30 minutes** for Apple to process
- Products should then be available in sandbox

---

## Quick Checklist

Check these in order:

- [ ] **Subscriptions show "Ready to Submit"** (not "Missing Metadata")
  - If "Missing Metadata": Follow `FIX_MISSING_METADATA.md`

- [ ] **Binary uploaded to App Store Connect**
  - Check TestFlight → see your build listed
  - Build status: "Ready to Test" or "Processing"

- [ ] **Subscriptions attached to app version**
  - Go to App Store tab → Your version
  - "In-App Purchases and Subscriptions" section shows your subscription group

- [ ] **Sandbox tester created**
  - Users and Access → Sandbox Testers
  - Your tester account exists ✅

- [ ] **Signed out of real Apple ID**
  - Settings → App Store → Sign Out
  - **Critical:** Must be signed out for sandbox to work

- [ ] **Waited 15-30 minutes** after completing all steps
  - Apple needs time to propagate changes

---

## Common Issues

### "Still showing Missing Metadata"

**Problem:** Products not in "Ready to Submit" status

**Solution:**
- Go through each subscription product
- Fill out ALL tabs (Subscription Info, Pricing, Review Info, Intro Offer)
- Make sure you **Save** each tab
- Look for red warning indicators
- Status must say "Ready to Submit" (not "Missing Metadata")

---

### "No binary uploaded"

**Problem:** App Store Connect doesn't have a build yet

**Solution:**
1. In Xcode: Product → Archive
2. Upload to App Store Connect
3. Wait for processing
4. Check TestFlight section to verify build is uploaded

**Note:** You don't need to submit for review - just uploading is enough for sandbox testing.

---

### "Products not attached to version"

**Problem:** Subscriptions exist but aren't linked to app version

**Solution:**
1. Go to App Store tab → Your app version
2. Scroll to "In-App Purchases and Subscriptions"
3. Click "+" or "Manage"
4. Select your subscription group
5. Save

**Note:** The app version must have a binary uploaded for subscriptions to attach.

---

### "Still not available after everything"

**Problem:** Propagation delay or configuration issue

**Solution:**
1. **Double-check status:**
   - Products: "Ready to Submit" ✅
   - Binary uploaded: "Ready to Test" ✅
   - Subscriptions attached: Visible in app version ✅

2. **Wait longer:**
   - Try again after 30-60 minutes
   - Apple propagation can be slow

3. **Check Xcode console:**
   - Open paywall in TestFlight
   - Check Xcode console logs
   - Look for: `✅ Fetched 2 products` (success)
   - Or: `⚠️ No products found` (still not ready)

4. **Verify sandbox account:**
   - Settings → App Store → Make sure you're signed out
   - When prompted during purchase, use sandbox account

---

## Timeline

**Minimum time needed:**

1. Fix metadata: **10-15 minutes** (filling out forms)
2. Upload binary: **5 minutes** (archive + upload)
3. Wait for processing: **10-30 minutes** (Apple processing)
4. Attach subscriptions: **2 minutes** (linking to version)
5. Wait for propagation: **15-30 minutes** (Apple propagating)

**Total: ~45-90 minutes** from start to working sandbox products

---

## You DON'T Need:

- ❌ App to be **submitted for review** (not required for sandbox)
- ❌ App to be **approved** (not required for sandbox)
- ❌ Products to be **approved** (just need "Ready to Submit")
- ❌ App to be in **production** (TestFlight sandbox works fine)

**You DO need:**
- ✅ Products in "Ready to Submit" status
- ✅ Binary uploaded (even if not submitted)
- ✅ Subscriptions attached to app version
- ✅ Sandbox tester account
- ✅ Signed out of real Apple ID

---

## Test Now

After completing all steps:

1. **Open TestFlight** on your device
2. **Open FlareWeather app**
3. **Navigate to paywall**
4. **Check Xcode console:**
   - Should see: `✅ Fetched 2 products`
   - Not: `⚠️ No products found`

5. **Tap Subscribe:**
   - Should prompt for Apple ID
   - Use: `khurrie@outlook.com` / `Flareweather1`
   - Purchase should complete in sandbox (no real charge)

---

## Still Not Working?

If products still don't work after checking everything:

1. **Share Xcode console logs** when you:
   - Open the paywall screen
   - See what it says about products

2. **Check App Store Connect:**
   - Screenshot of subscription status ("Ready to Submit"?)
   - Screenshot of app version showing subscriptions attached
   - Screenshot of TestFlight showing uploaded build

3. **Verify:**
   - Bundle ID matches: `KHUR.FlareWeather`
   - Product IDs match exactly: `fw_plus_monthly`, `fw_plus_yearly`
   - Both products in same subscription group

The most common issue is products still showing **"Missing Metadata"** - make sure you complete all required fields and status changes to "Ready to Submit"!

