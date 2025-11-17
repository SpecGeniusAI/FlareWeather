# Create Sandbox Tester Account in App Store Connect

Apple requires a **Sandbox Tester Account** to test in-app purchases and subscriptions in TestFlight. Here's how to create one:

---

## Step-by-Step Instructions

### Step 1: Go to App Store Connect

1. Open [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your **Apple Developer account** (the one you use to manage your app)

### Step 2: Navigate to Sandbox Testers

1. In the top navigation, click **"Users and Access"**
2. In the left sidebar, click **"Sandbox Testers"**
3. You'll see a list of existing sandbox testers (if any)

### Step 3: Create New Sandbox Tester

1. Click the **"+"** button (usually in the top right)
2. Fill in the form:

   **First Name**: (e.g., "Test" or "Kurtis")
   
   **Last Name**: (e.g., "User" or "Hurrie")
   
   **Email Address**: `khurrie@outlook.com` ⚠️ **Important**: 
   - Must be a **real email address** (can be yours)
   - Apple will send an email to verify
   - This email will be used when testing purchases in TestFlight
   
   **Password**: `kursed0987` (or any password you want)
   - Minimum 8 characters
   - Must include at least one uppercase letter, one lowercase letter, and one number
   
   **Country/Region**: Select your country (e.g., United States, Canada, etc.)

3. Click **"Save"** or **"Create"**

### Step 4: Verify Email (if prompted)

- Apple may send a verification email to `khurrie@outlook.com`
- Check your email and click the verification link if needed

---

## Using the Sandbox Tester Account

### In TestFlight:

1. **Sign out of your real Apple ID:**
   - Open **Settings** app on your iOS device
   - Tap **App Store** (or **iTunes & App Store** on older iOS)
   - Tap your Apple ID at the top
   - Tap **"Sign Out"**

2. **Launch FlareWeather app from TestFlight:**
   - Open the TestFlight app
   - Install/open FlareWeather

3. **When prompted for Apple ID during purchase:**
   - Enter: `khurrie@outlook.com`
   - Password: `kursed0987`
   - This will use the **sandbox environment** (no real charges)

---

## Important Notes

### Email Address:
- ✅ You can use your **real email address** (`khurrie@outlook.com`)
- ✅ Sandbox emails are separate from production App Store purchases
- ✅ You can use this email in the sandbox even if it's your real Apple ID email
- ✅ Apple won't send purchase receipts to this email in sandbox mode

### Password Requirements:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter  
- At least 1 number
- No spaces or special characters required (but can be used)

### Testing:
- ✅ Sandbox purchases **don't charge real money**
- ✅ Transactions appear in App Store Connect → **Sales and Trends** → **Sandbox**
- ✅ Subscription trials work normally in sandbox
- ✅ Can test cancellation, renewal, upgrades, etc.

### Limits:
- ⚠️ Sandbox testers can only test in **TestFlight builds**
- ⚠️ Sandbox testers **cannot** test in production App Store
- ⚠️ Each sandbox account can only be used on a limited number of devices

---

## Multiple Sandbox Testers

You can create multiple sandbox testers:
- Use different emails for different test scenarios
- Test family sharing with multiple accounts
- Test subscription upgrades/downgrades

**To create another:**
- Follow the same steps
- Use a different email address
- Each tester is independent

---

## Troubleshooting

### "Email already registered"
- This email might already be a sandbox tester
- Check the existing list of sandbox testers
- Or use a different email address

### "Invalid password format"
- Make sure password meets requirements:
  - 8+ characters
  - Uppercase + lowercase + number

### "Can't sign in with sandbox account"
- Make sure you **signed out** of your real Apple ID in Settings → App Store
- Sandbox accounts only work when signed out of production Apple ID
- Try signing out and restarting the device

### "Products not available"
- Make sure subscriptions are in **"Ready to Submit"** status (not "Missing Metadata")
- Make sure subscriptions are **attached to an app version**
- Wait 15-30 minutes after creating/updating subscriptions

---

## Quick Checklist

Before testing subscriptions in TestFlight:

- [ ] Sandbox tester created in App Store Connect → Users and Access → Sandbox Testers
- [ ] Email: `khurrie@outlook.com` (or another email you have access to)
- [ ] Password: `kursed0987` (meets requirements)
- [ ] **Signed out** of real Apple ID in Settings → App Store
- [ ] Subscriptions are in **"Ready to Submit"** status
- [ ] Subscriptions are **attached to app version**
- [ ] TestFlight build installed on device
- [ ] Ready to test purchases with sandbox account

---

## After Creating Sandbox Tester

Once created:

1. ✅ Sandbox tester is ready immediately
2. ✅ Sign out of real Apple ID on your test device
3. ✅ Open FlareWeather from TestFlight
4. ✅ Navigate to paywall
5. ✅ Tap Subscribe
6. ✅ When prompted for Apple ID, use: `khurrie@outlook.com` / `kursed0987`
7. ✅ Purchase will go through in sandbox (no real charge)

The sandbox tester account is separate from your backend database user account, but you can use the same email for both.

