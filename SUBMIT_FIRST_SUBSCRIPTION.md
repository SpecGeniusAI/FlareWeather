# Submitting Your First Subscription with App Version

Apple requires that your **first subscription must be submitted with a new app version**. This is a one-time requirement. Here's how to do it:

---

## Understanding the Requirement

**Important:** 
- ✅ **First subscription**: Must be submitted with a new app version
- ✅ **Additional subscriptions**: Can be submitted separately after the first one is approved
- ✅ **After first approval**: Future subscriptions can be submitted from the Subscriptions section directly

---

## Step 1: Complete Subscription Metadata (Do This First)

Before you can attach subscriptions to an app version, they must be in **"Ready to Submit"** status.

### Complete for Both Subscriptions:

1. **Go to App Store Connect** → Your App → **Features** → **Subscriptions**
2. Click on your subscription group
3. For **each subscription** (`fw_plus_monthly` and `fw_plus_yearly`):

   **Subscription Information Tab:**
   - Display Name: `FlareWeather Plus Monthly` (or "Monthly")
   - Description: Brief description of what users get
   - Duration: Already set (1 Month / 1 Year)

   **Pricing Tab:**
   - Set pricing tier (at least US region)
   - Monthly: $2.99/month
   - Yearly: $19.99/year

   **Introductory Offer Tab:**
   - Monthly: Add 7-Day Free Trial
   - Yearly: Leave empty

   **Review Information Tab:**
   - Subscription Name
   - Description (for Apple review)
   - Screenshots (at least 1)
   - Promotional Text (optional)

4. **Save** all tabs
5. **Verify status** changes to **"Ready to Submit"** ✅

---

## Step 2: Create a New App Version

You need a new app version to attach your subscriptions:

1. **Go to App Store Connect** → Your App → **App Store** tab
2. If you don't have a version in "Prepare for Submission":
   - Click **"+"** next to "iOS App"
   - Enter version number (e.g., `1.1.0` or `1.0.1`)
   - Click **"Create"**

3. If you already have a version:
   - You can use that version, or
   - Create a new one (e.g., increment the build number)

---

## Step 3: Attach Subscriptions to App Version

This is the critical step Apple mentioned:

1. **In App Store Connect**, go to your app
2. Go to the **App Store** tab
3. Click on your **new app version** (the one you want to submit)
4. Scroll down to **"In-App Purchases and Subscriptions"** section
5. Click the **"+"** button (or **"Manage"** if it's already there)
6. **Select your subscription group**:
   - Check the box next to **"FlareWeather Subscription"** (or whatever you named it)
   - This should include both `fw_plus_monthly` and `fw_plus_yearly`

7. Click **"Done"** or **"Save"**

**What this does:**
- Links your subscriptions to this app version
- Allows Apple to review them together
- Makes subscriptions available after approval

---

## Step 4: Upload App Binary

You need to upload a new build that includes your StoreKit code:

### In Xcode:

1. **Increment Build Number:**
   - Select your project
   - Go to **General** tab
   - Increment **Build** number (e.g., from `1` to `2`)
   - Version can stay the same or increment (e.g., `1.0.0` to `1.0.1`)

2. **Archive Build:**
   - In Xcode: **Product** → **Archive**
   - Wait for archive to complete

3. **Upload to App Store Connect:**
   - In Organizer window, select your archive
   - Click **"Distribute App"**
   - Choose **"App Store Connect"**
   - Follow the upload wizard
   - **Important:** Don't submit for review yet (you'll do that in App Store Connect)

### Alternative: Upload via TestFlight First

You can also upload to **TestFlight** first to test:
- Upload build to TestFlight
- Wait for processing
- Then attach subscriptions to app version (Step 3)
- Then submit for review (Step 5)

---

## Step 5: Select Subscriptions in App Version

**After binary is uploaded** (processing may take 10-30 minutes):

1. **Go back to App Store Connect** → Your App → **App Store** tab
2. Click on your **app version**
3. In **"In-App Purchases and Subscriptions"** section:
   - You should see your subscription group listed
   - Both `fw_plus_monthly` and `fw_plus_yearly` should be selected
   - Status should show they're ready

4. **Verify everything is correct:**
   - Subscriptions show as "Ready to Submit"
   - Both subscriptions are attached
   - Binary is uploaded and processed

---

## Step 6: Fill Out App Version Details

Before submitting, complete the app version information:

1. **Screenshots** (if required)
2. **App Description**
3. **What's New in This Version** (mention subscriptions)
4. **Review Information**
5. **Version Release** (automatic or manual)

---

## Step 7: Submit for Review

1. In your app version page, click **"Add for Review"** (or **"Submit for Review"**)
2. Review the checklist
3. Click **"Submit"**

**What happens:**
- App version and subscriptions are submitted together
- Apple reviews both
- After approval, subscriptions become available

---

## Testing While Waiting for Review

**Good news:** Even while waiting for review, you can test subscriptions in **sandbox**:

1. **Products must be "Ready to Submit"** (not just "Missing Metadata")
2. **TestFlight builds** can use sandbox subscriptions
3. **Sign out** of real Apple ID in Settings → App Store
4. **Use sandbox test account** when prompted during purchase

**Note:** Subscriptions won't work in TestFlight until they're in "Ready to Submit" status AND attached to an app version (even if that version isn't approved yet).

---

## After First Subscription is Approved

Once your first subscription is approved:

✅ **Future subscriptions** can be submitted directly from the **Subscriptions** section  
✅ **No need** to attach them to new app versions  
✅ **Can update** subscription pricing/details without new app version  
✅ **Can add** new subscriptions to the group independently

---

## Quick Checklist

Before submitting:

- [ ] Both subscriptions in **"Ready to Submit"** status (not "Missing Metadata")
- [ ] New app version created (or existing version ready)
- [ ] Subscriptions attached to app version (in "In-App Purchases and Subscriptions" section)
- [ ] New binary uploaded (includes StoreKit code)
- [ ] Build number incremented
- [ ] App version details filled out
- [ ] Ready to submit for review

---

## Common Issues

### "Subscriptions not showing in app version page"

**Solution:**
- Make sure subscriptions are in **"Ready to Submit"** status first
- Wait a few minutes after changing status (Apple processing)
- Refresh the page
- Try clicking "+" in "In-App Purchases and Subscriptions" section

### "Binary not processed yet"

**Solution:**
- Wait 15-30 minutes after uploading
- Check **TestFlight** section to see if build is processed
- Binary must be processed before you can submit version

### "Still can't test in TestFlight"

**Solution:**
- Make sure subscriptions are attached to app version (even if not approved)
- Wait 15-30 minutes after attaching subscriptions
- Use sandbox test account (not real Apple ID)
- Check Xcode console for product loading logs

---

## Summary Workflow

```
1. Create subscriptions → Fill metadata → "Ready to Submit" ✅
2. Create new app version (or use existing)
3. Attach subscriptions to app version
4. Upload new binary (with StoreKit code)
5. Wait for binary processing
6. Verify subscriptions attached to version
7. Fill out app version details
8. Submit for review
9. Wait for approval
10. After approval: Future subscriptions can be submitted separately
```

---

## Next Steps

1. **Complete subscription metadata** (fix "Missing Metadata" status)
2. **Create/select app version** in App Store Connect
3. **Attach subscriptions** to that version
4. **Upload new build** from Xcode
5. **Submit for review**

Once you complete these steps, your subscriptions will be available for testing in sandbox, and after approval, they'll be live in the App Store!

