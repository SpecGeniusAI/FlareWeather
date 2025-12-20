# Guide: Query Current Subscriber Info

You have two options to pull current subscriber info without waiting for users to open the app:

## Option 1: Use RevenueCat API (Easier - Recommended if using RevenueCat)

If you're using RevenueCat, this is the easiest option.

### Setup:

1. **Get RevenueCat API Key**
   - Go to RevenueCat Dashboard → **Project Settings** → **API Keys**
   - Copy your **Public API Key** or **Secret API Key**

2. **Add to Railway**
   - Add environment variable: `REVENUECAT_API_KEY` = (your API key)

3. **Run the script**
   ```bash
   python query_revenuecat_subscriptions.py
   ```

This will:
- Query RevenueCat for all users
- Match them to your database by email
- Update subscription status and transaction IDs
- Create/update entitlement records

**Note:** RevenueCat uses `app_user_id` to identify customers. The script tries to match by email, but if you use custom user IDs, you may need to adjust the matching logic.

---

## Option 2: Use Apple App Store Server API

This requires App Store Connect API credentials but works directly with Apple.

### Setup:

1. **Get App Store Connect API Credentials**
   - See `APPLE_API_SETUP.md` for detailed instructions
   - You need: Key ID, Issuer ID, Bundle ID, and Private Key

2. **Add to Railway**
   - `APP_STORE_KEY_ID`
   - `APP_STORE_ISSUER_ID`
   - `APP_STORE_BUNDLE_ID`
   - `APP_STORE_PRIVATE_KEY`

3. **Run the script**
   ```bash
   python query_apple_subscriptions.py
   ```

**Limitation:** This only works for users who already have `original_transaction_id` stored. For users who haven't opened the app, we can't query their subscription status.

---

## Which Option Should You Use?

- **Use RevenueCat** if:
  - You're using RevenueCat (which you are)
  - You want the easiest setup
  - You want to get all subscribers regardless of whether they've opened the app

- **Use Apple API** if:
  - You want to query directly from Apple
  - You only need users who have already opened the app (have transaction IDs)

---

## Recommendation

**Start with RevenueCat API** - it's easier and will get you more complete data since RevenueCat tracks all subscribers regardless of whether they've opened the app recently.

Once you have the RevenueCat API key set up in Railway, run:
```bash
python query_revenuecat_subscriptions.py
```

This will pull all current subscriber info and update your database.

---

## After Running

After running either script:
1. Check the output to see how many users were updated
2. Verify in Google Sheet (wait for next hourly sync)
3. Check with admin endpoint:
   ```bash
   curl https://flareweather-production.up.railway.app/admin/subscription-stats \
     -H "X-Admin-Key: YOUR_ADMIN_KEY"
   ```

Let me know which option you want to use and I can help you set it up!
