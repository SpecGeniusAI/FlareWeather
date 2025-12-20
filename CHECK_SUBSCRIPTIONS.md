# How to Check Subscription Data

## Step 1: Check Backend Service Logs (Not PostgreSQL)

1. **Go to Railway Dashboard**
2. **Click on your BACKEND service** (named "FlareWeather" - the one running your FastAPI app, NOT the PostgreSQL service)
3. **Click "Deployments" tab**
4. **Click the latest deployment**
5. **Click "Logs" tab**
6. **Search for**: `App Store notification` or `INITIAL_BUY` or `DID_RENEW`

**What you're looking for:**
- Messages like: `📨 Stored App Store notification`
- Messages like: `✅ Updated user email@example.com: subscription_status=active`
- Messages like: `INITIAL_BUY` or `DID_RENEW`

## Step 2: Check Database Directly (Alternative)

If you want to check what subscription data exists in the database, you can run the check script:

**Option A: Run locally (if you have database access)**
```bash
python3 check_subscriptions.py
```

**Option B: Check via Railway CLI or Database Admin**

Or I can create an admin endpoint to check this.

## Step 3: Check What We Found

Based on what we find:
- **If you see App Store notifications in logs**: Notifications are working, we just need to link users
- **If you see NO notifications**: The webhook might not be configured in App Store Connect
- **If you see entitlements in database but no users linked**: We need to link them

Let me know what you find in the **backend service logs** (not PostgreSQL logs)!
