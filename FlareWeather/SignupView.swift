import SwiftUI
import UIKit
import AuthenticationServices

struct SignupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var authService = AuthService()
    @FocusState private var focusedField: Field?
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    enum Field {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    signupForm
                }
                .padding(.vertical)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.adaptiveCardBackground.opacity(0.95), for: .navigationBar)
            .tint(Color.adaptiveText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .tint(Color.adaptiveText)
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            Image(colorScheme == .dark ? "LogoLight" : "LogoDark")
                .resizable()
                .scaledToFit()
                .frame(height: 32)
            
            Text("Create your account to get started")
                .font(.interBody)
                .foregroundColor(Color.adaptiveMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
    
    private var signupForm: some View {
        VStack(spacing: 20) {
            nameField
            emailField
            passwordField
            confirmPasswordField
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.interCaption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            signupButton
            dividerView
            appleSignInButton
        }
        .padding(20)
        .background(cardBackground)
        .padding(.horizontal)
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name (Optional)")
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            TextField("Your name", text: $name)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .tint(Color.adaptiveText)
                .textContentType(.name)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .email
                }
                .padding(12)
                .background(Color.adaptiveBackground)
                .cornerRadius(12)
                .allowsHitTesting(true)
        }
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            TextField("your@email.com", text: $email)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .tint(Color.adaptiveText)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .password
                }
                .padding(12)
                .background(Color.adaptiveBackground)
                .cornerRadius(12)
                .allowsHitTesting(true)
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            SecureField("Password (min 8 characters)", text: $password)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .tint(Color.adaptiveText)
                .textContentType(.newPassword)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }
                .padding(12)
                .background(Color.adaptiveBackground)
                .cornerRadius(12)
                .allowsHitTesting(true)
        }
    }
    
    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirm Password")
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
            
            SecureField("Confirm password", text: $confirmPassword)
                .font(.interBody)
                .foregroundColor(Color.adaptiveText)
                .tint(Color.adaptiveText)
                .textContentType(.newPassword)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.done)
                .onSubmit {
                    if isFormValid {
                        Task { @MainActor in
                            await signup()
                        }
                    }
                }
                .padding(12)
                .background(Color.adaptiveBackground)
                .cornerRadius(12)
                .allowsHitTesting(true)
        }
    }
    
    private var signupButton: some View {
        Button(action: {
            Task {
                await signup()
            }
        }) {
            HStack {
                if authService.isLoading || isLoading {
                    ProgressView()
                        .tint(Color.adaptiveText)
                } else {
                    Text("Sign Up")
                        .font(.interBody.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(authService.isLoading || isLoading || !isFormValid)
    }
    
    private var dividerView: some View {
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
    }
    
    private var appleSignInButton: some View {
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
        .disabled(authService.isLoading || isLoading)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                colorScheme == .dark
                    ? AnyShapeStyle(Color.adaptiveCardBackground)
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(hex: "#697797").opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private func signup() async {
        errorMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        // Validate passwords match
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        // Validate password length
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        do {
            try await authManager.signup(email: email, password: password, name: name.isEmpty ? nil : name)
            dismiss()
        } catch {
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
            
            print("🍎 Apple Sign In successful (signup):")
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
                print("✅ Apple Sign In completed successfully (signup)")
                dismiss()
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
    SignupView()
}

