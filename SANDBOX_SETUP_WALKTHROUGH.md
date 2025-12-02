# Sandbox Test Account Setup - Step-by-Step Walkthrough

This guide will walk you through setting up a sandbox test account to test subscriptions in TestFlight.

---

## Part 1: Create Sandbox Tester in App Store Connect

### Step 1.1: Go to App Store Connect

1. Open your web browser
2. Go to **[appstoreconnect.apple.com](https://appstoreconnect.apple.com)**
3. Sign in with your **Apple Developer account** (the account you use to manage FlareWeather)

### Step 1.2: Navigate to Sandbox Testers

1. In the top navigation bar, click **"Users and Access"**
2. In the left sidebar menu, click **"Sandbox Testers"**
3. You'll see a list of existing sandbox testers (if any)

### Step 1.3: Create New Sandbox Tester

1. Click the **"+"** button in the top-right corner (or "Create Sandbox Tester")
2. Fill out the form:

   **First Name:** 
   - Example: `Test` or `Kurtis`
   - This is just a display name

   **Last Name:**
   - Example: `User` or `Hurrie`
   - This is just a display name

   **Email Address:**
   - ⚠️ **IMPORTANT**: Use a **real email address** that you can access
   - Example: `khurrie@outlook.com` (you can use your own email)
   - Apple will send a verification email (if needed)
   - This email will be used when testing purchases in TestFlight
   - ✅ **You can use the same email as your real Apple ID** - they're separate systems

   **Password:**
   - Create a password (e.g., `TestPassword123`)
   - Requirements:
     - ✅ Minimum 8 characters
     - ✅ At least 1 uppercase letter
     - ✅ At least 1 lowercase letter
     - ✅ At least 1 number
   - Example: `FlareWeather123`

   **Country/Region:**
   - Select your country (e.g., **United States**, Canada, etc.)
   - This affects pricing/currency shown in sandbox

3. Click **"Create"** or **"Save"**

### Step 1.4: Verify Email (if prompted)

- Apple may send a verification email to the address you provided
- Check your email inbox and click the verification link if needed
- After verification, the sandbox tester is ready to use

---

## Part 2: Sign Out of Real Apple ID on Your Device

**CRITICAL STEP**: You MUST sign out of your real Apple ID for sandbox testing to work.

### Step 2.1: Open Settings

1. On your iPhone/iPad, open the **Settings** app
2. Scroll down and tap **"App Store"** (or **"iTunes & App Store"** on older iOS)

### Step 2.2: Sign Out

1. You'll see your Apple ID at the top of the screen
2. Tap on your **Apple ID email** (or name)
3. A menu will appear - tap **"Sign Out"**
4. Confirm by tapping **"Sign Out"** again

**⚠️ IMPORTANT:**
- Do **NOT** sign back in with your real Apple ID
- The device must remain **signed out** of the production App Store
- You'll sign in with the **sandbox account** when making a purchase

---

## Part 3: Test Subscription in TestFlight

### Step 3.1: Open FlareWeather from TestFlight

1. Make sure FlareWeather is installed via **TestFlight** (not App Store)
2. Open the **TestFlight** app
3. Find **FlareWeather** and tap **"Open"**
4. The app will launch

### Step 3.2: Navigate to Paywall

1. Complete the signup/onboarding flow (if needed)
2. When you reach the **paywall screen**, you'll see the subscription options
3. Tap on a subscription plan (Monthly or Yearly)
4. Tap **"Subscribe"** or **"Start My Free Week"**

### Step 3.3: Sign In with Sandbox Account

1. iOS will show a prompt: **"Sign in to iTunes Store"**
2. Enter your **sandbox tester credentials**:
   - **Email**: `khurrie@outlook.com` (or the email you used)
   - **Password**: `FlareWeather123` (or the password you created)
3. Tap **"Sign In"**

### Step 3.4: Complete Purchase

1. The purchase will process (this is in **sandbox mode** - **no real charge**)
2. You'll see a confirmation message
3. The subscription will activate in the app
4. You can verify it worked by checking:
   - App shows subscription as active
   - Settings → Your Plan shows the subscription

---

## Important Notes

### ✅ Sandbox vs Production

- **Sandbox Testers** = Test accounts for TestFlight/testing (no real charges)
- **Real Apple ID** = Production App Store (real charges)
- They are **completely separate** systems

### ✅ Email Address

- You **CAN** use the same email as your real Apple ID
- Sandbox emails are separate from production purchases
- Apple won't send real purchase receipts to sandbox email
- Example: You can use `khurrie@outlook.com` for both real Apple ID and sandbox tester

### ✅ Password Requirements

- Must be 8+ characters
- Must include uppercase, lowercase, and number
- Can include special characters (optional)

### ✅ Testing Limitations

- Sandbox testers only work in **TestFlight** builds (not production App Store)
- Each sandbox account has device limits (usually 3-5 devices)
- Sandbox purchases don't charge real money
- Transactions appear in App Store Connect → Sales and Trends → Sandbox

---

## Troubleshooting

### ❌ "Can't sign in with sandbox account"

**Problem**: Sandbox login fails

**Solutions**:
1. Make sure you're **signed out** of your real Apple ID in Settings → App Store
2. Restart your device
3. Make sure you're using the **correct sandbox email/password**
4. Try creating a new sandbox tester with a different email

### ❌ "Products not available"

**Problem**: Subscriptions don't load in TestFlight

**Solutions**:
1. Make sure subscriptions are in **"Ready to Submit"** status (not "Missing Metadata")
2. Make sure subscriptions are **attached to an app version** in App Store Connect
3. Wait 15-30 minutes after creating/updating subscriptions (Apple needs time to process)
4. Check that Product IDs match exactly: `fw_plus_monthly`, `fw_plus_yearly`

### ❌ "Already signed in" / "Use different account"

**Problem**: iOS still thinks you're signed in with production account

**Solutions**:
1. Go to Settings → App Store → Sign Out (if still signed in)
2. Restart the device
3. Make sure you're testing in **TestFlight** (not production App Store build)

### ❌ Email verification needed

**Problem**: Sandbox tester needs email verification

**Solutions**:
1. Check your email inbox (including spam/junk)
2. Click the verification link Apple sent
3. Try signing in again after verification

---

## Quick Checklist

Before testing subscriptions in TestFlight:

- [ ] Sandbox tester created in App Store Connect → Users and Access → Sandbox Testers
- [ ] Email: `khurrie@outlook.com` (or another email you have access to)
- [ ] Password: `FlareWeather123` (meets requirements: 8+ chars, uppercase, lowercase, number)
- [ ] Country/Region: Selected (e.g., United States)
- [ ] **Signed OUT** of real Apple ID in Settings → App Store on test device
- [ ] Subscriptions are in **"Ready to Submit"** status in App Store Connect
- [ ] Subscriptions are **attached to an app version** in App Store Connect
- [ ] TestFlight build installed on device (not production App Store)
- [ ] Ready to test purchases with sandbox account

---

## Visual Guide (What You'll See)

### In App Store Connect:

```
App Store Connect
├── Users and Access
    └── Sandbox Testers
        └── [+ Create Sandbox Tester]
            ├── First Name: Test
            ├── Last Name: User
            ├── Email: khurrie@outlook.com
            ├── Password: FlareWeather123
            └── Country: United States
```

### On Your iPhone:

```
Settings
└── App Store
    └── [Apple ID] ← Tap here
        └── Sign Out ← Tap this

TestFlight
└── FlareWeather
    └── Open
        └── Paywall
            └── Subscribe
                └── Sign in with sandbox account
                    ├── Email: khurrie@outlook.com
                    └── Password: FlareWeather123
```

---

## Next Steps

After setting up your sandbox tester:

1. ✅ Create the sandbox tester account
2. ✅ Sign out of real Apple ID on your test device
3. ✅ Open FlareWeather from TestFlight
4. ✅ Navigate to the paywall
5. ✅ Tap Subscribe
6. ✅ Sign in with sandbox credentials when prompted
7. ✅ Verify subscription activates successfully

If you encounter any issues, check the troubleshooting section above or review the console logs in Xcode when testing.

