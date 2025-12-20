# Solution: Sync Existing Subscriptions

## The Problem

- 45 users signed up
- 0 subscription entitlements in database
- Webhook is configured but Apple only sends notifications for NEW subscriptions (not retroactive)
- Existing subscribers aren't showing up

## Solution Options

### Option 1: Get original_transaction_id from iOS App (Recommended)

When users subscribe in the app, we need to capture their `original_transaction_id` and send it to the backend.

**Steps:**
1. iOS app gets `original_transaction_id` from StoreKit when user subscribes
2. Send it to backend endpoint: `POST /user/link-subscription`
3. Backend stores it on User record
4. Then App Store notifications can link properly

### Option 2: Query App Store Server API (Requires API Key)

If you have App Store Connect API credentials:
- Private Key
- Key ID  
- Issuer ID
- Bundle ID

We can query Apple's API to get subscription status for users.

### Option 3: Manual Entry (Quick Fix)

For existing subscribers, manually add their `original_transaction_id` to the database, then the sync will work.

## Recommended: Option 1

I'll create an endpoint that iOS can call to link subscriptions. This way:
- New subscriptions automatically link
- Existing subscriptions can be linked when user opens app
- Everything syncs properly

Would you like me to:
1. Create the `/user/link-subscription` endpoint?
2. Or set up App Store Server API querying (if you have API credentials)?
