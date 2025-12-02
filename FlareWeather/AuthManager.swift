import Foundation
import Security

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserResponse? = nil
    @Published var accessToken: String? = nil
    @Published var isOnboardingInProgress = false  // Track if user is in onboarding flow
    
    private let authService = AuthService()
    private let tokenKey = "flareweather_access_token"
    private let userKey = "flareweather_user"
    
    init() {
        // Load saved token and user on init
        loadSavedAuth()
    }
    
    func signup(email: String, password: String, name: String?) async throws {
        let response = try await authService.signup(email: email, password: password, name: name)
        await handleAuthResponse(response)
    }
    
    func login(email: String, password: String) async throws {
        print("🔐 AuthManager: Starting login for \(email)")
        do {
            let response = try await authService.login(email: email, password: password)
            print("✅ AuthManager: Login response received")
            await handleAuthResponse(response)
            print("✅ AuthManager: Auth response handled, isAuthenticated: \(isAuthenticated)")
        } catch {
            print("❌ AuthManager: Login error: \(error)")
            throw error
        }
    }
    
    func signInWithApple(
        userIdentifier: String,
        identityToken: String,
        authorizationCode: String?,
        email: String?,
        name: String?
    ) async throws {
        let response = try await authService.signInWithApple(
            userIdentifier: userIdentifier,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            email: email,
            name: name
        )
        await handleAuthResponse(response)
    }
    
    func logout() {
        accessToken = nil
        currentUser = nil
        isAuthenticated = false
        saveToken(nil)
        saveUser(nil)
        UserDefaults.standard.set(false, forKey: "hasGeneratedDailyInsightSession")
    }
    
    private func handleAuthResponse(_ response: AuthResponse) async {
        print("📝 AuthManager: Handling auth response for \(response.email)")
        accessToken = response.access_token
        currentUser = UserResponse(
            user_id: response.user_id,
            email: response.email,
            name: response.name,
            created_at: ""
        )
        isAuthenticated = true
        print("✅ AuthManager: Set isAuthenticated = true")
        saveToken(response.access_token)
        saveUser(currentUser)
        
        // Verify token by fetching user info
        do {
            if let token = accessToken {
                let userInfo = try await authService.getCurrentUser(token: token)
                currentUser = userInfo
                saveUser(userInfo)
                print("✅ AuthManager: User info fetched successfully")
            }
        } catch {
            print("⚠️  Failed to fetch user info: \(error)")
            // Don't fail login if user info fetch fails
        }
    }
    
    private func loadSavedAuth() {
        // Load token from Keychain
        if let token = loadToken() {
            accessToken = token
            isAuthenticated = true
            
            // Load user from UserDefaults
            if let userData = UserDefaults.standard.data(forKey: userKey),
               let user = try? JSONDecoder().decode(UserResponse.self, from: userData) {
                currentUser = user
            }
            
            // Verify token is still valid
            Task {
                do {
                    if let token = accessToken {
                        let userInfo = try await authService.getCurrentUser(token: token)
                        currentUser = userInfo
                        saveUser(userInfo)
                    }
                } catch {
                    // Token invalid, logout
                    logout()
                }
            }
        }
    }
    
    func deleteAccount() async throws {
        guard let token = accessToken else {
            throw AuthError.unauthorized
        }
        try await authService.deleteAccount(token: token)
        logout()
    }
    
    // MARK: - Keychain Storage
    
    private func saveToken(_ token: String?) {
        guard let token = token else {
            // Delete token
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: tokenKey
            ]
            SecItemDelete(query as CFDictionary)
            return
        }
        
        // Save token
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
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
    
    private func saveUser(_ user: UserResponse?) {
        if let user = user,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userKey)
        }
    }
}

