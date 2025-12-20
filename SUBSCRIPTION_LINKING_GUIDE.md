# Step-by-Step Guide: Link Subscriptions to Users

## The Problem
- Users are subscribing, but their `original_transaction_id` isn't being stored
- Without this, App Store notifications can't link to user accounts
- Result: All subscriptions show "N/A" in Google Sheet

## The Solution
We created a new endpoint: `POST /user/link-subscription`

When the iOS app calls this endpoint with the user's `original_transaction_id`, it:
1. Stores it on the User record
2. Links to existing SubscriptionEntitlement (if any)
3. Creates new entitlement record (if needed)
4. Updates subscription_status and subscription_plan

---

## Step 1: Get original_transaction_id from StoreKit

In your iOS app, you need to get the `original_transaction_id` from StoreKit transactions.

### Option A: From StoreKit directly (Recommended)
When a user subscribes, StoreKit provides a `Transaction` object with `originalID` property.
**Note:** Even if you use RevenueCat, you'll need to query StoreKit to get `originalTransactionId` as RevenueCat doesn't expose it directly.

### Option B: From RevenueCat (Limited)
RevenueCat doesn't directly expose `originalTransactionId` in their SDK. You'll need to query StoreKit transactions separately.

---

## Step 2: Create a Service Function in iOS

Add this to your iOS app (create a new file or add to existing service):

```swift
import Foundation

struct LinkSubscriptionRequest: Codable {
    let original_transaction_id: String
    let product_id: String?
}

struct LinkSubscriptionResponse: Codable {
    let success: Bool
    let message: String
    let subscription_status: String?
    let subscription_plan: String?
}

class SubscriptionLinkingService {
    static let shared = SubscriptionLinkingService()
    
    private var baseURL: String {
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"], !url.isEmpty {
            return url
        }
        if let url = Bundle.main.infoDictionary?["BackendURL"] as? String, !url.isEmpty {
            return url
        }
        return "https://flareweather-production.up.railway.app"
    }
    
    /// Link subscription to user account
    /// Call this when:
    /// 1. User completes a purchase
    /// 2. App detects an active subscription on launch
    func linkSubscription(originalTransactionId: String, productId: String?) async throws {
        guard let url = URL(string: "\(baseURL)/user/link-subscription") else {
            throw NSError(domain: "SubscriptionLinkingService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Get auth token from AuthManager
        guard let authToken = AuthManager.shared.accessToken else {
            throw NSError(domain: "SubscriptionLinkingService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let body = LinkSubscriptionRequest(
            original_transaction_id: originalTransactionId,
            product_id: productId
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SubscriptionLinkingService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SubscriptionLinkingService", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        let result = try JSONDecoder().decode(LinkSubscriptionResponse.self, from: data)
        print("✅ Subscription linked: \(result.message)")
    }
}
```

---

## Step 3: Update SubscriptionManager.swift

Add code to call the linking service when:
1. **Purchase completes**
2. **App detects active subscription**

### In `SubscriptionManager.swift`, update the `purchase` method:

```swift
func purchase(package: Package) async {
    isLoading = true
    errorMessage = nil
    
    defer {
        isLoading = false
    }
    
    do {
        let (_, info, _) = try await Purchases.shared.purchase(package: package)
        customerInfo = info
        updateEntitlementStatus(from: info)
        
        // ✅ NEW: Get originalTransactionId from StoreKit and link to backend
        // RevenueCat doesn't expose originalTransactionId, so we query StoreKit
        Task {
            await linkSubscriptionFromStoreKit(productId: package.storeProduct.productIdentifier)
        }
        
        print("✅ Purchase successful")
    } catch {
        // ... existing error handling
    }
}

// ✅ NEW: Helper method to get originalTransactionId from StoreKit
private func linkSubscriptionFromStoreKit(productId: String) async {
    // Query StoreKit for current entitlements
    for await result in Transaction.currentEntitlements {
        do {
            let transaction = try checkVerified(result)
            
            // Check if this transaction matches the product we just purchased
            if transaction.productID == productId || 
               transaction.productID.contains(productId) ||
               productId.contains(transaction.productID) {
                
                let originalTransactionId = String(transaction.originalID)
                
                // Link it to backend
                do {
                    try await SubscriptionLinkingService.shared.linkSubscription(
                        originalTransactionId: originalTransactionId,
                        productId: transaction.productID
                    )
                    print("✅ Linked subscription: \(originalTransactionId)")
                } catch {
                    print("⚠️ Failed to link subscription: \(error.localizedDescription)")
                    // Don't fail - just log the error
                }
                break // Found matching transaction, we're done
            }
        } catch {
            print("⚠️ Transaction verification error: \(error.localizedDescription)")
        }
    }
}
```

### Also update `refreshCustomerInfo` to link existing subscriptions:

```swift
func refreshCustomerInfo() async {
    isLoading = true
    errorMessage = nil
    
    defer {
        isLoading = false
    }
    
    do {
        let info = try await Purchases.shared.customerInfo()
        customerInfo = info
        updateEntitlementStatus(from: info)
        
        // ✅ NEW: Link subscription if user has active subscription
        // Get originalTransactionId from StoreKit (RevenueCat doesn't expose it)
        if isProUser, let activeEntitlement = info.entitlements[entitlementID] {
            let productId = activeEntitlement.productIdentifier
            Task {
                await linkSubscriptionFromStoreKit(productId: productId)
            }
        }
        
        print("✅ Customer info refreshed - isProUser: \(isProUser)")
    } catch {
        // ... existing error handling
    }
}
```

**Note:** The `linkSubscriptionFromStoreKit` helper method is defined in the `purchase` method section above. Make sure to add it to your `SubscriptionManager` class.

---

## Step 5: Test It

1. **Test with a new subscription:**
   - Subscribe in the app
   - Check backend logs to see if `/user/link-subscription` was called
   - Check database: `User.original_transaction_id` should be set

2. **Test with existing subscribers:**
   - When they open the app, `refreshCustomerInfo()` should call the linking service
   - Their subscription should link automatically

3. **Verify in Google Sheet:**
   - Wait for next hourly sync
   - Check if subscription_status is now populated

---

## Step 6: Handle StoreKit Fallback

If you're using StoreKit fallback (when RevenueCat isn't available), you'll need to get `original_transaction_id` from StoreKit transactions:

```swift
// In checkEntitlementsViaStoreKit or purchaseViaStoreKit
for await result in Transaction.currentEntitlements {
    do {
        let transaction = try checkVerified(result)
        // transaction.originalID is the original_transaction_id
        let originalTransactionId = String(transaction.originalID)
        
        // Link it
        try await SubscriptionLinkingService.shared.linkSubscription(
            originalTransactionId: originalTransactionId,
            productId: transaction.productID
        )
    } catch {
        // Handle error
    }
}
```

---

## Troubleshooting

### "Not authenticated" error
- Make sure you're getting the auth token correctly
- Check that the token is valid and not expired

### "User not found" error
- The endpoint uses `get_current_user` which requires a valid JWT token
- Make sure the user is logged in

### original_transaction_id is nil
- RevenueCat: Check how to get `originalTransactionId` from `CustomerInfo` or `Transaction`
- StoreKit: Use `transaction.originalID`

### Still showing "N/A" in Google Sheet
- Wait for next hourly sync (or trigger manually)
- Check backend logs for errors
- Verify `original_transaction_id` is stored in database

---

## Next Steps

1. ✅ Backend endpoint is ready (`POST /user/link-subscription`)
2. ⏳ Add `SubscriptionLinkingService` to iOS app
3. ⏳ Update `SubscriptionManager` to call linking service
4. ⏳ Test with new subscription
5. ⏳ Test with existing subscribers (they'll auto-link on next app open)
6. ⏳ Verify in Google Sheet after sync

---

## Questions?

- **Q: Do I need to call this every time?**
  - A: No, just once per subscription. The backend stores it permanently.

- **Q: What if the user has multiple subscriptions?**
  - A: The `original_transaction_id` is unique per user's subscription. Each subscription has its own.

- **Q: Will this work for existing subscribers?**
  - A: Yes! When they open the app, `refreshCustomerInfo()` will detect their subscription and link it.

- **Q: Do I need the shared secret?**
  - A: The shared secret is for verifying App Store notifications. For linking, you just need the `original_transaction_id` from StoreKit/RevenueCat.
