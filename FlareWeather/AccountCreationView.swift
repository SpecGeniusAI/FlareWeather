import SwiftUI
import AuthenticationServices

struct AccountCreationView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var onSignupSuccess: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create your account")
                        .font(.interTitle)
                        .foregroundColor(Color.adaptiveText)
                    
                    Text("We’ll save your preferences and personalize your insights.")
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                
                VStack(spacing: 20) {
                    inputField(title: "Name (optional)", placeholder: "Your name", text: $name, contentType: .name)
                    inputField(title: "Email", placeholder: "you@email.com", text: $email, contentType: .emailAddress, keyboardType: .emailAddress)
                    secureField(title: "Password", placeholder: "Create a password", text: $password)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.interCaption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: createAccount) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(Color.adaptiveText)
                            } else {
                                Text("Create Account")
                                    .font(.interBody.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity(isLoading || email.isEmpty || password.isEmpty ? 0.6 : 1)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.adaptiveMuted.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.interCaption)
                            .foregroundColor(Color.adaptiveMuted)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.adaptiveMuted.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)
                    
                    // Sign in with Apple Button
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            Task { @MainActor in
                                await handleAppleSignIn(result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .disabled(isLoading)
                }
                .padding(20)
                .cardStyle()
                .padding(.horizontal, 20)
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .navigationTitle("Account Setup")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Hide back button to prevent going back to paywall
    }
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, contentType: UITextContentType, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 12)
                }
                TextField("", text: text)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .tint(Color.adaptiveText)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .autocapitalization(contentType == .emailAddress ? .none : .words)
                    .padding(12)
            }
            .background(Color.adaptiveBackground)
            .cornerRadius(12)
        }
    }
    
    private func secureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.interBody)
                        .foregroundColor(Color.adaptiveMuted)
                        .padding(.horizontal, 12)
                }
                SecureField("", text: text)
                    .font(.interBody)
                    .foregroundColor(Color.adaptiveText)
                    .tint(Color.adaptiveText)
                    .textContentType(.password)
                    .padding(12)
            }
            .background(Color.adaptiveBackground)
            .cornerRadius(12)
        }
    }
    
    private func createAccount() {
        guard !email.isEmpty, !password.isEmpty else { return }
        errorMessage = nil
        isLoading = true
        
        Task { @MainActor in
            do {
                try await authManager.signup(email: email, password: password, name: name.isEmpty ? nil : name)
                let resolvedName = name.isEmpty ? "User" : name
                // Call onSignupSuccess which will navigate to paywall
                // This must happen immediately to prevent ContentView from switching views
                onSignupSuccess(resolvedName)
            } catch {
                errorMessage = (error as? AuthError)?.localizedDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }
    
    @MainActor
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid Apple Sign In credential"
                return
            }
            
            // Get user identifier
            let userIdentifier = appleIDCredential.user
            
            // Get identity token (JWT)
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Failed to get identity token"
                return
            }
            
            // Get authorization code (optional, for server verification)
            let authorizationCode = appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            
            // Get user info (only available on first sign in)
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            let name = fullName.flatMap { personNameComponents in
                let formatter = PersonNameComponentsFormatter()
                return formatter.string(from: personNameComponents)
            }
            
            print("🍎 Apple Sign In successful (account creation):")
            print("   User ID: \(userIdentifier)")
            print("   Email: \(email ?? "not provided")")
            print("   Name: \(name ?? "not provided")")
            
            // Send to backend
            do {
                try await authManager.signInWithApple(
                    userIdentifier: userIdentifier,
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    email: email,
                    name: name
                )
                print("✅ Apple Sign In completed successfully (account creation)")
                let resolvedName = name ?? "User"
                onSignupSuccess(resolvedName)
            } catch {
                print("❌ Apple Sign In error: \(error.localizedDescription)")
                errorMessage = (error as? AuthError)?.localizedDescription ?? error.localizedDescription
            }
            
        case .failure(let error):
            print("❌ Apple Sign In failed: \(error.localizedDescription)")
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, don't show error
                    break
                default:
                    errorMessage = "Apple Sign In failed: \(authError.localizedDescription)"
                }
            } else {
                errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationView {
        AccountCreationView(onSignupSuccess: { _ in })
            .environmentObject(AuthManager())
    }
}

