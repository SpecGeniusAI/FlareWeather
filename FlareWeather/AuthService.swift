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

struct UserResponse: Codable {
    let user_id: String
    let email: String
    let name: String?
    let created_at: String
}

@MainActor
final class AuthService: ObservableObject {
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
        
        // Default: use localhost for development
        let defaultURL = "http://localhost:8000"
        print("⚠️ AuthService: Using default backend URL: \(defaultURL)")
        print("   To change: Set BACKEND_URL environment variable in Xcode scheme or add BackendURL to Info.plist")
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
        
        print("📤 Login request to: \(url)")
        print("📤 Login request body: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        
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
    }
    
    func getCurrentUser(token: String) async throws -> UserResponse {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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

