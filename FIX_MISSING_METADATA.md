# Fix "Missing Metadata" Status for Subscriptions

If your subscriptions show **"Missing Metadata"** in App Store Connect, they won't be available in TestFlight until you complete all required fields. Follow these steps:

---

## Quick Fix Checklist

For each subscription product (`fw_plus_monthly` and `fw_plus_yearly`), you need to complete:

1. ✅ **Subscription Information** (Display Name, Description)
2. ✅ **Pricing** (at least one region)
3. ✅ **Review Information** (Screenshots, Promotional Text, Description)
4. ✅ **Introductory Offer** (for monthly only - 7-day free trial)

---

## Step 1: Fix Monthly Subscription (`fw_plus_monthly`)

### 1.1 Go to App Store Connect
1. Navigate to: **My Apps** → **FlareWeather** → **Features** → **Subscriptions**
2. Click on your subscription group (e.g., "FlareWeather Subscription")
3. Click on the **Monthly** subscription product

### 1.2 Fill Subscription Information Tab

**Required fields:**

- **Subscription Display Name**: 
  ```
  FlareWeather Plus Monthly
  ```
  (Or just "Monthly" - this is what users see)

- **Description**: 
  ```
  Monthly subscription to FlareWeather Plus. Get personalized daily and weekly weather insights tailored to your health conditions.
  ```
  (Make it clear what users get)

- **Subscription Duration**: 
  - Already set to **1 Month** ✓

### 1.3 Set Pricing Tab

**Required:** Set pricing for at least your primary market (e.g., United States)

1. Click **"Pricing"** tab
2. Click **"Edit"** or **"Add Pricing"**
3. Select your pricing tier:
   - For **$2.99/month**: Find and select the appropriate tier
   - You can also set pricing for other countries/regions, but **at minimum set United States**

4. Click **"Save"**

### 1.4 Configure Introductory Offer (7-Day Free Trial)

**Required for monthly subscription:**

1. Click **"Introductory Offer"** section
2. Click **"Add Introductory Offer"** (if not already added)
3. Configure:
   - **Offer Type**: **Free Trial**
   - **Duration**: **7 Days**
   - **Display Name**: `7-Day Free Trial`
   - **Note**: Leave other fields empty (no discount percentage needed for free trial)

4. Click **"Save"**

### 1.5 Fill Review Information Tab

**Required:** Apple needs review materials (even if you're just testing in sandbox)

1. Click **"Review Information"** tab
2. Fill out these fields:

   **Subscription Name (Display Name)**:
   ```
   FlareWeather Plus Monthly
   ```

   **Description** (for App Store review):
   ```
   FlareWeather Plus provides personalized daily and weekly weather insights to help users with chronic conditions like arthritis and chronic pain manage their symptoms. The monthly subscription includes AI-powered weather analysis tailored to individual health conditions and sensitivities.
   ```
   (Explain what the subscription provides)

   **Promotional Text** (optional, can leave blank for now):
   ```
   Get personalized weather insights tailored to your health conditions.
   ```

   **Review Screenshots**:
   - **At minimum**: Add one screenshot of your paywall/subscription screen
   - Can be a screenshot from your app showing what users get
   - Format: 6.5" display (iPhone 14 Pro Max) or 6.7" display
   - You can take a screenshot from TestFlight and upload it

3. Click **"Save"**

### 1.6 Save Subscription

1. Scroll to the top
2. Click **"Save"** (if there's a save button in the top right)
3. Status should change from **"Missing Metadata"** to **"Ready to Submit"**

---

## Step 2: Fix Yearly Subscription (`fw_plus_yearly`)

### 2.1 Go to Yearly Product

1. In the same subscription group, click on the **Yearly** subscription product

### 2.2 Fill Subscription Information Tab

- **Subscription Display Name**: 
  ```
  FlareWeather Plus Yearly
  ```
  (Or "Yearly")

- **Description**: 
  ```
  Yearly subscription to FlareWeather Plus. Save 44% compared to monthly. Get personalized daily and weekly weather insights tailored to your health conditions.
  ```

- **Subscription Duration**: 
  - Should be **1 Year** ✓

### 2.3 Set Pricing Tab

1. Click **"Pricing"** tab
2. Click **"Edit"** or **"Add Pricing"**
3. Select pricing tier for **$19.99/year**
4. Click **"Save"**

### 2.4 Introductory Offer

**For yearly subscription:**
- **Leave empty** (no introductory offer for yearly)
- Make sure no offer is added here

### 2.5 Fill Review Information Tab

Same as monthly:

1. Click **"Review Information"** tab
2. Fill out:

   **Subscription Name**:
   ```
   FlareWeather Plus Yearly
   ```

   **Description**:
   ```
   FlareWeather Plus provides personalized daily and weekly weather insights to help users with chronic conditions like arthritis and chronic pain manage their symptoms. The yearly subscription offers the best value, saving 44% compared to monthly billing. Includes AI-powered weather analysis tailored to individual health conditions and sensitivities.
   ```

   **Promotional Text** (optional):
   ```
   Best value: Save 44% with yearly subscription.
   ```

   **Review Screenshots**:
   - Same screenshot as monthly (or take a new one)
   - Shows your paywall/subscription screen

3. Click **"Save"**

### 2.6 Save Subscription

1. Click **"Save"** 
2. Status should change to **"Ready to Submit"**

---

## Step 3: Verify Status Changed

After completing all fields:

1. Go back to **Features** → **Subscriptions** → [Your Subscription Group]
2. Both products should now show: **"Ready to Submit"** ✅
3. If still showing "Missing Metadata":
   - Click on the product again
   - Look for **red warnings** or **missing fields indicators**
   - Complete any remaining required fields

---

## Step 4: Wait for Propagation (Important!)

After changing status from "Missing Metadata" to "Ready to Submit":

1. **Wait 5-15 minutes** for Apple to process the changes
2. Products may not appear in sandbox immediately
3. Sometimes takes up to **30 minutes**

### How to Test:

1. Open your app in TestFlight
2. Navigate to the paywall screen
3. Check Xcode console logs:
   - Should see: `✅ Fetched 2 products`
   - Instead of: `⚠️ No products found`

---

## Common Issues

### "Still showing Missing Metadata after filling everything"

**Check:**
- Did you click **"Save"** on each tab?
- Look for red warning icons next to fields
- Scroll through all sections to find missing required fields
- Some fields may be required in specific regions

### "Products still not loading after status changed"

**Wait longer:**
- Apple propagation can take 15-30 minutes
- Try again after waiting
- Check network connection

### "I don't have screenshots ready"

**Quick solution:**
- Take a screenshot from your TestFlight app showing the paywall
- Or use a design mockup
- Apple just needs something for review (won't be used in App Store until you submit)

### "Pricing tier not found"

**Solution:**
- Search for "$2.99" or "$19.99" in the pricing tier list
- If exact price not available, choose closest tier
- You can adjust pricing later

---

## Minimum Requirements Summary

To get products to **"Ready to Submit"** status, you **must** complete:

| Field | Monthly | Yearly | Notes |
|-------|---------|--------|-------|
| Display Name | ✅ Required | ✅ Required | What users see |
| Description | ✅ Required | ✅ Required | What it includes |
| Pricing (US) | ✅ Required | ✅ Required | At least one region |
| Intro Offer | ✅ Required (7-day trial) | ❌ None | Monthly only |
| Review Screenshot | ✅ Required | ✅ Required | At least 1 |
| Review Description | ✅ Required | ✅ Required | For Apple review |

---

## After Fixing

Once both products show **"Ready to Submit"**:

1. ✅ Wait 15 minutes for Apple to propagate
2. ✅ Test in TestFlight with sandbox account
3. ✅ Check Xcode console: Should see `✅ Fetched 2 products`
4. ✅ Products should now be available for purchase in TestFlight

---

## Need Help?

If you're still seeing issues after completing all fields:

1. **Check App Store Connect**: Look for any red warning indicators
2. **Screenshot**: Take a screenshot of the subscription details page showing what's missing
3. **Console Logs**: Share the Xcode console output when you open the paywall

The most common issue is forgetting to fill out the **"Review Information"** tab - make sure you complete that section for both products!

