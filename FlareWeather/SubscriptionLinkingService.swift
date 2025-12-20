import Foundation
import Security

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
    
    private let tokenKey = "flareweather_access_token"
    
    private var baseURL: String {
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"], !url.isEmpty {
            return url
        }
        if let url = Bundle.main.infoDictionary?["BackendURL"] as? String, !url.isEmpty {
            return url
        }
        return "https://flareweather-production.up.railway.app"
    }
    
    /// Load auth token from Keychain (same storage AuthManager uses)
    private func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func linkSubscription(originalTransactionId: String, productId: String?) async throws {
        guard let url = URL(string: "\(baseURL)/user/link-subscription") else {
            throw NSError(domain: "SubscriptionLinkingService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        guard let authToken = loadToken() else {
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
