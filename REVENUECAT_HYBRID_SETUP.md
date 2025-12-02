# RevenueCat Hybrid Setup

## Overview

Your app now uses a **hybrid approach**:
- ✅ **Custom Paywall UI** - Your beautiful `PaywallPlaceholderView` stays exactly as is
- ✅ **RevenueCat Backend** - All purchases are tracked in RevenueCat dashboard for analytics

## How It Works

### 1. Custom UI (Unchanged)
- `PaywallPlaceholderView` continues to work exactly as before
- Uses StoreKit `Product` objects for display
- Your custom design, benefits, and flow remain intact

### 2. RevenueCat Tracking (New)
- When a user purchases, the purchase routes through RevenueCat
- RevenueCat automatically tracks:
  - Purchase events
  - Subscription status
  - Revenue metrics
  - Customer lifetime value
  - Churn analysis
- All visible in your RevenueCat dashboard in real-time

### 3. Purchase Flow

```
User taps "Subscribe" in PaywallPlaceholderView
    ↓
SubscriptionManager.purchase(Product) is called
    ↓
RevenueCat finds matching Package for that Product
    ↓
Purchase goes through RevenueCat (tracked in dashboard)
    ↓
RevenueCat handles StoreKit purchase
    ↓
Entitlement checked via RevenueCat
    ↓
User gets access + data appears in dashboard
```

## What Changed

### SubscriptionManager.swift
- ✅ Still fetches StoreKit `Product` objects for UI
- ✅ `purchase(Product)` method routes through RevenueCat
- ✅ RevenueCat tracks all purchases automatically
- ✅ Entitlement checking via RevenueCat's `CustomerInfo`
- ✅ All existing methods work the same way

### PaywallPlaceholderView.swift
- ✅ **No changes needed** - works exactly as before
- ✅ Still uses `subscriptionManager.products`
- ✅ Still calls `subscriptionManager.purchase(product)`

### SettingsView.swift
- ✅ Uses your custom `PaywallPlaceholderView`
- ✅ RevenueCat's `CustomerCenterView` for subscription management

## Benefits

1. **Keep Your Design** - No need to redesign your paywall
2. **Real-time Dashboard** - See all metrics in RevenueCat
3. **Analytics** - Track conversion, MRR, churn automatically
4. **Webhooks** - Get notified of purchase events
5. **Cross-platform** - Same dashboard for iOS, Android, web
6. **Customer Management** - Grant promotional subscriptions, see history

## RevenueCat Dashboard Features

Once purchases start flowing, you'll see:
- 📊 **Revenue Metrics** - MRR, ARR, LTV
- 👥 **Customer Analytics** - Conversion rates, churn
- 📈 **Charts** - Revenue over time, subscriber growth
- 🔔 **Webhooks** - Real-time purchase notifications
- 🎁 **Promotions** - Grant free trials, discounts
- 📱 **Customer Profiles** - See individual purchase history

## Setup Checklist

1. ✅ Add RevenueCat package via SPM
2. ✅ Replace test API key with production key in `FlareWeatherApp.swift`
3. ✅ Set up products in RevenueCat Dashboard:
   - `fw_plus_monthly`
   - `fw_plus_yearly`
   - `fw_lifetime` (if using)
4. ✅ Create entitlement: `FlareWeather Pro`
5. ✅ Create offering "default" with packages
6. ✅ Upload Apple IAP key to RevenueCat

## Testing

1. Make a test purchase through your custom paywall
2. Check RevenueCat dashboard - purchase should appear immediately
3. Verify entitlement status updates correctly
4. Test restore purchases functionality

## Notes

- Your custom paywall UI is completely unchanged
- All purchases automatically flow through RevenueCat
- RevenueCat handles receipt validation server-side
- You get all the benefits of RevenueCat without changing your UI

