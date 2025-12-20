# Quick Start: Link Subscriptions

## What You Need to Do

1. **Create `SubscriptionLinkingService.swift`** - Copy the code from `SUBSCRIPTION_LINKING_GUIDE.md` Step 2
2. **Update `SubscriptionManager.swift`** - Add the linking calls (see guide Step 3)
3. **Test it** - Subscribe in the app and verify it works

## The Code You Need

### 1. Create `FlareWeather/SubscriptionLinkingService.swift`

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
    
    func linkSubscription(originalTransactionId: String, productId: String?) async throws {
        guard let url = URL(string: "\(baseURL)/user/link-subscription") else {
            throw NSError(domain: "SubscriptionLinkingService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
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

### 2. Add Helper Method to `SubscriptionManager.swift`

Add this helper method to your `SubscriptionManager` class:

```swift
// ✅ NEW: Helper method to get originalTransactionId from StoreKit
private func linkSubscriptionFromStoreKit(productId: String) async {
    // Query StoreKit for current entitlements
    for await result in Transaction.currentEntitlements {
        do {
            let transaction = try checkVerified(result)
            
            // Check if this transaction matches the product
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
                }
                break // Found matching transaction
            }
        } catch {
            print("⚠️ Transaction verification error: \(error.localizedDescription)")
        }
    }
}
```

### 3. Update `purchase` Method in `SubscriptionManager.swift`

Find the `purchase(package:)` method and add this after the purchase succeeds:

```swift
// After: customerInfo = info
// After: updateEntitlementStatus(from: info)

// ✅ NEW: Link subscription to backend
Task {
    await linkSubscriptionFromStoreKit(productId: package.storeProduct.productIdentifier)
}
```

### 4. Update `refreshCustomerInfo` Method in `SubscriptionManager.swift`

Find the `refreshCustomerInfo()` method and add this after updating entitlement status:

```swift
// After: updateEntitlementStatus(from: info)

// ✅ NEW: Link subscription if user has active subscription
if isProUser, let activeEntitlement = info.entitlements[entitlementID] {
    let productId = activeEntitlement.productIdentifier
    Task {
        await linkSubscriptionFromStoreKit(productId: productId)
    }
}
```

## Testing

1. **Build and run the app**
2. **Subscribe** (or restore if you already have a subscription)
3. **Check Xcode console** - You should see: `✅ Linked subscription: [transaction_id]`
4. **Check backend logs** (Railway) - Should see `/user/link-subscription` endpoint called
5. **Wait for Google Sheet sync** (hourly) - Subscription status should appear

## Troubleshooting

- **"Not authenticated"** → User needs to be logged in
- **No console message** → Check that `linkSubscriptionFromStoreKit` is being called
- **Still shows "N/A"** → Wait for next hourly Google Sheet sync

## Full Details

See `SUBSCRIPTION_LINKING_GUIDE.md` for complete step-by-step instructions.
