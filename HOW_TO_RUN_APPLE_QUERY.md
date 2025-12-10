# How to Run the Apple Subscription Query

## Prerequisites

Make sure you have these environment variables set in Railway:
- ✅ `APP_STORE_KEY_ID` = `6ALD8NU43B` (your Key ID)
- ✅ `APP_STORE_ISSUER_ID` = (the UUID from App Store Connect)
- ✅ `APP_STORE_BUNDLE_ID` = (your app's bundle ID, e.g., `com.yourcompany.flareweather`)
- ✅ `APP_STORE_PRIVATE_KEY` = (contents of your .p8 file)

## Option 1: Run on Railway (Recommended)

### Method A: Using Railway CLI

1. **Install Railway CLI** (if you don't have it):
   ```bash
   npm i -g @railway/cli
   railway login
   ```

2. **Connect to your project**:
   ```bash
   railway link
   ```

3. **Run the script**:
   ```bash
   railway run python query_apple_subscriptions.py
   ```

### Method B: Using Railway Dashboard

1. Go to your Railway project dashboard
2. Click on your backend service
3. Go to **Settings** → **Deployments**
4. Click **"New Deployment"** or use the **"Run Command"** option
5. Enter: `python query_apple_subscriptions.py`
6. Click **Run**

### Method C: SSH into Railway Container

1. In Railway dashboard, go to your service
2. Click **"View Logs"**
3. Look for SSH connection info, or use Railway CLI:
   ```bash
   railway shell
   ```
4. Once connected, run:
   ```bash
   python query_apple_subscriptions.py
   ```

## Option 2: Run Locally (for testing)

1. **Set up environment variables**:
   ```bash
   export APP_STORE_KEY_ID="6ALD8NU43B"
   export APP_STORE_ISSUER_ID="your-issuer-id-here"
   export APP_STORE_BUNDLE_ID="com.yourcompany.flareweather"
   export APP_STORE_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXX.p8)"
   ```

2. **Install dependencies**:
   ```bash
   pip install app-store-server-library
   ```

3. **Run the script**:
   ```bash
   python query_apple_subscriptions.py
   ```

## What the Script Does

1. ✅ Checks if all credentials are set
2. ✅ Connects to Apple's App Store Server API
3. ✅ Finds all users with `original_transaction_id` in your database
4. ✅ Queries Apple's API for each user's subscription status
5. ✅ Updates `subscription_status` and `subscription_plan` in database
6. ✅ Creates/updates `SubscriptionEntitlement` records
7. ✅ Shows a summary of updated users

## Expected Output

```
🔐 Initializing App Store Server API client...

📊 Found 45 total users
✅ 1 users already have original_transaction_id

🔍 Querying subscription for user: khurrie@outlook.com (transaction: 0)

   ✅ Created entitlement: fw_plus_yearly - active
   ✅ Processed 1 subscription(s)

✅ Updated 1 users' subscription status

📊 Summary:
   Users with subscription status: 1
   Users with transaction ID: 1
```

## Troubleshooting

### "Missing App Store Connect API credentials"
- Check that all 4 environment variables are set in Railway
- Make sure `APP_STORE_PRIVATE_KEY` includes the full key with newlines

### "app-store-server-library not installed"
- The package should install automatically on Railway
- If running locally: `pip install app-store-server-library`

### "No subscription found in Apple's response"
- User might not have an active subscription
- Transaction ID might be invalid (e.g., "0" from simulator)
- Subscription might have expired

### "Error querying for user"
- Check Railway logs for detailed error
- Verify the transaction ID is valid
- Make sure you're using PRODUCTION environment (not SANDBOX)

## After Running

1. **Check the output** - see how many users were updated
2. **Verify in database** - check `User.subscription_status` and `SubscriptionEntitlement` table
3. **Check Google Sheet** - wait for next hourly sync to see updated data
4. **Verify with admin endpoint**:
   ```bash
   curl https://flareweather-production.up.railway.app/admin/subscription-stats \
     -H "X-Admin-Key: YOUR_ADMIN_KEY"
   ```

## Schedule Regular Runs (Optional)

You can set this up to run automatically:

1. **Using Railway Cron** (if available):
   - Add a scheduled task to run daily/weekly

2. **Using GitHub Actions**:
   - Create a workflow that runs the script on a schedule

3. **Manual runs**:
   - Just run it whenever you need updated subscription data

Let me know if you need help running it!
