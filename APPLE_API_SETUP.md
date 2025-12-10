# Setup: Query Apple App Store Server API

To pull current subscriber info from Apple, you need App Store Connect API credentials.

## Step 1: Get App Store Connect API Credentials

1. **Go to App Store Connect**
   - Visit: https://appstoreconnect.apple.com
   - Sign in with your Apple Developer account

2. **Create an API Key**
   - Go to: **Users and Access** → **Keys** tab
   - Click **Generate API Key** (+ button)
   - Name it: "FlareWeather Subscription Query"
   - Select role: **App Manager** or **Admin**
   - Click **Generate**

3. **Download the Key**
   - Click **Download API Key** (you can only download once!)
   - Save the `.p8` file securely
   - Copy the **Key ID** (shown on the page)
   - Copy the **Issuer ID** (shown at top of Keys page)

4. **Get Your Bundle ID**
   - Go to: **My Apps** → Select FlareWeather
   - Copy the **Bundle ID** (e.g., `com.yourcompany.flareweather`)

## Step 2: Add Credentials to Railway

Add these environment variables to your Railway backend service:

1. **APP_STORE_KEY_ID** = (the Key ID you copied)
2. **APP_STORE_ISSUER_ID** = (the Issuer ID you copied)
3. **APP_STORE_BUNDLE_ID** = (your app's bundle ID)
4. **APP_STORE_PRIVATE_KEY** = (contents of the .p8 file)

### To get the private key content:

```bash
# On your Mac, run:
cat /path/to/your/AuthKey_XXXXXXXXXX.p8
```

Copy the entire output (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`) and paste it as the `APP_STORE_PRIVATE_KEY` value in Railway.

**Important:** Keep the newlines in the key! Railway environment variables support multi-line values.

## Step 3: Install the Library

Add to your `requirements.txt`:

```
app-store-server-library
```

Or install locally:

```bash
pip install app-store-server-library
```

## Step 4: Run the Query Script

Once credentials are set up, you can run:

```bash
python query_apple_subscriptions.py
```

This will:
1. Query Apple's API for all users who have `original_transaction_id`
2. Update their subscription status in the database
3. Create/update `SubscriptionEntitlement` records

## Limitations

⚠️ **Important:** This only works for users who already have `original_transaction_id` stored. 

For users who haven't opened the app yet, we can't query their subscription status because we don't have their transaction ID.

## Alternative: Export from App Store Connect

If you want to see all subscribers (even without transaction IDs), you can:

1. Go to App Store Connect → **Sales and Trends**
2. Export subscription data
3. Manually match users by email (if you have their emails in the export)

## Next Steps

Once you have the credentials set up in Railway, I can help you:
1. Run the query script
2. Update the code to handle the API response properly
3. Set up automatic syncing

Let me know when you have the credentials ready!
