# Free Trial Subscription Linking

## Issue
User signed up with a monthly subscription (free trial) but subscription isn't showing as linked.

## How Free Trials Work
- Free trials are still **active subscriptions** in App Store
- RevenueCat should detect them as `isActive == true`
- The linking code should work for free trials

## Why It Might Not Be Linked

1. **App wasn't reopened after subscribing**
   - The linking happens in `refreshCustomerInfo()` which runs on app launch
   - If they subscribed and didn't close/reopen the app, linking might not have run

2. **Linking code didn't detect subscription**
   - Check if `isProUser` is true
   - Check if `activeEntitlement` exists

3. **StoreKit transaction not available yet**
   - Sometimes there's a delay between purchase and transaction availability

## Solution

**Ask the user to:**
1. Force close the app completely
2. Reopen the app
3. This will trigger `refreshCustomerInfo()` which should link the subscription

## Check Status

Run this to check if linking happened:
```bash
railway ssh -- "/opt/venv/bin/python -c \"
from database import SessionLocal, User
db = SessionLocal()
user = db.query(User).filter(User.email == 'kurtis@specgenius.co').first()
if user:
    print(f'original_transaction_id: {user.original_transaction_id}')
    print(f'subscription_status: {user.subscription_status}')
\""
```

If `original_transaction_id` is still None after reopening, there might be an issue with the linking code.

