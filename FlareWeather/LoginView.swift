import SwiftUI
import UIKit
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showingOnboarding = false
    @State private var showingForgotPassword = false
    @State private var showingResetCode = false
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo/Header
                    VStack(spacing: 12) {
                        // App Logo
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        
                        VStack(spacing: 6) {
                            Text("FlareWeather")
                                .font(.interTitle)
                                .foregroundColor(Color.adaptiveText)
                            
                            Text("Discover how weather affects your health")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveMuted)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Login Form
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                            
                            ZStack(alignment: .leading) {
                                if email.isEmpty {
                                    Text("your@email.com")
                                        .font(.interBody)
                                        .foregroundColor(Color.muted)
                                        .padding(.horizontal, 12)
                                }
                                TextField("", text: $email)
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveText)
                                    .tint(Color.adaptiveText)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .textContentType(.emailAddress)
                                    .padding(12)
                            }
                            .background(Color.adaptiveBackground)
                            .cornerRadius(12)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveText)
                            
                            ZStack(alignment: .leading) {
                                if password.isEmpty {
                                    Text("Password")
                                        .font(.interBody)
                                        .foregroundColor(Color.muted)
                                        .padding(.horizontal, 12)
                                }
                                SecureField("", text: $password)
                                    .font(.interBody)
                                    .foregroundColor(Color.adaptiveText)
                                    .tint(Color.adaptiveText)
                                    .textContentType(.password)
                                    .padding(12)
                            }
                            .background(Color.adaptiveBackground)
                            .cornerRadius(12)
                        }
                        
                        Button("Forgot password?") {
                            showingForgotPassword = true
                        }
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        Button("Enter reset code") {
                            showingResetCode = true
                        }
                        .font(.interCaption)
                        .foregroundColor(Color.adaptiveMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.interCaption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Login Button
                        Button(action: {
                            print("🔘 LoginView: Button tapped!")
                            Task { @MainActor in
                                print("🔘 LoginView: Task started")
                                await login()
                                print("🔘 LoginView: Task completed")
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(Color.adaptiveText)
                                } else {
                                    Text("Log In")
                                        .font(.interBody.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        
                        // Apple Sign In Button
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
                        
                        // Signup Link
                        HStack(spacing: 8) {
                            Text("Don't have an account?")
                                .font(.interBody)
                                .foregroundColor(Color.adaptiveMuted)
                            
                            Button("Sign Up") {
                                showingOnboarding = true
                            }
                            .font(.interBody.weight(.semibold))
                            .foregroundColor(Color.adaptiveText)
                        }
                    }
                    .padding(20)
                    .cardStyle()
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .tint(Color.adaptiveText)
            .background(
                NavigationLink(
                    destination: ForgotPasswordView(),
                    isActive: $showingForgotPassword
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .background(
                NavigationLink(
                    destination: ResetPasswordCodeView(initialEmail: email),
                    isActive: $showingResetCode
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingFlowView()
                    .environmentObject(authManager)
            }
        }
        .tint(Color.adaptiveText)
        .onAppear {
            // Set placeholder text color to muted (grey) instead of blue
            UITextField.appearance().attributedPlaceholder = NSAttributedString(
                string: "",
                attributes: [NSAttributedString.Key.foregroundColor: UIColor(Color.muted)]
            )
        }
    }
    
    @MainActor
    private func login() async {
        errorMessage = nil
        isLoading = true
        print("🔐 LoginView: Starting login for \(email)")
        
        defer {
            isLoading = false
            print("🔐 LoginView: Login completed, isLoading = false")
        }
        
        do {
            try await authManager.login(email: email, password: password)
            print("✅ LoginView: Login successful, isAuthenticated: \(authManager.isAuthenticated)")
        } catch {
            print("❌ LoginView: Login error: \(error.localizedDescription)")
            print("❌ LoginView: Full error: \(error)")
            errorMessage = error.localizedDescription
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
            
            print("🍎 Apple Sign In successful:")
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
                print("✅ Apple Sign In completed successfully")
            } catch {
                print("❌ Apple Sign In error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
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
    LoginView()
}

