import Foundation

struct SignupRequest: Codable {
    let email: String
    let password: String
    let name: String?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    let user_id: String
    let email: String
    let name: String?
}

struct UserResponse: Codable, Equatable {
    let user_id: String
    let email: String
    let name: String?
    let created_at: String
    let has_access: Bool?
    let access_type: String?
    let access_expires_at: String?
    let access_required: Bool?
    let access_expired: Bool?
    let logout_message: String?
    
    static func == (lhs: UserResponse, rhs: UserResponse) -> Bool {
        return lhs.user_id == rhs.user_id &&
               lhs.email == rhs.email &&
               lhs.name == rhs.name &&
               lhs.created_at == rhs.created_at &&
               lhs.has_access == rhs.has_access &&
               lhs.access_type == rhs.access_type &&
               lhs.access_expires_at == rhs.access_expires_at &&
               lhs.access_required == rhs.access_required &&
               lhs.access_expired == rhs.access_expired &&
               lhs.logout_message == rhs.logout_message
    }
}

struct ForgotPasswordResponsePayload: Codable {
    let message: String
}

struct ResetPasswordResponsePayload: Codable {
    let success: Bool
}

struct ServerErrorResponse: Codable {
    let detail: String?
    let error: String?
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Backend URL - configurable via environment variable or Info.plist
    // For local testing, use: "http://localhost:8000"
    // For production, use: "https://flareweather-production.up.railway.app"
    private var baseURL: String {
        // First try to get from environment variable (set in Xcode scheme)
        if let url = ProcessInfo.processInfo.environment["BACKEND_URL"], !url.isEmpty {
            print("✅ AuthService: Backend URL found in environment variable: \(url)")
            return url
        }
        
        // Second, try to get from Info.plist
        if let url = Bundle.main.infoDictionary?["BackendURL"] as? String, !url.isEmpty {
            print("✅ AuthService: Backend URL found in Info.plist: \(url)")
            return url
        }
        
        // Default: use production Railway URL
        let defaultURL = "https://flareweather-production.up.railway.app"
        print("✅ AuthService: Using production backend URL: \(defaultURL)")
        return defaultURL
    }
    
    func signup(email: String, password: String, name: String?) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/signup") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let requestBody = SignupRequest(email: email, password: password, name: name)
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(requestBody)
        } catch {
            throw AuthError.serverError("Failed to encode request data")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30.0  // 30 second timeout
        
        print("📤 Signup request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 Signup response status: \(http.statusCode)")
        
        guard (200..<300).contains(http.statusCode) else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorData["detail"] {
                throw AuthError.serverError(detail)
            }
            throw AuthError.serverError("Signup failed")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        print("✅ Signup successful: \(authResponse.email)")
        return authResponse
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let requestBody = LoginRequest(email: email, password: password)
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(requestBody)
        } catch {
            throw AuthError.serverError("Failed to encode request data")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30.0  // 30 second timeout
        
        print("📤 Login request to: \(url)")
        print("📤 Login request body: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        
        // Retry logic for network errors (up to 3 attempts)
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    print("❌ AuthService: Invalid response type")
                    throw URLError(.badServerResponse)
                }
                
                print("📥 Login response status: \(http.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Login response body: \(responseString)")
                }
                
                guard (200..<300).contains(http.statusCode) else {
                    if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                       let detail = errorData["detail"] {
                        print("❌ AuthService: Server error: \(detail)")
                        throw AuthError.serverError(detail)
                    }
                    let errorMessage = "Login failed with status \(http.statusCode)"
                    print("❌ AuthService: \(errorMessage)")
                    throw AuthError.serverError(errorMessage)
                }
                
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                print("✅ Login successful: \(authResponse.email)")
                return authResponse
            } catch let error as URLError {
                lastError = error
                print("❌ AuthService: Network error on attempt \(attempt)/3: \(error.localizedDescription)")
                
                // Check if it's a retryable error
                let retryableErrors: [URLError.Code] = [
                    .cannotConnectToHost,
                    .cannotFindHost,
                    .networkConnectionLost,
                    .notConnectedToInternet,
                    .timedOut,
                    .dnsLookupFailed
                ]
                
                if retryableErrors.contains(error.code) && attempt < 3 {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt - 1))
                    print("🔄 AuthService: Retrying in \(delay) seconds...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Convert to user-friendly error message
                    let userMessage: String
                    switch error.code {
                    case .cannotConnectToHost, .cannotFindHost:
                        userMessage = "Couldn't connect to server. Please check your internet connection and try again."
                    case .notConnectedToInternet, .networkConnectionLost:
                        userMessage = "No internet connection. Please check your network settings."
                    case .timedOut:
                        userMessage = "Connection timed out. The server may be busy. Please try again."
                    case .dnsLookupFailed:
                        userMessage = "Couldn't reach server. Please check your internet connection."
                    default:
                        userMessage = "Network error: \(error.localizedDescription)"
                    }
                    throw AuthError.serverError(userMessage)
                }
            } catch {
                // Non-network errors (like decoding errors) shouldn't be retried
                throw error
            }
        }
        
        // If we get here, all retries failed
        if let urlError = lastError as? URLError {
            let userMessage: String
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost:
                userMessage = "Couldn't connect to server after multiple attempts. Please check your internet connection."
            case .notConnectedToInternet, .networkConnectionLost:
                userMessage = "No internet connection. Please check your network settings."
            case .timedOut:
                userMessage = "Connection timed out. The server may be busy. Please try again later."
            default:
                userMessage = "Network error: \(urlError.localizedDescription)"
            }
            throw AuthError.serverError(userMessage)
        }
        
        throw AuthError.serverError("Login failed. Please try again.")
    }
    
    func getCurrentUser(token: String) async throws -> UserResponse {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0  // 30 second timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.unauthorized
        }
        
        return try JSONDecoder().decode(UserResponse.self, from: data)
    }
    
    func signInWithApple(
        userIdentifier: String,
        identityToken: String,
        authorizationCode: String?,
        email: String?,
        name: String?
    ) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/apple") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let requestBody: [String: Any?] = [
            "user_identifier": userIdentifier,
            "identity_token": identityToken,
            "authorization_code": authorizationCode,
            "email": email,
            "name": name
        ]
        
        // Remove nil values
        let cleanedBody = requestBody.compactMapValues { $0 }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: cleanedBody) else {
            throw AuthError.serverError("Failed to encode request data")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30.0  // 30 second timeout
        
        print("📤 Apple Sign In request to: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 Apple Sign In response status: \(http.statusCode)")
        
        guard (200..<300).contains(http.statusCode) else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let detail = errorData["detail"] {
                throw AuthError.serverError(detail)
            }
            throw AuthError.serverError("Apple Sign In failed")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        print("✅ Apple Sign In successful: \(authResponse.email)")
        return authResponse
    }
    
    func deleteAccount(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/delete") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.serverError("Failed to delete account. Please try again later.")
        }
    }
    
    func forgotPassword(email: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/forgot-password") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let payload = ["email": email]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AuthError.serverError("Failed to encode reset request.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 20.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            if let errorDetail = try? JSONDecoder().decode(ServerErrorResponse.self, from: data),
               let detail = errorDetail.detail ?? errorDetail.error {
                throw AuthError.serverError(detail)
            }
            throw AuthError.serverError("Unable to request password reset.")
        }
        
        // Decode to ensure backend returned expected structure (optional)
        _ = try? JSONDecoder().decode(ForgotPasswordResponsePayload.self, from: data)
    }
    
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        guard let url = URL(string: "\(baseURL)/auth/reset-password") else {
            throw URLError(.badURL)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let payload: [String: String] = [
            "email": email,
            "code": code,
            "new_password": newPassword
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw AuthError.serverError("Failed to encode reset data.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 20.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200..<300).contains(http.statusCode) else {
            if let errorDetail = try? JSONDecoder().decode(ServerErrorResponse.self, from: data),
               let detail = errorDetail.detail ?? errorDetail.error {
                throw AuthError.serverError(detail)
            }
            throw AuthError.serverError("That code is incorrect or has expired.")
        }
        
        let resetResponse = try JSONDecoder().decode(ResetPasswordResponsePayload.self, from: data)
        if resetResponse.success == false {
            throw AuthError.serverError("That code is incorrect or has expired.")
        }
    }
}

enum AuthError: LocalizedError {
    case serverError(String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Unauthorized. Please log in again."
        }
    }
}

